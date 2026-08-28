import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';

class NotesSection extends StatelessWidget {
  final String sharedNotes;
  final String privateNotes;
  final bool isStorytellerMode;
  final bool isEditing;
  final void Function(String shared, String private) onChanged;

  const NotesSection({
    super.key,
    required this.sharedNotes,
    required this.privateNotes,
    required this.isStorytellerMode,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SheetThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Заметки рассказчика',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Видит игрок',
          style: TextStyle(fontSize: 12, color: theme.muted),
        ),
        const SizedBox(height: 8),
        _box(
          context,
          theme,
          text: sharedNotes,
          hint: isEditing && isStorytellerMode
              ? 'Заметки для игрока…'
              : 'Пока пусто',
          enabled: isEditing && isStorytellerMode,
          onChanged: (v) => onChanged(v, privateNotes),
        ),
        if (isStorytellerMode) ...[
          const SizedBox(height: 20),
          Text(
            'Скрытые заметки мастера',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Только рассказчик',
            style: TextStyle(fontSize: 12, color: theme.muted),
          ),
          const SizedBox(height: 8),
          _box(
            context,
            theme,
            text: privateNotes,
            hint: isEditing ? 'Секретные пометки…' : 'Пока пусто',
            enabled: isEditing,
            onChanged: (v) => onChanged(sharedNotes, v),
          ),
        ],
      ],
    );
  }

  Widget _box(
    BuildContext context,
    SheetTheme theme, {
    required String text,
    required String hint,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.border.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: enabled
          ? TextFormField(
              initialValue: text,
              maxLines: 6,
              minLines: 3,
              style: TextStyle(color: theme.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: theme.muted),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            )
          : Text(
              text.trim().isEmpty ? hint : text,
              style: TextStyle(
                color: text.trim().isEmpty ? theme.muted : theme.ink,
                fontSize: 14,
                fontStyle:
                    text.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
    );
  }
}
