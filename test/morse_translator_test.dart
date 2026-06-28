import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/morse/services/morse_translator.dart';

void main() {
  final translator = MorseTranslator();

  test('encodes SOS to ... --- ...', () {
    final r = translator.translate('SOS');
    expect(r.words.length, 1);
    final symbols = r.words.first.letters.map((l) => l.symbols).toList();
    expect(symbols, ['...', '---', '...']);
    expect(r.unsupportedCharacters, isEmpty);
  });

  test('encodes HELP correctly and is case-insensitive', () {
    final r = translator.translate('help');
    final symbols = r.words.first.letters.map((l) => l.symbols).join(' ');
    expect(symbols, '.... . .-.. .--.');
  });

  test('splits multiple words', () {
    final r = translator.translate('OK GO');
    expect(r.words.length, 2);
  });

  test('flags unsupported characters', () {
    final r = translator.translate('A#');
    expect(r.unsupportedCharacters, contains('#'));
  });

  test('empty / whitespace input yields no words', () {
    expect(translator.translate('   ').words, isEmpty);
  });
}
