import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/style/text_style.dart'; // для InjuryLevel

class HealthSection extends StatelessWidget {
  final List<InjuryLevel> healthLevels;
  final void Function(List<InjuryLevel>) onChanged;
  final bool useVerticalLayout;

  const HealthSection({
    Key? key,
    required this.healthLevels,
    required this.onChanged,
    required this.useVerticalLayout,
  }) : super(key: key);

  final String _description =
      'Здоровье отражает физическое состояние персонажа.\n'
      '• Пустая клетка — здоров.\n'
      '• Круг (●) — лёгкое ранение (Bashing damage).\n'
      '• Крест (✘) — тяжёлое ранение (Lethal damage).\n'
      'Когда все клетки заполнены, персонаж недееспособен.';

  static const List<String> _levelNames = [
    'Синяки',
    'Задет (-1)',
    'Сильно задет (-1)',
    'Ранен (-2)',
    'Тяжело ранен (-2)',
    'Искалечен (-5)',
    'Обездвижен',
  ];

  void _showDescription(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Здоровье'),
        content: Text(_description),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _toggleInjury(int index) {
    final newLevels = List<InjuryLevel>.from(healthLevels);
    switch (newLevels[index]) {
      case InjuryLevel.empty:
        newLevels[index] = InjuryLevel.bashing;
        break;
      case InjuryLevel.bashing:
        newLevels[index] = InjuryLevel.lethal;
        break;
      case InjuryLevel.lethal:
        newLevels[index] = InjuryLevel.empty;
        break;
    }
    onChanged(newLevels);
  }

  Widget _buildHealthIndicator(BuildContext context, int index) {
    IconData iconData;
    Color color;

    switch (healthLevels[index]) {
      case InjuryLevel.empty:
        iconData = Icons.circle_outlined;
        color = SheetThemeScope.of(context).muted;
        break;
      case InjuryLevel.bashing:
        iconData = Icons.circle;
        color = SheetThemeScope.of(context).danger;
        break;
      case InjuryLevel.lethal:
        iconData = Icons.close;
        color = SheetThemeScope.of(context).danger;
        break;
    }

    return GestureDetector(
      onTap: () => _toggleInjury(index),
      child: Icon(iconData, size: 26, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Здоровье',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SheetThemeScope.of(context).ink),
        ),
        const SizedBox(height: 8),
        ...List.generate(7, (index) {
          if (useVerticalLayout) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: GestureDetector(
                onLongPress: () => _showDescription(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_levelNames[index], style: TextStyle(fontSize: 15, color: SheetThemeScope.of(context).ink)),
                    const SizedBox(height: 4),
                    _buildHealthIndicator(context, index),
                  ],
                ),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: GestureDetector(
                onLongPress: () => _showDescription(context),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(_levelNames[index], style: TextStyle(fontSize: 15, color: SheetThemeScope.of(context).ink))),
                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: _buildHealthIndicator(context, index))),
                  ],
                ),
              ),
            );
          }
        }),
      ],
    );
  }
}