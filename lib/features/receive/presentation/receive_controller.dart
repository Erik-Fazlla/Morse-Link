import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/light_reading.dart';
import '../domain/receive_state.dart';
import '../domain/signal_quality.dart';
import '../services/light_detector.dart';
import '../services/light_source.dart';
import '../services/morse_accumulator.dart';
import '../services/morse_decoder.dart';
import '../services/pulse_classifier.dart';
import '../services/pulse_timer.dart';
import '../services/transmission_synchronizer.dart';
import '../services/unit_estimator.dart';

/// One point for the developer luminance/threshold/decision visualization.
class LumSample {
  const LumSample({
    required this.luminance,
    required this.threshold,
    required this.isOn,
  });
  final double luminance;
  final double? threshold;
  final bool isOn;
}

/// Orchestrates the live receive pipeline:
/// [LightSource] → [LightDetector] → [PulseTimer] → [TransmissionSynchronizer]
/// → [MorseAccumulator] → [MorseDecoder], surfacing a [ReceiveState] plus
/// developer diagnostics. Mirrors SendController's lifecycle discipline:
/// dispose guards, listener-safe notifies, and a static instance counter.
class ReceiveController extends ChangeNotifier {
  ReceiveController({
    required LightSource source,
    LightDetector? detector,
    PulseTimer? pulseTimer,
    TransmissionSynchronizer? synchronizer,
    MorseAccumulator? accumulator,
    MorseDecoder? decoder,
    int seedUnitMs = 180,
    this.diagnosticsIntervalMs = 80,
    this.historyLength = 180,
  })  : _source = source,
        _detector = detector ?? LightDetector(),
        _timer = pulseTimer ?? PulseTimer(),
        _sync = synchronizer ??
            TransmissionSynchronizer(
              estimator: MedianUnitEstimator(seedUnitMs: seedUnitMs),
              classifier: PulseClassifier(),
            ),
        _accumulator = accumulator ?? MorseAccumulator(),
        _decoder = decoder ?? MorseDecoder() {
    _activeControllerCount++;
  }

  static int _activeControllerCount = 0;
  static int get activeControllerCount => _activeControllerCount;

  final LightSource _source;
  final LightDetector _detector;
  final PulseTimer _timer;
  final TransmissionSynchronizer _sync;
  final MorseAccumulator _accumulator;
  final MorseDecoder _decoder;
  final int diagnosticsIntervalMs;
  final int historyLength;

  ReceiveState _state = ReceiveState.idle;
  ReceiveState get state => _state;

  // --- developer diagnostics ---
  double _currentLuminance = 0;
  double? _currentThreshold;
  bool _isLightOn = false;
  double _fps = 0;
  double _avgLatencyMs = 0;
  final List<LumSample> _history = [];

  double get currentLuminance => _currentLuminance;
  double? get currentThreshold => _currentThreshold;
  bool get isLightOn => _isLightOn;
  double get fps => _fps;
  double get avgLatencyMs => _avgLatencyMs;
  List<LumSample> get history => List.unmodifiable(_history);

  // --- internals ---
  bool _isDisposed = false;
  bool _idleFlushed = false;
  int _symbolTotal = 0;
  int _symbolUnknown = 0;
  Timer? _diagnosticsTimer;
  int _fpsWindowStartMs = 0;
  int _fpsFrames = 0;
  int _latencyMicrosSum = 0;
  int _latencyCount = 0;

  Future<void> startReceiving() async {
    if (_isDisposed || _state.isReceiving || _state.status == ReceiveStatus.starting) {
      return;
    }

    _resetPipeline();
    _setState(_state.copyWith(
      status: ReceiveStatus.starting,
      syncPhase: _sync.phase,
      quality: SignalQuality.idle,
      liveMorse: '',
      decodedText: '',
      clearError: true,
    ));

    final ok = await _source.start(_onReading);
    if (_isDisposed) {
      await _source.stop();
      return;
    }
    if (!ok) {
      _setError(_messageFor(_source.lastError));
      return;
    }

    _startDiagnosticsClock();
    _setState(_state.copyWith(status: ReceiveStatus.receiving));
  }

  Future<void> stopReceiving() async {
    if (_isDisposed) return;
    _stopDiagnosticsClock();
    await _source.stop();
    if (_isDisposed) return;
    _accumulator.flush();
    _setState(_state.copyWith(
      status: ReceiveStatus.stopped,
      decodedText: _decoder.decode(_accumulator.letters).trim(),
      syncPhase: _sync.phase,
    ));
  }

