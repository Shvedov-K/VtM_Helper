import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/descriptions/attributes_descriptions.dart';
import 'package:vtm_helper/descriptions/specialty_suggestions.dart';
import 'package:vtm_helper/widgets/attribute_row.dart';

class AttributesSection extends StatelessWidget {
  final Map<String, int> attributes;
  final Map<String, String> specialties;
  final void Function(String, int) onChanged;
  final void Function(String, String?) onSpecialtyChanged;
  final bool useVerticalLayout;
  final bool isEditing;

  const AttributesSection({
    Key? key,
    required this.attributes,
    required this.specialties,
    required this.onChanged,
    required this.onSpecialtyChanged,
    required this.useVerticalLayout,
    required this.isEditing,
  }) : super(key: key);

  void _showDescription(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Text(attributesDescriptions[name] ?? 'Описание отсутствует.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static const List<String> _physical = ['Сила', 'Ловкость', 'Выносливость'];
  static const List<String> _social = [
    'Обаяние',
    'Манипулирование',
    'Внешность',
  ];
  static const List<String> _mental = [
    'Восприятие',
    'Интеллект',
    'Сообразительность',
  ];

  Widget _buildCategory(
    BuildContext context,
    String title,
    List<String> names,
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
        ...names.map(
          (name) => AttributeRow(
            name: name,
            initialValue: attributes[name] ?? 1,
            useVerticalLayout: false, // в колонках листа всегда имя | точки в ряд
            onChanged: isEditing ? (value) => onChanged(name, value) : null,
            onLongPress: () => _showDescription(context, name),
            isEnabled: isEditing,
            specialty: specialties[name],
            specialtySuggestions:
                attributeSpecialtySuggestions[name] ?? const [],
            onSpecialtyChanged: isEditing
                ? (value) => onSpecialtyChanged(name, value)
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Атрибуты',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCategory(context, 'Физические', _physical),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCategory(context, 'Социальные', _social),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCategory(context, 'Ментальные', _mental),
            ),
          ],
        ),
      ],
    );
  }
}
