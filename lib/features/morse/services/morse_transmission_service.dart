import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/timing_instruction.dart';
import '../domain/transmission_diagnostics.dart';
import '../domain/transmission_repeat_mode.dart';
import '../domain/transmission_state.dart';
import 'flashlight_controller.dart';

class MorseTransmissionService {
  MorseTransmissionService({
    required FlashlightController flashlightController,
  })  : _flashlightController = flashlightController,
        state = DebugValueNotifier<TransmissionState>(
          label: 'MorseTransmissionService.state',
          value: TransmissionState.idle,
        ),
        diagnostics = DebugValueNotifier<TransmissionDiagnostics>(
          label: 'MorseTransmissionService.diagnostics',
          value: TransmissionDiagnostics.idle,
        ) {
    _activeServiceCount++;
    _log('service created');
  }

  static int _activeServiceCount = 0;

  static int get activeServiceCount => _activeServiceCount;

  final FlashlightController _flashlightController;
  final DebugValueNotifier<TransmissionState> state;
  final DebugValueNotifier<TransmissionDiagnostics> diagnostics;

  int _sessionId = 0;
  Stopwatch? _stopwatch;
  Timer? _diagnosticsTimer;
  bool _isDisposed = false;
  String? _lastError;

  String? get lastError => _lastError;

  int get totalListenerCount =>
      state.listenerCount + diagnostics.listenerCount;

  Future<TransmissionStatus> transmit({
    required List<TimingInstruction> Function() buildSequence,
    required TransmissionRepeatConfig repeatConfig,
    required int timingUnitMs,
  }) async {
    if (_isDisposed) {
      _log('transmit ignored after disposal');
      return TransmissionStatus.error;
    }

    final initialSequence = buildSequence();
    debugPrint(
      '[MorseTransmission] timing sequence rebuilt for initial transmission '
      '(${initialSequence.length} instructions)',
    );

    if (initialSequence.isEmpty) {
      _setError(
        'No timing instructions to transmit.',
        diagnosticsPhase: 'empty sequence',
      );
      return TransmissionStatus.error;
    }

    if (!state.value.canStart) {
      return state.value.status;
    }

    final session = ++_sessionId;
    final totalRepeats = repeatConfig.totalRepetitions;

    _setState(
      TransmissionState.transmitting(
        isLightOn: false,
        currentRepeat: 1,
        totalRepeats: totalRepeats,
      ),
    );
    _startDiagnosticsClock(
      timingUnitMs: timingUnitMs,
      currentRepeat: 1,
      totalRepeats: totalRepeats,
    );

    try {
      final isReady = await _flashlightController.prepare();
      if (session != _sessionId) {
        return state.value.status;
      }

      if (!isReady) {
        _setError(
          'Flashlight unavailable or permission denied.',
          diagnosticsPhase: 'permission denied',
        );
        return TransmissionStatus.error;
      }

      var currentRepeat = 1;
      while (_shouldContinueRepeating(currentRepeat, totalRepeats)) {
        final cycleResetApplied = await _ensureFlashlightOff(session: session);
        if (!cycleResetApplied) {
          return state.value.status;
        }

        final sequence = currentRepeat == 1 ? initialSequence : buildSequence();
        debugPrint(
          '[MorseTransmission] repeat started: $currentRepeat'
          '${totalRepeats == null ? '/forever' : '/$totalRepeats'}',
        );
        debugPrint(
          '[MorseTransmission] timing sequence rebuilt for repeat '
          '$currentRepeat (${sequence.length} instructions)',
        );

        final completed = await _transmitSingleMessage(
          sequence: sequence,
          session: session,
          currentRepeat: currentRepeat,
          totalRepeats: totalRepeats,
        );
        if (!completed) {
          return state.value.status;
        }

        debugPrint(
          '[MorseTransmission] repeat ended: $currentRepeat'
          '${totalRepeats == null ? '/forever' : '/$totalRepeats'}',
        );

        final hasMoreRepeats =
            totalRepeats == null || currentRepeat < totalRepeats;
        if (hasMoreRepeats) {
          final separatorCompleted = await _applyRepeatSeparator(
            session: session,
            currentRepeat: currentRepeat,
            totalRepeats: totalRepeats,
            separatorDurationMs: timingUnitMs * 7,
          );
          if (!separatorCompleted) {
            return state.value.status;
          }

          if (repeatConfig.delayBetweenRepeatsMs > 0) {
            final delayCompleted = await _applyRepeatDelay(
              session: session,
              currentRepeat: currentRepeat,
              totalRepeats: totalRepeats,
              delayDurationMs: repeatConfig.delayBetweenRepeatsMs,
            );
            if (!delayCompleted) {
              return state.value.status;
            }
          }
        }

        currentRepeat++;
      }

      _setState(TransmissionState.idle);
      return TransmissionStatus.idle;
    } catch (error) {
      _setError(
        'Transmission failed unexpectedly.',
        diagnosticsPhase: 'runtime error',
        debugDetails: '$error',
      );
      return TransmissionStatus.error;
    } finally {
      await _cleanupFlashlightState(session);
    }
  }

