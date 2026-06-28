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
      // dot=1u, dash=3u → split at 2u; reject absurdly long ON pulses.
      const dotDashSplit = (MorseTiming.dotUnits + MorseTiming.dashUnits) / 2; // 2
      const maxOnUnits = MorseTiming.dashUnits * 2; // 6
      if (units > maxOnUnits) return PulseSymbol.unknown;
      return units < dotDashSplit ? PulseSymbol.dot : PulseSymbol.dash;
    }

    // OFF: symbol=1u, letter=3u, word=7u.
    const symLetterSplit =
        (MorseTiming.symbolGapUnits + MorseTiming.letterGapUnits) / 2; // 2
    const letterWordSplit =
        (MorseTiming.letterGapUnits + MorseTiming.wordGapUnits) / 2; // 5
    if (units < symLetterSplit) return PulseSymbol.symbolGap;
    if (units < letterWordSplit) return PulseSymbol.letterGap;
    return PulseSymbol.wordGap;
  }
}
