import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_message_template.dart';

class SavedMessageRepository {
  static const String _customMessagesKey = 'saved_message_custom_entries';
  static const String _favoriteIdsKey = 'saved_message_favorite_ids';

  static const List<SavedMessageTemplate> builtInTemplates = [
    SavedMessageTemplate(
      id: 'builtin-sos',
      title: 'SOS',
      messageText: 'SOS',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-help',
      title: 'HELP',
      messageText: 'HELP',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-need-water',
      title: 'NEED WATER',
      messageText: 'NEED WATER',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-need-medical',
      title: 'NEED MEDICAL',
      messageText: 'NEED MEDICAL',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-safe',
      title: 'SAFE',
      messageText: 'SAFE',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-danger',
      title: 'DANGER',
      messageText: 'DANGER',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-send-location',
      title: 'SEND LOCATION',
      messageText: 'SEND LOCATION',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-yes',
      title: 'YES',
      messageText: 'YES',
      isBuiltIn: true,
      isFavorite: false,
    ),
    SavedMessageTemplate(
      id: 'builtin-no',
      title: 'NO',
      messageText: 'NO',
      isBuiltIn: true,
      isFavorite: false,
    ),
  ];

  Future<List<SavedMessageTemplate>> loadTemplates() async {
    final preferences = await SharedPreferences.getInstance();
    final favoriteIds = preferences.getStringList(_favoriteIdsKey) ?? const [];
    final rawCustom = preferences.getStringList(_customMessagesKey) ?? const [];
    var hadCorruptedEntries = false;

    final customEntries = rawCustom
        .map((entry) {
          final decoded = _tryDecodeTemplate(entry);
          if (decoded == null) {
            hadCorruptedEntries = true;
          }
          return decoded;
        })
        .whereType<SavedMessageTemplate>()
        .toList(growable: false);

    if (hadCorruptedEntries) {
      await _persistCustomTemplates(
        preferences,
        customEntries,
      );
    }

    final merged = <SavedMessageTemplate>[
      ...builtInTemplates,
      ...customEntries.map((entry) => entry.copyWith(isBuiltIn: false)),
    ].map((entry) {
      return entry.copyWith(isFavorite: favoriteIds.contains(entry.id));
    }).toList();

    merged.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      if (a.isBuiltIn != b.isBuiltIn) {
        return a.isBuiltIn ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });

    return merged;
  }

  Future<void> saveCustomTemplate(SavedMessageTemplate template) async {
    final preferences = await SharedPreferences.getInstance();
    final current = await _loadCustomTemplates(preferences);
    final index = current.indexWhere((entry) => entry.id == template.id);
    final normalized = template.copyWith(isBuiltIn: false);

    if (index >= 0) {
      current[index] = normalized;
    } else {
      current.add(normalized);
    }

    await _persistCustomTemplates(preferences, current);
  }

  Future<void> deleteCustomTemplate(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final current = await _loadCustomTemplates(preferences);
    current.removeWhere((entry) => entry.id == id);
    await _persistCustomTemplates(preferences, current);

    final favorites = preferences.getStringList(_favoriteIdsKey) ?? <String>[];
    favorites.remove(id);
    await _persistStringList(
      preferences: preferences,
      key: _favoriteIdsKey,
      values: favorites,
    );
  }

  Future<void> setFavorite(String id, bool isFavorite) async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = preferences.getStringList(_favoriteIdsKey) ?? <String>[];

    if (isFavorite) {
      if (!favorites.contains(id)) {
        favorites.add(id);
      }
    } else {
      favorites.remove(id);
    }

    await _persistStringList(
      preferences: preferences,
      key: _favoriteIdsKey,
      values: favorites,
    );
  }

  Future<List<SavedMessageTemplate>> _loadCustomTemplates(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getStringList(_customMessagesKey) ?? const [];
    return raw
        .map(_tryDecodeTemplate)
        .whereType<SavedMessageTemplate>()
        .toList();
  }

  SavedMessageTemplate? _tryDecodeTemplate(String rawEntry) {
    try {
      return SavedMessageTemplate.fromJson(
        jsonDecode(rawEntry) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistCustomTemplates(
    SharedPreferences preferences,
    List<SavedMessageTemplate> templates,
  ) {
    return _persistStringList(
      preferences: preferences,
      key: _customMessagesKey,
      values: templates.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<void> _persistStringList({
    required SharedPreferences preferences,
    required String key,
    required List<String> values,
  }) async {
    final didPersist = await preferences.setStringList(key, values);
    if (!didPersist) {
      throw StateError('Failed to persist saved message data for $key');
    }
  }
}
