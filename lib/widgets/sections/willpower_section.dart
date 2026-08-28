import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/style/text_style.dart';

class WillpowerSection extends StatelessWidget {
  final int permanent;
  final int current;
  final void Function(int, int) onChanged;

  const WillpowerSection({
    Key? key,
    required this.permanent,
    required this.current,
    required this.onChanged,
  }) : super(key: key);

  final String _description =
      'Сила воли отражает способность персонажа противостоять страху, '
      'соблазнам и контролировать свои действия. '
      'Кружки — максимальный запас, квадратики — текущие очки.';

  void _showDescription(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сила воли'),
        content: Text(_description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _onPermanentTap(int index) {
    final target = index + 1;
    int newPermanent;
    if (permanent == target) {
      newPermanent = (permanent - 1).clamp(0, 10);
    } else {
      newPermanent = target.clamp(0, 10);
    }
    onChanged(newPermanent, current.clamp(0, newPermanent));
  }

  void _onCurrentTap(int index) {
    final target = index + 1;
    int newCurrent;
    if (current == target) {
      newCurrent = (current - 1).clamp(0, permanent);
    } else {
      newCurrent = target.clamp(0, permanent);
    }
    onChanged(permanent, newCurrent);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сила воли',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
        ),
        const SizedBox(height: 8),
        // Постоянный запас (кружки)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(10, (index) {
            final isFilled = index < permanent;
            return GestureDetector(
              onTap: () => _onPermanentTap(index),
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
        const SizedBox(height: 4),
        // Текущие очки (квадратики)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(10, (index) {
            final isFilled = index < current;
            return GestureDetector(
              onTap: () => _onCurrentTap(index),
              onLongPress: () => _showDescription(context),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
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