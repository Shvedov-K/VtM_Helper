import 'dart:convert';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';

class SyncPayload {
  static const characterType = 'vtm_helper_character';
  static const chronicleType = 'vtm_helper_chronicle';
  static const chronicleInfoType = 'vtm_helper_chronicle_info';
  static const version = 1;

  static String wrapCharacter(
    Character c, {
    bool includePrivateNotes = false,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'type': characterType,
      'version': version,
      'character': c.toJson(includePrivateNotes: includePrivateNotes),
    });
  }

  static String wrapChronicle(
    Chronicle chronicle,
    List<Character> characters, {
    bool includePrivateNotes = false,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'type': chronicleType,
      'version': version,
      'chronicle': chronicle.toJson(),
      'characters': characters
          .map((c) => c.toJson(includePrivateNotes: includePrivateNotes))
          .toList(),
    });
  }

  static bool looksLikeOurs(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return false;
      final type = decoded['type']?.toString();
      return type == characterType ||
          type == chronicleType ||
          type == chronicleInfoType ||
          decoded.containsKey('character') ||
          decoded.containsKey('chronicle');
    } catch (_) {
      return false;
    }
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
        Character.fromJson(Map<String, dynamic>.from(body as Map)),
      );
    }
    if (type == chronicleType || map.containsKey('chronicle')) {
      final chron = Chronicle.fromJson(
        Map<String, dynamic>.from(map['chronicle'] as Map),
      );
      final chars = <Character>[];
      for (final e in map['characters'] as List? ?? []) {
        try {
          chars.add(Character.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
      return ParsedSync.chronicle(chron, chars);
    }
    if (map.containsKey('id') && map.containsKey('attributes')) {
      return ParsedSync.character(Character.fromJson(map));
    }
    throw const FormatException('Неизвестный формат файла VTM Helper');
  }

  static String wrapChronicleInfo(PlayerChronicleInfo info) {
    return const JsonEncoder.withIndent('  ').convert({
      'type': chronicleInfoType,
      'version': version,
      'chronicleName': info.chronicleName,
      'rootFolderId': info.rootFolderId,
      'inviteLink': info.inviteLink,
      'playerDisplayName': info.playerDisplayName,
      'playerFolderId': info.playerFolderId,
    });
  }

  static PlayerChronicleInfo? parseChronicleInfo(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['type']?.toString() != chronicleInfoType) return null;
      final root = map['rootFolderId']?.toString() ?? '';
      final name = map['chronicleName']?.toString() ?? '';
      if (root.isEmpty) return null;
      return PlayerChronicleInfo(
        chronicleName: name,
        rootFolderId: root,
        inviteLink: map['inviteLink']?.toString(),
        playerDisplayName: map['playerDisplayName']?.toString(),
        playerFolderId: map['playerFolderId']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class PlayerChronicleInfo {
  final String chronicleName;
  final String rootFolderId;
  final String? inviteLink;
  final String? playerDisplayName;
  final String? playerFolderId;

  PlayerChronicleInfo({
    required this.chronicleName,
    required this.rootFolderId,
    this.inviteLink,
    this.playerDisplayName,
    this.playerFolderId,
  });
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
