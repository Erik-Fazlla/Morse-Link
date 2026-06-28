import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/transmission_history_entry.dart';

class TransmissionHistoryRepository {
  static const String _storageKey = 'transmission_history_entries';
  static const int _maxEntries = 50;

  Future<List<TransmissionHistoryEntry>> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final rawEntries = preferences.getStringList(_storageKey) ?? const [];
    var hadCorruptedEntries = false;

    final decodedEntries = rawEntries
        .map((entry) {
          final decoded = _tryDecodeEntry(entry);
          if (decoded == null) {
            hadCorruptedEntries = true;
          }
          return decoded;
        })
        .whereType<TransmissionHistoryEntry>()
        .toList(growable: false);

    if (hadCorruptedEntries) {
      await _persistEntries(preferences, decodedEntries);
    }

    return decodedEntries;
  }

  Future<void> saveEntry(TransmissionHistoryEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getStringList(_storageKey) ?? <String>[];
    final updated = <String>[
      jsonEncode(entry.toJson()),
      ...existing,
    ];

    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }

    final didPersist = await preferences.setStringList(_storageKey, updated);
    if (!didPersist) {
      throw StateError('Failed to persist transmission history');
    }
  }

  TransmissionHistoryEntry? _tryDecodeEntry(String rawEntry) {
    try {
      return TransmissionHistoryEntry.fromJson(
        jsonDecode(rawEntry) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistEntries(
    SharedPreferences preferences,
    List<TransmissionHistoryEntry> entries,
  ) async {
    final didPersist = await preferences.setStringList(
      _storageKey,
      entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    if (!didPersist) {
      throw StateError('Failed to repair transmission history storage');
    }
  }
}
