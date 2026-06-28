import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';

void main() {
  final c = PulseClassifier();
  const unit = 100;

  test('ON pulses → dot / dash', () {
    expect(c.classify(const Pulse(isOn: true, durationMs: 100), unit),
        PulseSymbol.dot);
    expect(c.classify(const Pulse(isOn: true, durationMs: 300), unit),
        PulseSymbol.dash);
    expect(c.classify(const Pulse(isOn: true, durationMs: 130), unit),
        PulseSymbol.dot);
    expect(c.classify(const Pulse(isOn: true, durationMs: 260), unit),
        PulseSymbol.dash);
  });

  test('OFF pulses → symbol / letter / word gap', () {
    expect(c.classify(const Pulse(isOn: false, durationMs: 100), unit),
        PulseSymbol.symbolGap);
    expect(c.classify(const Pulse(isOn: false, durationMs: 300), unit),
        PulseSymbol.letterGap);
    expect(c.classify(const Pulse(isOn: false, durationMs: 700), unit),
        PulseSymbol.wordGap);
  });

  test('garbage → unknown, never throws', () {
    expect(c.classify(const Pulse(isOn: true, durationMs: 0), unit),
        PulseSymbol.unknown);
    expect(c.classify(const Pulse(isOn: true, durationMs: -5), unit),
        PulseSymbol.unknown);
    expect(c.classify(const Pulse(isOn: true, durationMs: 900), unit),
        PulseSymbol.unknown);
    expect(c.classify(const Pulse(isOn: true, durationMs: 100), 0),
        PulseSymbol.unknown);
  });
}
