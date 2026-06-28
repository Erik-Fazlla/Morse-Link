import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/light_detector.dart';
import 'package:morse/features/receive/services/pulse_timer.dart';

void main() {
  test('produces deterministic pulse durations from transitions', () {
    final pt = PulseTimer();
    final out = <String>[];
    void t(bool on, int at) {
      final p = pt.onTransition(LightTransition(isOn: on, atMs: at));
      if (p != null) out.add('${p.isOn ? "ON" : "OFF"} ${p.durationMs}');
    }

    t(true, 0); // open ON
    t(false, 100); // close ON 100
    t(true, 200); // close OFF 100
    final tail = pt.flush(500); // close ON 300
    if (tail != null) out.add('${tail.isOn ? "ON" : "OFF"} ${tail.durationMs}');

    expect(out, ['ON 100', 'OFF 100', 'ON 300']);
  });

  test('flush with nothing open returns null', () {
    expect(PulseTimer().flush(100), isNull);
  });
}
