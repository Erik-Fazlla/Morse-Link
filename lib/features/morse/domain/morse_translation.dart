class MorseLetter {
  const MorseLetter({
    required this.character,
    required this.symbols,
  });

  final String character;
  final String symbols;
}

class MorseWord {
  const MorseWord({
    required this.letters,
  });

  final List<MorseLetter> letters;
}

class MorseTranslation {
  const MorseTranslation({
    required this.sourceText,
    required this.words,
    required this.unsupportedCharacters,
  });

  final String sourceText;
  final List<MorseWord> words;
  final List<String> unsupportedCharacters;

  bool get isEmpty => words.every((word) => word.letters.isEmpty);

  String get morsePreview {
    final segments = <String>[];

    for (final word in words) {
      if (word.letters.isEmpty) {
        continue;
      }

      segments.add(word.letters.map((letter) => letter.symbols).join(' '));
    }

    return segments.join(' / ');
  }
}
