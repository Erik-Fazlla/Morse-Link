import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/signal_quality.dart';

void main() {
  test('Pulse holds fields', () {
    const p = Pulse(isOn: true, durationMs: 180);
    expect(p.isOn, true);
    expect(p.durationMs, 180);
  });

  test('SignalQuality.copyWith updates one field, leaves others', () {
    final q = SignalQuality.idle.copyWith(signalStrengthPct: 80);
    expect(q.signalStrengthPct, 80);
    expect(q.decodeConfidencePct, 0);
    expect(q.detected, false);
  });
}
