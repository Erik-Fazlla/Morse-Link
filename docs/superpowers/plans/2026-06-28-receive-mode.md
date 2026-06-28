# RECEIVE Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Receive Morse transmitted by another phone's flashlight via the camera and decode it to readable text, without modifying SEND behavior.

**Architecture:** A staged push pipeline — CameraLightSource → LightDetector → PulseTimer → TransmissionSynchronizer (gates decoding behind a sync phase) → PulseClassifier → MorseAccumulator → MorseDecoder → ReceiveController → UI. Pure-logic stages are TDD'd against synthetic data; camera + UI are validated on device. Shared Morse alphabet + timing constants are extracted once and reused by SEND and RECEIVE.

**Tech Stack:** Flutter / Dart, `camera` plugin, `shared_preferences` (existing), `flutter_test`.

**Source spec:** `docs/superpowers/specs/2026-06-28-receive-mode-design.md`

**Milestone rule:** Implement ONE milestone at a time. After each, run the full SEND regression (`flutter test`) and verify the milestone's objectives before starting the next. Do not combine milestones or do unrelated refactors.

---

## File Structure

**Shared refactor (M0):**
- Create `lib/features/morse/domain/morse_alphabet.dart` — the single canonical `kMorseAlphabet` map.
- Create `lib/features/morse/domain/morse_timing.dart` — `MorseTiming` unit-ratio constants.
- Modify `lib/features/morse/services/morse_translator.dart` — reference `kMorseAlphabet`.
- Modify `lib/features/morse/services/timing_sequence_builder.dart` — reference `MorseTiming`.

**RECEIVE domain (M1–M2):**
- `lib/features/receive/domain/{light_reading,pulse,pulse_symbol,sync_phase,signal_quality,receive_state,decoded_message}.dart`

**RECEIVE services:**
- `lib/features/receive/services/unit_estimator.dart` (M1)
- `lib/features/receive/services/pulse_classifier.dart` (M1)
- `lib/features/receive/services/morse_accumulator.dart` (M1)
- `lib/features/receive/services/morse_decoder.dart` (M1)
- `lib/features/receive/services/transmission_synchronizer.dart` (M1)
- `lib/features/receive/services/light_source.dart` (M2 — interface + FakeLightSource)
- `lib/features/receive/services/light_detector.dart` (M2)
- `lib/features/receive/services/pulse_timer.dart` (M2)
- `lib/features/receive/services/camera_light_source.dart` (M3)

**RECEIVE presentation (M3–M4):**
- `lib/features/receive/presentation/receive_controller.dart` (M3)
- `lib/features/receive/presentation/screens/receive_screen.dart` (M4)
- Modify `lib/features/send/presentation/screens/home_screen.dart` (M4 — enable RECEIVE tile)

**Tests:**
- `test/receive/*_test.dart` per service + an end-to-end pipeline test.

---

# Milestone M0 — Shared Morse Domain Refactor

**Objective:** Extract the alphabet and timing ratios into shared domain files and repoint SEND, with zero behavior change. Existing tests stay green.

### Task M0.1: Extract canonical alphabet

**Files:**
- Create: `lib/features/morse/domain/morse_alphabet.dart`
- Modify: `lib/features/morse/services/morse_translator.dart`

- [ ] **Step 1: Create the alphabet file**

```dart
/// Canonical Morse alphabet — single source of truth for SEND (translation)
/// and RECEIVE (decoding). Keys are uppercase characters; values are
/// dot/dash strings.
const Map<String, String> kMorseAlphabet = {
  'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.',
  'F': '..-.', 'G': '--.', 'H': '....', 'I': '..', 'J': '.---',
  'K': '-.-', 'L': '.-..', 'M': '--', 'N': '-.', 'O': '---',
  'P': '.--.', 'Q': '--.-', 'R': '.-.', 'S': '...', 'T': '-',
  'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-', 'Y': '-.--',
  'Z': '--..',
  '0': '-----', '1': '.----', '2': '..---', '3': '...--', '4': '....-',
  '5': '.....', '6': '-....', '7': '--...', '8': '---..', '9': '----.',
  '.': '.-.-.-', ',': '--..--', '?': '..--..', '!': '-.-.--', '/': '-..-.',
  '-': '-....-', '(': '-.--.', ')': '-.--.-', ':': '---...', ';': '-.-.-.',
  '=': '-...-', '+': '.-.-.', '@': '.--.-.', '\'': '.----.', '"': '.-..-.',
};
```

- [ ] **Step 2: Repoint the translator**

In `lib/features/morse/services/morse_translator.dart`: delete the `static const Map<String, String> _alphabet = {...};` block (lines 4–56). Add at top:
```dart
import '../domain/morse_alphabet.dart';
```
Replace the single use `final symbols = _alphabet[character];` with:
```dart
final symbols = kMorseAlphabet[character];
```

- [ ] **Step 3: Run SEND translator tests — must stay green**

