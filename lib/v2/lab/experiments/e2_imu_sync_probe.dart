import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// E2 — Gyro <-> camera time-sync probe.
///
/// Logs gyroscope samples alongside camera frames and checks whether an
/// IMU-predicted image-plane shift correlates with the OBSERVED shift of a
/// tracked bright spot (wave the phone at a light source). Reports the gyro
/// sample rate, mean gyro-to-frame time offset, and a 2x2 Pearson-correlation
/// matrix between the two gyro axes (gx, gy) and the two observed shift axes
/// (horizontal, vertical) — this lets the correct device axis mapping reveal
/// itself empirically instead of assuming one.
///
/// Diagnostic only: the centroid tracker here is a minimal, standalone
/// implementation for this experiment, not the frozen Vision Engine's Module 7
/// localizer (see docs/architecture/2026-06-30-vision-engine-design.md).
/// Horizontal field of view is an ASSUMED constant (not calibrated) — shift
/// predictions are for correlation/trend purposes only.
class E2ImuSyncProbeScreen extends StatefulWidget {
  const E2ImuSyncProbeScreen({super.key});

  @override
  State<E2ImuSyncProbeScreen> createState() => _E2ImuSyncProbeScreenState();
}

class _GyroSample {
  const _GyroSample(this.tMs, this.x, this.y, this.z);
  final int tMs;
  final double x; // rad/s
  final double y;
  final double z;
}

class _Centroid {
  const _Centroid(this.x, this.y); // normalized 0..1
  final double x;
  final double y;
}

