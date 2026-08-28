import 'package:vtm_helper/models/character.dart';

class CharacterDiff {
  static List<String> describe(Character local, Character remote) {
    final out = <String>[];

    void scalar(String label, Object a, Object b) {
      if (a.toString() != b.toString()) {
        out.add('$label: $a → $b');
      }
    }

    scalar('Имя', local.name, remote.name);
    scalar('Игрок', local.player, remote.player);
    scalar('Клан', local.clan, remote.clan);
    scalar('Поколение', local.generation, remote.generation);
    scalar('Натура', local.nature, remote.nature);
    scalar('Маска', local.mask, remote.mask);
    scalar('Концепция', local.concept, remote.concept);
    scalar('Убежище', local.haven, remote.haven);
    scalar('Человечность', local.humanity, remote.humanity);
    scalar('Воля (пост.)', local.willpowerPermanent, remote.willpowerPermanent);
    scalar('Воля (тек.)', local.willpowerCurrent, remote.willpowerCurrent);
    scalar('Кровь', local.bloodPool, remote.bloodPool);
    scalar('Опыт', local.experience, remote.experience);

    _mapInt(out, 'Атрибут', local.attributes, remote.attributes);
    _mapInt(out, 'Способность', local.abilities, remote.abilities);
    _mapInt(out, 'Добродетель', local.virtues, remote.virtues);
    _mapStr(out, 'Спец. атрибута', local.attributeSpecialties, remote.attributeSpecialties);
    _mapStr(out, 'Спец. способности', local.abilitySpecialties, remote.abilitySpecialties);
    _items(out, 'Дисциплина', local.disciplines, remote.disciplines);
    _items(out, 'Дополнение', local.backgrounds, remote.backgrounds);
    _items(out, 'Мерит', local.merits, remote.merits);
    _items(out, 'Демерит', local.flaws, remote.flaws);
    _list(out, 'Свои таланты', local.extraTalents, remote.extraTalents);
    _list(out, 'Свои навыки', local.extraSkills, remote.extraSkills);
    _list(out, 'Свои познания', local.extraKnowledges, remote.extraKnowledges);

    if (local.storytellerNotes != remote.storytellerNotes) {
      out.add('Заметки рассказчика изменены');
    }
    if (local.storytellerPrivateNotes != remote.storytellerPrivateNotes) {
      out.add('Скрытые заметки мастера изменены');
    }
    if (!_healthEq(local.healthLevels, remote.healthLevels)) {
      out.add('Здоровье изменено');
    }

    return out;
  }

  static void _mapInt(
    List<String> out,
    String prefix,
    Map<String, int> a,
    Map<String, int> b,
  ) {
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      final av = a[k] ?? 0;
      final bv = b[k] ?? 0;
      if (av != bv) out.add('$prefix «$k»: $av → $bv');
    }
  }

  static void _mapStr(
    List<String> out,
    String prefix,
    Map<String, String> a,
    Map<String, String> b,
  ) {
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      final av = a[k] ?? '';
      final bv = b[k] ?? '';
      if (av != bv) out.add('$prefix «$k»: $av → $bv');
    }
  }

  static void _items(
    List<String> out,
    String prefix,
    List<ExpandableItem> a,
    List<ExpandableItem> b,
  ) {
    final am = {for (final e in a) e.name: e.value};
    final bm = {for (final e in b) e.name: e.value};
    final keys = {...am.keys, ...bm.keys};
    for (final k in keys) {
      if (!am.containsKey(k)) {
        out.add('$prefix «$k»: добавлено (${bm[k]})');
      } else if (!bm.containsKey(k)) {
        out.add('$prefix «$k»: удалено');
      } else if (am[k] != bm[k]) {
        out.add('$prefix «$k»: ${am[k]} → ${bm[k]}');
      }
    }
  }

  static void _list(
    List<String> out,
    String prefix,
    List<String> a,
    List<String> b,
  ) {
    for (final x in b) {
      if (!a.contains(x)) out.add('$prefix: +$x');
    }
    for (final x in a) {
      if (!b.contains(x)) out.add('$prefix: −$x');
    }
  }

  static bool _healthEq(List<InjuryLevel> a, List<InjuryLevel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
