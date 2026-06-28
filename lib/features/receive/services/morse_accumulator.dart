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
        break; // skip noise — never throws
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

  /// Running Morse string for live display, words separated by ' / '.
  String get liveMorse {
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
    return words.join(' / ');
  }

  void reset() {
    _letters.clear();
    _current.clear();
  }
}
