import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/style/text_style.dart';
import 'package:vtm_helper/widgets/expandable_item_row.dart';
import 'package:vtm_helper/widgets/attribure_row.dart';

class AdvantagesSection extends StatefulWidget {
  final List<ExpandableItem> disciplines;
  final List<ExpandableItem> backgrounds;
  final Map<String, int> virtues;
  final Function(List<ExpandableItem>) onDisciplinesChanged;
  final Function(List<ExpandableItem>) onBackgroundsChanged;
  final Function(String, int) onVirtueChanged;
  final bool useVerticalLayout;
  final bool isEditing;

  const AdvantagesSection({
    Key? key,
    required this.disciplines,
    required this.backgrounds,
    required this.virtues,
    required this.onDisciplinesChanged,
    required this.onBackgroundsChanged,
    required this.onVirtueChanged,
    required this.useVerticalLayout,
    required this.isEditing,
  }) : super(key: key);

  @override
  State<AdvantagesSection> createState() => _AdvantagesSectionState();
}

class _AdvantagesSectionState extends State<AdvantagesSection> {
  static const Map<String, String> virtueDescriptions = {
    'Совесть': 'Способность отличать добро от зла, моральный компас.',
    'Самоконтроль': 'Способность сдерживать свои инстинкты и эмоции.',
    'Храбрость':
        'Способность противостоять страху и действовать в опасных ситуациях.',
  };

  void _showVirtueDescription(String virtue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(virtue),
        content: Text(virtueDescriptions[virtue] ?? 'Описание отсутствует'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDescription(ExpandableItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: Text(item.description ?? 'Описание отсутствует'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editDescription(
    ExpandableItem item,
    Function(List<ExpandableItem>) onChanged,
    List<ExpandableItem> list,
  ) {
    final controller = TextEditingController(text: item.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Редактировать описание для ${item.name}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Введите описание...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.description = controller.text.isNotEmpty
                    ? controller.text
                    : null;
              });
              onChanged(list);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _addItem(
    List<ExpandableItem> list,
    String type,
    Function(List<ExpandableItem>) onChanged,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Добавить $type'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Введите название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newItem = ExpandableItem(name: controller.text);
                final updatedList = List<ExpandableItem>.from(list)
                  ..add(newItem);
                onChanged(updatedList);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(
    int index,
    List<ExpandableItem> list,
    Function(List<ExpandableItem>) onChanged,
  ) {
    final updatedList = List<ExpandableItem>.from(list)..removeAt(index);
    onChanged(updatedList);
  }

  Widget _buildExpandableSection({
    required String title,
    required List<ExpandableItem> items,
    required Function(List<ExpandableItem>) onChanged,
    required String itemType,
    required bool isEditing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
        ),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return ExpandableItemRow(
            name: item.name,
            value: item.value,
            onChanged: (newValue) {
              final updatedList = List<ExpandableItem>.from(items);
              updatedList[index].value = newValue;
              onChanged(updatedList);
            },
            onTap: () => _showDescription(item),
            onEdit: isEditing
                ? () => _editDescription(item, onChanged, items)
                : null,
            onDelete: isEditing
                ? () => _deleteItem(index, items, onChanged)
                : null,
            useVerticalLayout: widget.useVerticalLayout,
            isEditing: isEditing,
          );
        }),
        const SizedBox(height: 4),
        if (isEditing)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: SheetThemeScope.of(context).ink,
              ),
              onPressed: () => _addItem(items, itemType, onChanged),
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
            'Преимущества',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
          ),
        ),
        const SizedBox(height: 16),

        _buildExpandableSection(
          title: 'Дисциплины',
          items: widget.disciplines,
          onChanged: widget.onDisciplinesChanged,
          itemType: 'дисциплину',
          isEditing: widget.isEditing,
        ),

        const SizedBox(height: 16),

        _buildExpandableSection(
          title: 'Дополнения',
          items: widget.backgrounds,
          onChanged: widget.onBackgroundsChanged,
          itemType: 'дополнение',
          isEditing: widget.isEditing,
        ),

        const SizedBox(height: 16),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Добродетели',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
            ),
            const SizedBox(height: 8),
            ...widget.virtues.keys.map(
              (virtue) => AttributeRow(
                name: virtue,
                initialValue: widget.virtues[virtue] ?? 0,
                useVerticalLayout: widget.useVerticalLayout,
                onChanged: widget.isEditing
                    ? (value) => widget.onVirtueChanged(virtue, value)
                    : null,
                onLongPress: () => _showVirtueDescription(virtue),
                isEnabled: widget.isEditing,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
