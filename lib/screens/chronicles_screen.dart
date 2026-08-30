import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:vtm_helper/models/chronicle.dart';
import 'package:vtm_helper/services/storage_service.dart';
import 'package:vtm_helper/services/sync_payload.dart';
import 'package:vtm_helper/screens/google_sync_screen.dart';

class ChroniclesScreen extends StatefulWidget {
  const ChroniclesScreen({super.key});

  @override
  State<ChroniclesScreen> createState() => _ChroniclesScreenState();
}

class _ChroniclesScreenState extends State<ChroniclesScreen> {
  final StorageService _storage = StorageService();
  List<Chronicle> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.loadChronicles();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _storage.saveChronicles(_items);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _edit({Chronicle? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final isPlayer = existing?.role == ChronicleRole.player;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(existing == null ? 'Новая хроника' : 'Хроника'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: existing == null || !isPlayer,
                  readOnly: isPlayer,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  existing == null
                      ? 'Вы будете рассказчиком этой хроники. '
                          'Игроки присоединяются по ссылке с Google Диска.'
                      : (isPlayer
                          ? 'Вы — игрок. Роль здесь не меняется.'
                          : 'Вы — рассказчик.'),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              if (!isPlayer)
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Сохранить'),
                ),
            ],
          );
        },
      );
      if (ok != true) return;
      final name = nameCtrl.text.trim().isEmpty
          ? 'Без названия'
          : nameCtrl.text.trim();
      if (!mounted) return;
      if (existing == null) {
        _items.add(
          Chronicle(
            id: const Uuid().v4(),
            name: name,
            role: ChronicleRole.storyteller,
          ),
        );
      } else if (existing.role == ChronicleRole.storyteller) {
        existing.name = name;
      }
      await _save();
    } finally {
      nameCtrl.dispose();
    }
  }

  Future<void> _export(Chronicle c) async {
    final chars = await _storage.loadCharacters();
    final mine = chars.where((ch) => ch.chronicleId == c.id).toList();
    final json = SyncPayload.wrapChronicle(
      c,
      mine,
      includePrivateNotes: c.role == ChronicleRole.storyteller,
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Экспорт «${c.name}»'),
        content: SingleChildScrollView(child: SelectableText(json)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Хроника и ${mine.length} персонаж(ей) в буфере')),
    );
  }

  Future<void> _delete(Chronicle c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить хронику'),
        content: Text(
          'Удалить «${c.name}»? Персонажи останутся, привязка снимется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final chars = await _storage.loadCharacters();
    var changed = false;
    for (final ch in chars) {
      if (ch.chronicleId == c.id) {
        ch.chronicleId = null;
        changed = true;
      }
    }
    if (changed) await _storage.saveCharacters(chars);

    _items.removeWhere((e) => e.id == c.id);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Хроники'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_outlined),
            tooltip: 'Google Диск',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleSyncScreen()),
              );
              await _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Новая хроника',
            onPressed: () => _edit(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Пока нет хроник'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Создать хронику'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final c = _items[i];
                    final isSt = c.role == ChronicleRole.storyteller;
                    return ListTile(
                      leading: Icon(
                        isSt ? Icons.menu_book : Icons.person_outline,
                      ),
                      title: Text(c.name),
                      subtitle: Text(isSt ? 'Рассказчик' : 'Игрок'),
                      onTap: () => _edit(existing: c),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.ios_share),
                            tooltip: 'Экспорт',
                            onPressed: () => _export(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _delete(c),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
