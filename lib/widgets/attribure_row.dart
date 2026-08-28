import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';

class AttributeRow extends StatefulWidget {
  final String name;
  final int initialValue;
  final bool useVerticalLayout;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onLongPress;
  final bool isEnabled;

  /// Текущая специализация (null / пустая = нет)
  final String? specialty;

  /// Список подсказок для диалога
  final List<String> specialtySuggestions;

  /// Вызывается при сохранении / очистке специализации
  final ValueChanged<String?>? onSpecialtyChanged;

  /// Если задан — в режиме редактирования показывается кнопка удаления
  final VoidCallback? onDelete;

  const AttributeRow({
    super.key,
    required this.name,
    this.initialValue = 1,
    this.useVerticalLayout = false,
    this.onChanged,
    this.onLongPress,
    this.isEnabled = false,
    this.specialty,
    this.specialtySuggestions = const [],
    this.onSpecialtyChanged,
    this.onDelete,
  });

  @override
  State<AttributeRow> createState() => _AttributeRowState();
}

class _AttributeRowState extends State<AttributeRow> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(0, 5);
  }

  @override
  void didUpdateWidget(AttributeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _value = widget.initialValue.clamp(0, 5);
    }
  }

  void _toggleAt(int index) {
    if (!widget.isEnabled) return;
    final target = index + 1;
    setState(() {
      if (_value == target) {
        _value = (_value - 1).clamp(0, 5);
      } else {
        _value = target.clamp(0, 5);
      }
    });
    widget.onChanged?.call(_value);
  }

  Future<void> _openSpecialtyDialog() async {
    if (widget.onSpecialtyChanged == null) return;

    final controller = TextEditingController(text: widget.specialty ?? '');
    final suggestions = widget.specialtySuggestions;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Специализация: ${widget.name}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Введите свою или выберите ниже',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Или выберите:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: suggestions.map((s) {
                            final selected = controller.text == s;
                            return ActionChip(
                              label: Text(s),
                              backgroundColor: selected
                                  ? Colors.deepPurple.shade700
                                  : null,
                              onPressed: () {
                                controller.text = s;
                                setDialogState(() {});
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text(
                    'Очистить',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    // null = отмена, '' = очистить, иначе текст
    if (result == null) return;
    if (result.isEmpty) {
      widget.onSpecialtyChanged!(null);
    } else {
      widget.onSpecialtyChanged!(result);
    }
  }

  Widget _buildDotsRow({double iconSize = 16, double gap = 1}) {
    final theme = SheetThemeScope.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final isFilled = index < _value;
          return GestureDetector(
            onTap: () => _toggleAt(index),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gap),
              child: Icon(
                isFilled ? Icons.circle : Icons.circle_outlined,
                size: iconSize,
                color: isFilled
                    ? theme.filled
                    : theme.emptyBorder.withOpacity(0.45),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNameBlock(BuildContext context) {
    final hasSpecialty =
        widget.specialty != null && widget.specialty!.trim().isNotEmpty;
    final canEditSpecialty = widget.isEnabled && widget.onSpecialtyChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.name,
                style: TextStyle(fontSize: 13, color: SheetThemeScope.of(context).ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isEnabled && widget.onDelete != null)
              InkWell(
                onTap: widget.onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: SheetThemeScope.of(context).danger,
                  ),
                ),
              ),
          ],
        ),
        if (hasSpecialty) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: canEditSpecialty ? _openSpecialtyDialog : null,
            child: Text(
              '↳ ${widget.specialty}',
              style: TextStyle(
                fontSize: 11,
                color: SheetThemeScope.of(context).accent,
                fontStyle: FontStyle.italic,
              ),
              softWrap: true,
            ),
          ),
        ] else if (canEditSpecialty) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: _openSpecialtyDialog,
            child: Text(
              '+ специализация',
              style: TextStyle(
                fontSize: 12,
                color: SheetThemeScope.of(context).muted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useVerticalLayout) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNameBlock(context),
              const SizedBox(height: 4),
              _buildDotsRow(),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNameBlock(context),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildDotsRow(),
              ),
            ],
          ),
        ),
      );
    }
  }
}
