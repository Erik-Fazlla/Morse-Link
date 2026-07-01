import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// E1 — Frame timing & frame-rate characterization.
///
/// Streams the camera and measures, per device: delivered FPS, inter-frame
/// interval statistics (mean / jitter σ / min / max / p90), per-frame
/// processing latency for a representative luminance workload, and a
/// dropped-frame estimate. All timing uses the wall clock — the camera plugin
/// does not expose a hardware/sensor frame timestamp, which is itself an E1
/// finding to record.
///
/// Diagnostic only. No decode, no V1 involvement. Run it, read the summary,
/// export via device logs (Log summary → `flutter logs` / `adb logcat`).
class E1TimingProbeScreen extends StatefulWidget {
  const E1TimingProbeScreen({super.key});

  @override
  State<E1TimingProbeScreen> createState() => _E1TimingProbeScreenState();
}

class _E1TimingProbeScreenState extends State<E1TimingProbeScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _running = false;
  bool _busy = false;
  String? _error;

  // timing state
  int _startMs = 0;
  int _lastFrameMs = 0;
  int _frameCount = 0;
  final List<int> _intervals = []; // recent inter-frame intervals (ms)
  static const int _maxIntervals = 600;

  // processing latency (microseconds)
  double _latencyAvgUs = 0;
  int _latencyMaxUs = 0;

  int _gapCount = 0; // intervals > 2x running median → estimated drops

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
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
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
      await controller.startImageStream(_onImage);
      _running = true;
      _uiTimer = Timer.periodic(
          const Duration(milliseconds: 250), (_) => _refreshUi());
      setState(() {});
    } on CameraException catch (e) {
      setState(() => _error = 'Camera error: ${e.code}');
    } catch (e) {
      setState(() => _error = 'Failed to start: $e');
    }
  }

  void _reset() {
    _startMs = DateTime.now().millisecondsSinceEpoch;
    _lastFrameMs = 0;
    _frameCount = 0;
    _intervals.clear();
    _latencyAvgUs = 0;
    _latencyMaxUs = 0;
    _gapCount = 0;
  }

  void _onImage(CameraImage image) {
    if (!_running || _busy) return;
    _busy = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_lastFrameMs != 0) {
        final dt = now - _lastFrameMs;
        _intervals.add(dt);
        if (_intervals.length > _maxIntervals) {
          _intervals.removeRange(0, _intervals.length - _maxIntervals);
        }
        final med = _median(_intervals);
        if (med > 0 && dt > 2 * med) _gapCount++;
      }
      _lastFrameMs = now;
      _frameCount++;

      // Representative per-frame workload: strided mean luminance of the Y plane.
      final sw = Stopwatch()..start();
      _strideMeanLuma(image);
      sw.stop();
      final us = sw.elapsedMicroseconds;
      _latencyAvgUs += (us - _latencyAvgUs) * 0.05; // EMA
      if (us > _latencyMaxUs) _latencyMaxUs = us;
    } finally {
      _busy = false;
    }
  }

  double _strideMeanLuma(CameraImage image, {int stride = 4}) {
    final bytes = image.planes[0].bytes;
    if (bytes.isEmpty) return 0;
    var sum = 0;
    var n = 0;
    for (var i = 0; i < bytes.length; i += stride) {
      sum += bytes[i];
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  Future<void> _stop() async {
    if (!_running) return;
    _running = false;
    _uiTimer?.cancel();
    _uiTimer = null;
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

  // --- stats ---
  double get _elapsedS =>
      _startMs == 0 ? 0 : (DateTime.now().millisecondsSinceEpoch - _startMs) / 1000;
  double get _fps => _elapsedS <= 0 ? 0 : _frameCount / _elapsedS;
  double get _meanInterval =>
      _intervals.isEmpty ? 0 : _intervals.reduce((a, b) => a + b) / _intervals.length;
  double get _jitter {
    if (_intervals.length < 2) return 0;
    final m = _meanInterval;
    final v = _intervals.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
        _intervals.length;
    return math.sqrt(v);
  }

  int get _minInterval => _intervals.isEmpty ? 0 : _intervals.reduce(math.min);
  int get _maxInterval => _intervals.isEmpty ? 0 : _intervals.reduce(math.max);
  int get _p90 => _percentile(_intervals, 0.90);

  int _median(List<int> xs) => _percentile(xs, 0.5);
  int _percentile(List<int> xs, double p) {
    if (xs.isEmpty) return 0;
    final s = List<int>.from(xs)..sort();
    final idx = (p * (s.length - 1)).round().clamp(0, s.length - 1);
    return s[idx];
  }

  String _summary() =>
      'E1 timing: device_frames=$_frameCount elapsed=${_elapsedS.toStringAsFixed(1)}s '
      'fps=${_fps.toStringAsFixed(2)} mean_dt=${_meanInterval.toStringAsFixed(1)}ms '
      'jitter=${_jitter.toStringAsFixed(1)}ms min=$_minInterval max=$_maxInterval '
      'p90=${_p90}ms est_gaps=$_gapCount lat_avg=${(_latencyAvgUs / 1000).toStringAsFixed(2)}ms '
      'lat_max=${(_latencyMaxUs / 1000).toStringAsFixed(2)}ms ts_source=wallclock';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E1 · Frame Timing')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Streams the camera and measures frame timing. Wall-clock only '
                '(no sensor timestamp exposed). Run ≥60 s per device, in the '
                'lighting you will actually use.',
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
              _statRow('Frames', '$_frameCount'),
              _statRow('Elapsed', '${_elapsedS.toStringAsFixed(1)} s'),
              _statRow('Delivered FPS', _fps.toStringAsFixed(2)),
              _statRow('Mean interval', '${_meanInterval.toStringAsFixed(1)} ms'),
              _statRow('Jitter (σ)', '${_jitter.toStringAsFixed(1)} ms'),
              _statRow('Min / Max', '$_minInterval / $_maxInterval ms'),
              _statRow('p90 interval', '$_p90 ms'),
              _statRow('Est. dropped gaps', '$_gapCount'),
              _statRow('Proc latency avg',
                  '${(_latencyAvgUs / 1000).toStringAsFixed(2)} ms'),
              _statRow('Proc latency max',
                  '${(_latencyMaxUs / 1000).toStringAsFixed(2)} ms'),
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
                    onPressed: _frameCount == 0
                        ? null
                        : () => debugPrint(_summary()),
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