class _E2ImuSyncProbeScreenState extends State<E2ImuSyncProbeScreen>
    with WidgetsBindingObserver {
  /// Assumed horizontal field of view of the rear camera at ResolutionPreset.low.
  /// NOT calibrated — used only to convert angular rate into an expected
  /// fractional image shift for the correlation check.
  static const double _assumedHFovDeg = 65.0;

  CameraController? _controller;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  bool _running = false;
  bool _busyFrame = false;
  String? _error;

  final List<_GyroSample> _gyroBuffer = [];
  static const int _maxGyroBuffer = 400;

  int? _prevFrameMs;
  _Centroid? _prevCentroid;
  int _frameCount = 0;
  int _framesWithSpot = 0;
  int _gyroCount = 0;
  int _startMs = 0;
  double _meanGyroFrameOffsetMs = 0;
  String? _gyroWarning;
  Timer? _gyroWatchdog;

  // Paired samples for correlation: predicted (from gx/gy) vs actual shift.
  final List<double> _gx = [];
  final List<double> _gy = [];
  final List<double> _shiftX = [];
  final List<double> _shiftY = [];
  static const int _maxPairs = 400;

  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _gyroWatchdog?.cancel();
    _gyroSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _gyroWarning = null;
    });
    try {
      final granted = (await Permission.camera.request()).isGranted;
      if (!granted) {
        setState(() => _error = 'Camera permission denied.');
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available.');
        return;
      }
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();

      _reset();
      // Set running BEFORE subscribing to either stream so no early event
      // from either source can be dropped by the `!_running` guard.
      _running = true;
      await controller.startImageStream(_onImage);
      try {
        _gyroSub = gyroscopeEventStream().listen(
          _onGyro,
          onError: (Object err) {
            if (!mounted) return;
            setState(() => _error = 'Gyroscope stream error: $err');
          },
          cancelOnError: false,
        );
      } catch (e) {
        // Constructing/subscribing to the stream threw synchronously.
        setState(() => _error = 'Failed to subscribe to gyroscope: $e');
      }
      _uiTimer = Timer.periodic(
          const Duration(milliseconds: 250), (_) => _refreshUi());
      // Watchdog: if no gyro callback has fired within 3s of a running camera
      // stream, the platform channel is not delivering events at all -- most
      // likely a stale native build (plugin added after last full reinstall;
      // hot reload/restart does not re-register new native plugins) or the
      // device has no hardware gyroscope. Surface this explicitly instead of
      // leaving the user to interpret a silent "0.0".
      _gyroWatchdog = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_running) return;
        if (_gyroCount == 0) {
          setState(() {
            _gyroWarning = 'No gyroscope events received after 3s (camera is '
                'running). Likely cause: the app needs a FULL reinstall '
                '(uninstall + flutter run / fresh install) after '
                'sensors_plus was added -- hot reload/restart does not '
                're-register new native plugins. If a fresh install still '
                'shows this, the device may lack a hardware gyroscope.';
          });
        }
      });
      setState(() {});
    } on CameraException catch (e) {
      setState(() => _error = 'Camera error: ${e.code}');
    } catch (e) {
      setState(() => _error = 'Failed to start: $e');
    }
  }

  void _reset() {
    _startMs = DateTime.now().millisecondsSinceEpoch;
    _gyroBuffer.clear();
    _prevFrameMs = null;
    _prevCentroid = null;
    _frameCount = 0;
    _framesWithSpot = 0;
    _gyroCount = 0;
    _meanGyroFrameOffsetMs = 0;
    _gyroWarning = null;
    _gx.clear();
    _gy.clear();
    _shiftX.clear();
    _shiftY.clear();
  }

  void _onGyro(GyroscopeEvent e) {
    if (!_running) return;
    final t = DateTime.now().millisecondsSinceEpoch;
    _gyroBuffer.add(_GyroSample(t, e.x, e.y, e.z));
    if (_gyroBuffer.length > _maxGyroBuffer) {
      _gyroBuffer.removeRange(0, _gyroBuffer.length - _maxGyroBuffer);
    }
    _gyroCount++;
    if (_gyroWarning != null) {
      _gyroWatchdog?.cancel();
      if (mounted) setState(() => _gyroWarning = null);
    }
  }

  void _onImage(CameraImage image) {
    if (!_running || _busyFrame) return;
    _busyFrame = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      _frameCount++;

      // Nearest-gyro time offset (sync quality).
      if (_gyroBuffer.isNotEmpty) {
        var best = (now - _gyroBuffer.first.tMs).abs();
        for (final g in _gyroBuffer) {
          final d = (now - g.tMs).abs();
          if (d < best) best = d;
        }
        _meanGyroFrameOffsetMs += (best - _meanGyroFrameOffsetMs) * 0.05;
      }

      final centroid = _findCentroid(image);
      if (centroid != null) _framesWithSpot++;

      if (_prevFrameMs != null && _prevCentroid != null && centroid != null) {
        final dtMs = now - _prevFrameMs!;
        if (dtMs > 0 && dtMs < 500) {
          final angles = _integrateGyro(_prevFrameMs!, now);
          final hfovRad = _assumedHFovDeg * math.pi / 180.0;
          // Small-angle approximation: fractional shift ~= angle / hfov.
          final predX = angles.$1 / hfovRad;
          final predY = angles.$2 / hfovRad;
          final actX = centroid.x - _prevCentroid!.x;
          final actY = centroid.y - _prevCentroid!.y;

          _gx.add(predX);
          _gy.add(predY);
          _shiftX.add(actX);
          _shiftY.add(actY);
          if (_gx.length > _maxPairs) {
            _gx.removeAt(0);
            _gy.removeAt(0);
            _shiftX.removeAt(0);
            _shiftY.removeAt(0);
          }
        }
      }

      _prevFrameMs = now;
      _prevCentroid = centroid;
    } finally {
      _busyFrame = false;
    }
  }

  /// Rectangular integration of gyro x/y angular rate over (fromMs, toMs].
  (double, double) _integrateGyro(int fromMs, int toMs) {
    final samples =
        _gyroBuffer.where((g) => g.tMs > fromMs && g.tMs <= toMs).toList();
    if (samples.isEmpty) return (0, 0);
    var lastT = fromMs;
    var angleX = 0.0, angleY = 0.0;
    for (final s in samples) {
      final dt = (s.tMs - lastT) / 1000.0;
      angleX += s.x * dt;
      angleY += s.y * dt;
      lastT = s.tMs;
    }
    return (angleX, angleY);
  }

  /// Minimal standalone bright-spot centroid for this experiment only (NOT the
  /// Vision Engine's Module 7 localizer). Threshold relative to the frame's own
  /// peak; null when no clear spot.
  _Centroid? _findCentroid(CameraImage image, {int stride = 4}) {
    final bytes = image.planes[0].bytes;
    final w = image.width;
    final h = image.height;
    final rowStride = image.planes[0].bytesPerRow;
    if (bytes.isEmpty || w <= 0 || h <= 0) return null;

    var maxV = 0;
    for (var row = 0; row < h; row += stride) {
      final base = row * rowStride;
      for (var col = 0; col < w; col += stride) {
        final idx = base + col;
        if (idx < bytes.length && bytes[idx] > maxV) maxV = bytes[idx];
      }
    }
    if (maxV < 40) return null;

    final thr = maxV * 0.8;
    var sumX = 0.0, sumY = 0.0;
    var n = 0;
    for (var row = 0; row < h; row += stride) {
      final base = row * rowStride;
      for (var col = 0; col < w; col += stride) {
        final idx = base + col;
        if (idx < bytes.length && bytes[idx] >= thr) {
          sumX += col;
          sumY += row;
          n++;
        }
      }
    }
    if (n < 4) return null;
    return _Centroid((sumX / n) / w, (sumY / n) / h);
  }

  double _corr(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    if (n < 5) return 0;
    final aa = a.sublist(a.length - n);
    final bb = b.sublist(b.length - n);
    final meanA = aa.reduce((x, y) => x + y) / n;
    final meanB = bb.reduce((x, y) => x + y) / n;
    var num = 0.0, da = 0.0, db = 0.0;
    for (var i = 0; i < n; i++) {
      final ea = aa[i] - meanA;
      final eb = bb[i] - meanB;
      num += ea * eb;
      da += ea * ea;
      db += eb * eb;
    }
    if (da <= 0 || db <= 0) return 0;
    return num / math.sqrt(da * db);
  }

  Future<void> _stop() async {
    if (!_running) return;
    _running = false;
    _uiTimer?.cancel();
    _uiTimer = null;
    _gyroWatchdog?.cancel();
    _gyroWatchdog = null;
    await _gyroSub?.cancel();
    _gyroSub = null;
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } catch (_) {}
      try {
        await c.dispose();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _refreshUi() {
    if (mounted) setState(() {});
  }

  double get _elapsedS => _startMs == 0
      ? 0
      : (DateTime.now().millisecondsSinceEpoch - _startMs) / 1000;
  double get _gyroHz => _elapsedS <= 0 ? 0 : _gyroCount / _elapsedS;
  double get _spotRate => _frameCount == 0 ? 0 : _framesWithSpot / _frameCount;

  String _summary() =>
      'E2 imu-sync: frames=$_frameCount spot_rate=${(_spotRate * 100).toStringAsFixed(1)}% '
      'gyro_count=$_gyroCount gyro_hz=${_gyroHz.toStringAsFixed(2)} mean_offset=${_meanGyroFrameOffsetMs.toStringAsFixed(1)}ms '
      'pairs=${_gx.length} '
      'corr_gx_shiftX=${_corr(_gx, _shiftX).toStringAsFixed(2)} '
      'corr_gx_shiftY=${_corr(_gx, _shiftY).toStringAsFixed(2)} '
      'corr_gy_shiftX=${_corr(_gy, _shiftX).toStringAsFixed(2)} '
      'corr_gy_shiftY=${_corr(_gy, _shiftY).toStringAsFixed(2)} '
      'assumed_hfov=${_assumedHFovDeg}deg ts_source=wallclock';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E2 · Gyro/Camera Sync')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Point at a flashlight/bright light and wave the phone (pan and '
                'tilt) while running. Correlations reveal which gyro axis maps '
                'to which image-shift axis on THIS device — no mapping is '
                'hardcoded. HFOV is an approximation, not calibrated.',
                style: TextStyle(color: Color(0xFF9D9D9D)),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF5A36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF5A36)),
                  ),
                  child: Text(_error!),
                ),
              if (_gyroWarning != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFB020),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFB020)),
                  ),
                  child: Text(_gyroWarning!,
                      style: const TextStyle(fontSize: 13)),
                ),
              _statRow('Frames', '$_frameCount'),
              _statRow(
                  'Spot detected', '${(_spotRate * 100).toStringAsFixed(1)}%'),
              _statRow('Gyro count (raw)', '$_gyroCount'),
              _statRow('Gyro rate', '${_gyroHz.toStringAsFixed(2)} Hz'),
              _statRow('Mean gyro↔frame offset',
                  '${_meanGyroFrameOffsetMs.toStringAsFixed(1)} ms'),
              _statRow('Correlation pairs', '${_gx.length}'),
              const Divider(color: Color(0xFF262626)),
              _statRow(
                  'corr(gx, shiftX)', _corr(_gx, _shiftX).toStringAsFixed(2)),
              _statRow(
                  'corr(gx, shiftY)', _corr(_gx, _shiftY).toStringAsFixed(2)),
              _statRow(
                  'corr(gy, shiftX)', _corr(_gy, _shiftX).toStringAsFixed(2)),
              _statRow(
                  'corr(gy, shiftY)', _corr(_gy, _shiftY).toStringAsFixed(2)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _running ? _stop : _start,
                      child: Text(_running ? 'Stop' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed:
                        _frameCount == 0 ? null : () => debugPrint(_summary()),
                    child: const Text('Log summary'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Color(0xFF8A8A8A))),
            Text(v,
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