  /// Release the camera when the app goes to the background.
  Future<void> handleAppPaused() async {
    if (_state.isReceiving || _state.status == ReceiveStatus.starting) {
      await stopReceiving();
    }
  }

  void _onReading(LightReading reading) {
    if (_isDisposed) return;
    final sw = Stopwatch()..start();

    final transition = _detector.process(reading);
    _currentLuminance = reading.luminance;
    _currentThreshold = _detector.thresholdMid;
    _isLightOn = _detector.isOn;
    _pushHistory();

    var produced = false;
    if (transition != null) {
      _idleFlushed = false;
      final pulse = _timer.onTransition(transition);
      if (pulse != null) {
        for (final symbol in _sync.process(pulse)) {
          _symbolTotal++;
          if (symbol.name == 'unknown') _symbolUnknown++;
          _accumulator.add(symbol);
          produced = true;
        }
      }
    }

    // Flush the in-progress letter once the line goes idle, so the final
    // letter of a message appears without waiting for a stop.
    if (!_idleFlushed && _detector.isIdle(reading.timestampMs)) {
      _accumulator.flush();
      _idleFlushed = true;
      produced = true;
    }

    _recordLatency(sw.elapsedMicroseconds);
    _fpsFrames++;

    if (produced) {
      _refreshDecode();
      _notifySafely();
    }
  }

  void _refreshDecode() {
    _setState(_state.copyWith(
      syncPhase: _sync.phase,
      liveMorse: _accumulator.liveMorse,
      decodedText: _decoder.decode(_accumulator.letters).trim(),
      quality: _currentQuality(),
    ));
  }

  SignalQuality _currentQuality() => SignalQuality(
        detected: _detector.hasSignal,
        estUnitMs: _sync.estimatedUnitMs,
        signalStrengthPct: _detector.signalStrengthPct,
        decodeConfidencePct: _symbolTotal == 0
            ? 0
            : ((1 - _symbolUnknown / _symbolTotal) * 100),
      );

  void _pushHistory() {
    _history.add(LumSample(
      luminance: _currentLuminance,
      threshold: _currentThreshold,
      isOn: _isLightOn,
    ));
    if (_history.length > historyLength) {
      _history.removeRange(0, _history.length - historyLength);
    }
  }

  void _recordLatency(int micros) {
    _latencyMicrosSum += micros;
    _latencyCount++;
  }

  void _startDiagnosticsClock() {
    _stopDiagnosticsClock();
    _fpsWindowStartMs = DateTime.now().millisecondsSinceEpoch;
    _fpsFrames = 0;
    _diagnosticsTimer = Timer.periodic(
      Duration(milliseconds: diagnosticsIntervalMs),
      (_) => _tickDiagnostics(),
    );
  }

  void _tickDiagnostics() {
    if (_isDisposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _fpsWindowStartMs;
    if (elapsed >= 1000) {
      _fps = _fpsFrames * 1000 / elapsed;
      _fpsFrames = 0;
      _fpsWindowStartMs = now;
      if (_latencyCount > 0) {
        _avgLatencyMs = _latencyMicrosSum / _latencyCount / 1000.0;
        _latencyMicrosSum = 0;
        _latencyCount = 0;
      }
    }
    _setState(_state.copyWith(quality: _currentQuality()));
    _notifySafely();
  }

  void _stopDiagnosticsClock() {
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;
  }

  void _resetPipeline() {
    _detector.reset();
    _timer.reset();
    _sync.reset();
    _accumulator.reset();
    _history.clear();
    _idleFlushed = false;
    _symbolTotal = 0;
    _symbolUnknown = 0;
    _currentLuminance = 0;
    _currentThreshold = null;
    _isLightOn = false;
    _fps = 0;
    _avgLatencyMs = 0;
  }

  String _messageFor(LightSourceError error) {
    switch (error) {
      case LightSourceError.permissionDenied:
        return 'Camera permission denied. Enable it in settings to receive.';
      case LightSourceError.unavailable:
        return 'Camera unavailable on this device.';
      case LightSourceError.interrupted:
        return 'Camera stream interrupted.';
      case LightSourceError.none:
        return 'Unable to start the camera.';
    }
  }

  void _setError(String message) {
    _stopDiagnosticsClock();
    _setState(_state.copyWith(
      status: ReceiveStatus.error,
      errorMessage: message,
    ));
  }

  void _setState(ReceiveState next) {
    if (_isDisposed) return;
    _state = next;
  }

  void _notifySafely() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    if (_activeControllerCount > 0) _activeControllerCount--;
    _stopDiagnosticsClock();
    unawaited(_source.stop());
    super.dispose();
  }
}
