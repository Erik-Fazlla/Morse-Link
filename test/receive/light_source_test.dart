import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/light_reading.dart';
import 'package:morse/features/receive/services/light_source.dart';

void main() {
  test('FakeLightSource emits queued readings in order', () async {
    final src = FakeLightSource([
      const LightReading(luminance: 10, timestampMs: 0),
      const LightReading(luminance: 200, timestampMs: 100),
    ]);
    final got = <double>[];
    await src.start((r) => got.add(r.luminance));
    await src.stop();
    expect(got, [10, 200]);
  });
}
