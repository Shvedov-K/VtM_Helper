import 'package:vtm_helper/models/trait_ids.dart';

enum InjuryLevel { empty, bashing, lethal }

class Character {
  static const healthBoxCount = 7;

  String id;
  String name;
  String player;
  String chronicle;
  String nature;
  String mask;
  String generation;
  String haven;
  String clan;
  String concept;

  // Атрибуты
  Map<String, int> attributes;

  // Способности (таланты, навыки, познания)
  Map<String, int> abilities;

  // Специализации атрибутов и способностей (имя характеристики -> текст)
  Map<String, String> attributeSpecialties;
  Map<String, String> abilitySpecialties;

  // Дополнительные способности по категориям (сверх стандартного списка)
  List<String> extraTalents;
  List<String> extraSkills;
  List<String> extraKnowledges;

  // Описания для своих способностей
  Map<String, String> customAbilityDescriptions;

  // Дисциплины, Дополнения, Мериты, Демериты
  List<ExpandableItem> disciplines;
  List<ExpandableItem> backgrounds;
  List<ExpandableItem> merits;
  List<ExpandableItem> flaws;

  // Добродетели
  Map<String, int> virtues;

  // Человечность
  int humanity;

  // Сила воли
  int willpowerPermanent;
  int willpowerCurrent;

  // Запас крови
  int bloodPool;

  // Опыт
  int experience;

  // Тема оформления листа (id из SheetTheme.presets)
  String sheetThemeId;

  // Заметки рассказчика: видимые игроку и только для мастера
  String storytellerNotes;
  String storytellerPrivateNotes;

  /// Привязка к хронике приложения (не поле «Хроника» в шапке бланка)
  String? chronicleId;
  String? drivePlayerName;

  /// Unix ms — для будущего синка / конфликтов
  int updatedAt;

  // Здоровье
  List<InjuryLevel> healthLevels;

  Character({
    required this.id,
    this.name = '',
    this.player = '',
    this.chronicle = '',
    this.nature = '',
    this.mask = '',
    this.generation = '',
    this.haven = '',
    this.clan = '',
    this.concept = '',
    Map<String, int>? attributes,
    Map<String, int>? abilities,
    Map<String, String>? attributeSpecialties,
    Map<String, String>? abilitySpecialties,
    List<String>? extraTalents,
    List<String>? extraSkills,
    List<String>? extraKnowledges,
    Map<String, String>? customAbilityDescriptions,
    List<ExpandableItem>? disciplines,
    List<ExpandableItem>? backgrounds,
    List<ExpandableItem>? merits,
    List<ExpandableItem>? flaws,
    Map<String, int>? virtues,
    this.humanity = 7,
    this.willpowerPermanent = 5,
    this.willpowerCurrent = 3,
    this.bloodPool = 10,
    this.experience = 0,
    this.sheetThemeId = 'caitiff',
    this.storytellerNotes = '',
    this.storytellerPrivateNotes = '',
    this.chronicleId,
    this.drivePlayerName,
    int? updatedAt,
    List<InjuryLevel>? healthLevels,
  }) : attributes =
           attributes ??
           {
             'Сила': 1,
             'Ловкость': 1,
             'Выносливость': 1,
             'Обаяние': 1,
             'Манипулирование': 1,
             'Внешность': 1,
             'Восприятие': 1,
             'Интеллект': 1,
             'Сообразительность': 1,
           },
       abilities =
           abilities ??
           {
             // Заполните по необходимости, но лучше сохранять все по списку. Для простоты оставим пустым и будем динамически инициализировать.
           },
       attributeSpecialties = attributeSpecialties ?? {},
       abilitySpecialties = abilitySpecialties ?? {},
       extraTalents = extraTalents ?? [],
       extraSkills = extraSkills ?? [],
       extraKnowledges = extraKnowledges ?? [],
       customAbilityDescriptions = customAbilityDescriptions ?? {},
       disciplines = disciplines ?? [],
       backgrounds = backgrounds ?? [],
       merits = merits ?? [],
       flaws = flaws ?? [],
       virtues = virtues ?? {'Совесть': 0, 'Самоконтроль': 0, 'Храбрость': 0},
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       healthLevels =
           healthLevels ?? List.filled(healthBoxCount, InjuryLevel.empty);

