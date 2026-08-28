/// Стабильные id встроенных черт. UI пока на русском.
class TraitIds {
  static const schemaVersion = 2;

  static const attributes = <String, String>{
    'Сила': 'strength',
    'Ловкость': 'dexterity',
    'Выносливость': 'stamina',
    'Обаяние': 'charisma',
    'Манипулирование': 'manipulation',
    'Внешность': 'appearance',
    'Восприятие': 'perception',
    'Интеллект': 'intelligence',
    'Сообразительность': 'wits',
  };

  static const abilities = <String, String>{
    'Бдительность': 'alertness',
    'Атлетика': 'athletics',
    'Рукопашный бой': 'brawl',
    'Уклонение': 'dodge',
    'Эмпатия': 'empathy',
    'Красноречие': 'expression',
    'Запугивание': 'intimidation',
    'Лидерство': 'leadership',
    'Уличные порядки': 'streetwise',
    'Хитрость': 'subterfuge',
    'Понимание зверей': 'animalKen',
    'Ремесло': 'crafts',
    'Вождение': 'drive',
    'Этикет': 'etiquette',
    'Огнестрельное оружие': 'firearms',
    'Холодное оружие': 'melee',
    'Исполнение': 'performance',
    'Безопасность': 'security',
    'Скрытность': 'stealth',
    'Выживание': 'survival',
    'Гуманитарные науки': 'academics',
    'Компьютеры': 'computer',
    'Финансы': 'finance',
    'Расследование': 'investigation',
    'Закон': 'law',
    'Языки': 'linguistics',
    'Медицина': 'medicine',
    'Оккультизм': 'occult',
    'Политика': 'politics',
    'Естественные науки': 'science',
  };

  static const virtues = <String, String>{
    'Совесть': 'conscience',
    'Самоконтроль': 'selfControl',
    'Храбрость': 'courage',
  };

  static Map<String, String> get _allRuToId => {
        ...attributes,
        ...abilities,
        ...virtues,
      };

  static Map<String, String> get _allIdToRu {
    final out = <String, String>{};
    _allRuToId.forEach((ru, id) => out[id] = ru);
    return out;
  }

  static String idForRu(String ru, {String? fallbackPrefix}) {
    return _allRuToId[ru] ??
        '${fallbackPrefix ?? 'custom'}_${_slug(ru)}';
  }

  static String ruForKey(String key) {
    if (_allRuToId.containsKey(key)) return key;
    return _allIdToRu[key] ?? key;
  }

  static Map<String, int> encodeIntMap(Map<String, int> ruKeyed) {
    final out = <String, int>{};
    ruKeyed.forEach((k, v) => out[idForRu(k)] = v);
    return out;
  }

  static Map<String, int> decodeIntMap(Map<String, dynamic> raw) {
    final out = <String, int>{};
    raw.forEach((k, v) {
      final n = v is int ? v : int.tryParse('$v') ?? 0;
      out[ruForKey(k)] = n;
    });
    return out;
  }

  static Map<String, String> encodeStrMap(Map<String, String> ruKeyed) {
    final out = <String, String>{};
    ruKeyed.forEach((k, v) => out[idForRu(k)] = v);
    return out;
  }

  static Map<String, String> decodeStrMap(Map<String, dynamic> raw) {
    final out = <String, String>{};
    raw.forEach((k, v) {
      out[ruForKey(k)] = '$v';
    });
    return out;
  }

  static List<Map<String, String>> encodeExtras(List<String> labels) {
    return labels
        .map((label) => {'id': idForRu(label, fallbackPrefix: 'custom'), 'label': label})
        .toList();
  }

  static List<String> decodeExtras(dynamic raw) {
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      if (e is String) {
        out.add(e);
      } else if (e is Map) {
        final label = e['label']?.toString();
        out.add(label ?? e['id']?.toString() ?? '');
      }
    }
    return out.where((s) => s.isNotEmpty).toList();
  }

  static String _slug(String s) {
    final cleaned = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'item' : cleaned;
  }
}
