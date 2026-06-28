import '../domain/morse_translation.dart';
import '../domain/timing_instruction.dart';

class TimingSequenceBuilder {
  List<TimingInstruction> build({
    required MorseTranslation translation,
    required int unitMs,
  }) {
    if (translation.isEmpty) {
      return const [];
    }

    final instructions = <TimingInstruction>[];

    for (var wordIndex = 0; wordIndex < translation.words.length; wordIndex++) {
      final word = translation.words[wordIndex];

      for (var letterIndex = 0; letterIndex < word.letters.length; letterIndex++) {
        final letter = word.letters[letterIndex];
        final symbols = letter.symbols.split('');

        for (var symbolIndex = 0; symbolIndex < symbols.length; symbolIndex++) {
          final symbol = symbols[symbolIndex];
          instructions.add(
            TimingInstruction(
              isOn: true,
              durationMs: symbol == '.' ? unitMs : unitMs * 3,
              symbol: symbol,
              phaseLabel: 'signal',
            ),
          );

          final isLastSymbol = symbolIndex == symbols.length - 1;
          if (!isLastSymbol) {
            instructions.add(
              TimingInstruction(
                isOn: false,
                durationMs: unitMs,
                symbol: symbol,
                phaseLabel: 'symbol gap',
              ),
            );
          }
        }

        final isLastLetter = letterIndex == word.letters.length - 1;
        if (!isLastLetter) {
          instructions.add(
            TimingInstruction(
              isOn: false,
              durationMs: unitMs * 3,
              symbol: 'gap',
              phaseLabel: 'letter gap',
            ),
          );
        }
      }

      final isLastWord = wordIndex == translation.words.length - 1;
      if (!isLastWord) {
        instructions.add(
          TimingInstruction(
            isOn: false,
            durationMs: unitMs * 7,
            symbol: '/',
            phaseLabel: 'word gap',
          ),
        );
      }
    }

    return instructions;
  }
}