  Map<String, dynamic> toJson({bool includePrivateNotes = true}) {
    return {
      'id': id,
      'name': name,
      'player': player,
      'chronicle': chronicle,
      'nature': nature,
      'mask': mask,
      'generation': generation,
      'haven': haven,
      'clan': clan,
      'concept': concept,
      'schemaVersion': TraitIds.schemaVersion,
      'attributes': TraitIds.encodeIntMap(attributes),
      'abilities': TraitIds.encodeIntMap(abilities),
      'attributeSpecialties': TraitIds.encodeStrMap(attributeSpecialties),
      'abilitySpecialties': TraitIds.encodeStrMap(abilitySpecialties),
      'extraTalents': TraitIds.encodeExtras(extraTalents),
      'extraSkills': TraitIds.encodeExtras(extraSkills),
      'extraKnowledges': TraitIds.encodeExtras(extraKnowledges),
      'customAbilityDescriptions': TraitIds.encodeStrMap(customAbilityDescriptions),
      'disciplines': disciplines.map((d) => d.toJson()).toList(),
      'backgrounds': backgrounds.map((b) => b.toJson()).toList(),
      'merits': merits.map((m) => m.toJson()).toList(),
      'flaws': flaws.map((f) => f.toJson()).toList(),
      'virtues': TraitIds.encodeIntMap(virtues),
      'humanity': humanity,
      'willpowerPermanent': willpowerPermanent,
      'willpowerCurrent': willpowerCurrent,
      'bloodPool': bloodPool,
      'experience': experience,
      'sheetThemeId': sheetThemeId,
      'storytellerNotes': storytellerNotes,
      if (includePrivateNotes)
        'storytellerPrivateNotes': storytellerPrivateNotes,
      'chronicleId': chronicleId,
      'drivePlayerName': drivePlayerName,
      'updatedAt': updatedAt,
      'healthLevels': healthLevels.map((l) => l.index).toList(),
    };
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    // Обратная совместимость: старые сохранения хранили дополнения в ключе 'merits'
    final List<dynamic> backgroundsJson =
        (json['backgrounds'] as List?) ?? (json['merits'] as List?) ?? [];
    // Новые мериты — только из ключа 'merits', если есть и 'backgrounds'
    // Если 'backgrounds' отсутствует, считаем, что 'merits' — это старые дополнения
    final bool hasBackgroundsKey = json.containsKey('backgrounds');
    final List<dynamic> meritsJson = hasBackgroundsKey
        ? (json['merits'] as List? ?? [])
        : [];

    return Character(
      id: json['id'],
      name: json['name'] ?? '',
      player: json['player'] ?? '',
      chronicle: json['chronicle'] ?? '',
      nature: json['nature'] ?? '',
      mask: json['mask'] ?? '',
      generation: json['generation'] ?? '',
      haven: json['haven'] ?? '',
      clan: json['clan'] ?? '',
      concept: json['concept'] ?? '',
      attributes: TraitIds.decodeIntMap(
        Map<String, dynamic>.from(json['attributes'] ?? {}),
      ),
      abilities: TraitIds.decodeIntMap(
        Map<String, dynamic>.from(json['abilities'] ?? {}),
      ),
      attributeSpecialties: TraitIds.decodeStrMap(
        Map<String, dynamic>.from(json['attributeSpecialties'] ?? {}),
      ),
      abilitySpecialties: TraitIds.decodeStrMap(
        Map<String, dynamic>.from(json['abilitySpecialties'] ?? {}),
      ),
      extraTalents: TraitIds.decodeExtras(json['extraTalents']),
      extraSkills: TraitIds.decodeExtras(json['extraSkills']),
      extraKnowledges: TraitIds.decodeExtras(json['extraKnowledges']),
      customAbilityDescriptions: TraitIds.decodeStrMap(
        Map<String, dynamic>.from(json['customAbilityDescriptions'] ?? {}),
      ),
      disciplines: _itemsFromJson(json['disciplines']),
      backgrounds: _itemsFromJson(backgroundsJson),
      merits: _itemsFromJson(meritsJson),
      flaws: _itemsFromJson(json['flaws']),
      virtues: TraitIds.decodeIntMap(
        Map<String, dynamic>.from(
          json['virtues'] ?? {'conscience': 0, 'selfControl': 0, 'courage': 0},
        ),
      ),
      humanity: json['humanity'] ?? 7,
      willpowerPermanent: json['willpowerPermanent'] ?? 5,
      willpowerCurrent: json['willpowerCurrent'] ?? 3,
      bloodPool: json['bloodPool'] ?? 10,
      experience: json['experience'] ?? 0,
      sheetThemeId: json['sheetThemeId'] ?? 'caitiff',
      storytellerNotes: json['storytellerNotes'] ?? '',
      storytellerPrivateNotes: json['storytellerPrivateNotes'] ?? '',
      chronicleId: json['chronicleId'],
      drivePlayerName: json['drivePlayerName'],
      updatedAt: json['updatedAt'] ?? 0,
      healthLevels: _healthFromJson(json['healthLevels']),
    );
  }

  static List<ExpandableItem> _itemsFromJson(dynamic raw) {
    if (raw is! List) return [];
    final out = <ExpandableItem>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(ExpandableItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<InjuryLevel> _healthFromJson(dynamic raw) {
    final out = List<InjuryLevel>.filled(healthBoxCount, InjuryLevel.empty);
    if (raw is! List) return out;
    for (var i = 0; i < raw.length && i < healthBoxCount; i++) {
      final e = raw[i];
      final idx = e is int ? e : int.tryParse('$e');
      if (idx != null && idx >= 0 && idx < InjuryLevel.values.length) {
        out[i] = InjuryLevel.values[idx];
      }
    }
    return out;
  }
}

class ExpandableItem {
  String name;
  int value;
  String? description;

  ExpandableItem({required this.name, this.value = 0, this.description});

  Map<String, dynamic> toJson() {
    return {
      'id': TraitIds.idForRu(name, fallbackPrefix: 'custom'),
      'label': name,
      'name': name, // старые клиенты
      'value': value,
      'description': description,
    };
  }

  factory ExpandableItem.fromJson(Map<String, dynamic> json) {
    return ExpandableItem(
      name: json['label']?.toString() ?? json['name']?.toString() ?? '',
      value: json['value'] ?? 0,
      description: json['description'],
    );
  }
}
