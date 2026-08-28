import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/models/character.dart';

class HeaderSection extends StatelessWidget {
  final Character character;
  final void Function({
    String? name,
    String? player,
    String? chronicle,
    String? nature,
    String? mask,
    String? generation,
    String? haven,
    String? clan,
    String? concept,
  }) onChanged;
  final bool useVerticalLayout;
  final bool isEditing;

  const HeaderSection({
    Key? key,
    required this.character,
    required this.onChanged,
    required this.useVerticalLayout,
    required this.isEditing,
  }) : super(key: key);

  void _showEditDialog(
    BuildContext context,
    String label,
    String currentValue,
    Function(String) onSave,
  ) {
    if (!isEditing) return;
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Редактировать $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'Введите значение',
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
              onSave(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    final theme = SheetThemeScope.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: theme.muted, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: theme.muted),
              ),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 16, color: theme.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(
    BuildContext context, {
    required String label1,
    required String value1,
    required String label2,
    required String value2,
    required String label3,
    required String value3,
    required VoidCallback onTap1,
    required VoidCallback onTap2,
    required VoidCallback onTap3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildField(context, label1, value1, onTap1),
          const SizedBox(width: 8),
          _buildField(context, label2, value2, onTap2),
          const SizedBox(width: 8),
          _buildField(context, label3, value3, onTap3),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = SheetThemeScope.of(context);
    return Center(
      child: Column(
        children: [
          Text(
            '✞ ────── ВАМПИР ────── ✞',
            style: TextStyle(
              fontSize: 20,
              color: theme.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildFieldRow(
            context,
            label1: 'Имя',
            value1: character.name,
            label2: 'Натура',
            value2: character.nature,
            label3: 'Поколение',
            value3: character.generation,
            onTap1: () => _showEditDialog(
              context,
              'Имя',
              character.name,
              (val) => onChanged(name: val),
            ),
            onTap2: () => _showEditDialog(
              context,
              'Натура',
              character.nature,
              (val) => onChanged(nature: val),
            ),
            onTap3: () => _showEditDialog(
              context,
              'Поколение',
              character.generation,
              (val) => onChanged(generation: val),
            ),
          ),
          _buildFieldRow(
            context,
            label1: 'Игрок',
            value1: character.player,
            label2: 'Маска',
            value2: character.mask,
            label3: 'Убежище',
            value3: character.haven,
            onTap1: () => _showEditDialog(
              context,
              'Игрок',
              character.player,
              (val) => onChanged(player: val),
            ),
            onTap2: () => _showEditDialog(
              context,
              'Маска',
              character.mask,
              (val) => onChanged(mask: val),
            ),
            onTap3: () => _showEditDialog(
              context,
              'Убежище',
              character.haven,
              (val) => onChanged(haven: val),
            ),
          ),
          _buildFieldRow(
            context,
            label1: 'Хроника',
            value1: character.chronicle,
            label2: 'Клан',
            value2: character.clan,
            label3: 'Концепция',
            value3: character.concept,
            onTap1: () => _showEditDialog(
              context,
              'Хроника',
              character.chronicle,
              (val) => onChanged(chronicle: val),
            ),
            onTap2: () => _showEditDialog(
              context,
              'Клан',
              character.clan,
              (val) => onChanged(clan: val),
            ),
            onTap3: () => _showEditDialog(
              context,
              'Концепция',
              character.concept,
              (val) => onChanged(concept: val),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: theme.accent, thickness: 2),
        ],
      ),
    );
  }
}
