import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/services/morse_accumulator.dart';

void main() {
  test('accumulates SOS letters', () {
    final a = MorseAccumulator();
    for (final s in [
      PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot,
      PulseSymbol.symbolGap, PulseSymbol.dot,
      PulseSymbol.letterGap,
      PulseSymbol.dash, PulseSymbol.symbolGap, PulseSymbol.dash,
      PulseSymbol.symbolGap, PulseSymbol.dash,
      PulseSymbol.letterGap,
      PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot,
      PulseSymbol.symbolGap, PulseSymbol.dot,
    ]) {
      a.add(s);
    }
    a.flush();
    expect(a.letters, ['...', '---', '...']);
  });

  test('wordGap inserts a break and unknown is ignored', () {
    final a = MorseAccumulator();
    a.add(PulseSymbol.dot);
    a.add(PulseSymbol.unknown);
    a.add(PulseSymbol.wordGap);
    a.add(PulseSymbol.dash);
    a.flush();
    expect(a.letters, ['.', '', '-']);
  });

  test('liveMorse renders in-progress letter', () {
    final a = MorseAccumulator();
    a.add(PulseSymbol.dot);
    a.add(PulseSymbol.dot);
    expect(a.liveMorse, '..');
  });

  test('liveMorse separates words with " / "', () {
    final a = MorseAccumulator();
    a.add(PulseSymbol.dot); // E
    a.add(PulseSymbol.letterGap);
    a.add(PulseSymbol.dash); // T
    a.add(PulseSymbol.wordGap);
    a.add(PulseSymbol.dot); // A start
    expect(a.liveMorse, '. - / .');
  });

  test('reset clears everything', () {
    final a = MorseAccumulator();
    a.add(PulseSymbol.dot);
    a.add(PulseSymbol.letterGap);
    a.reset();
    expect(a.letters, isEmpty);
    expect(a.liveMorse, '');
  });
}
