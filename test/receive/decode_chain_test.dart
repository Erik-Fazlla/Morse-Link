import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/services/morse_accumulator.dart';
import 'package:morse/features/receive/services/morse_decoder.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';
import 'package:morse/features/receive/services/transmission_synchronizer.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

/// Build an ON/OFF pulse train for a Morse string at a given unit.
/// `morseWords`: letters separated by ' ', words by '/'. e.g. '... --- ...'
/// A trailing silence is appended so short messages finalize via the
/// synchronizer's silence path.
List<Pulse> pulsesFor(String morseWords, int unit) {
  final pulses = <Pulse>[];
  final words =
      morseWords.split('/').map((w) => w.trim()).where((w) => w.isNotEmpty);
  final wordList = words.toList();
  for (var w = 0; w < wordList.length; w++) {
    final letters =
        wordList[w].split(' ').where((s) => s.isNotEmpty).toList();
    for (var l = 0; l < letters.length; l++) {
      final symbols = letters[l].split('');
      for (var s = 0; s < symbols.length; s++) {
        pulses.add(Pulse(isOn: true, durationMs: symbols[s] == '.' ? unit : unit * 3));
        if (s < symbols.length - 1) {
          pulses.add(Pulse(isOn: false, durationMs: unit)); // symbol gap
        }
      }
      if (l < letters.length - 1) {
        pulses.add(Pulse(isOn: false, durationMs: unit * 3)); // letter gap
      }
    }
    if (w < wordList.length - 1) {
      pulses.add(Pulse(isOn: false, durationMs: unit * 7)); // word gap
    }
  }
  pulses.add(Pulse(isOn: false, durationMs: unit * 8)); // trailing silence
  return pulses;
}

TransmissionSynchronizer _sync() => TransmissionSynchronizer(
      estimator: MedianUnitEstimator(seedUnitMs: 180),
      classifier: PulseClassifier(),
    );

String decodeAll(List<Pulse> pulses) {
  final sync = _sync();
  final acc = MorseAccumulator();
  for (final p in pulses) {
    for (final sym in sync.process(p)) {
      acc.add(sym);
    }
  }
  acc.flush();
  return MorseDecoder().decode(acc.letters).trim();
}

void main() {
  test('SOS decodes', () {
    expect(decodeAll(pulsesFor('... --- ...', 100)), 'SOS');
  });

  test('HELLO decodes', () {
    expect(decodeAll(pulsesFor('.... . .-.. .-.. ---', 120)), 'HELLO');
  });

  test('single letter E decodes', () {
    // Single symbols rely on the seed unit (canonical 180ms).
    expect(decodeAll(pulsesFor('.', 180)), 'E');
  });

  test('single letter T decodes', () {
    expect(decodeAll(pulsesFor('-', 180)), 'T');
  });

  test('numbers 123 decode', () {
    expect(decodeAll(pulsesFor('.---- ..--- ...--', 120)), '123');
  });

  test('mixed message SOS HELP decodes with a space', () {
    expect(decodeAll(pulsesFor('... --- ... / .... . .-.. .--.', 120)),
        'SOS HELP');
  });

  test('timing tolerance: jittered SOS still decodes', () {
    final base = pulsesFor('... --- ...', 100);
    final jittered = [
      for (var i = 0; i < base.length; i++)
        Pulse(
          isOn: base[i].isOn,
          // even index = ON (shorter), odd = OFF (longer): +/-12% wobble.
          durationMs: (base[i].durationMs * (i.isEven ? 0.88 : 1.12)).round(),
        ),
    ];
    expect(decodeAll(jittered), 'SOS');
  });

  test('noise while searching: no ON signal → no decode, no crash', () {
    final sync = _sync();
    final acc = MorseAccumulator();
    expect(() {
      for (final p in const [
        Pulse(isOn: false, durationMs: 40),
        Pulse(isOn: false, durationMs: 250),
        Pulse(isOn: false, durationMs: 40),
      ]) {
        for (final s in sync.process(p)) {
          acc.add(s);
        }
      }
      acc.flush();
    }, returnsNormally);
    expect(MorseDecoder().decode(acc.letters).trim(), '');
  });

  test('invalid / garbage pulses never crash the pipeline', () {
    final sync = _sync();
    final acc = MorseAccumulator();
    expect(() {
      for (final p in const [
        Pulse(isOn: true, durationMs: 0),
        Pulse(isOn: false, durationMs: -5),
        Pulse(isOn: true, durationMs: 99999),
        Pulse(isOn: false, durationMs: 1),
        Pulse(isOn: true, durationMs: 7),
        Pulse(isOn: false, durationMs: 100000),
      ]) {
        for (final s in sync.process(p)) {
          acc.add(s);
        }
      }
      acc.flush();
      MorseDecoder().decode(acc.letters);
    }, returnsNormally);
  });
}
