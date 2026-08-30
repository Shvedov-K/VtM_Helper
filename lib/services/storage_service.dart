import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/models/chronicle.dart';

class StorageService {
  static const String _charactersKey = 'characters';
  static const String _themesKey = 'custom_sheet_themes';
  static const String _stModeKey = 'storyteller_mode';
  static const String _chroniclesKey = 'chronicles';
  static const String _syncLogKey = 'sync_log';

  static Future<void> _lock = Future.value();
  static List<Character>? _characters;
  static List<Chronicle>? _chronicles;

  Future<T> _sync<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _lock = _lock.then((_) {}, onError: (_) {}).then((_) async {
      try {
        done.complete(await action());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<List<Character>> loadCharacters() =>
      _sync(_loadCharactersUnlocked);

  Future<void> saveCharacters(List<Character> characters) => _sync(() async {
        await _writeCharactersUnlocked(characters);
      });

  Future<void> addCharacter(Character character) => _sync(() async {
        final characters = await _loadCharactersUnlocked();
        characters.add(character);
        await _writeCharactersUnlocked(characters);
      });

  Future<void> updateCharacter(Character updated) => _sync(() async {
        final characters = await _loadCharactersUnlocked();
        final index = characters.indexWhere((c) => c.id == updated.id);
        if (index != -1) {
          characters[index] = updated;
        } else {
          characters.add(updated);
        }
        await _writeCharactersUnlocked(characters);
      });

  Future<void> deleteCharacter(String id) => _sync(() async {
        final characters = await _loadCharactersUnlocked();
        characters.removeWhere((c) => c.id == id);
        await _writeCharactersUnlocked(characters);
      });

  Future<List<Character>> _loadCharactersUnlocked() async {
    if (_characters != null) return _characters!;
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_charactersKey);
    if (data == null) {
      _characters = [];
      return _characters!;
    }
    final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
    final loaded = <Character>[];
    for (final e in jsonList) {
      try {
        loaded.add(Character.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        // Skip a corrupt record instead of wiping the roster.
      }
    }
    _characters = loaded;
    return _characters!;
  }

  Future<void> _writeCharactersUnlocked(List<Character> characters) async {
    _characters = characters;
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(characters.map((c) => c.toJson()).toList());
    await prefs.setString(_charactersKey, data);
  }

  Future<List<SheetTheme>> loadCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_themesKey);
    if (data == null || data.isEmpty) return [];
    final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
    final loaded = <SheetTheme>[];
    for (final e in jsonList) {
      try {
        loaded.add(SheetTheme.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    return loaded;
  }

  Future<void> saveCustomThemes(List<SheetTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(themes.map((th) => th.toJson()).toList());
    await prefs.setString(_themesKey, data);
  }

  Future<bool> loadStorytellerMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_stModeKey) ?? false;
  }

  Future<void> saveStorytellerMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stModeKey, value);
  }

  Future<List<Chronicle>> loadChronicles() =>
      _sync(_loadChroniclesUnlocked);

  Future<void> saveChronicles(List<Chronicle> chronicles) => _sync(() async {
        await _writeChroniclesUnlocked(chronicles);
      });

  Future<List<Chronicle>> _loadChroniclesUnlocked() async {
    if (_chronicles != null) return _chronicles!;
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_chroniclesKey);
    if (data == null || data.isEmpty) {
      _chronicles = [];
      return _chronicles!;
    }
    final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
    final loaded = <Chronicle>[];
    for (final e in jsonList) {
      try {
        loaded.add(Chronicle.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    _chronicles = loaded;
    return _chronicles!;
  }

  Future<void> _writeChroniclesUnlocked(List<Chronicle> chronicles) async {
    _chronicles = chronicles;
    final prefs = await SharedPreferences.getInstance();
    final String data =
        json.encode(chronicles.map((c) => c.toJson()).toList());
    await prefs.setString(_chroniclesKey, data);
  }

  Future<List<Map<String, dynamic>>> loadSyncLog() => _sync(() async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_syncLogKey);
        if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
        try {
          return (json.decode(raw) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      });

  Future<void> addSyncLog({
    required String action,
    required String characterName,
    String? detail,
  }) =>
      _sync(() async {
        final prefs = await SharedPreferences.getInstance();
        var list = <Map<String, dynamic>>[];
        final raw = prefs.getString(_syncLogKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            list = (json.decode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } catch (_) {
            list = [];
          }
        }
        list.insert(0, {
          'at': DateTime.now().millisecondsSinceEpoch,
          'action': action,
          'characterName': characterName,
          'detail': detail ?? '',
        });
        if (list.length > 80) {
          list.removeRange(80, list.length);
        }
        await prefs.setString(_syncLogKey, json.encode(list));
      });
}
