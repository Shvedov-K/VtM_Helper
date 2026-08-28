import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';

class ExpandableItemRow extends StatelessWidget {
  final String name;
  final int value;
  final bool useVerticalLayout;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isEditing;

  const ExpandableItemRow({
    Key? key,
    required this.name,
    required this.value,
    this.useVerticalLayout = false,
    this.onChanged,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isEditing = false,
  }) : super(key: key);

  void _handleDotTap(int index) {
    final target = index + 1;
    int newValue;
    if (value == target) {
      newValue = (value - 1).clamp(0, 5);
    } else {
      newValue = target.clamp(0, 5);
    }
    onChanged?.call(newValue);
  }

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: const Text('Выберите действие:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (onEdit != null) onEdit!();
            },
            child: const Text('Редактировать описание'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (onDelete != null) onDelete!();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildDotsRow() {
      return LayoutBuilder(
        builder: (context, constraints) {
          double availableWidth = constraints.maxWidth;
          double iconSize = 18.0;
          double horizontalPadding = 3.0 * 2;

          if (availableWidth < (iconSize * 5 + horizontalPadding * 5)) {
            iconSize = (availableWidth - horizontalPadding * 5) / 5;
            iconSize = iconSize.clamp(12.0, 18.0);
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final isFilled = index < value;
              return GestureDetector(
                onTap: isEditing ? () => _handleDotTap(index) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: Icon(
                    isFilled ? Icons.circle : Icons.circle_outlined,
                    size: iconSize,
                    color: isFilled ? SheetThemeScope.of(context).filled : SheetThemeScope.of(context).emptyBorder.withOpacity(0.45),
                  ),
                ),
              );
            }),
          );
        },
      );
    }

    Widget content;
    if (useVerticalLayout) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontSize: 15, color: SheetThemeScope.of(context).ink)),
          const SizedBox(height: 4),
          _buildDotsRow(),
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: TextStyle(fontSize: 15, color: SheetThemeScope.of(context).ink))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _buildDotsRow())),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: isEditing ? () => _showOptionsDialog(context) : null,
        child: content,
      ),
    );
  }
}