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

// ---------------------------------------------------------------------------
// Synthetic luminance generation
// ---------------------------------------------------------------------------

class _Seg {
  const _Seg(this.durMs, this.on);
  final int durMs;
  final bool on;
}

/// Ideal ON/OFF segments for a Morse string with leading + trailing silence.
/// `morse`: letters by ' ', words by '/'. e.g. '... --- ...'
List<_Seg> _segments(String morse, int unit) {
  final segs = <_Seg>[const _Seg(400, false)]; // leading ambient
  final words =
      morse.split('/').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
  for (var w = 0; w < words.length; w++) {
    final letters = words[w].split(' ').where((s) => s.isNotEmpty).toList();
    for (var l = 0; l < letters.length; l++) {
      final syms = letters[l].split('');
      for (var s = 0; s < syms.length; s++) {
        segs.add(_Seg(syms[s] == '.' ? unit : unit * 3, true));
        if (s < syms.length - 1) segs.add(_Seg(unit, false));
      }
      if (l < letters.length - 1) segs.add(_Seg(unit * 3, false));
    }
    if (w < words.length - 1) segs.add(_Seg(unit * 7, false));
  }
  segs.add(_Seg(unit * 8, false)); // trailing silence
  return segs;
}

/// Sample segments into readings. `ambient(t)` adds a luminance offset.
List<LightReading> _sample(
  List<_Seg> segs, {
  int sampleMs = 20,
  double bright = 235,
  double dark = 15,
  double Function(int t)? ambient,
}) {
  final out = <LightReading>[];
  var t = 0;
  for (final seg in segs) {
    final end = t + seg.durMs;
    while (t < end) {
      var lum = seg.on ? bright : dark;
      if (ambient != null) lum += ambient(t);
      out.add(LightReading(
          luminance: lum.clamp(0, 255).toDouble(), timestampMs: t));
      t += sampleMs;
    }
  }
  return out;
}

List<LightReading> _readings(String morse, int unit,
        {int sampleMs = 20,
        double bright = 235,
        double dark = 15,
        double Function(int t)? ambient}) =>
    _sample(_segments(morse, unit),
        sampleMs: sampleMs, bright: bright, dark: dark, ambient: ambient);

// ---------------------------------------------------------------------------
// Pipeline drivers
// ---------------------------------------------------------------------------

TransmissionSynchronizer _newSync() => TransmissionSynchronizer(
      estimator: MedianUnitEstimator(seedUnitMs: 180),
      classifier: PulseClassifier(),
    );

/// Decode a single transmission to text.
String _decode(List<LightReading> readings, {LightDetector? detector}) {
  final det = detector ?? LightDetector();
  final timer = PulseTimer();
  final sync = _newSync();
  final acc = MorseAccumulator();
  var lastMs = 0;
  for (final r in readings) {
    lastMs = r.timestampMs;
    final tr = det.process(r);
    if (tr == null) continue;
    final p = timer.onTransition(tr);
    if (p == null) continue;
    for (final s in sync.process(p)) {
      acc.add(s);
    }
  }
  final tail = timer.flush(lastMs);
  if (tail != null) {
    for (final s in sync.process(tail)) {
      acc.add(s);
    }
  }
  acc.flush();
  return MorseDecoder().decode(acc.letters).trim();
}

