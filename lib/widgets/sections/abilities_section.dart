import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/descriptions/abilities_descriptions.dart';
import 'package:vtm_helper/descriptions/specialty_suggestions.dart';
import 'package:vtm_helper/style/text_style.dart';
import 'package:vtm_helper/widgets/attribure_row.dart';

enum AbilityCategory { talent, skill, knowledge }

class AbilitiesSection extends StatelessWidget {
  final Map<String, int> abilities;
  final Map<String, String> specialties;
  final List<String> extraTalents;
  final List<String> extraSkills;
  final List<String> extraKnowledges;
  final Map<String, String> customDescriptions;
  final void Function(String, int) onChanged;
  final void Function(String, String?) onSpecialtyChanged;
  final void Function(String name, String? description)? onCustomDescriptionChanged;
  final void Function(AbilityCategory category, String name)? onAbilityAdded;
  final void Function(AbilityCategory category, String name)? onAbilityRemoved;
  final bool useVerticalLayout;
  final bool isEditing;

  const AbilitiesSection({
    Key? key,
    required this.abilities,
    required this.specialties,
    required this.extraTalents,
    required this.extraSkills,
    required this.extraKnowledges,
    required this.customDescriptions,
    required this.onChanged,
    required this.onSpecialtyChanged,
    this.onCustomDescriptionChanged,
    this.onAbilityAdded,
    this.onAbilityRemoved,
    required this.useVerticalLayout,
    required this.isEditing,
  }) : super(key: key);

  static const List<String> _talents = [
    'Бдительность',
    'Атлетика',
    'Рукопашный бой',
    'Уклонение',
    'Эмпатия',
    'Красноречие',
    'Запугивание',
    'Лидерство',
    'Уличные порядки',
    'Хитрость',
  ];

  static const List<String> _skills = [
    'Понимание зверей',
    'Ремесло',
    'Вождение',
    'Этикет',
    'Огнестрельное оружие',
    'Холодное оружие',
    'Исполнение',
    'Безопасность',
    'Скрытность',
    'Выживание',
  ];

  static const List<String> _knowledges = [
    'Гуманитарные науки',
    'Компьютеры',
    'Финансы',
    'Расследование',
    'Закон',
    'Языки',
    'Медицина',
    'Оккультизм',
    'Политика',
    'Естественные науки',
  ];

  static final Set<String> standardAbilities = {
    ..._talents,
    ..._skills,
    ..._knowledges,
  };

  void _showDescription(
    BuildContext context,
    String abilityName, {
    bool isCustom = false,
  }) {
    final text = isCustom
        ? (customDescriptions[abilityName] ?? 'Описание не задано.')
        : (abilitiesDescriptions[abilityName] ?? 'Описание отсутствует.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(abilityName),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          if (isCustom && isEditing && onCustomDescriptionChanged != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _editCustomDescription(context, abilityName);
              },
              child: const Text('Редактировать'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editCustomDescription(BuildContext context, String abilityName) {
    final controller = TextEditingController(
      text: customDescriptions[abilityName] ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Описание: $abilityName'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Введите описание способности...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onCustomDescriptionChanged?.call(abilityName, null);
            },
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(ctx);
              onCustomDescriptionChanged?.call(
                abilityName,
                value.isEmpty ? null : value,
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, AbilityCategory category) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final existing = {
      ...standardAbilities,
      ...extraTalents,
      ...extraSkills,
      ...extraKnowledges,
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Добавить ${_categoryLabel(category).toLowerCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Название способности',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Описание (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => _confirmAdd(
              context,
              ctx,
              nameController,
              descController,
              category,
              existing,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(AbilityCategory c) {
    switch (c) {
      case AbilityCategory.talent:
        return 'Талант';
      case AbilityCategory.skill:
        return 'Навык';
      case AbilityCategory.knowledge:
        return 'Познание';
    }
  }

  void _confirmAdd(
    BuildContext parentContext,
    BuildContext dialogContext,
    TextEditingController nameController,
    TextEditingController descController,
    AbilityCategory category,
    Set<String> existing,
  ) {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    if (existing.contains(name) || abilities.containsKey(name)) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text('Способность «$name» уже есть')),
      );
      return;
    }
    final desc = descController.text.trim();
    Navigator.pop(dialogContext);
    onAbilityAdded?.call(category, name);
    if (desc.isNotEmpty) {
      onCustomDescriptionChanged?.call(name, desc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Способности',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCategory(
                context,
                'Таланты',
                AbilityCategory.talent,
                _talents,
                extraTalents,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCategory(
                context,
                'Навыки',
                AbilityCategory.skill,
                _skills,
                extraSkills,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCategory(
                context,
                'Познания',
                AbilityCategory.knowledge,
                _knowledges,
                extraKnowledges,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context,
    String title,
    AbilityCategory category,
    List<String> standardList,
    List<String> extras,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 8),
        ...standardList.map(
          (name) => AttributeRow(
            name: name,
            initialValue: abilities[name] ?? 0,
            useVerticalLayout: useVerticalLayout,
            onChanged: isEditing ? (value) => onChanged(name, value) : null,
            onLongPress: () => _showDescription(context, name),
            isEnabled: isEditing,
            specialty: specialties[name],
            specialtySuggestions:
                abilitySpecialtySuggestions[name] ?? const [],
            onSpecialtyChanged: isEditing
                ? (value) => onSpecialtyChanged(name, value)
                : null,
          ),
        ),
        ...extras.map(
          (name) => AttributeRow(
            name: name,
            initialValue: abilities[name] ?? 0,
            useVerticalLayout: useVerticalLayout,
            onChanged: isEditing ? (value) => onChanged(name, value) : null,
            onLongPress: () =>
                _showDescription(context, name, isCustom: true),
            isEnabled: isEditing,
            specialty: specialties[name],
            specialtySuggestions: const [],
            onSpecialtyChanged: isEditing
                ? (value) => onSpecialtyChanged(name, value)
                : null,
            onDelete: isEditing && onAbilityRemoved != null
                ? () => onAbilityRemoved!(category, name)
                : null,
          ),
        ),
        if (isEditing && onAbilityAdded != null)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: SheetThemeScope.of(context).ink,
              ),
              tooltip: 'Добавить ${_categoryLabel(category).toLowerCase()}',
              onPressed: () => _showAddDialog(context, category),
            ),
          ),
      ],
    );
  }
}
