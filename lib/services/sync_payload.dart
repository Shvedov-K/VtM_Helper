import 'dart:convert';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';

class SyncPayload {
  static const characterType = 'vtm_helper_character';
  static const chronicleType = 'vtm_helper_chronicle';
  static const version = 1;

  static String wrapCharacter(Character c) {
    return const JsonEncoder.withIndent('  ').convert({
      'type': characterType,
      'version': version,
      'character': c.toJson(),
    });
  }

  static String wrapChronicle(Chronicle chronicle, List<Character> characters) {
    return const JsonEncoder.withIndent('  ').convert({
      'type': chronicleType,
      'version': version,
      'chronicle': chronicle.toJson(),
      'characters': characters.map((c) => c.toJson()).toList(),
    });
  }

  static ParsedSync parse(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw const FormatException('Ожидался JSON-объект');
    }
    final map = Map<String, dynamic>.from(decoded);
    final type = map['type']?.toString();

    if (type == characterType || map.containsKey('character')) {
      final body = map['character'] ?? map;
      return ParsedSync.character(
        Character.fromJson(Map<String, dynamic>.from(body)),
      );
    }
    if (type == chronicleType || map.containsKey('chronicle')) {
      final chron = Chronicle.fromJson(
        Map<String, dynamic>.from(map['chronicle'] as Map),
      );
      final chars = (map['characters'] as List? ?? [])
          .map((e) => Character.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ParsedSync.chronicle(chron, chars);
    }
    // Голый персонаж без обёртки
    if (map.containsKey('id') && map.containsKey('attributes')) {
      return ParsedSync.character(Character.fromJson(map));
    }
    throw const FormatException('Неизвестный формат файла VTM Helper');
  }
}

class ParsedSync {
  final Character? character;
  final Chronicle? chronicle;
  final List<Character> characters;

  ParsedSync.character(Character c)
      : character = c,
        chronicle = null,
        characters = const [];

  ParsedSync.chronicle(this.chronicle, this.characters) : character = null;

  bool get isCharacter => character != null;
  bool get isChronicle => chronicle != null;
}