  Future<bool> _transmitSingleMessage({
    required List<TimingInstruction> sequence,
    required int session,
    required int currentRepeat,
    required int? totalRepeats,
  }) async {
    for (final instruction in sequence) {
      if (session != _sessionId) {
        return false;
      }

      _setState(
        TransmissionState.transmitting(
          isLightOn: instruction.isOn,
          currentRepeat: currentRepeat,
          totalRepeats: totalRepeats,
        ),
      );
      _setDiagnostics(
        diagnostics.value.copyWith(
          status: TransmissionStatus.transmitting,
          currentSymbol: instruction.symbol,
          currentPhase: instruction.isOn ? 'ON' : instruction.phaseLabel,
          currentDurationMs: instruction.durationMs,
          currentRepeat: currentRepeat,
          totalRepeats: totalRepeats,
        ),
      );

      final stateApplied = await _setFlashlightState(
        turnOn: instruction.isOn,
        session: session,
      );
      if (!stateApplied) {
        return false;
      }

      final completed = await _waitInterruptible(
        durationMs: instruction.durationMs,
        session: session,
      );
      if (!completed) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _applyRepeatSeparator({
    required int session,
    required int currentRepeat,
    required int? totalRepeats,
    required int separatorDurationMs,
  }) async {
    final stateApplied = await _setFlashlightState(
      turnOn: false,
      session: session,
    );
    if (!stateApplied) {
      return false;
    }

    _setState(
      TransmissionState.transmitting(
        isLightOn: false,
        currentRepeat: currentRepeat,
        totalRepeats: totalRepeats,
        isWaitingBetweenRepeats: true,
      ),
    );
    _setDiagnostics(
      diagnostics.value.copyWith(
        status: TransmissionStatus.transmitting,
        currentSymbol: '/',
        currentPhase: 'inter-message separator',
        currentDurationMs: separatorDurationMs,
        currentRepeat: currentRepeat,
        totalRepeats: totalRepeats,
      ),
    );

    return _waitInterruptible(
      durationMs: separatorDurationMs,
      session: session,
    );
  }

  Future<bool> _applyRepeatDelay({
    required int session,
    required int currentRepeat,
    required int? totalRepeats,
    required int delayDurationMs,
  }) async {
    _setState(
      TransmissionState.transmitting(
        isLightOn: false,
        currentRepeat: currentRepeat,
        totalRepeats: totalRepeats,
        isWaitingBetweenRepeats: true,
      ),
    );
    _setDiagnostics(
      diagnostics.value.copyWith(
        status: TransmissionStatus.transmitting,
        currentSymbol: '/',
        currentPhase: 'repeat delay',
        currentDurationMs: delayDurationMs,
        currentRepeat: currentRepeat,
        totalRepeats: totalRepeats,
      ),
    );

    return _waitInterruptible(
      durationMs: delayDurationMs,
      session: session,
    );
  }

  Future<void> stop() async {
    if (_isDisposed) {
      _log('stop ignored after disposal');
      return;
    }

    if (!state.value.canStop) {
      return;
    }

    _sessionId++;
    _setState(TransmissionState.stopped);
    _setDiagnostics(
      diagnostics.value.copyWith(
        status: TransmissionStatus.stopped,
        currentPhase: 'stopped',
      ),
    );

    final shutdownSucceeded = await _shutdownFlashlightSafely();
    if (!shutdownSucceeded) {
      _setError(
        'Unable to shut down flashlight safely.',
        diagnosticsPhase: 'flashlight error',
      );
    }
  }

  Future<bool> _waitInterruptible({
    required int durationMs,
    required int session,
  }) async {
    var remaining = durationMs;

    while (remaining > 0) {
      if (session != _sessionId) {
        return false;
      }

      final slice = remaining > 50 ? 50 : remaining;
      await Future<void>.delayed(Duration(milliseconds: slice));
      remaining -= slice;
    }

    return true;
  }

  Future<bool> _setFlashlightState({
    required bool turnOn,
    required int session,
  }) async {
    if (session != _sessionId) {
      return false;
    }

    try {
      if (turnOn) {
        await _flashlightController.turnOn();
      } else {
        await _flashlightController.turnOff();
      }
    } catch (error) {
      if (session == _sessionId) {
        _setError(
          turnOn
              ? 'Unable to enable flashlight.'
              : 'Unable to disable flashlight.',
          diagnosticsPhase: 'flashlight error',
          debugDetails: '$error',
        );
      }
      return false;
    }

    return session == _sessionId;
  }

  void pause() {
    if (_isDisposed) {
      _log('pause ignored after disposal');
      return;
    }

    if (state.value.status == TransmissionStatus.transmitting) {
      _setState(TransmissionState.paused);
      _setDiagnostics(
        diagnostics.value.copyWith(
          status: TransmissionStatus.paused,
          currentPhase: 'paused',
        ),
      );
    }
  }

  Future<void> _cleanupFlashlightState(int session) async {
    final shutdownSucceeded = await _shutdownFlashlightSafely();
    if (!shutdownSucceeded && state.value.status != TransmissionStatus.error) {
      _setError(
        'Unable to shut down flashlight safely.',
        diagnosticsPhase: 'flashlight error',
      );
      _stopDiagnosticsClock(resetToIdle: false);
      return;
    }

    if (session == _sessionId && state.value.isLightOn) {
      _setState(state.value.copyWith(isLightOn: false));
    }

    _stopDiagnosticsClock(resetToIdle: session == _sessionId);
  }

  Future<bool> _shutdownFlashlightSafely() async {
    try {
      await _flashlightController.turnOff();
      return true;
    } catch (error) {
      _lastError = '$error';
      return false;
    }
  }

  Future<bool> _ensureFlashlightOff({
    required int session,
  }) async {
    if (session != _sessionId) {
      return false;
    }

    return _setFlashlightState(
      turnOn: false,
      session: session,
    );
  }

  void _setState(TransmissionState nextState) {
    if (_isDisposed) {
      return;
    }

    state.value = nextState;
  }

  void _setDiagnostics(TransmissionDiagnostics nextDiagnostics) {
    if (_isDisposed) {
      return;
    }

    diagnostics.value = nextDiagnostics;
  }

  void _startDiagnosticsClock({
    required int timingUnitMs,
    required int currentRepeat,
    required int? totalRepeats,
  }) {
    _stopDiagnosticsClock(resetToIdle: false);
    _stopwatch = Stopwatch()..start();
    _setDiagnostics(
      TransmissionDiagnostics.idle.copyWith(
        status: TransmissionStatus.transmitting,
        currentPhase: 'preparing',
        timingUnitMs: timingUnitMs,
        currentRepeat: currentRepeat,
        totalRepeats: totalRepeats,
      ),
    );
    _diagnosticsTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_isDisposed) {
        return;
      }

      final stopwatch = _stopwatch;
      if (stopwatch == null) {
        return;
      }

      _setDiagnostics(
        diagnostics.value.copyWith(
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      );
    });
  }