Run: `flutter test test/morse_translator_test.dart`
Expected: PASS (behavior identical; only the map's location changed).

- [ ] **Step 4: Commit**

```bash
git add lib/features/morse/domain/morse_alphabet.dart lib/features/morse/services/morse_translator.dart
git commit -m "refactor: extract canonical kMorseAlphabet, repoint translator"
```

### Task M0.2: Extract timing ratios

**Files:**
- Create: `lib/features/morse/domain/morse_timing.dart`
- Modify: `lib/features/morse/services/timing_sequence_builder.dart`

- [ ] **Step 1: Create the timing constants file**

```dart
/// Morse timing as unit multiples — shared by SEND (sequence building) and
/// RECEIVE (pulse classification). One time-unit = `unitMs`.
class MorseTiming {
  const MorseTiming._();

  static const int dotUnits = 1;
  static const int dashUnits = 3;
  static const int symbolGapUnits = 1;
  static const int letterGapUnits = 3;
  static const int wordGapUnits = 7;
}
```

- [ ] **Step 2: Repoint the builder**

In `lib/features/morse/services/timing_sequence_builder.dart`, add:
```dart
import '../domain/morse_timing.dart';
```
Replace the hardcoded multiples:
- signal `durationMs: symbol == '.' ? unitMs : unitMs * 3,` → `durationMs: symbol == '.' ? unitMs * MorseTiming.dotUnits : unitMs * MorseTiming.dashUnits,`
- symbol gap `durationMs: unitMs,` → `durationMs: unitMs * MorseTiming.symbolGapUnits,`
- letter gap `durationMs: unitMs * 3,` → `durationMs: unitMs * MorseTiming.letterGapUnits,`
- word gap `durationMs: unitMs * 7,` → `durationMs: unitMs * MorseTiming.wordGapUnits,`

- [ ] **Step 3: Run full regression — must stay green**

Run: `flutter test`
Expected: PASS (all existing SEND tests; output ms values are numerically identical).

- [ ] **Step 4: Commit**

```bash
git add lib/features/morse/domain/morse_timing.dart lib/features/morse/services/timing_sequence_builder.dart
git commit -m "refactor: extract MorseTiming ratios, repoint sequence builder"
```

### M0 Verification Gate
- [ ] `flutter test` fully green.
- [ ] `flutter analyze` clean.
- [ ] Confirm no SEND `.dart` file other than `morse_translator.dart` and `timing_sequence_builder.dart` changed: `git diff --stat c36058a -- lib/features/send lib/features/morse/services lib/features/protocol`.
- [ ] STOP. Report results before M1.

---

# Milestone M1 — Decode Core (no camera)

**Objective:** Build the pure-logic decode chain (estimator → synchronizer → classifier → accumulator → decoder) and prove a synthetic pulse train for "SOS" and "HELLO" decodes correctly. No camera, fully unit-tested.

### Task M1.1: Domain models

**Files:**
- Create: `lib/features/receive/domain/pulse.dart`, `pulse_symbol.dart`, `sync_phase.dart`, `light_reading.dart`, `signal_quality.dart`
- Test: `test/receive/domain_test.dart`

- [ ] **Step 1: Create the domain files**

`pulse.dart`:
```dart
/// One measured light interval. `isOn` = light was on; `durationMs` = length.
class Pulse {
  const Pulse({required this.isOn, required this.durationMs});
  final bool isOn;
  final int durationMs;
}
```

`pulse_symbol.dart`:
```dart
/// A classified pulse. ON pulses map to dot/dash; OFF pulses map to gaps.
enum PulseSymbol { dot, dash, symbolGap, letterGap, wordGap, unknown }
```

`sync_phase.dart`:
```dart
/// Synchronizer state. Decoding only runs while [locked].
enum SyncPhase { searching, synchronizing, locked }
```

`light_reading.dart`:
```dart
/// One luminance sample. `luminance` is mean Y-plane brightness (0–255).
class LightReading {
  const LightReading({required this.luminance, required this.timestampMs});
  final double luminance;
  final int timestampMs;
}
```

`signal_quality.dart`:
```dart
/// Two distinct measures, never merged:
/// - [signalStrengthPct]: optical contrast (ON vs OFF luminance).
/// - [decodeConfidencePct]: timing fit of pulses to unit multiples.
class SignalQuality {
  const SignalQuality({
    this.detected = false,
    this.estUnitMs = 0,
    this.signalStrengthPct = 0,
    this.decodeConfidencePct = 0,
  });

  final bool detected;
  final int estUnitMs;
  final double signalStrengthPct;
  final double decodeConfidencePct;

  static const idle = SignalQuality();

  SignalQuality copyWith({
    bool? detected,
    int? estUnitMs,
    double? signalStrengthPct,
    double? decodeConfidencePct,
  }) =>
      SignalQuality(
        detected: detected ?? this.detected,
        estUnitMs: estUnitMs ?? this.estUnitMs,
        signalStrengthPct: signalStrengthPct ?? this.signalStrengthPct,
        decodeConfidencePct: decodeConfidencePct ?? this.decodeConfidencePct,
      );
}
```

- [ ] **Step 2: Write a smoke test**

`test/receive/domain_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/signal_quality.dart';

void main() {
  test('Pulse holds fields', () {
    const p = Pulse(isOn: true, durationMs: 180);
    expect(p.isOn, true);
    expect(p.durationMs, 180);
  });

  test('SignalQuality.copyWith updates one field', () {
    final q = SignalQuality.idle.copyWith(signalStrengthPct: 80);
    expect(q.signalStrengthPct, 80);
    expect(q.decodeConfidencePct, 0);
  });
}
```

- [ ] **Step 3: Run — expect PASS**

Run: `flutter test test/receive/domain_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/receive/domain test/receive/domain_test.dart
git commit -m "feat(receive): add pipeline domain models"
```

### Task M1.2: MorseDecoder

**Files:**
- Create: `lib/features/receive/services/morse_decoder.dart`
- Test: `test/receive/morse_decoder_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/morse_decoder.dart';

void main() {
  final decoder = MorseDecoder();

  test('decodes single letters', () {
    expect(decoder.decodeLetter('...'), 'S');
    expect(decoder.decodeLetter('---'), 'O');
    expect(decoder.decodeLetter('.-'), 'A');
  });

  test('unknown code returns "?"', () {
    expect(decoder.decodeLetter('........'), '?');
  });

  test('decodes a sequence with a word break', () {
    // HELLO WORLD letters
    final letters = ['....', '.', '.-..', '.-..', '---'];
    expect(decoder.decode(letters), 'HELLO');
  });
}
```

- [ ] **Step 2: Run — expect FAIL (MorseDecoder undefined)**

Run: `flutter test test/receive/morse_decoder_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../../morse/domain/morse_alphabet.dart';

/// Decodes Morse codes to text using the inverse of [kMorseAlphabet].
class MorseDecoder {
  MorseDecoder()
      : _inverse = {
          for (final entry in kMorseAlphabet.entries) entry.value: entry.key,
        };

  final Map<String, String> _inverse;

  /// One letter's code ('...') to a character; '?' if unrecognized/empty.
  String decodeLetter(String code) {
    if (code.isEmpty) return '';
    return _inverse[code] ?? '?';
  }

  /// A list of letter codes to text. Use a null/empty entry as a word break
  /// (rendered as a space).
  String decode(List<String> letters) {
    final buffer = StringBuffer();
    for (final code in letters) {
      if (code.isEmpty) {
        buffer.write(' ');
      } else {
        buffer.write(decodeLetter(code));
      }
    }
    return buffer.toString();
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/morse_decoder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/morse_decoder.dart test/receive/morse_decoder_test.dart
git commit -m "feat(receive): add MorseDecoder (inverse of shared alphabet)"
```

### Task M1.3: PulseClassifier

**Files:**
- Create: `lib/features/receive/services/pulse_classifier.dart`
- Test: `test/receive/pulse_classifier_test.dart`

Boundaries derived from `MorseTiming` ratios (midpoints): ON dot/dash split at 2u; OFF symbol/letter split at 2u, letter/word split at 5u. An ON pulse longer than 6u or any pulse ≤ 0 → `unknown`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';

void main() {
  final c = PulseClassifier();
  const unit = 100;

  test('ON pulses → dot / dash', () {
    expect(c.classify(const Pulse(isOn: true, durationMs: 100), unit), PulseSymbol.dot);
    expect(c.classify(const Pulse(isOn: true, durationMs: 300), unit), PulseSymbol.dash);
    expect(c.classify(const Pulse(isOn: true, durationMs: 130), unit), PulseSymbol.dot);
    expect(c.classify(const Pulse(isOn: true, durationMs: 260), unit), PulseSymbol.dash);
  });

  test('OFF pulses → symbol / letter / word gap', () {
    expect(c.classify(const Pulse(isOn: false, durationMs: 100), unit), PulseSymbol.symbolGap);
    expect(c.classify(const Pulse(isOn: false, durationMs: 300), unit), PulseSymbol.letterGap);
    expect(c.classify(const Pulse(isOn: false, durationMs: 700), unit), PulseSymbol.wordGap);
  });

  test('garbage → unknown', () {
    expect(c.classify(const Pulse(isOn: true, durationMs: 0), unit), PulseSymbol.unknown);
    expect(c.classify(const Pulse(isOn: true, durationMs: 900), unit), PulseSymbol.unknown);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/pulse_classifier_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../../morse/domain/morse_timing.dart';
import '../domain/pulse.dart';
import '../domain/pulse_symbol.dart';

/// Maps a measured [Pulse] to a [PulseSymbol] relative to the current unit.
/// Never hardcodes ms — boundaries are midpoints of the MorseTiming ratios.
class PulseClassifier {
  PulseSymbol classify(Pulse pulse, int unitMs) {
    if (unitMs <= 0 || pulse.durationMs <= 0) return PulseSymbol.unknown;
    final units = pulse.durationMs / unitMs;

    if (pulse.isOn) {
      // dot=1u, dash=3u → split at 2u; reject absurdly long ON.
      const dotDashSplit = (MorseTiming.dotUnits + MorseTiming.dashUnits) / 2; // 2
      const maxOnUnits = MorseTiming.dashUnits * 2; // 6
      if (units > maxOnUnits) return PulseSymbol.unknown;
      return units < dotDashSplit ? PulseSymbol.dot : PulseSymbol.dash;
    }

    // OFF: symbol=1u, letter=3u, word=7u.
    const symLetterSplit = (MorseTiming.symbolGapUnits + MorseTiming.letterGapUnits) / 2; // 2
    const letterWordSplit = (MorseTiming.letterGapUnits + MorseTiming.wordGapUnits) / 2; // 5
    if (units < symLetterSplit) return PulseSymbol.symbolGap;
    if (units < letterWordSplit) return PulseSymbol.letterGap;
    return PulseSymbol.wordGap;
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/pulse_classifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/pulse_classifier.dart test/receive/pulse_classifier_test.dart
git commit -m "feat(receive): add PulseClassifier"
```

### Task M1.4: MorseAccumulator

**Files:**
- Create: `lib/features/receive/services/morse_accumulator.dart`
- Test: `test/receive/morse_accumulator_test.dart`

Behavior: `dot`/`dash` append to the in-progress letter. `symbolGap` is a no-op (within-letter separator). `letterGap` flushes the letter. `wordGap` flushes the letter then pushes an empty word-break marker. `unknown` is ignored. `flush()` pushes any in-progress letter (call on idle timeout / stop). `letters` returns completed letter codes (empty string = word break). `liveMorse` renders completed + in-progress as a space-separated string with ` / ` between words.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/services/morse_accumulator.dart';

void main() {
  test('accumulates SOS letters', () {
    final a = MorseAccumulator();
    // S = ... (gaps between dots are symbolGap)
    for (final s in [
      PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot,
      PulseSymbol.letterGap,
      PulseSymbol.dash, PulseSymbol.symbolGap, PulseSymbol.dash, PulseSymbol.symbolGap, PulseSymbol.dash,
      PulseSymbol.letterGap,
      PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot,
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
    a.add(PulseSymbol.wordGap); // flushes 'A'-start letter '.', adds break
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
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/morse_accumulator_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../domain/pulse_symbol.dart';

/// Turns a [PulseSymbol] stream into Morse letter codes and a live string.
class MorseAccumulator {
  final List<String> _letters = [];
  final StringBuffer _current = StringBuffer();

  /// Completed letter codes. An empty string marks a word break.
  List<String> get letters => List.unmodifiable(_letters);

  void add(PulseSymbol symbol) {
    switch (symbol) {
      case PulseSymbol.dot:
        _current.write('.');
        break;
      case PulseSymbol.dash:
        _current.write('-');
        break;
      case PulseSymbol.symbolGap:
        break; // within-letter separator; nothing to record
      case PulseSymbol.letterGap:
        _flushCurrent();
        break;
      case PulseSymbol.wordGap:
        _flushCurrent();
        _letters.add(''); // word break
        break;
      case PulseSymbol.unknown:
        break; // skip noise
    }
  }

  /// Push any in-progress letter (call on stop / idle timeout).
  void flush() => _flushCurrent();

  void _flushCurrent() {
    if (_current.isNotEmpty) {
      _letters.add(_current.toString());
      _current.clear();
    }
  }

  /// Running Morse string for live display.
  String liveMorse {
    final parts = <String>[];
    final words = <String>[];
    final wordLetters = <String>[];
    for (final code in _letters) {
      if (code.isEmpty) {
        words.add(wordLetters.join(' '));
        wordLetters.clear();
      } else {
        wordLetters.add(code);
      }
    }
    if (_current.isNotEmpty) wordLetters.add(_current.toString());
    if (wordLetters.isNotEmpty) words.add(wordLetters.join(' '));
    parts.addAll(words);
    return parts.join(' / ');
  }

  void reset() {
    _letters.clear();
    _current.clear();
  }
}
```

Note: `liveMorse` is a getter — change signature to `String get liveMorse {`.

- [ ] **Step 4: Fix the getter syntax**

Ensure the declaration reads `String get liveMorse {` (not `String liveMorse {`).

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/receive/morse_accumulator_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/receive/services/morse_accumulator.dart test/receive/morse_accumulator_test.dart
git commit -m "feat(receive): add MorseAccumulator"
```

### Task M1.5: UnitEstimator

**Files:**
- Create: `lib/features/receive/services/unit_estimator.dart`
- Test: `test/receive/unit_estimator_test.dart`

Interface + default median impl. Seeds 180ms. Consumes ON-pulse durations. The unit estimate = median of the "dot cluster" (durations ≤ 1.6× the running minimum ON duration). `isStable` once ≥ 3 ON pulses recorded.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

void main() {
  test('seeds default before any input', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    expect(e.estimatedUnitMs, 180);
    expect(e.isStable, false);
  });

  test('converges to dot length from ON pulses (dots + dashes)', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    // dots ~100ms, dashes ~300ms
    for (final d in [100, 300, 100, 100, 300]) {
      e.addOnPulse(d);
    }
    expect(e.isStable, true);
    expect(e.estimatedUnitMs, inInclusiveRange(90, 110));
  });

  test('reset clears state', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    e.addOnPulse(100);
    e.reset();
    expect(e.estimatedUnitMs, 180);
    expect(e.isStable, false);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/unit_estimator_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
/// Estimates the Morse time-unit (ms) from observed ON-pulse durations.
/// Swap this implementation for future auto-calibration.
abstract class UnitEstimator {
  int get estimatedUnitMs;
  bool get isStable;
  void addOnPulse(int durationMs);
  void reset();
}

class MedianUnitEstimator implements UnitEstimator {
  MedianUnitEstimator({this.seedUnitMs = 180}) : _unit = seedUnitMs;

  final int seedUnitMs;
  final List<int> _onDurations = [];
  int _unit;

  @override
  int get estimatedUnitMs => _unit;

  @override
  bool get isStable => _onDurations.length >= 3;

  @override
  void addOnPulse(int durationMs) {
    if (durationMs <= 0) return;
    _onDurations.add(durationMs);
    final minOn = _onDurations.reduce((a, b) => a < b ? a : b);
    final dotCluster = _onDurations.where((d) => d <= minOn * 1.6).toList()..sort();
    _unit = _median(dotCluster);
  }

  @override
  void reset() {
    _onDurations.clear();
    _unit = seedUnitMs;
  }

  int _median(List<int> sorted) {
    if (sorted.isEmpty) return _unit;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/unit_estimator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/unit_estimator.dart test/receive/unit_estimator_test.dart
git commit -m "feat(receive): add UnitEstimator (median dot-cluster)"
```

### Task M1.6: TransmissionSynchronizer

**Files:**
- Create: `lib/features/receive/services/transmission_synchronizer.dart`
- Test: `test/receive/transmission_synchronizer_test.dart`

Behavior: gates decoding behind a sync phase, owns the estimator, and **buffers pulses during searching/synchronizing then replays them on lock** so no leading symbols are lost.
- `searching`: first ON pulse → buffer it, feed estimator, go `synchronizing`.
- `synchronizing`: buffer pulses; feed ON pulses to estimator; when `estimator.isStable` → `locked`, then replay the whole buffer through the classifier and return those symbols.
- `locked`: classify the pulse immediately, return one symbol.
- `process(Pulse)` returns `List<PulseSymbol>` (empty while still buffering; the replayed batch on the lock transition; a single-element list while locked).
- `noteSilence()` / long idle handling lives in the controller; the synchronizer exposes `reset()` to return to `searching`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/domain/sync_phase.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';
import 'package:morse/features/receive/services/transmission_synchronizer.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

void main() {
  TransmissionSynchronizer build() => TransmissionSynchronizer(
        estimator: MedianUnitEstimator(seedUnitMs: 180),
        classifier: PulseClassifier(),
      );

  test('starts searching', () {
    expect(build().phase, SyncPhase.searching);
  });

  test('buffers during sync then replays on lock; nothing lost', () {
    final s = build();
    final emitted = <PulseSymbol>[];
    // S = dot, gap, dot, gap, dot  (3 ON pulses → estimator stable on the 3rd)
    final pulses = <Pulse>[
      const Pulse(isOn: true, durationMs: 100),
      const Pulse(isOn: false, durationMs: 100),
      const Pulse(isOn: true, durationMs: 100),
      const Pulse(isOn: false, durationMs: 100),
      const Pulse(isOn: true, durationMs: 100),
    ];
    for (final p in pulses) {
      emitted.addAll(s.process(p));
    }
    expect(s.phase, SyncPhase.locked);
    expect(emitted, [
      PulseSymbol.dot, PulseSymbol.symbolGap,
      PulseSymbol.dot, PulseSymbol.symbolGap, PulseSymbol.dot,
    ]);
  });

  test('reset returns to searching', () {
    final s = build();
    s.process(const Pulse(isOn: true, durationMs: 100));
    s.reset();
    expect(s.phase, SyncPhase.searching);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/transmission_synchronizer_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../domain/pulse.dart';
import '../domain/pulse_symbol.dart';
import '../domain/sync_phase.dart';
import 'pulse_classifier.dart';
import 'unit_estimator.dart';

/// Gates decoding behind a synchronization phase. Buffers leading pulses
/// while the estimator stabilizes, then replays them on lock so no symbols
/// are lost. Seam for future preamble detection / acknowledgements.
class TransmissionSynchronizer {
  TransmissionSynchronizer({
    required UnitEstimator estimator,
    required PulseClassifier classifier,
  })  : _estimator = estimator,
        _classifier = classifier;

  final UnitEstimator _estimator;
  final PulseClassifier _classifier;
  final List<Pulse> _buffer = [];
  SyncPhase _phase = SyncPhase.searching;

  SyncPhase get phase => _phase;
  int get estimatedUnitMs => _estimator.estimatedUnitMs;

  /// Feed one pulse. Returns the symbols ready for decoding (possibly empty,
  /// or the replayed batch on the lock transition).
  List<PulseSymbol> process(Pulse pulse) {
    if (_phase == SyncPhase.locked) {
      if (pulse.isOn) _estimator.addOnPulse(pulse.durationMs);
      return [_classifier.classify(pulse, _estimator.estimatedUnitMs)];
    }

    // searching / synchronizing: buffer and calibrate from ON pulses.
    if (_phase == SyncPhase.searching && pulse.isOn) {
      _phase = SyncPhase.synchronizing;
    }
    _buffer.add(pulse);
    if (pulse.isOn) _estimator.addOnPulse(pulse.durationMs);

    if (_phase == SyncPhase.synchronizing && _estimator.isStable) {
      _phase = SyncPhase.locked;
      final unit = _estimator.estimatedUnitMs;
      final replayed = _buffer
          .map((p) => _classifier.classify(p, unit))
          .toList(growable: false);
      _buffer.clear();
      return replayed;
    }
    return const [];
  }

  void reset() {
    _phase = SyncPhase.searching;
    _buffer.clear();
    _estimator.reset();
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/transmission_synchronizer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/transmission_synchronizer.dart test/receive/transmission_synchronizer_test.dart
git commit -m "feat(receive): add TransmissionSynchronizer (buffer + replay on lock)"
```

### Task M1.7: Decode-chain integration test

**Files:**
- Test: `test/receive/decode_chain_test.dart`

- [ ] **Step 1: Write the test (synthetic pulse train → text)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/services/morse_accumulator.dart';
import 'package:morse/features/receive/services/morse_decoder.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';
import 'package:morse/features/receive/services/transmission_synchronizer.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

/// Build the ON/OFF pulse train for a message at a given unit.
List<Pulse> pulsesFor(String morseWords, int unit) {
  // morseWords: letters separated by ' ', words by '/'. e.g. '... --- ...'
  final pulses = <Pulse>[];
  final words = morseWords.split('/').map((w) => w.trim()).toList();
  for (var w = 0; w < words.length; w++) {
    final letters = words[w].split(' ').where((s) => s.isNotEmpty).toList();
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
    if (w < words.length - 1) {
      pulses.add(Pulse(isOn: false, durationMs: unit * 7)); // word gap
    }
  }
  return pulses;
}

String decodeAll(List<Pulse> pulses) {
  final sync = TransmissionSynchronizer(
    estimator: MedianUnitEstimator(seedUnitMs: 180),
    classifier: PulseClassifier(),
  );
  final acc = MorseAccumulator();
  for (final p in pulses) {
    for (final sym in sync.process(p)) {
      acc.add(sym);
    }
  }
  acc.flush();
  return MorseDecoder().decode(acc.letters);
}

void main() {
  test('SOS decodes', () {
    expect(decodeAll(pulsesFor('... --- ...', 100)), 'SOS');
  });

  test('HELLO decodes', () {
    expect(decodeAll(pulsesFor('.... . .-.. .-.. ---', 120)), 'HELLO');
  });

  test('two words decode with a space', () {
    expect(decodeAll(pulsesFor('.... .. / - .... . .-. .', 100)), 'HI THERE');
  });
}
```

- [ ] **Step 2: Run — expect PASS (all stages wired)**

Run: `flutter test test/receive/decode_chain_test.dart`
Expected: PASS. If "HI" loses its first letter, the synchronizer's buffer/replay is broken — fix M1.6, not the test.

- [ ] **Step 3: Commit**

```bash
git add test/receive/decode_chain_test.dart
git commit -m "test(receive): end-to-end decode chain (SOS/HELLO/two-words)"
```

### M1 Verification Gate
- [ ] `flutter test` fully green (SEND regression + all new receive tests).
- [ ] `flutter analyze` clean.
- [ ] Decode chain produces `SOS`, `HELLO`, `HI THERE`.
- [ ] STOP. Report before M2.

---

# Milestone M2 — Light → Pulses (offline, FakeLightSource)

**Objective:** Convert a luminance-reading stream into ON/OFF transitions and pulses, and run the FULL pipeline end-to-end against a `FakeLightSource` (no camera). Prove a synthetic luminance train for "SOS" decodes.

### Task M2.1: LightSource interface + FakeLightSource

**Files:**
- Create: `lib/features/receive/services/light_source.dart`
- Test: `test/receive/light_source_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/light_reading.dart';
import 'package:morse/features/receive/services/light_source.dart';

void main() {
  test('FakeLightSource emits queued readings then completes', () async {
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
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/light_source_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../domain/light_reading.dart';

typedef LightReadingCallback = void Function(LightReading reading);

/// Source of luminance samples. Implemented by FakeLightSource (tests) and
/// CameraLightSource (device).
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
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/light_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/light_source.dart test/receive/light_source_test.dart
git commit -m "feat(receive): add LightSource interface + FakeLightSource"
```

### Task M2.2: LightDetector (luminance → transitions)

**Files:**
- Create: `lib/features/receive/services/light_detector.dart`
- Test: `test/receive/light_detector_test.dart`

Behavior: adaptive threshold with hysteresis. Tracks a running min (dark) and max (bright); threshold = midpoint; hysteresis band ±10% of range avoids chatter. Emits a transition `(bool isOn, int atMs)` only when state flips. Exposes `signalStrengthPct` = `(max-min)/255*100`. Until the range is meaningful (max-min < `minRangeForSignal`, default 20), reports no signal and emits nothing.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/light_reading.dart';
import 'package:morse/features/receive/services/light_detector.dart';

void main() {
  test('emits ON/OFF transitions across the adaptive threshold', () {
    final d = LightDetector();
    final transitions = <bool>[];
    void feed(double lum, int t) {
      final tr = d.process(LightReading(luminance: lum, timestampMs: t));
      if (tr != null) transitions.add(tr.isOn);
    }

    // establish range, then bright (ON), dark (OFF), bright (ON)
    feed(10, 0);
    feed(220, 100);
    feed(220, 130);
    feed(10, 200);
    feed(220, 300);
    expect(transitions, [true, false, true]);
  });

  test('flat dark input → no signal, no transitions', () {
    final d = LightDetector();
    final transitions = [];
    for (var t = 0; t < 5; t++) {
      final tr = d.process(LightReading(luminance: 8, timestampMs: t * 50));
      if (tr != null) transitions.add(tr);
    }
    expect(transitions, isEmpty);
    expect(d.signalStrengthPct, lessThan(10));
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/light_detector_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../domain/light_reading.dart';

/// A light ON/OFF transition at a timestamp.
class LightTransition {
  const LightTransition({required this.isOn, required this.atMs});
  final bool isOn;
  final int atMs;
}

/// Converts a luminance stream into ON/OFF transitions using an adaptive
/// threshold with hysteresis. Swap for future noise filtering.
class LightDetector {
  LightDetector({this.minRangeForSignal = 20});

  final double minRangeForSignal;
  double? _min;
  double? _max;
  bool _isOn = false;
  bool _hasState = false;

  double get signalStrengthPct {
    if (_min == null || _max == null) return 0;
    return ((_max! - _min!) / 255.0 * 100).clamp(0, 100);
  }

  bool get hasSignal => (_max ?? 0) - (_min ?? 0) >= minRangeForSignal;

  LightTransition? process(LightReading r) {
    _min = _min == null ? r.luminance : (r.luminance < _min! ? r.luminance : _min);
    _max = _max == null ? r.luminance : (r.luminance > _max! ? r.luminance : _max);

    if (!hasSignal) return null;

    final mid = (_min! + _max!) / 2;
    final band = (_max! - _min!) * 0.1;
    final nextOn = r.luminance > mid + band
        ? true
        : (r.luminance < mid - band ? false : _isOn);

    if (!_hasState) {
      _hasState = true;
      _isOn = nextOn;
      return LightTransition(isOn: nextOn, atMs: r.timestampMs);
    }
    if (nextOn != _isOn) {
      _isOn = nextOn;
      return LightTransition(isOn: nextOn, atMs: r.timestampMs);
    }
    return null;
  }

  void reset() {
    _min = null;
    _max = null;
    _isOn = false;
    _hasState = false;
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/light_detector_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/light_detector.dart test/receive/light_detector_test.dart
git commit -m "feat(receive): add LightDetector (adaptive threshold + hysteresis)"
```

### Task M2.3: PulseTimer (transitions → pulses)

**Files:**
- Create: `lib/features/receive/services/pulse_timer.dart`
- Test: `test/receive/pulse_timer_test.dart`

Behavior: each transition closes the previous interval. On a transition at `t`, if there was a prior transition at `t0` with state `s0`, emit `Pulse(isOn: s0, durationMs: t - t0)`. The current open interval is closed by `flush(nowMs)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/light_detector.dart';
import 'package:morse/features/receive/services/pulse_timer.dart';

void main() {
  test('produces pulses from transitions', () {
    final pt = PulseTimer();
    final out = [];
    void t(bool on, int at) {
      final p = pt.onTransition(LightTransition(isOn: on, atMs: at));
      if (p != null) out.add('${p.isOn ? "ON" : "OFF"} ${p.durationMs}');
    }

    t(true, 0);    // start ON
    t(false, 100); // closes ON 100
    t(true, 200);  // closes OFF 100
    final tail = pt.flush(500); // closes ON 300
    if (tail != null) out.add('${tail.isOn ? "ON" : "OFF"} ${tail.durationMs}');

    expect(out, ['ON 100', 'OFF 100', 'ON 300']);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/receive/pulse_timer_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import '../domain/pulse.dart';
import 'light_detector.dart';

/// Closes each light interval into a [Pulse] when the next transition arrives.
class PulseTimer {
  bool? _openState;
  int _openAtMs = 0;

  /// Returns the pulse that just ended, if any.
  Pulse? onTransition(LightTransition t) {
    Pulse? closed;
    if (_openState != null) {
      closed = Pulse(isOn: _openState!, durationMs: t.atMs - _openAtMs);
    }
    _openState = t.isOn;
    _openAtMs = t.atMs;
    return closed;
  }

  /// Close the currently open interval at [nowMs].
  Pulse? flush(int nowMs) {
    if (_openState == null) return null;
    final p = Pulse(isOn: _openState!, durationMs: nowMs - _openAtMs);
    _openState = null;
    return p;
  }

  void reset() {
    _openState = null;
    _openAtMs = 0;
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `flutter test test/receive/pulse_timer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/services/pulse_timer.dart test/receive/pulse_timer_test.dart
git commit -m "feat(receive): add PulseTimer (intervals → pulses)"
```

### Task M2.4: Full-pipeline test through FakeLightSource

**Files:**
- Test: `test/receive/pipeline_e2e_test.dart`

- [ ] **Step 1: Write the test (luminance train → text)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/light_reading.dart';
import 'package:morse/features/receive/services/light_detector.dart';
import 'package:morse/features/receive/services/light_source.dart';
import 'package:morse/features/receive/services/morse_accumulator.dart';
import 'package:morse/features/receive/services/morse_decoder.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';
import 'package:morse/features/receive/services/pulse_timer.dart';
import 'package:morse/features/receive/services/transmission_synchronizer.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

/// Build a luminance sample train (one sample per 20ms) for a morse string.
List<LightReading> luminanceFor(String morse, int unit) {
  const sampleMs = 20;
  const bright = 230.0, dark = 12.0;
  final readings = <LightReading>[];
  var t = 0;
  void hold(double lum, int durMs) {
    for (var elapsed = 0; elapsed < durMs; elapsed += sampleMs) {
      readings.add(LightReading(luminance: lum, timestampMs: t));
      t += sampleMs;
    }
  }

  final letters = morse.split(' ').where((s) => s.isNotEmpty).toList();
  for (var l = 0; l < letters.length; l++) {
    final symbols = letters[l].split('');
    for (var s = 0; s < symbols.length; s++) {
      hold(bright, symbols[s] == '.' ? unit : unit * 3);
      if (s < symbols.length - 1) hold(dark, unit);
    }
    if (l < letters.length - 1) hold(dark, unit * 3);
  }
  hold(dark, unit * 4); // trailing silence
  return readings;
}

void main() {
  test('SOS luminance train decodes through the full pipeline', () async {
    final source = FakeLightSource(luminanceFor('... --- ...', 200));
    final detector = LightDetector();
    final timer = PulseTimer();
    final sync = TransmissionSynchronizer(
      estimator: MedianUnitEstimator(seedUnitMs: 180),
      classifier: PulseClassifier(),
    );
    final acc = MorseAccumulator();
    var lastMs = 0;

    await source.start((reading) {
      lastMs = reading.timestampMs;
      final tr = detector.process(reading);
      if (tr == null) return;
      final pulse = timer.onTransition(tr);
      if (pulse == null) return;
      for (final sym in sync.process(pulse)) {
        acc.add(sym);
      }
    });
    final tail = timer.flush(lastMs);
    if (tail != null) {
      for (final sym in sync.process(tail)) {
        acc.add(sym);
      }
    }
    acc.flush();

    expect(MorseDecoder().decode(acc.letters), 'SOS');
  });
}
```

- [ ] **Step 2: Run — expect PASS**

Run: `flutter test test/receive/pipeline_e2e_test.dart`
Expected: PASS. This is the offline proof of the whole detection→decode chain.

- [ ] **Step 3: Commit**

```bash
git add test/receive/pipeline_e2e_test.dart
git commit -m "test(receive): full pipeline e2e via FakeLightSource (SOS)"
```

### M2 Verification Gate
- [ ] `flutter test` fully green.
- [ ] `flutter analyze` clean.
- [ ] FakeLightSource SOS luminance train decodes to `SOS`.
- [ ] STOP. Report before M3.

---

# Milestone M3 — Camera Integration + Controller

**Objective:** Real camera feeds the pipeline; `ReceiveController` orchestrates with the SEND lifecycle discipline. Validated on device (no unit tests for camera glue — it requires hardware). Controller logic that IS testable gets a test with FakeLightSource.

> Camera/plugin glue code (exact `CameraImage` plane handling, controller init) is finalized against the installed `camera` plugin version at execution. The interfaces below are fixed; the plugin-specific body is filled in then and verified on device.

### Task M3.1: Add the camera dependency

**Files:** Modify `pubspec.yaml`; verify `android/app/src/main/AndroidManifest.xml`.

- [ ] **Step 1:** Add under `dependencies:` in `pubspec.yaml`: `camera: ^0.11.0+2` (pin to the latest 0.11.x resolved by `flutter pub get`).
- [ ] **Step 2:** Run `flutter pub get`. Expected: resolves without conflict.
- [ ] **Step 3:** Confirm `<uses-permission android:name="android.permission.CAMERA"/>` is present in `AndroidManifest.xml`. If absent, add it. (Camera permission is already requested at runtime by `TorchFlashlightController`.)
- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "build(receive): add camera dependency"
```

### Task M3.2: CameraLightSource

**Files:** Create `lib/features/receive/services/camera_light_source.dart`.

Implements `LightSource`. `start`: pick the rear camera, init a low-resolution `CameraController` (ResolutionPreset.low) with `enableAudio: false`, set `imageFormatGroup` (YUV420 on Android), call `startImageStream`. For each `CameraImage`, compute mean luminance by sampling every Nth byte of plane[0] (Y plane), build `LightReading(luminance: mean, timestampMs: DateTime.now().millisecondsSinceEpoch)`, call `onReading`. `stop`: `stopImageStream` + `dispose`. Returns `false` (not throws) when no camera / init fails. Exposes the `CameraController` (or a preview widget builder) for the screen.

- [ ] **Step 1:** Implement the class against the resolved `camera` API. Key points enforced:
  - Sample stride on the Y plane (e.g. every 16th byte) — keeps CPU low.
  - Never throw out of `start`/`stop`; catch `CameraException` → return false / no-op.
  - Guard the image-stream callback against use after `stop`.
- [ ] **Step 2:** `flutter analyze` clean.
- [ ] **Step 3:** Smoke-run on device: log mean luminance while waving the phone at a light; confirm values swing low↔high.
- [ ] **Step 4: Commit**

```bash
git add lib/features/receive/services/camera_light_source.dart
git commit -m "feat(receive): add CameraLightSource (Y-plane luminance sampling)"
```

### Task M3.3: ReceiveState model

**Files:** Create `lib/features/receive/domain/receive_state.dart`, `decoded_message.dart`.

- [ ] **Step 1:** Implement:

```dart
import 'signal_quality.dart';
import 'sync_phase.dart';

enum ReceiveStatus { idle, starting, receiving, stopped, error }

class ReceiveState {
  const ReceiveState({
    required this.status,
    required this.syncPhase,
    required this.quality,
    required this.liveMorse,
    required this.decodedText,
    this.errorMessage,
  });

  final ReceiveStatus status;
  final SyncPhase syncPhase;
  final SignalQuality quality;
  final String liveMorse;
  final String decodedText;
  final String? errorMessage;

  static const idle = ReceiveState(
    status: ReceiveStatus.idle,
    syncPhase: SyncPhase.searching,
    quality: SignalQuality.idle,
    liveMorse: '',
    decodedText: '',
  );

  bool get isReceiving => status == ReceiveStatus.receiving;

  ReceiveState copyWith({
    ReceiveStatus? status,
    SyncPhase? syncPhase,
    SignalQuality? quality,
    String? liveMorse,
    String? decodedText,
    String? errorMessage,
  }) =>
      ReceiveState(
        status: status ?? this.status,
        syncPhase: syncPhase ?? this.syncPhase,
        quality: quality ?? this.quality,
        liveMorse: liveMorse ?? this.liveMorse,
        decodedText: decodedText ?? this.decodedText,
        errorMessage: errorMessage,
      );
}
```

`decoded_message.dart`:
```dart
import 'signal_quality.dart';

class DecodedMessage {
  const DecodedMessage({
    required this.text,
    required this.morse,
    required this.receivedAt,
    required this.quality,
  });
  final String text;
  final String morse;
  final DateTime receivedAt;
  final SignalQuality quality;
}
```

- [ ] **Step 2:** `flutter analyze` clean.
- [ ] **Step 3: Commit**

```bash
git add lib/features/receive/domain/receive_state.dart lib/features/receive/domain/decoded_message.dart
git commit -m "feat(receive): add ReceiveState + DecodedMessage models"
```

### Task M3.4: ReceiveController

**Files:** Create `lib/features/receive/presentation/receive_controller.dart`; Test `test/receive/receive_controller_test.dart`.

Mirrors `SendController` lifecycle: `_isDisposed`, guarded methods, `_notifySafely()`, static `activeControllerCount`, `dispose()` stops the source and detaches. Takes a `LightSource` (injectable → FakeLightSource in tests), plus detector/timer/synchronizer/accumulator/decoder. `startReceiving()`: reset stages, `status=starting`, `source.start(...)`; on first failure set `error` (cameraUnavailable/permissionDenied). Per reading: run detector→timer→synchronizer→accumulator, recompute `decodedText` via decoder, update `liveMorse`, recompute `SignalQuality` (strength from detector, confidence from accumulator/classifier fit), `status=receiving`, `_notifySafely()`. An idle timer (Timer) flushes the pending letter after `unit*7` of silence. `stopReceiving()`: `source.stop()`, flush, `status=stopped`. Confidence metric: fraction of classified ON/OFF pulses that were not `unknown`, as a percentage.

- [ ] **Step 1: Write the failing test (FakeLightSource → decodedText == 'SOS')**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/presentation/receive_controller.dart';
import 'package:morse/features/receive/services/light_source.dart';
// reuse luminanceFor from a shared test helper or inline it here.

void main() {
  test('controller decodes SOS from a fake source and notifies', () async {
    final readings = /* luminanceFor('... --- ...', 200) — inline helper */;
    final controller = ReceiveController.forTest(
      source: FakeLightSource(readings),
    );
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.startReceiving();
    await controller.stopReceiving();

    expect(notified, true);
    expect(controller.state.decodedText, 'SOS');
    controller.dispose();
    expect(ReceiveController.activeControllerCount, 0);
  });
}
```

- [ ] **Step 2:** Run — expect FAIL (controller undefined).
- [ ] **Step 3:** Implement the controller with the lifecycle discipline above and a `ReceiveController.forTest({required LightSource source})` factory that wires default stages. Production constructor builds stages + `CameraLightSource`.
- [ ] **Step 4:** Run — expect PASS. `flutter analyze` clean.
- [ ] **Step 5: Commit**

```bash
git add lib/features/receive/presentation/receive_controller.dart test/receive/receive_controller_test.dart
git commit -m "feat(receive): add ReceiveController (SEND lifecycle discipline)"
```

### M3 Verification Gate
- [ ] `flutter test` fully green (incl. controller test via FakeLightSource).
- [ ] `flutter analyze` clean.
- [ ] On-device smoke: luminance swings logged; `ReceiveController.activeControllerCount` returns to 0 after dispose.
- [ ] STOP. Report before M4.

---

# Milestone M4 — RECEIVE Screen + Navigation

**Objective:** Build the RECEIVE UI and wire navigation. Validate on device against a real flashlight transmission from a second phone (or the SEND side of another device).

> Widget code (exact layout, `CameraPreview`) is finalized at execution against the camera plugin; the structure, state wiring, and the single SEND-file edit below are fixed.

### Task M4.1: ReceiveSessionScreen + ReceiveScreen

**Files:** Create `lib/features/receive/presentation/screens/receive_screen.dart`.

- [ ] **Step 1:** Implement `ReceiveSessionScreen` (StatefulWidget) that owns a `ReceiveController` and disposes it in `dispose()` — mirroring `SendSessionScreen`. It builds `ReceiveScreen(controller:)`.
- [ ] **Step 2:** Implement `ReceiveScreen` as an `AnimatedBuilder`/`ListenableBuilder` on the controller showing:
  - Live `CameraPreview` (when receiving) or a placeholder.
  - Sync-phase / detection status chip (searching / synchronizing / locked).
  - **Start Receiving** / **Stop Receiving** buttons (disabled per status).
  - Live Morse string (`state.liveMorse`).
  - Decoded text (`Receiving...` → `state.decodedText`).
  - **Two separate** indicators: Signal strength (`quality.signalStrengthPct`) and Decode confidence (`quality.decodeConfidencePct`), plus estimated unit (`quality.estUnitMs`).
  - Error banner when `status == error` (cameraUnavailable / permissionDenied).
- [ ] **Step 3:** `flutter analyze` clean. Run app, open RECEIVE, confirm no crash when starting/stopping with no signal.
- [ ] **Step 4: Commit**

```bash
git add lib/features/receive/presentation/screens/receive_screen.dart
git commit -m "feat(receive): add RECEIVE screen (preview, status, strength vs confidence)"
```

### Task M4.2: Enable navigation from HomeScreen

**Files:** Modify `lib/features/send/presentation/screens/home_screen.dart`.

- [ ] **Step 1:** Replace the RECEIVE `_DisabledPanel` (lines ~62–65) with an `_ActionPanel`:

```dart
_ActionPanel(
  title: 'RECEIVE',
  subtitle: 'Point the camera at another phone\'s flashlight to decode.',
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReceiveSessionScreen(),
      ),
    );
  },
),
```
Add the import: `import '../../../receive/presentation/screens/receive_screen.dart';`. Leave the SEND tile and `_buildSendController` untouched. (`_DisabledPanel` may become unused — remove it only if no longer referenced.)

- [ ] **Step 2:** Run — full regression: `flutter test`. Expected: PASS (this edit doesn't touch SEND logic; `widget_test` still green).
- [ ] **Step 3:** `flutter analyze` clean.
- [ ] **Step 4:** On-device end-to-end: Phone A SEND "SOS" / "HELLO" at a known unit; Phone B RECEIVE; confirm decode appears. Adjust detector stride / estimator seed only if needed (no interface changes).
- [ ] **Step 5: Commit**

```bash
git add lib/features/send/presentation/screens/home_screen.dart
git commit -m "feat(receive): enable RECEIVE navigation from home"
```

### M4 Verification Gate
- [ ] `flutter test` fully green (SEND regression intact).
- [ ] `flutter analyze` clean.
- [ ] On-device: a real flashlight "SOS" from another phone decodes to readable text. Camera unavailable / permission denied shows an error, never crashes.
- [ ] STOP. Report. Phase 2 success criteria met (save deferred per spec §13).

---

## Self-Review (completed by plan author)

**Spec coverage:** camera input (M3), light detection (M2), pulse timing (M2), classification (M1), synchronizer + sync phase (M1.6), morse builder (M1.4), decoder (M1.2), display (M4), strength vs confidence separated (M1.1 domain + M4 UI), error handling (M3/M4 gates), performance via low-res + Y-plane stride (M3.2), future-compat interfaces (UnitEstimator/LightSource/Synchronizer), shared refactor (M0), history deferred (no task — intentional per spec §13). All covered.

**Placeholders:** Pure-logic tasks (M0–M2) carry complete code + tests. Camera/UI bodies (M3.2, M4.1) are intentionally finalized against the live plugin at execution — flagged explicitly, with fixed interfaces and validation steps, because that glue is hardware-bound and not unit-testable.

**Type consistency:** `LightReading{luminance,timestampMs}`, `Pulse{isOn,durationMs}`, `LightTransition{isOn,atMs}`, `PulseSymbol`, `SyncPhase`, `SignalQuality{detected,estUnitMs,signalStrengthPct,decodeConfidencePct}`, `ReceiveState`, methods `process()/onTransition()/flush()/classify()/decode()/decodeLetter()/add()/letters/liveMorse` — used consistently across tasks and tests.
