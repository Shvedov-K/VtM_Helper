import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';
import 'package:vtm_helper/services/storage_service.dart';
import 'package:vtm_helper/services/drive_sync_service.dart';
import 'package:vtm_helper/screens/character_sheet_screen.dart';
import 'package:vtm_helper/screens/chronicles_screen.dart';
import 'package:vtm_helper/screens/google_sync_screen.dart';
import 'package:vtm_helper/services/sync_payload.dart';

class CharacterListScreen extends StatefulWidget {
  const CharacterListScreen({super.key});

  @override
  State<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  final StorageService _storage = StorageService();
  List<Character> _characters = [];
  List<Chronicle> _chronicles = [];
  String? _filterChronicleId; // null = все
  bool _isLoading = true;
  bool _googleSignedIn = false;
  bool _driveReady = false;

  @override
  void initState() {
    super.initState();
    _reload();
    DriveSyncService.instance.warmUp().then((_) async {
      if (!mounted) return;
      await _reload();
      await _refreshGoogleState();
    });
  }

  Future<void> _refreshGoogleState() async {
    final signed = DriveSyncService.instance.isSignedIn;
    final drive =
        signed ? await DriveSyncService.instance.hasDriveToken() : false;
    if (!mounted) return;
    setState(() {
      _googleSignedIn = signed;
      _driveReady = drive;
    });
  }

  Future<void> _reload() async {
    final chars = await _storage.loadCharacters();
    final chrons = await _storage.loadChronicles();
    if (!mounted) return;
    setState(() {
      _characters = chars;
      _chronicles = chrons;
      _isLoading = false;
    });
  }

  Chronicle? _chronicleOf(Character c) {
    if (c.chronicleId == null) return null;
    for (final x in _chronicles) {
      if (x.id == c.chronicleId) return x;
    }
    return null;
  }

  Future<void> _createNewCharacter() async {
    final newChar = Character(
      id: const Uuid().v4(),
      name: 'Новый персонаж',
      chronicleId: _filterChronicleId,
    );
    await _storage.addCharacter(newChar);
    await _reload();
    _openCharacter(newChar);
  }

