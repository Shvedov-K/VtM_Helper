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

  Future<List<Character>> loadCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_charactersKey);
    if (data == null) return [];
    final List<dynamic> jsonList = json.decode(data);
    return jsonList.map((e) => Character.fromJson(e)).toList();
  }

  Future<void> saveCharacters(List<Character> characters) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(characters.map((c) => c.toJson()).toList());
    await prefs.setString(_charactersKey, data);
  }

  Future<void> addCharacter(Character character) async {
    final characters = await loadCharacters();
    characters.add(character);
    await saveCharacters(characters);
  }

  Future<void> updateCharacter(Character updated) async {
    final characters = await loadCharacters();
    final index = characters.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      characters[index] = updated;
      await saveCharacters(characters);
    }
  }

  Future<void> deleteCharacter(String id) async {
    final characters = await loadCharacters();
    characters.removeWhere((c) => c.id == id);
    await saveCharacters(characters);
  }

  Future<List<SheetTheme>> loadCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_themesKey);
    if (data == null || data.isEmpty) return [];
    final List<dynamic> jsonList = json.decode(data);
    return jsonList
        .map((e) => SheetTheme.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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

  Future<List<Chronicle>> loadChronicles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_chroniclesKey);
    if (data == null || data.isEmpty) return [];
    final List<dynamic> jsonList = json.decode(data);
    return jsonList
        .map((e) => Chronicle.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveChronicles(List<Chronicle> chronicles) async {
    final prefs = await SharedPreferences.getInstance();
    final String data =
        json.encode(chronicles.map((c) => c.toJson()).toList());
    await prefs.setString(_chroniclesKey, data);
  }

  Future<List<Map<String, dynamic>>> loadSyncLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncLogKey);
    if (raw == null || raw.isEmpty) return [];
    return (json.decode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> addSyncLog({
    required String action,
    required String characterName,
    String? detail,
  }) async {
    final list = await loadSyncLog();
    list.insert(0, {
      'at': DateTime.now().millisecondsSinceEpoch,
      'action': action,
      'characterName': characterName,
      'detail': detail ?? '',
    });
    if (list.length > 80) {
      list.removeRange(80, list.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncLogKey, json.encode(list));
  }
}
