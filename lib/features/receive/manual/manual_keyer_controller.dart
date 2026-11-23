import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../morse/domain/morse_alphabet.dart';

/// A letter the current symbols could still become.
@immutable
class KeyerCandidate {
  const KeyerCandidate(this.character, this.code);

  final String character;
  final String code;
}

/// Manual receive: the user watches the other phone's flashes and keys
/// each one in as a dot or a dash. This controller turns those taps into
/// text. No camera, no timing analysis — the human eye does the detection.
class ManualKeyerController extends ChangeNotifier {
  ManualKeyerController({
    this.autoCommitDelay = const Duration(milliseconds: 1400),
  });

  /// Longest code in [kMorseAlphabet].
  static const int maxSymbols = 6;

  static final Map<String, String> _inverse = {
    for (final e in kMorseAlphabet.entries) e.value: e.key,
  };

  /// Idle time after the last tap before the pending letter is committed,
  /// when [autoCommitEnabled] is on.
  final Duration autoCommitDelay;

  bool _autoCommitEnabled = false;
  String _text = '';
  String _symbols = '';
  Timer? _pauseTimer;
  bool _disposed = false;

  String get text => _text;
  String get symbols => _symbols;
  bool get autoCommitEnabled => _autoCommitEnabled;

  /// The character the current symbols spell, or null.
  String? get pendingLetter => _symbols.isEmpty ? null : _inverse[_symbols];

  bool get canCommit => pendingLetter != null;

  /// Letters whose code starts with the current symbols, shortest first.
  List<KeyerCandidate> get candidates {
    if (_symbols.isEmpty) return const [];
    final list = [
      for (final e in kMorseAlphabet.entries)
        if (e.value.startsWith(_symbols)) KeyerCandidate(e.key, e.value),
    ]..sort((a, b) {
        final byLength = a.code.length.compareTo(b.code.length);
        return byLength != 0 ? byLength : a.code.compareTo(b.code);
      });
    return list;
  }

  set autoCommitEnabled(bool value) {
    if (_autoCommitEnabled == value) return;
    _autoCommitEnabled = value;
    if (!value) _pauseTimer?.cancel();
    _notify();
  }

  void dot() => _addSymbol('.');
  void dash() => _addSymbol('-');

  void _addSymbol(String symbol) {
    if (_symbols.length >= maxSymbols) return;
    _symbols += symbol;
    _restartPauseTimer();
    _notify();
  }

  /// Ends the current letter. Does nothing if the symbols spell no letter.
  void commitLetter() {
    _pauseTimer?.cancel();
    final letter = pendingLetter;
    if (letter == null) return;
    _text += letter;
    _symbols = '';
    _notify();
  }

  /// Ends the current word: commits a pending letter, then one space.
  void space() {
    _pauseTimer?.cancel();
    final letter = pendingLetter;
    if (letter != null) {
      _text += letter;
      _symbols = '';
    }
    if (_text.isNotEmpty && !_text.endsWith(' ')) {
      _text += ' ';
    }
    _notify();
  }

  /// Removes the last symbol; with none pending, the last character.
  void backspace() {
    _pauseTimer?.cancel();
    if (_symbols.isNotEmpty) {
      _symbols = _symbols.substring(0, _symbols.length - 1);
    } else if (_text.isNotEmpty) {
      _text = _text.substring(0, _text.length - 1);
    } else {
      return;
    }
    _notify();
  }

  void clear() {
    _pauseTimer?.cancel();
    if (_text.isEmpty && _symbols.isEmpty) return;
    _text = '';
    _symbols = '';
    _notify();
  }

  void _restartPauseTimer() {
    _pauseTimer?.cancel();
    if (!_autoCommitEnabled) return;
    _pauseTimer = Timer(autoCommitDelay, () {
      if (!_disposed) commitLetter();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pauseTimer?.cancel();
    super.dispose();
  }
}
