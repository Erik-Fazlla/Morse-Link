import '../domain/light_reading.dart';

typedef LightReadingCallback = void Function(LightReading reading);

/// Source of luminance samples. Implemented by [FakeLightSource] (tests) and,
/// later, a camera-backed source on device.
abstract class LightSource {
  Future<bool> start(LightReadingCallback onReading);
  Future<void> stop();
}

/// Replays a fixed list of readings synchronously — for tests.
class FakeLightSource implements LightSource {
  FakeLightSource(this._readings);

  final List<LightReading> _readings;
  bool _running = false;

  @override
  Future<bool> start(LightReadingCallback onReading) async {
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
