import '../domain/morse_alphabet.dart';
import '../domain/morse_translation.dart';

class MorseTranslator {
  MorseTranslation translate(String input) {
    final normalized = input.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const MorseTranslation(
        sourceText: '',
        words: [],
        unsupportedCharacters: [],
      );
    }

    final words = <MorseWord>[];
    final unsupported = <String>{};
    final rawWords = normalized.split(RegExp(r'\s+'));

    for (final rawWord in rawWords) {
      final letters = <MorseLetter>[];

      for (final character in rawWord.split('')) {
        final symbols = kMorseAlphabet[character];
        if (symbols == null) {
          unsupported.add(character);
          continue;
        }

        letters.add(MorseLetter(character: character, symbols: symbols));
      }

      if (letters.isNotEmpty) {
        words.add(MorseWord(letters: letters));
      }
    }

    return MorseTranslation(
      sourceText: normalized,
      words: words,
      unsupportedCharacters: unsupported.toList()..sort(),
    );
  }
}
