import '../domain/morse_translation.dart';

class MorseTranslator {
  static const Map<String, String> _alphabet = {
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    'F': '..-.',
    'G': '--.',
    'H': '....',
    'I': '..',
    'J': '.---',
    'K': '-.-',
    'L': '.-..',
    'M': '--',
    'N': '-.',
    'O': '---',
    'P': '.--.',
    'Q': '--.-',
    'R': '.-.',
    'S': '...',
    'T': '-',
    'U': '..-',
    'V': '...-',
    'W': '.--',
    'X': '-..-',
    'Y': '-.--',
    'Z': '--..',
    '0': '-----',
    '1': '.----',
    '2': '..---',
    '3': '...--',
    '4': '....-',
    '5': '.....',
    '6': '-....',
    '7': '--...',
    '8': '---..',
    '9': '----.',
    '.': '.-.-.-',
    ',': '--..--',
    '?': '..--..',
    '!': '-.-.--',
    '/': '-..-.',
    '-': '-....-',
    '(': '-.--.',
    ')': '-.--.-',
    ':': '---...',
    ';': '-.-.-.',
    '=': '-...-',
    '+': '.-.-.',
    '@': '.--.-.',
    '\'': '.----.',
    '"': '.-..-.',
  };

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
        final symbols = _alphabet[character];
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
