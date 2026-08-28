import 'package:flutter/material.dart';
import 'package:vtm_helper/theme/sheet_theme.dart';

class SheetThemeEditorScreen extends StatefulWidget {
  final SheetTheme initial;
  final bool isNew;

  const SheetThemeEditorScreen({
    super.key,
    required this.initial,
    this.isNew = true,
  });

  @override
  State<SheetThemeEditorScreen> createState() => _SheetThemeEditorScreenState();
}

class _SheetThemeEditorScreenState extends State<SheetThemeEditorScreen> {
  late TextEditingController _name;
  late SheetTheme _theme;

  static const _fields = <String, String>{
    'background': 'Фон листа',
    'border': 'Рамка',
    'ink': 'Текст / иконки',
    'muted': 'Приглушённый текст',
    'accent': 'Акцент (разделители, XP)',
    'filled': 'Закрашенные точки',
    'emptyBorder': 'Контур пустых точек',
    'danger': 'Урон / удаление',
    'overLimit': 'Кровь сверх лимита',
  };

  @override
  void initState() {
    super.initState();
    _theme = widget.initial;
    _name = TextEditingController(text: widget.initial.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Color _colorOf(String key) {
    switch (key) {
      case 'background':
        return _theme.background;
      case 'border':
        return _theme.border;
      case 'ink':
        return _theme.ink;
      case 'muted':
        return _theme.muted;
      case 'accent':
        return _theme.accent;
      case 'filled':
        return _theme.filled;
      case 'emptyBorder':
        return _theme.emptyBorder;
      case 'danger':
        return _theme.danger;
      case 'overLimit':
        return _theme.overLimit;
      default:
        return Colors.black;
    }
  }

  void _setColor(String key, Color color) {
    setState(() {
      switch (key) {
        case 'background':
          _theme = _theme.copyWith(background: color);
          break;
        case 'border':
          _theme = _theme.copyWith(border: color);
          break;
        case 'ink':
          _theme = _theme.copyWith(ink: color);
          break;
        case 'muted':
          _theme = _theme.copyWith(muted: color);
          break;
        case 'accent':
          _theme = _theme.copyWith(accent: color);
          break;
        case 'filled':
          _theme = _theme.copyWith(filled: color);
          break;
        case 'emptyBorder':
          _theme = _theme.copyWith(emptyBorder: color);
          break;
        case 'danger':
          _theme = _theme.copyWith(danger: color);
          break;
        case 'overLimit':
          _theme = _theme.copyWith(overLimit: color);
          break;
      }
    });
  }

  Future<void> _pickColor(String key) async {
    var draft = _colorOf(key);
    final hex = TextEditingController(text: SheetTheme.colorToHex(draft));

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: Text(_fields[key] ?? key),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: draft,
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hex,
                      decoration: const InputDecoration(
                        labelText: 'HEX',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        setD(() {
                          draft = SheetTheme.colorFromHex(v, draft);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _slider('R', draft.red, (v) {
                      setD(() {
                        draft = draft.withRed(v);
                        hex.text = SheetTheme.colorToHex(draft);
                      });
                    }),
                    _slider('G', draft.green, (v) {
                      setD(() {
                        draft = draft.withGreen(v);
                        hex.text = SheetTheme.colorToHex(draft);
                      });
                    }),
                    _slider('B', draft.blue, (v) {
                      setD(() {
                        draft = draft.withBlue(v);
                        hex.text = SheetTheme.colorToHex(draft);
                      });
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, draft),
                  child: const Text('ОК'),
                ),
              ],
            );
          },
        );
      },
    );

    hex.dispose();
    if (result != null) _setColor(key, result);
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value.toDouble(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 36, child: Text('$value')),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim().isEmpty ? 'Своя тема' : _name.text.trim();
    Navigator.pop(context, _theme.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Новая тема' : 'Редактировать тему'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _theme.background,
              border: Border.all(color: _theme.border, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Превью',
                  style: TextStyle(
                    color: _theme.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text('Приглушённый текст', style: TextStyle(color: _theme.muted)),
                Divider(color: _theme.accent, thickness: 2),
                Row(
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < 3 ? Icons.circle : Icons.circle_outlined,
                        color: i < 3 ? _theme.filled : _theme.emptyBorder,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Урон', style: TextStyle(color: _theme.danger)),
                Text('Сверх лимита', style: TextStyle(color: _theme.overLimit)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._fields.entries.map((e) {
            final c = _colorOf(e.key);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value),
              subtitle: Text(SheetTheme.colorToHex(c)),
              trailing: GestureDetector(
                onTap: () => _pickColor(e.key),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              onTap: () => _pickColor(e.key),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Сохранить тему'),
          ),
        ],
      ),
    );
  }
}