/// Decode a stream that may contain multiple transmissions, using the idle
/// timeout to segment them.
List<String> _decodeSegments(List<LightReading> readings,
    {int idleTimeoutMs = 1000}) {
  LightDetector det() => LightDetector(idleTimeoutMs: idleTimeoutMs);
  var detector = det();
  var timer = PulseTimer();
  var sync = _newSync();
  var acc = MorseAccumulator();
  var sawSignal = false;
  var lastMs = 0;
  final results = <String>[];

  void finalize() {
    final tail = timer.flush(lastMs);
    if (tail != null) {
      for (final s in sync.process(tail)) {
        acc.add(s);
      }
    }
    acc.flush();
    final text = MorseDecoder().decode(acc.letters).trim();
    if (text.isNotEmpty) results.add(text);
    detector = det();
    timer = PulseTimer();
    sync = _newSync();
    acc = MorseAccumulator();
    sawSignal = false;
  }

  for (final r in readings) {
    lastMs = r.timestampMs;
    if (sawSignal && detector.isIdle(r.timestampMs)) {
      finalize();
    }
    final tr = detector.process(r);
    if (tr == null) continue;
    sawSignal = true;
    final p = timer.onTransition(tr);
    if (p == null) continue;
    for (final s in sync.process(p)) {
      acc.add(s);
    }
  }
  finalize();
  return results;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('clean SOS luminance train decodes', () async {
    final source = FakeLightSource(_readings('... --- ...', 200));
    final captured = <LightReading>[];
    await source.start(captured.add);
    expect(_decode(captured), 'SOS');
  });

  test('decodes under a high ambient floor (adaptive threshold)', () {
    final r = _readings('.... . .-.. .-.. ---', 200, bright: 250, dark: 95);
    expect(_decode(r), 'HELLO');
  });

  test('decodes through a gradually changing ambient level', () {
    // Gentle ramp: +0.2 luminance per sample stays under the false-signal
    // bound (minRange * floorUpRate per sample).
    final r = _readings('... --- ...', 200,
        ambient: (t) => t * 0.008); // 0.008/ms ≈ 0.16 per 20ms sample
    expect(_decode(r), 'SOS');
  });

  test('rejects random noise spikes, still decodes', () {
    final base = _readings('... --- ...', 200);
    // Inject single-sample spikes (20ms < minPulse) — opposite of each region.
    final noisy = <LightReading>[];
    for (var i = 0; i < base.length; i++) {
      final r = base[i];
      if (i % 17 == 0) {
        // brief spike to the opposite extreme for one sample
        noisy.add(LightReading(
            luminance: r.luminance > 120 ? 10 : 245,
            timestampMs: r.timestampMs));
      } else {
        noisy.add(r);
      }
    }
    expect(_decode(noisy), 'SOS');
  });

  test('noise-only input (no sustained pulses) decodes to nothing', () {
    final readings = <LightReading>[];
    for (var i = 0; i < 200; i++) {
      // dark with isolated 1-sample spikes every 10 frames
      final lum = (i % 10 == 0) ? 240.0 : 14.0;
      readings.add(LightReading(luminance: lum, timestampMs: i * 20));
    }
    expect(_decode(readings), '');
  });

  test('tolerates missing frames (dropped samples)', () {
    final base = _readings('... --- ...', 200);
    final dropped = [
      for (var i = 0; i < base.length; i++)
        if (i % 3 != 0) base[i], // drop every third sample
    ];
    expect(_decode(dropped), 'SOS');
  });

  test('tolerates frame-rate jitter (variable intervals)', () {
    // Re-time a clean segment list with jittered sample spacing.
    final segs = _segments('.... . .-.. .-.. ---', 200);
    final out = <LightReading>[];
    var t = 0;
    var i = 0;
    for (final seg in segs) {
      final end = t + seg.durMs;
      while (t < end) {
        out.add(LightReading(
            luminance: seg.on ? 235 : 15, timestampMs: t));
        // jitter spacing 14..34 ms deterministically
        t += 14 + (i * 7) % 21;
        i++;
      }
    }
    expect(_decode(out), 'HELLO');
  });

  test('decodes a long continuous transmission', () {
    expect(_decode(_readings('... --- ... / ... --- ... / ... --- ...', 150)),
        'SOS SOS SOS');
  });

  test('two transmissions separated by silence both decode', () {
    // First message, long dark gap (> idle timeout), second message.
    final first = _readings('... --- ...', 200); // ends with trailing silence
    // Second message starts with a dot so the estimator calibrates the unit
    // (a letter of only dashes is dot/dash-ambiguous without a known unit —
    // future calibration work, spec §7).
    final secondSegs = _segments('.... ..', 200); // 'HI'
    final gapMs = 2600;
    final startSecond = first.last.timestampMs + gapMs;
    final second = <LightReading>[];
    var t = startSecond;
    for (final seg in secondSegs) {
      final end = t + seg.durMs;
      while (t < end) {
        second.add(
            LightReading(luminance: seg.on ? 235 : 15, timestampMs: t));
        t += 20;
      }
    }
    // dark filler across the gap so idle is observed
    final filler = <LightReading>[];
    for (var g = first.last.timestampMs + 20; g < startSecond; g += 100) {
      filler.add(LightReading(luminance: 15, timestampMs: g));
    }
    final stream = [...first, ...filler, ...second];
    expect(_decodeSegments(stream, idleTimeoutMs: 1000), ['SOS', 'HI']);
  });
}
