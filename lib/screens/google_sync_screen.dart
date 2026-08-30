import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';
import 'package:vtm_helper/services/drive_sync_service.dart';
import 'package:vtm_helper/services/google_config.dart';
import 'package:vtm_helper/services/storage_service.dart';


class GoogleSyncScreen extends StatefulWidget {
  final Chronicle? focus;

  const GoogleSyncScreen({super.key, this.focus});

  @override
  State<GoogleSyncScreen> createState() => _GoogleSyncScreenState();
}

class _GoogleSyncScreenState extends State<GoogleSyncScreen> {
  final _drive = DriveSyncService.instance;
  final _storage = StorageService();
  bool _busy = false;
  String? _status;
  List<Chronicle> _chronicles = [];
  StreamSubscription? _userSub;

  @override
  void initState() {
    super.initState();
    _reload();
    _userSub = _drive.onUserChanged.listen((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loginAndRestore();
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _loginAndRestore() async {
    if (!mounted) return;
    try {
      final acc = await _drive.trySilentSignIn();
      if (!mounted) return;
      setState(() {});
      if (acc == null) return;
      await _run(() => _applyRestore());
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _applyRestore({bool force = false}) async {
    final result = await _drive.restoreOnSignIn(
      force: force,
      interactive: force,
    );
    await _reload();
    if (!mounted) return;
    if (result == null) {
      return;
    }
    if (result.needsConsent) {
      _status =
          'Аккаунт Google есть, но нет токена Drive. '
          'Нажми «Синхронизировать Диск» и разреши доступ к Диску.';
    } else if (result.isEmpty) {
      final extra =
          result.detail == null || result.detail!.isEmpty ? '' : ' (${result.detail})';
      _status =
          'На Диске не нашлись хроники этого аккаунта$extra. '
          'Проверь, что вход выполнен тем же Google-аккаунтом, которым заливали лист.';
    } else {
      _status =
          'Синхронизировано: хроник ${result.chroniclesFound} '
          '(новых ${result.chroniclesAdded}), '
          'листов +${result.addedCharacters}, '
          'обновлено ${result.updatedCharacters}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_status!)),
    );
  }

  Future<void> _reload() async {
    final list = await _storage.loadChronicles();
    if (!mounted) return;
    setState(() => _chronicles = list);
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await job();
    } catch (e) {
      var s = e.toString();
      if (s.startsWith('Bad state: ')) s = s.substring('Bad state: '.length);
      if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
      _status = s;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signed = _drive.isSignedIn;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Диск'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Лог синка',
            onPressed: _showLog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kGoogleServerClientId.isEmpty)
            Card(
              color: Colors.orange.shade900,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Скопируй dart_defines.json.example в dart_defines.json '
                  'и запускай с --dart-define-from-file=dart_defines.json. '
                  'Без GOOGLE_SERVER_CLIENT_ID вход в Google не заработает.',
                ),
              ),
            ),
          if (!DriveSyncService.isGoogleSignInSupported)
            Card(
              color: Colors.blueGrey.shade800,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'На Windows-приложении входа в Google нет. '
                  'Используй Android APK или веб: '
                  'flutter run -d chrome --dart-define-from-file=dart_defines.json',
                ),
              ),
            ),
          ListTile(
            leading: Icon(signed ? Icons.cloud_done : Icons.cloud_off),
            title: Text(signed ? 'Вход выполнен' : 'Не выполнен вход'),
            subtitle: Text(signed ? (_drive.email ?? '') : 'Нужен аккаунт Google'),
          ),
          if (!signed)
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        _status = 'Открывается окно Google…';
                        if (mounted) setState(() {});
                        final ok = await _drive.signIn();
                        if (!ok) {
                          throw DriveException('Вход отменён');
                        }
                        await _applyRestore(force: true);
                      }),
              icon: const Icon(Icons.login),
              label: const Text('Войти в Google'),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final ok = await _drive.ensureDriveAccess(
                          interactive: true,
                        );
                        if (!ok) {
                          throw DriveException(
                            'Не удалось получить доступ к Диску. '
                            'Должно открыться окно Google — разреши Drive. '
                            'Если окна не было, разреши всплывающие для этого сайта и нажми ещё раз.',
                          );
                        }
                        await _applyRestore(force: true);
                      }),
              icon: const Icon(Icons.sync),
              label: const Text('Синхронизировать Диск'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await _drive.signOut();
                        if (mounted) setState(() {});
                      }),
              icon: const Icon(Icons.logout),
              label: const Text('Выйти'),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _joinByLink,
            icon: const Icon(Icons.link),
            label: const Text('Присоединиться по ссылке'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Хроники',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_chronicles.isEmpty)
            const Text('Создайте хронику как рассказчик или присоединитесь по ссылке.'),
          ..._chronicles.map(_chronicleTile),
          if (_busy) const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      _status!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Копировать',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _status!));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Сообщение скопировано')),
                      );
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'Как это работает: рассказчик создаёт папку хроники на Диске '
            'и получает ссылку. Ссылка — секрет: кто её знает, может читать '
            'хронику и писать в папку игроков. Не выкладывайте её публично. '
            'Игрок вставляет ссылку и забирает/отправляет листы кнопками. '
            'После входа в Google приложение само ищет хроники этого аккаунта '
            'на Диске и подтягивает листы (и у рассказчика, и у игрока). '
            'Скрытые заметки мастера на Диск не уходят.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }


  Widget _chronicleTile(Chronicle c) {
    final hasFolder = c.driveFolderId != null && c.driveFolderId!.isNotEmpty;
    final link = c.inviteLink;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              c.role == ChronicleRole.storyteller
                  ? 'Вы — рассказчик'
                  : 'Вы — игрок${c.playerDisplayName == null ? '' : ' (${c.playerDisplayName})'}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.role == ChronicleRole.storyteller && !hasFolder)
                  ElevatedButton(
                    onPressed: _busy ? null : () => _createInvite(c),
                    child: const Text('Создать приглашение'),
                  ),
                if (hasFolder && link != null && link.isNotEmpty)
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ссылка скопирована')),
                      );
                    },
                    child: const Text('Копировать ссылку'),
                  ),
                if (hasFolder) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _upload(c),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Отправить'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _download(c),
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('Скачать'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInvite(Chronicle c) async {
    await _run(() async {
      final created = await _drive.createSharedChronicleFolder(c.name);
      c.driveFolderId = created.folderId;
      c.inviteLink = created.inviteLink;
      c.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _persist(c);
      await _drive.uploadChronicle(chronicle: c, characters: const []);
      if (mounted) {
        setState(() => _status = 'Ссылка готова — отправьте игрокам');
      }
    });
  }

  Future<void> _joinByLink() async {
    if (!_drive.isSignedIn) {
      final ok = await _drive.signIn();
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    final linkCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Присоединиться к хронике'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Пригласительная ссылка',
                  hintText: 'https://drive.google.com/drive/folders/...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ваше имя в хронике',
                  hintText: 'Как подписать папку игрока',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Войти')),
          ],
        ),
      );
      if (ok != true) return;
      final raw = linkCtrl.text.trim();
      final playerName = nameCtrl.text.trim();
      if (raw.isEmpty || playerName.isEmpty) {
        if (mounted) setState(() => _status = 'Нужны и ссылка, и имя');
        return;
      }
      await _run(() async {
        final folderId = _parseFolderId(raw);
        final invite = raw.contains('http')
            ? raw
            : 'https://drive.google.com/drive/folders/$folderId';
        final remoteName = await _drive.readChronicleName(folderId);
        final joined = await _drive.joinChronicle(
          rootFolderId: folderId,
          playerName: playerName,
          chronicleName: remoteName,
          inviteLink: invite,
        );
        final all = await _storage.loadChronicles();
        final existing = all.where((c) => c.driveFolderId == folderId).toList();
        if (existing.isNotEmpty) {
          final c = existing.first;
          if (c.role == ChronicleRole.player) {
            c.playerDisplayName = playerName;
            c.playerFolderId = joined.playerFolderId;
          }
          c.inviteLink = invite;
          if (remoteName != null && remoteName.isNotEmpty) {
            c.name = remoteName;
          }
          c.updatedAt = DateTime.now().millisecondsSinceEpoch;
        } else {
          all.add(
            Chronicle(
              id: const Uuid().v4(),
              name: remoteName ?? 'Хроника',
              role: ChronicleRole.player,
              driveFolderId: folderId,
              inviteLink: invite,
              playerDisplayName: playerName,
              playerFolderId: joined.playerFolderId,
            ),
          );
        }
        await _storage.saveChronicles(all);
        await _reload();
        if (mounted) setState(() => _status = 'Вы в хронике как $playerName');
      });
    } finally {
      linkCtrl.dispose();
      nameCtrl.dispose();
    }
  }

  String _parseFolderId(String raw) {
    final m = RegExp(r'/folders/([a-zA-Z0-9_-]+)').firstMatch(raw);
    if (m != null) return m.group(1)!;
    final m2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(raw);
    if (m2 != null) return m2.group(1)!;
    return raw.trim();
  }

  Future<void> _persist(Chronicle c) async {
    final all = await _storage.loadChronicles();
    final i = all.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      all[i] = c;
    } else {
      all.add(c);
    }
    await _storage.saveChronicles(all);
    await _reload();
  }

  Future<void> _upload(Chronicle c) async {
    await _run(() async {
      final chars = await _storage.loadCharacters();
      final mine = chars.where((ch) => ch.chronicleId == c.id).toList();
      await _drive.uploadChronicle(chronicle: c, characters: mine);
      await _storage.addSyncLog(
        action: 'Отправка',
        characterName: c.name,
        detail: '${mine.length} персонаж(ей)',
      );
      if (mounted) {
        setState(() => _status = 'Отправлено: ${mine.length} персонаж(ей)');
      }
    });
  }

  Future<void> _download(Chronicle c) async {
    await _run(() async {
      final folderId = c.driveFolderId;
      if (folderId != null && folderId.isNotEmpty) {
        final remoteName = await _drive.readChronicleName(folderId);
        if (remoteName != null &&
            remoteName.isNotEmpty &&
            remoteName != c.name) {
          c.name = remoteName;
          await _persist(c);
        }
      }
      final incoming = await _drive.downloadCharacters(c);
      final local = await _storage.loadCharacters();
      var added = 0;
      var updated = 0;
      var skipped = 0;
      for (final ch in incoming) {
        ch.chronicleId = c.id;
        if (c.role != ChronicleRole.storyteller) {
          ch.storytellerPrivateNotes = '';
        }
        final idx = local.indexWhere((x) => x.id == ch.id);
        if (idx == -1) {
          await _storage.addCharacter(ch);
          added++;
        } else {
          final localChar = local[idx];
          if (c.role == ChronicleRole.storyteller &&
              ch.storytellerPrivateNotes.isEmpty &&
              localChar.storytellerPrivateNotes.isNotEmpty) {
            ch.storytellerPrivateNotes = localChar.storytellerPrivateNotes;
          }
          if (ch.updatedAt == localChar.updatedAt) {
            skipped++;
            continue;
          }
          final apply = await _confirmOverwrite(localChar, ch);
          if (apply == true) {
            await _storage.updateCharacter(ch);
            updated++;
            await _storage.addSyncLog(
              action: 'Скачивание (перезапись)',
              characterName: ch.name,
              detail: '${_stamp(localChar.updatedAt)} → ${_stamp(ch.updatedAt)}',
            );
          } else {
            skipped++;
          }
        }
      }
      await _storage.addSyncLog(
        action: 'Скачивание',
        characterName: c.name,
        detail: '+$added, перезаписано $updated, пропущено $skipped',
      );
      await _reload();
      if (!mounted) return;
      setState(() {
        if (incoming.isEmpty) {
          _status =
              'На Диске нет файлов персонажей. Игрок должен привязать лист к хронике и нажать «Отправить». Если файлы уже есть — выйди из Google и войди снова (нужен новый доступ Drive).';
        } else {
          _status = 'Скачано: +$added, обновлено $updated (файлов ${incoming.length})';
        }
      });
    });
  }

  String _stamp(int ms) {
    if (ms <= 0) return 'нет даты';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<bool> _confirmOverwrite(Character local, Character remote) async {
    final newer = remote.updatedAt > local.updatedAt
        ? 'На Диске новее'
        : (remote.updatedAt < local.updatedAt
            ? 'Локальная копия новее'
            : 'Даты совпадают');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Перезаписать «${local.name}»?'),
        content: Text(
          '$newer\nЛокально: ${_stamp(local.updatedAt)}\nНа Диске: ${_stamp(remote.updatedAt)}\n\nСкачивание заменит локальный лист версией с Диска.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Оставить локальный'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Скачать с Диска'),
          ),
        ],
      ),
    );
    return go == true;
  }

  Future<void> _showLog() async {
    final log = await _storage.loadSyncLog();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Лог синхронизации',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: log.isEmpty
                      ? const Center(child: Text('Пока пусто'))
                      : ListView.builder(
                          itemCount: log.length,
                          itemBuilder: (ctx, i) {
                            final e = log[i];
                            final at = DateTime.fromMillisecondsSinceEpoch(e['at'] ?? 0);
                            String two(int n) => n.toString().padLeft(2, '0');
                            final stamp =
                                '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
                            return ListTile(
                              dense: true,
                              title: Text('${e['action']} — ${e['characterName']}'),
                              subtitle: Text('$stamp  ${e['detail'] ?? ''}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
