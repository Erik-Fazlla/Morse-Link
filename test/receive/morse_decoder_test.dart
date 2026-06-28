import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/morse_decoder.dart';

void main() {
  final decoder = MorseDecoder();

  test('decodes single letters', () {
    expect(decoder.decodeLetter('...'), 'S');
    expect(decoder.decodeLetter('---'), 'O');
    expect(decoder.decodeLetter('.-'), 'A');
    expect(decoder.decodeLetter('.'), 'E');
    expect(decoder.decodeLetter('-'), 'T');
  });

  test('decodes digits', () {
    expect(decoder.decodeLetter('.----'), '1');
    expect(decoder.decodeLetter('..---'), '2');
    expect(decoder.decodeLetter('...--'), '3');
  });

  test('unknown code returns "?"', () {
    expect(decoder.decodeLetter('........'), '?');
  });

  test('empty code returns empty string', () {
    expect(decoder.decodeLetter(''), '');
  });

  test('decodes a letter sequence', () {
    final letters = ['....', '.', '.-..', '.-..', '---'];
    expect(decoder.decode(letters), 'HELLO');
  });

  test('decodes a word break as a space', () {
    final letters = ['....', '..', '', '-', '....', '.', '.-.', '.'];
    expect(decoder.decode(letters), 'HI THERE');
  });
}
