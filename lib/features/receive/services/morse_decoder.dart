import '../../morse/domain/morse_alphabet.dart';

/// Decodes Morse codes to text using the inverse of [kMorseAlphabet].
class MorseDecoder {
  MorseDecoder()
      : _inverse = {
          for (final entry in kMorseAlphabet.entries) entry.value: entry.key,
        };

  final Map<String, String> _inverse;

  /// One letter's code ('...') to a character; '?' if unrecognized.
  /// Empty input yields '' (no character).
  String decodeLetter(String code) {
    if (code.isEmpty) return '';
    return _inverse[code] ?? '?';
  }

  /// A list of letter codes to text. An empty entry is a word break (space).
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
