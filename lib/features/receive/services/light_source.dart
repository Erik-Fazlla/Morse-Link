import '../domain/light_reading.dart';

typedef LightReadingCallback = void Function(LightReading reading);

/// Why a [LightSource] failed to start or stopped unexpectedly.
enum LightSourceError { none, permissionDenied, unavailable, interrupted }

/// Source of luminance samples. Implemented by [FakeLightSource] (tests) and
/// the camera-backed source on device. The decode pipeline only ever sees
/// [LightReading]s through this interface — it never knows the source.
abstract class LightSource {
  /// Begin delivering readings. Returns true on success; on failure returns
  /// false and sets [lastError]. Must never throw.
  Future<bool> start(LightReadingCallback onReading);

  /// Stop delivering readings and release resources. Must never throw.
  Future<void> stop();

  /// Reason for the most recent failure (or [LightSourceError.none]).
  LightSourceError get lastError;
}

/// Replays a fixed list of readings synchronously — for tests. Can simulate a
/// start failure via [failWith].
class FakeLightSource implements LightSource {
  FakeLightSource(
    this._readings, {
    LightSourceError failWith = LightSourceError.none,
  }) : _lastError = failWith;

  final List<LightReading> _readings;
  final LightSourceError _lastError;
  bool _running = false;

  @override
  LightSourceError get lastError => _lastError;

  @override
  Future<bool> start(LightReadingCallback onReading) async {
    if (_lastError != LightSourceError.none) return false;
    _running = true;
    for (final r in _readings) {
      if (!_running) break;
      onReading(r);
    }
    return true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }
}
