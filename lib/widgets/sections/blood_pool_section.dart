import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';

class BloodPoolLimits {
  final int maxBlood;
  final int perTurn;

  const BloodPoolLimits(this.maxBlood, this.perTurn);

  static BloodPoolLimits? forGeneration(String generationRaw) {
    final match = RegExp(r'(\d{1,2})').firstMatch(generationRaw);
    if (match == null) return null;
    final gen = int.tryParse(match.group(1)!);
    if (gen == null) return null;

    const table = <int, BloodPoolLimits>{
      15: BloodPoolLimits(10, 1),
      14: BloodPoolLimits(10, 1),
      13: BloodPoolLimits(10, 1),
      12: BloodPoolLimits(11, 1),
      11: BloodPoolLimits(12, 1),
      10: BloodPoolLimits(13, 1),
      9: BloodPoolLimits(14, 2),
      8: BloodPoolLimits(15, 3),
      7: BloodPoolLimits(20, 4),
      6: BloodPoolLimits(30, 6),
      5: BloodPoolLimits(40, 8),
      4: BloodPoolLimits(50, 10),
      3: BloodPoolLimits(50, 10),
    };
    return table[gen];
  }
}

class BloodPoolSection extends StatelessWidget {
  final int value;
  final String generation;
  final void Function(int) onChanged;

  const BloodPoolSection({
    Key? key,
    required this.value,
    required this.generation,
    required this.onChanged,
  }) : super(key: key);

  static const int _hardCap = 60;

  BloodPoolLimits? get _limits => BloodPoolLimits.forGeneration(generation);

  int get _ruleMax => _limits?.maxBlood ?? 20;

  int get _boxCount {
    final needed = value > _ruleMax ? value : _ruleMax;
    return needed.clamp(10, _hardCap);
  }

  bool get _overLimit => _limits != null && value > _limits!.maxBlood;

  void _showDescription(BuildContext context) {
    final limits = _limits;
    final genHint = limits == null
        ? 'Укажите поколение в шапке листа — появится лимит по V20.'
        : 'По V20 для этого поколения:\n'
            '• максимум крови: ${limits.maxBlood}\n'
            '• можно тратить за ход: ${limits.perTurn}\n\n'
            'Можно поставить больше максимума — лишние клетки подсвечиваются.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Запас крови'),
        content: SingleChildScrollView(
          child: Text(
            'Запас крови — сколько vitae доступно для дисциплин, '
            'исцеления и усиления атрибутов.\n\n'
            '$genHint\n\n'
            'Таблица (поколение → макс. / за ход):\n'
            '13–15 → 10 / 1\n'
            '12 → 11 / 1\n'
            '11 → 12 / 1\n'
            '10 → 13 / 1\n'
            '9 → 14 / 2\n'
            '8 → 15 / 3\n'
            '7 → 20 / 4\n'
            '6 → 30 / 6\n'
            '5 → 40 / 8\n'
            '4–3 → 50 / 10',
          ),
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

  void _handleTap(int index) {
    final target = index + 1;
    if (value == target) {
      onChanged((value - 1).clamp(0, _hardCap));
    } else {
      onChanged(target.clamp(0, _hardCap));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SheetThemeScope.of(context);
    final limits = _limits;

    final hint = limits == null
        ? (generation.trim().isEmpty
            ? 'Укажите поколение в шапке — будет подсказка по лимиту'
            : 'Поколение «$generation»: нет данных в таблице V20')
        : _overLimit
            ? 'Лимит ${limits.maxBlood} • до ${limits.perTurn} за ход  ·  выше лимита!'
            : 'Макс. ${limits.maxBlood} • до ${limits.perTurn} за ход';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Запас крови',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.ink,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              limits != null ? '$value / ${limits.maxBlood}' : '$value',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _overLimit ? theme.overLimit : theme.ink,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.info_outline, size: 22, color: theme.ink),
              tooltip: 'Подсказка',
              onPressed: () => _showDescription(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            color: _overLimit ? theme.overLimit : theme.muted,
            fontStyle: FontStyle.italic,
            fontWeight: _overLimit ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(_boxCount, (index) {
            final isFilled = index < value;
            final isOverSlot = limits != null && index >= limits.maxBlood;
            final fill = isOverSlot ? theme.overLimit : theme.filled;
            final border = isOverSlot ? theme.overLimit : theme.emptyBorder;

            return GestureDetector(
              onTap: () => _handleTap(index),
              onLongPress: () => _showDescription(context),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isFilled ? fill : Colors.transparent,
                  border: Border.all(color: border, width: 2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: theme.ink, size: 28),
              onPressed: value > 0
                  ? () => onChanged((value - 1).clamp(0, _hardCap))
                  : null,
              disabledColor: theme.muted.withOpacity(0.4),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: theme.ink, size: 28),
              onPressed: value < _hardCap
                  ? () => onChanged((value + 1).clamp(0, _hardCap))
                  : null,
            ),
            if (_overLimit)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Выше лимита поколения',
                  style: TextStyle(
                    color: theme.overLimit,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