  void _openCharacter(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CharacterSheetScreen(character: character),
      ),
    ).then((_) => _reload());
  }

  Future<void> _openChronicles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChroniclesScreen()),
    );
    await _reload();
  }

  Future<void> _assignChronicle(Character character) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Хроника персонажа',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Без хроники'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ..._chronicles.map(
                (c) => ListTile(
                  title: Text(c.name),
                  subtitle: Text(
                    c.role == ChronicleRole.storyteller
                        ? 'Вы — рассказчик'
                        : 'Вы — игрок',
                  ),
                  selected: character.chronicleId == c.id,
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
              ),
              if (_chronicles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Сначала создайте хронику'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen == null) return;
    final previous = _chronicleOf(character);
    character.chronicleId = chosen.isEmpty ? null : chosen;
    character.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _storage.updateCharacter(character);
    Chronicle? next;
    if (chosen.isNotEmpty) {
      for (final c in _chronicles) {
        if (c.id == chosen) {
          next = c;
          break;
        }
      }
    }
    try {
      await DriveSyncService.instance.relocateCharacter(
        character: character,
        from: previous,
        to: next,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Локально перенесено, Диск: $e')),
        );
      }
    }
    await _reload();
  }

  Future<void> _deleteCharacter(Character character) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить персонажа'),
        content: Text('Вы уверены, что хотите удалить "${character.name}"?'),
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
    if (confirm == true) {
      await _storage.deleteCharacter(character.id);
      await _reload();
    }
  }

  List<Character> get _visible {
    if (_filterChronicleId == null) return _characters;
    return _characters
        .where((c) => c.chronicleId == _filterChronicleId)
        .toList();
  }

  Future<void> _exportCharacter(Character character) async {
    final json = SyncPayload.wrapCharacter(
      character,
      includePrivateNotes:
          _chronicleOf(character)?.role == ChronicleRole.storyteller,
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Экспорт персонажа'),
        content: SingleChildScrollView(
          child: SelectableText(json),
        ),
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
      const SnackBar(content: Text('JSON скопирован в буфер')),
    );
  }

  Future<void> _importFromClipboardOrText() async {
    final controller = TextEditingController();
    try {
      final clip = await Clipboard.getData('text/plain');
      if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
        controller.text = clip.text!;
      }
      if (!mounted) return;
      final raw = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Импорт JSON'),
          content: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Вставьте JSON персонажа или хроники',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Импорт'),
            ),
          ],
        ),
      );
      if (raw == null || raw.trim().isEmpty) return;
      final parsed = SyncPayload.parse(raw);
      if (parsed.isCharacter) {
        await _importOneCharacter(parsed.character!);
      } else if (parsed.isChronicle) {
        await _importChronicleBundle(parsed.chronicle!, parsed.characters);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось импортировать: $e')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _importOneCharacter(Character incoming) async {
    final existing = _characters.where((c) => c.id == incoming.id).toList();
    if (existing.isEmpty) {
      await _storage.addCharacter(incoming);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортирован «${incoming.name}»')),
      );
      return;
    }
    final local = existing.first;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Персонаж «${incoming.name}» уже есть'),
        content: Text(
          'Локально обновлён: ${_fmt(local.updatedAt)}\n'
          'В файле: ${_fmt(incoming.updatedAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('Оставить локального'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'copy'),
            child: const Text('Как нового'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
    if (choice == 'replace') {
      await _storage.updateCharacter(incoming);
    } else if (choice == 'copy') {
      incoming.id = DateTime.now().millisecondsSinceEpoch.toString();
      incoming.name = '${incoming.name} (копия)';
      await _storage.addCharacter(incoming);
    }
    await _reload();
  }

  Future<void> _importChronicleBundle(
    Chronicle chronicle,
    List<Character> characters,
  ) async {
    final conflicts = characters
        .where((ch) => _characters.any((c) => c.id == ch.id))
        .toList();
    var replaceAll = true;
    if (conflicts.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Хроника «${chronicle.name}»'),
          content: Text(
            'Уже есть ${conflicts.length} из ${characters.length} персонажей. '
            'Замена сотрёт локальные здоровье, кровь и заметки.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: const Text('Оставить локальных'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'ask'),
              child: const Text('По одному'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Заменить всех'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'ask') {
        for (final ch in characters) {
          ch.chronicleId = chronicle.id;
          await _importOneCharacter(ch);
        }
        final list = await _storage.loadChronicles();
        final idx = list.indexWhere((c) => c.id == chronicle.id);
        if (idx == -1) {
          list.add(chronicle);
        } else {
          list[idx] = chronicle;
        }
        await _storage.saveChronicles(list);
        await _reload();
        return;
      }
      replaceAll = choice == 'replace';
    }

    final list = await _storage.loadChronicles();
    final idx = list.indexWhere((c) => c.id == chronicle.id);
    if (idx == -1) {
      list.add(chronicle);
    } else {
      list[idx] = chronicle;
    }
    await _storage.saveChronicles(list);
    for (final ch in characters) {
      ch.chronicleId = chronicle.id;
      final exists = _characters.any((c) => c.id == ch.id);
      if (exists) {
        if (replaceAll) await _storage.updateCharacter(ch);
      } else {
        await _storage.addCharacter(ch);
      }
    }
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Импортирована хроника «${chronicle.name}» (${characters.length} перс.)',
        ),
      ),
    );
  }

  String _fmt(int ms) {
    if (ms <= 0) return 'нет даты';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VTM Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Импорт JSON',
            onPressed: _importFromClipboardOrText,
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Присоединиться к хронике',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleSyncScreen()),
              );
              await _reload();
              await _refreshGoogleState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Хроники',
            onPressed: _openChronicles,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewCharacter,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_googleSignedIn && !_driveReady)
                  Material(
                    color: Colors.orange.shade800,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: const Text('Google вошёл, Диск ещё не подключен'),
                      subtitle: const Text(
                        'Открой облако и нажми «Синхронизировать Диск»',
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GoogleSyncScreen(),
                          ),
                        );
                        await _reload();
                        await _refreshGoogleState();
                      },
                    ),
                  ),
                if (_chronicles.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: const Text('Все'),
                            selected: _filterChronicleId == null,
                            onSelected: (_) =>
                                setState(() => _filterChronicleId = null),
                          ),
                        ),
                        ..._chronicles.map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: _filterChronicleId == c.id,
                              onSelected: (_) =>
                                  setState(() => _filterChronicleId = c.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _visible.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _characters.isEmpty
                                    ? 'У вас пока нет персонажей'
                                    : 'В этой хронике пока нет персонажей',
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _createNewCharacter,
                                icon: const Icon(Icons.add),
                                label: const Text('Создать'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _visible.length,
                          itemBuilder: (ctx, index) {
                            final character = _visible[index];
                            final chron = _chronicleOf(character);
                            final bits = <String>[
                              if (character.clan.isNotEmpty) character.clan,
                              if (chron != null)
                                '${chron.name} · ${chron.role == ChronicleRole.storyteller ? 'ST' : 'игрок'}',
                            ];
                            return ListTile(
                              title: Text(character.name),
                              subtitle:
                                  bits.isEmpty ? null : Text(bits.join(' · ')),
                              onTap: () => _openCharacter(character),
                              onLongPress: () => _assignChronicle(character),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'export') {
                                    _exportCharacter(character);
                                  } else if (v == 'chronicle') {
                                    _assignChronicle(character);
                                  } else if (v == 'delete') {
                                    _deleteCharacter(character);
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(
                                    value: 'export',
                                    child: Text('Экспорт JSON'),
                                  ),
                                  PopupMenuItem(
                                    value: 'chronicle',
                                    child: Text('Хроника'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
