import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/manual/manual_keyer_controller.dart';

void main() {
  late ManualKeyerController keyer;

  setUp(() => keyer = ManualKeyerController());
  tearDown(() => keyer.dispose());

  void key(String symbols) {
    for (final s in symbols.split('')) {
      s == '.' ? keyer.dot() : keyer.dash();
    }
  }

  test('starts empty', () {
    expect(keyer.text, '');
    expect(keyer.symbols, '');
    expect(keyer.pendingLetter, isNull);
    expect(keyer.canCommit, isFalse);
  });

  test('dot and dash build the pending symbols and live letter', () {
    key('...');
    expect(keyer.symbols, '...');
    expect(keyer.pendingLetter, 'S');
    expect(keyer.canCommit, isTrue);
  });

  test('commitLetter appends decoded letter and clears symbols', () {
    key('...');
    keyer.commitLetter();
    key('---');
    keyer.commitLetter();
    key('...');
    keyer.commitLetter();
    expect(keyer.text, 'SOS');
    expect(keyer.symbols, '');
  });

  test('pattern with no letter cannot be committed', () {
    key('......'); // 6 dots: no character
    expect(keyer.pendingLetter, isNull);
    expect(keyer.canCommit, isFalse);
    keyer.commitLetter();
    expect(keyer.text, '');
    expect(keyer.symbols, '......');
  });

  test('symbols are capped at 6 (longest code in alphabet)', () {
    key('-------');
    expect(keyer.symbols.length, 6);
  });

  test('candidates are letters whose code starts with the symbols', () {
    key('.-');
    final letters = keyer.candidates.map((c) => c.character).toSet();
    expect(letters, containsAll(<String>['A', 'L', 'R', 'W', 'P', 'J']));
    expect(letters, isNot(contains('N')));
  });

  test('space commits pending letter then adds one word gap', () {
    key('....');
    keyer.space();
    keyer.space();
    key('..');
    keyer.commitLetter();
    expect(keyer.text, 'H I');
  });

  test('space on empty text does nothing', () {
    keyer.space();
    expect(keyer.text, '');
  });

  test('backspace removes last symbol first, then last character', () {
    key('...');
    keyer.commitLetter();
    key('-.');
    keyer.backspace();
    expect(keyer.symbols, '-');
    keyer.backspace();
    expect(keyer.symbols, '');
    keyer.backspace();
    expect(keyer.text, '');
  });

  test('clear resets everything', () {
    key('...');
    keyer.commitLetter();
    key('-');
    keyer.clear();
    expect(keyer.text, '');
    expect(keyer.symbols, '');
  });

  test('notifies listeners on change', () {
    var calls = 0;
    keyer.addListener(() => calls++);
    keyer.dot();
    keyer.commitLetter();
    expect(calls, 2);
  });

  test('auto letter gap commits pending letter after the pause', () async {
    final fast = ManualKeyerController(
      autoCommitDelay: const Duration(milliseconds: 20),
    )..autoCommitEnabled = true;
    fast.dot();
    expect(fast.text, '');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(fast.text, 'E');
    expect(fast.symbols, '');
    fast.dispose();
  });

  test('auto letter gap is off by default', () async {
    final fast = ManualKeyerController(
      autoCommitDelay: const Duration(milliseconds: 20),
    );
    fast.dot();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(fast.text, '');
    fast.dispose();
  });
}
