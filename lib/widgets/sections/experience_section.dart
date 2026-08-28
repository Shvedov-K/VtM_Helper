import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';

class ExperienceSection extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const ExperienceSection({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  void _editDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Опыт'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Текущее количество XP',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(ctx, controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => _save(ctx, controller),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext ctx, TextEditingController controller) {
    final parsed = int.tryParse(controller.text.trim()) ?? 0;
    Navigator.pop(ctx);
    onChanged(parsed.clamp(0, 99999));
  }

  @override
  Widget build(BuildContext context) {
    final theme = SheetThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Опыт',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: theme.ink, size: 28),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              disabledColor: theme.muted.withOpacity(0.4),
            ),
            GestureDetector(
              onTap: () => _editDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.accent,
                  border: Border.all(color: theme.border, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$value XP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: theme.ink, size: 28),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}