  void _stopDiagnosticsClock({required bool resetToIdle}) {
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;

    if (resetToIdle) {
      _setDiagnostics(TransmissionDiagnostics.idle);
    }
  }

  bool _shouldContinueRepeating(int currentRepeat, int? totalRepeats) {
    if (totalRepeats == null) {
      return true;
    }

    return currentRepeat <= totalRepeats;
  }

  void dispose() {
    if (_isDisposed) {
      _log('dispose ignored because service is already disposed');
      return;
    }

    _isDisposed = true;
    if (_activeServiceCount > 0) {
      _activeServiceCount--;
    }
    _log('disposing service');
    _stopDiagnosticsClock(resetToIdle: true);
    diagnostics.dispose();
    state.dispose();
  }

  void _setError(
    String message, {
    required String diagnosticsPhase,
    String? debugDetails,
  }) {
    _lastError = debugDetails ?? message;
    _setState(TransmissionState.error(message));
    _setDiagnostics(
      diagnostics.value.copyWith(
        status: TransmissionStatus.error,
        currentPhase: diagnosticsPhase,
      ),
    );
  }

  void _log(String message) {
    debugPrint('[MorseTransmissionService] $message');
  }
}

class DebugValueNotifier<T> extends ValueNotifier<T> {
  DebugValueNotifier({
    required this.label,
    required T value,
  }) : super(value) {
    debugPrint('[Notifier:$label] created');
  }

  final String label;
  int _listenerCount = 0;

  int get listenerCount => _listenerCount;

  @override
  void addListener(VoidCallback listener) {
    _listenerCount++;
    debugPrint('[Notifier:$label] listener attached');
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_listenerCount > 0) {
      _listenerCount--;
    }
    debugPrint('[Notifier:$label] listener removed');
    super.removeListener(listener);
  }

  @override
  set value(T newValue) {
    super.value = newValue;
  }

  @override
  void dispose() {
    debugPrint('[Notifier:$label] disposed');
    super.dispose();
  }
}
