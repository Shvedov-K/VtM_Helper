import 'package:flutter/material.dart';

/// Тема оформления листа персонажа (не всего приложения).
class SheetTheme {
  final String id;
  final String name;
  final Color background;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color filled;
  final Color emptyBorder;
  final Color danger;
  final Color overLimit;

  const SheetTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.filled,
    required this.emptyBorder,
    required this.danger,
    required this.overLimit,
  });

  static const String defaultId = 'caitiff';

  /// 7 кланов Камарильи + Каитиф (классика).
  static const List<SheetTheme> presets = [
    caitiff,
    brujah,
    ventrue,
    toreador,
    tremere,
    nosferatu,
    gangrel,
    malkavian,
  ];

  static SheetTheme byId(String? id, {List<SheetTheme> custom = const []}) {
    for (final t in presets) {
      if (t.id == id) return t;
    }
    for (final t in custom) {
      if (t.id == id) return t;
    }
    return caitiff;
  }

  static bool isPreset(String id) => presets.any((t) => t.id == id);

  SheetTheme copyWith({
    String? id,
    String? name,
    Color? background,
    Color? border,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? filled,
    Color? emptyBorder,
    Color? danger,
    Color? overLimit,
  }) {
    return SheetTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      background: background ?? this.background,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      filled: filled ?? this.filled,
      emptyBorder: emptyBorder ?? this.emptyBorder,
      danger: danger ?? this.danger,
      overLimit: overLimit ?? this.overLimit,
    );
  }

  static String colorToHex(Color c) {
    final v = c.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${v.substring(2)}';
  }

  static Color colorFromHex(String raw, Color fallback) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return fallback;
    final n = int.tryParse(s, radix: 16);
    if (n == null) return fallback;
    return Color(n);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'background': colorToHex(background),
        'border': colorToHex(border),
        'ink': colorToHex(ink),
        'muted': colorToHex(muted),
        'accent': colorToHex(accent),
        'filled': colorToHex(filled),
        'emptyBorder': colorToHex(emptyBorder),
        'danger': colorToHex(danger),
        'overLimit': colorToHex(overLimit),
      };

  factory SheetTheme.fromJson(Map<String, dynamic> json) {
    Color c(String key, Color fb) =>
        colorFromHex(json[key]?.toString() ?? '', fb);
    return SheetTheme(
      id: json['id']?.toString() ?? 'custom',
      name: json['name']?.toString() ?? 'Своя тема',
      background: c('background', const Color(0xFFE8E8E8)),
      border: c('border', const Color(0xFF000000)),
      ink: c('ink', const Color(0xFF000000)),
      muted: c('muted', const Color(0xFF666666)),
      accent: c('accent', const Color(0xFF7E57C2)),
      filled: c('filled', const Color(0xFF000000)),
      emptyBorder: c('emptyBorder', const Color(0xFF000000)),
      danger: c('danger', const Color(0xFFC62828)),
      overLimit: c('overLimit', const Color(0xFFE65100)),
    );
  }

  // --- Пресеты ---

  /// Каитиф / классический бумажный бланк
  static const caitiff = SheetTheme(
    id: 'caitiff',
    name: 'Каитиф',
    background: Color(0xFFE8E8E8),
    border: Color(0xFF000000),
    ink: Color(0xFF000000),
    muted: Color(0xFF666666),
    accent: Color(0xFF7E57C2),
    filled: Color(0xFF000000),
    emptyBorder: Color(0xFF000000),
    danger: Color(0xFFC62828),
    overLimit: Color(0xFFE65100),
  );

  /// Бруха — алый и уголь
  static const brujah = SheetTheme(
    id: 'brujah',
    name: 'Бруха',
    background: Color(0xFF2A2224),
    border: Color(0xFFB71C1C),
    ink: Color(0xFFF5E6E6),
    muted: Color(0xFFB0A0A0),
    accent: Color(0xFFE53935),
    filled: Color(0xFFE53935),
    emptyBorder: Color(0xFFC4A0A0),
    danger: Color(0xFFFF5252),
    overLimit: Color(0xFFFF8A65),
  );

  /// Вентру — холодный синий и золото
  static const ventrue = SheetTheme(
    id: 'ventrue',
    name: 'Вентру',
    background: Color(0xFFE8EEF4),
    border: Color(0xFF1A237E),
    ink: Color(0xFF0D1B2A),
    muted: Color(0xFF5C6B7A),
    accent: Color(0xFFC9A227),
    filled: Color(0xFF1A237E),
    emptyBorder: Color(0xFF1A237E),
    danger: Color(0xFFB71C1C),
    overLimit: Color(0xFFEF6C00),
  );

  /// Тореадор — крем и роза
  static const toreador = SheetTheme(
    id: 'toreador',
    name: 'Тореадор',
    background: Color(0xFFF7EDE4),
    border: Color(0xFF6D2E4B),
    ink: Color(0xFF3E1F2B),
    muted: Color(0xFF8D6B7A),
    accent: Color(0xFFC2185B),
    filled: Color(0xFFAD1457),
    emptyBorder: Color(0xFF6D2E4B),
    danger: Color(0xFFB71C1C),
    overLimit: Color(0xFFE65100),
  );

  /// Тремер — тёмный рубин
  static const tremere = SheetTheme(
    id: 'tremere',
    name: 'Тремер',
    background: Color(0xFF1C1218),
    border: Color(0xFF8B0000),
    ink: Color(0xFFF0E0E4),
    muted: Color(0xFFA89098),
    accent: Color(0xFFC62828),
    filled: Color(0xFFB71C1C),
    emptyBorder: Color(0xFFC4A0A8),
    danger: Color(0xFFFF5252),
    overLimit: Color(0xFFFF8A65),
  );

  /// Носферату — болото
  static const nosferatu = SheetTheme(
    id: 'nosferatu',
    name: 'Носферату',
    background: Color(0xFF2C3228),
    border: Color(0xFF4A5C3A),
    ink: Color(0xFFD4DCC8),
    muted: Color(0xFF9AA890),
    accent: Color(0xFF7CB342),
    filled: Color(0xFF558B2F),
    emptyBorder: Color(0xFFA8B898),
    danger: Color(0xFFEF5350),
    overLimit: Color(0xFFFFA726),
  );

  /// Гангрел — земля
  static const gangrel = SheetTheme(
    id: 'gangrel',
    name: 'Гангрел',
    background: Color(0xFFE6DFD0),
    border: Color(0xFF4E342E),
    ink: Color(0xFF2E1F14),
    muted: Color(0xFF7D6B58),
    accent: Color(0xFF6D4C41),
    filled: Color(0xFF5D4037),
    emptyBorder: Color(0xFF5D4037),
    danger: Color(0xFFBF360C),
    overLimit: Color(0xFFE65100),
  );

  /// Малкавиан — сирень
  static const malkavian = SheetTheme(
    id: 'malkavian',
    name: 'Малкавиан',
    background: Color(0xFFEDE7F6),
    border: Color(0xFF4A148C),
    ink: Color(0xFF1A0A2E),
    muted: Color(0xFF7E6B9A),
    accent: Color(0xFF7E57C2),
    filled: Color(0xFF6A1B9A),
    emptyBorder: Color(0xFF4A148C),
    danger: Color(0xFFC62828),
    overLimit: Color(0xFFEF6C00),
  );
}

/// InheritedWidget — доступ к теме листа из любой секции.
class SheetThemeScope extends InheritedWidget {
  final SheetTheme theme;

  const SheetThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  static SheetTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SheetThemeScope>();
    return scope?.theme ?? SheetTheme.caitiff;
  }

  @override
  bool updateShouldNotify(SheetThemeScope oldWidget) =>
      theme.id != oldWidget.theme.id ||
      theme.name != oldWidget.theme.name ||
      theme.background != oldWidget.theme.background ||
      theme.accent != oldWidget.theme.accent ||
      theme.ink != oldWidget.theme.ink;
}
