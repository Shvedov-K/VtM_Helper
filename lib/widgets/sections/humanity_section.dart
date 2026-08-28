import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/style/text_style.dart';

class HumanitySection extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const HumanitySection({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  final String _description =
      'Человечность — мера моральной целостности вампира. '
      'Чем выше значение, тем ближе персонаж к людям. '
      'Падение человечности ведёт к озверению.';

  void _showDescription(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Человечность'),
        content: Text(_description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _handleTap(int index) {
    final target = index + 1;
    if (value == target) {
      onChanged((value - 1).clamp(0, 10));
    } else {
      onChanged(target.clamp(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Человечность',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(10, (index) {
            final isFilled = index < value;
            return GestureDetector(
              onTap: () => _handleTap(index),
              onLongPress: () => _showDescription(context),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? SheetThemeScope.of(context).ink : Colors.transparent,
                  border: Border.all(color: SheetThemeScope.of(context).ink, width: 2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}