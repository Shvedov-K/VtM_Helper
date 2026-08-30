import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:uuid/uuid.dart';
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';
import 'package:vtm_helper/services/google_auth_client.dart';
import 'package:vtm_helper/services/google_config.dart';
import 'package:vtm_helper/services/storage_service.dart';
import 'package:vtm_helper/services/sync_payload.dart';
import 'package:vtm_helper/services/web_google_oauth.dart';

class DriveSyncService {
  DriveSyncService._();
  static final DriveSyncService instance = DriveSyncService._();

  static bool get isGoogleSignInSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  static const List<String> _driveScopes = <String>[
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _driveScopes,
    clientId: kIsWeb && kGoogleServerClientId.isNotEmpty
        ? kGoogleServerClientId
        : null,
    serverClientId: kIsWeb || kGoogleServerClientId.isEmpty
        ? null
        : kGoogleServerClientId,
  );

  bool _restoredThisSession = false;
  Future<DriveRestoreResult?>? _restoreInFlight;
  String? _webAccessToken;
  String? _webEmail;
  final StreamController<void> _webAuthChanges = StreamController<void>.broadcast();

  GoogleSignInAccount? get account => _googleSignIn.currentUser;
  bool get isSignedIn =>
      kIsWeb ? _webAccessToken != null : account != null;
  String? get email => kIsWeb ? _webEmail : account?.email;
  Stream<void> get onUserChanged => kIsWeb
      ? _webAuthChanges.stream
      : _googleSignIn.onCurrentUserChanged.map((_) {});

  Future<GoogleSignInAccount?> trySilentSignIn() async {
    if (!isGoogleSignInSupported || kGoogleServerClientId.isEmpty) return null;
    // GIS One Tap on web often hangs ~1 min with `unknown_reason`.
    if (kIsWeb) {
      final restored = webGoogleRestoreSession();
      if (restored != null) {
        _webAccessToken = restored.accessToken;
        _webEmail = restored.email;
        return null;
      }
      return null;
    }
    try {
      return await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void>? _warmUpInFlight;

  Future<void> warmUp() {
    return _warmUpInFlight ??= _warmUpBody();
  }

  Future<void> _warmUpBody() async {
    try {
      if (kIsWeb) await webGoogleEnsureSdk();
      await trySilentSignIn();
      if (!isSignedIn) return;
      final ok = await ensureDriveAccess(interactive: false);
      if (ok) await restoreOnSignIn(interactive: false);
    } catch (_) {}
  }

  Future<bool> signIn() async {
    if (kIsWeb) {
      try {
        final session = await webGoogleSignIn();
        if (session == null) return false;
        _webAccessToken = session.accessToken;
        _webEmail = session.email;
        _webAuthChanges.add(null);
        return true;
      } on StateError catch (e) {
        throw DriveException(e.message);
      }
    }
    if (!isGoogleSignInSupported) {
      throw UnsupportedError(
        'На Windows/Linux/macOS вход Google в этом приложении не поддерживается. '
        'Собери веб-версию: flutter run -d chrome  (или выложи Flutter Web).',
      );
    }
    if (kGoogleServerClientId.isEmpty) {
      throw StateError(
        'Не задан GOOGLE_SERVER_CLIENT_ID. '
            'Скопируй dart_defines.json.example в dart_defines.json '
            'и запускай с --dart-define-from-file=dart_defines.json',
      );
    }
    try {
      final user = await _googleSignIn.signIn();
      return user != null;
    } on MissingPluginException {
      throw UnsupportedError(
        'Плагин Google Sign-In не собран для этой платформы. '
        'Нужен полный перезапуск на Android или Flutter Web.',
      );
    } on PlatformException catch (e) {
      throw DriveException(_describeGoogleSignInError(e));
    }
  }

  Future<void> signOut() async {
    if (!isGoogleSignInSupported) return;
    _restoredThisSession = false;
    _restoreInFlight = null;
    if (kIsWeb) {
      _webAccessToken = null;
      _webEmail = null;
      webGoogleClearSession();
      _webAuthChanges.add(null);
      return;
    }
    await _googleSignIn.signOut();
  }

  Future<DriveRestoreResult?> restoreOnSignIn({
    bool force = false,
    bool interactive = false,
  }) {
    if (_restoredThisSession && !force) return Future.value(null);
    if (force) {
      _restoredThisSession = false;
      _restoreInFlight = null;
    }
    return _restoreInFlight ??= _restoreOnSignInBody(
      interactive: interactive,
    ).whenComplete(() {
      _restoreInFlight = null;
    });
  }

  Future<bool> hasDriveToken() => _hasDriveToken();

  Future<bool> _hasDriveToken() async {
    if (kIsWeb) {
      if (_webAccessToken != null) return true;
      final restored = webGoogleRestoreSession();
      if (restored == null) return false;
      _webAccessToken = restored.accessToken;
      _webEmail = restored.email;
      return true;
    }
    final user = _googleSignIn.currentUser;
    if (user == null) return false;
    try {
      final headers = await user.authHeaders;
      final auth = headers['Authorization'] ?? headers['authorization'];
      if (auth != null && auth.startsWith('Bearer ') && auth.length > 20) {
        return true;
      }
      final token = (await user.authentication).accessToken;
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureDriveAccess({required bool interactive}) async {
    if (await _hasDriveToken()) return true;
    if (!interactive) return false;
    if (kIsWeb) return await signIn();
    try {
      await _googleSignIn.requestScopes(_driveScopes);
    } catch (_) {}
    return await _hasDriveToken();
  }

  Future<drive.DriveApi> _api({bool interactive = true}) async {
    if (kIsWeb) {
      if (!await _hasDriveToken()) {
        if (interactive) {
          final ok = await signIn();
          if (!ok) {
            throw DriveException('Вход в Google отменён.');
          }
        } else {
          throw DriveException('Нет входа в Google.');
        }
      }
      return drive.DriveApi(
        GoogleAuthClient({'Authorization': 'Bearer $_webAccessToken'}),
      );
    }
    GoogleSignInAccount? user = _googleSignIn.currentUser;
    if (user == null) {
      if (interactive) {
        try {
          user = await _googleSignIn.signIn();
        } on PlatformException catch (e) {
          throw DriveException(_describeGoogleSignInError(e));
        }
      } else {
        user = await trySilentSignIn();
      }
    }
    if (user == null) {
      throw DriveException(
        interactive
            ? 'Нет входа в Google. Нажми «Войти в Google».'
            : 'Нет входа в Google.',
      );
    }
    final granted = await ensureDriveAccess(interactive: interactive);
    if (!granted) {
      throw DriveException(
        interactive
            ? 'Нет доступа к Диску. Нажми «Синхронизировать Диск» и в окне Google разреши Drive (не только аккаунт).'
            : 'Нет доступа к Диску. Открой Google Диск и нажми «Синхронизировать Диск».',
      );
    }
    user = _googleSignIn.currentUser ?? user;
    final headers = await _authHeaders(user);
    return drive.DriveApi(GoogleAuthClient(headers));
  }

  Future<Map<String, String>> _authHeaders(GoogleSignInAccount user) async {
    final headers = Map<String, String>.from(await user.authHeaders);
    final authHeader = headers['Authorization'] ?? headers['authorization'];
    if (authHeader != null && authHeader.startsWith('Bearer ') && authHeader.length > 20) {
      return headers;
    }
    final token = (await user.authentication).accessToken;
    if (token == null || token.isEmpty) {
      throw DriveException(
        'Google не выдал токен Диска. Нажми «Синхронизировать Диск» и разреши доступ в окне Google.',
      );
    }
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }


  Future<CreatedChronicleFolder> createSharedChronicleFolder(String name) async {
    final api = await _api();
    final root = await _createFolder(
      api,
      name: 'VTM — $name',
      vtmTag: 'chronicleRoot',
    );
    final playersId = await _createFolder(api, name: 'players', parentId: root);
    await api.permissions.create(
      drive.Permission()
        ..type = 'anyone'
        ..role = 'reader'
        ..allowFileDiscovery = false,
      root,
    );
    await api.permissions.create(
      drive.Permission()
        ..type = 'anyone'
        ..role = 'writer'
        ..allowFileDiscovery = false,
      playersId,
    );
    final fresh = await api.files.get(root, $fields: 'id, webViewLink') as drive.File;
    final link = fresh.webViewLink ??
        'https://drive.google.com/drive/folders/$root';
    return CreatedChronicleFolder(folderId: root, inviteLink: link);
  }

  Future<String?> readChronicleName(String rootFolderId) async {
    try {
      final api = await _api();
      final fileId = await _findFileId(
        api,
        folderId: rootFolderId,
        fileName: 'chronicle.json',
      );
      if (fileId != null) {
        final parsed = await _readPayload(api, fileId);
        final fromJson = parsed.chronicle?.name.trim();
        if (fromJson != null && fromJson.isNotEmpty) return fromJson;
      }
      final folder = await api.files.get(
        rootFolderId,
        $fields: 'id, name',
        supportsAllDrives: true,
      ) as drive.File;
      return _nameFromFolderTitle(folder.name);
    } catch (_) {
      return null;
    }
  }

  static String? _nameFromFolderTitle(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (t.isEmpty) return null;
    const prefix = 'VTM — ';
    if (t.startsWith(prefix)) {
      t = t.substring(prefix.length).trim();
    }
    return t.isEmpty ? null : t;
  }

  Future<JoinedPlayerFolder> joinChronicle({
    required String rootFolderId,
    required String playerName,
    String? chronicleName,
    String? inviteLink,
  }) async {
    final api = await _api();
    final playersId = await _ensureFolder(api, parentId: rootFolderId, name: 'players');
    final mine = await _ensureFolder(
      api,
      parentId: playersId,
      name: playerName,
      vtmTag: 'playerFolder',
    );
    final name = (chronicleName ?? '').trim().isNotEmpty
        ? chronicleName!.trim()
        : (await readChronicleName(rootFolderId) ?? playerName);
    await _writePlayerManifest(
      api,
      playerFolderId: mine,
      info: PlayerChronicleInfo(
        chronicleName: name,
        rootFolderId: rootFolderId,
        inviteLink: inviteLink ??
            'https://drive.google.com/drive/folders/$rootFolderId',
        playerDisplayName: playerName,
        playerFolderId: mine,
      ),
    );
    return JoinedPlayerFolder(playersDirId: playersId, playerFolderId: mine);
  }

  Future<void> uploadChronicle({
    required Chronicle chronicle,
    required List<Character> characters,
  }) async {
    final rootId = chronicle.driveFolderId;
    if (rootId == null || rootId.isEmpty) {
      throw StateError('У хроники нет папки на Диске');
    }
    final api = await _api();
    await _upsert(
      api,
      folderId: rootId,
      fileName: 'chronicle.json',
      body: SyncPayload.wrapChronicle(chronicle, const []),
    );

    if (chronicle.role == ChronicleRole.player) {
      var folderId = chronicle.playerFolderId;
      if (folderId == null || folderId.isEmpty) {
        final name = chronicle.playerDisplayName ?? 'player';
        final joined = await joinChronicle(
          rootFolderId: rootId,
          playerName: name,
          chronicleName: chronicle.name,
          inviteLink: chronicle.inviteLink,
        );
        folderId = joined.playerFolderId;
      }
      await _writePlayerManifest(
        api,
        playerFolderId: folderId,
        info: PlayerChronicleInfo(
          chronicleName: chronicle.name,
          rootFolderId: rootId,
          inviteLink: chronicle.inviteLink,
          playerDisplayName: chronicle.playerDisplayName,
          playerFolderId: folderId,
        ),
      );
      for (final ch in characters) {
        ch.drivePlayerName = chronicle.playerDisplayName;
        await _upsert(
          api,
          folderId: folderId,
          fileName: 'character_${ch.id}.json',
          body: SyncPayload.wrapCharacter(ch),
          vtmTag: 'character',
        );
      }
      return;
    }

    // Рассказчик: раскладывает по подпапкам игроков
    final playersId = await _ensureFolder(api, parentId: rootId, name: 'players');
    for (final ch in characters) {
      final owner = (ch.drivePlayerName ?? '').trim().isEmpty
          ? 'storyteller'
          : ch.drivePlayerName!.trim();
      final dest = await _ensureFolder(api, parentId: playersId, name: owner);
      await _writePlayerManifest(
        api,
        playerFolderId: dest,
        info: PlayerChronicleInfo(
          chronicleName: chronicle.name,
          rootFolderId: rootId,
          inviteLink: chronicle.inviteLink,
          playerDisplayName: owner,
          playerFolderId: dest,
        ),
      );
      await _upsert(
        api,
        folderId: dest,
        fileName: 'character_${ch.id}.json',
        body: SyncPayload.wrapCharacter(ch),
        vtmTag: 'character',
      );
    }
  }

  Future<void> uploadOneCharacter({
    required Chronicle chronicle,
    required Character character,
  }) async {
    final rootId = chronicle.driveFolderId;
    if (rootId == null || rootId.isEmpty) {
      throw StateError('У хроники нет папки на Диске');
    }
    final api = await _api();
    String dest;
    if (chronicle.role == ChronicleRole.player) {
      dest = chronicle.playerFolderId ?? '';
      if (dest.isEmpty) {
        final name = chronicle.playerDisplayName ?? 'player';
        dest = (await joinChronicle(
          rootFolderId: rootId,
          playerName: name,
          chronicleName: chronicle.name,
          inviteLink: chronicle.inviteLink,
        ))
            .playerFolderId;
      }
      character.drivePlayerName = chronicle.playerDisplayName;
    } else {
      final playersId = await _ensureFolder(api, parentId: rootId, name: 'players');
      final owner = (character.drivePlayerName ?? '').trim().isEmpty
          ? 'storyteller'
          : character.drivePlayerName!.trim();
      dest = await _ensureFolder(api, parentId: playersId, name: owner);
    }
    if (chronicle.role == ChronicleRole.player) {
      await _writePlayerManifest(
        api,
        playerFolderId: dest,
        info: PlayerChronicleInfo(
          chronicleName: chronicle.name,
          rootFolderId: rootId,
          inviteLink: chronicle.inviteLink,
          playerDisplayName: chronicle.playerDisplayName,
          playerFolderId: dest,
        ),
      );
    }
    await _upsert(
      api,
      folderId: dest,
      fileName: 'character_${character.id}.json',
      body: SyncPayload.wrapCharacter(character),
      vtmTag: 'character',
    );
    await _deleteCharacterCopies(
      api,
      characterId: character.id,
      exceptFolderId: dest,
    );
  }

  static const personalFolderName = 'VtM Helper — личные листы';

  Future<void> uploadStandaloneCharacter(Character character) async {
    character.chronicleId = null;
    final api = await _api();
    final dest = await _ensurePersonalFolder(api);
    await _upsert(
      api,
      folderId: dest,
      fileName: 'character_${character.id}.json',
      body: SyncPayload.wrapCharacter(character),
      vtmTag: 'character',
    );
    await _deleteCharacterCopies(
      api,
      characterId: character.id,
      exceptFolderId: dest,
    );
  }

  Future<void> relocateCharacter({
    required Character character,
    Chronicle? from,
    Chronicle? to,
  }) async {
    if (!isSignedIn) return;
    if (to != null && to.driveFolderId != null && to.driveFolderId!.isNotEmpty) {
      await uploadOneCharacter(chronicle: to, character: character);
    } else {
      await uploadStandaloneCharacter(character);
    }
    if (from == null || from.driveFolderId == to?.driveFolderId) return;
    final api = await _api();
    if (from.playerFolderId != null && from.playerFolderId!.isNotEmpty) {
      await _deleteNamedFile(
        api,
        from.playerFolderId!,
        'character_${character.id}.json',
      );
    }
  }

  Future<String> _ensurePersonalFolder(drive.DriveApi api) async {
    try {
      final tagged = await _queryFiles(
        api,
        q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and appProperties has { key='vtm' and value='personalRoot' }",
        fields: 'nextPageToken, files(id, name)',
      );
      if (tagged.isNotEmpty && tagged.first.id != null) return tagged.first.id!;
    } catch (_) {}
    final named = await _queryFiles(
      api,
      q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and name = '${_q(personalFolderName)}'",
      fields: 'nextPageToken, files(id, name)',
    );
    if (named.isNotEmpty && named.first.id != null) {
      final id = named.first.id!;
      try {
        await api.files.update(
          drive.File()..appProperties = {'vtm': 'personalRoot'},
          id,
        );
      } catch (_) {}
      return id;
    }
    return _createFolder(
      api,
      name: personalFolderName,
      vtmTag: 'personalRoot',
    );
  }

  Future<String?> _personalFolderId(drive.DriveApi api) async {
    try {
      final tagged = await _queryFiles(
        api,
        q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and appProperties has { key='vtm' and value='personalRoot' }",
        fields: 'nextPageToken, files(id)',
      );
      if (tagged.isNotEmpty) return tagged.first.id;
    } catch (_) {}
    final named = await _queryFiles(
      api,
      q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and name = '${_q(personalFolderName)}'",
      fields: 'nextPageToken, files(id)',
    );
    return named.isNotEmpty ? named.first.id : null;
  }

  Future<List<Character>> downloadPersonalCharacters({
    bool interactive = false,
  }) async {
    final api = await _api(interactive: interactive);
    final folderId = await _personalFolderId(api);
    if (folderId == null) return [];
    return _downloadInFolder(api, folderId);
  }

  Future<Character?> downloadStandaloneCharacter(String characterId) async {
    final api = await _api(interactive: false);
    final folderId = await _personalFolderId(api);
    if (folderId == null) return null;
    final fileId = await _findFileId(
      api,
      folderId: folderId,
      fileName: 'character_$characterId.json',
    );
    if (fileId == null) return null;
    return _readCharacterFile(api, fileId);
  }

  Future<void> _deleteCharacterCopies(
    drive.DriveApi api, {
    required String characterId,
    required String exceptFolderId,
  }) async {
    final fileName = 'character_$characterId.json';
    final folders = <String>{};
    final personal = await _personalFolderId(api);
    if (personal != null) folders.add(personal);
    final chronicles = await StorageService().loadChronicles();
    for (final c in chronicles) {
      if (c.playerFolderId != null && c.playerFolderId!.isNotEmpty) {
        folders.add(c.playerFolderId!);
      }
      if (c.role == ChronicleRole.storyteller &&
          c.driveFolderId != null &&
          c.driveFolderId!.isNotEmpty) {
        final playersId = await _findFolder(
          api,
          parentId: c.driveFolderId!,
          name: 'players',
        );
        if (playersId != null) {
          final subs = await _listChildren(api, playersId, foldersOnly: true);
          for (final s in subs) {
            if (s.id != null) folders.add(s.id!);
          }
        }
      }
    }
    folders.remove(exceptFolderId);
    for (final folderId in folders) {
      await _deleteNamedFile(api, folderId, fileName);
    }
  }

  Future<void> _deleteNamedFile(
    drive.DriveApi api,
    String folderId,
    String fileName,
  ) async {
    try {
      final id = await _findFileId(
        api,
        folderId: folderId,
        fileName: fileName,
      );
      if (id == null) return;
      await api.files.delete(id, supportsAllDrives: true);
    } catch (_) {}
  }

  Future<Character?> downloadOneCharacter({
    required Chronicle chronicle,
    required String characterId,
  }) async {
    final api = await _api();
    final fileName = 'character_$characterId.json';
    final folderCandidates = <String>[];
    if (chronicle.playerFolderId != null &&
        chronicle.playerFolderId!.isNotEmpty) {
      folderCandidates.add(chronicle.playerFolderId!);
    }
    final rootId = chronicle.driveFolderId;
    if (rootId != null && rootId.isNotEmpty) {
      final playersId = await _findFolder(api, parentId: rootId, name: 'players');
      if (playersId != null) {
        final hint = chronicle.playerDisplayName ?? chronicle.name;
        if (hint.isNotEmpty) {
          final named = await _findFolder(api, parentId: playersId, name: hint);
          if (named != null) folderCandidates.add(named);
        }
        final st = await _findFolder(api, parentId: playersId, name: 'storyteller');
        if (st != null) folderCandidates.add(st);
        final subs = await _listChildren(api, playersId, foldersOnly: true);
        for (final s in subs) {
          if (s.id != null) folderCandidates.add(s.id!);
        }
      }
      folderCandidates.add(rootId);
    }

    String? fileId;
    for (final folderId in folderCandidates.toSet()) {
      fileId = await _findFileId(api, folderId: folderId, fileName: fileName);
      if (fileId != null) break;
    }
    if (fileId == null) {
      final listed = await api.files.list(
        q: "name = '${_q(fileName)}' and trashed = false",
        $fields: 'files(id, name)',
        pageSize: 5,
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      );
      fileId = listed.files?.isNotEmpty == true ? listed.files!.first.id : null;
    }
    if (fileId == null) return null;
    return _readCharacterFile(api, fileId);
  }

  Future<String?> _findFileId(
    drive.DriveApi api, {
    required String folderId,
    required String fileName,
  }) async {
    final listed = await api.files.list(
      q: "'${_q(folderId)}' in parents and name = '${_q(fileName)}' and trashed = false",
      $fields: 'files(id)',
      pageSize: 1,
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );
    if (listed.files == null || listed.files!.isEmpty) return null;
    return listed.files!.first.id;
  }

  Future<Character?> _readCharacterFile(drive.DriveApi api, String fileId) async {
    try {
      final parsed = await _readPayload(api, fileId);
      return parsed.character;
    } catch (_) {
      return null;
    }
  }

  Future<ParsedSync> _readPayload(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
      supportsAllDrives: true,
    ) as drive.Media;
    final bytes = await media.stream.fold<List<int>>(
      <int>[],
      (p, e) => p..addAll(e),
    );
    return SyncPayload.parse(utf8.decode(bytes));
  }

  Future<List<Character>> downloadCharacters(Chronicle chronicle) async {
    final rootId = chronicle.driveFolderId;
    if (rootId == null) return [];
    final api = await _api();
    if (chronicle.role == ChronicleRole.player) {
      var folderId = chronicle.playerFolderId;
      if (folderId == null || folderId.isEmpty) {
        final name = chronicle.playerDisplayName ?? 'player';
        final joined = await joinChronicle(rootFolderId: rootId, playerName: name);
        folderId = joined.playerFolderId;
      }
      return _downloadInFolder(api, folderId);
    }
    // Рассказчик: рекурсивно все character_*.json в дереве папки
    return _downloadTree(api, rootId);
  }

  Future<List<Character>> _downloadTree(
    drive.DriveApi api,
    String folderId, {
    String? ownerHint,
  }) async {
    final result = <Character>[];
    result.addAll(await _downloadInFolder(api, folderId, ownerHint: ownerHint));
    final subs = await _listChildren(
      api,
      folderId,
      foldersOnly: true,
    );
    for (final sub in subs) {
      if (sub.id == null) continue;
      result.addAll(await _downloadTree(
        api,
        sub.id!,
        ownerHint: sub.name,
      ));
    }
    return result;
  }

  Future<List<drive.File>> _listChildren(
    drive.DriveApi api,
    String folderId, {
    bool foldersOnly = false,
    bool jsonOnly = false,
  }) async {
    var q = "'${_q(folderId)}' in parents and trashed = false";
    if (foldersOnly) {
      q += " and mimeType = 'application/vnd.google-apps.folder'";
    }
    if (jsonOnly) {
      q += " and name contains 'character_'";
    }
    final out = <drive.File>[];
    String? pageToken;
    do {
      final listed = await api.files.list(
        q: q,
        $fields: 'nextPageToken, files(id, name, mimeType)',
        pageSize: 100,
        pageToken: pageToken,
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      );
      out.addAll(listed.files ?? const <drive.File>[]);
      pageToken = listed.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return out;
  }

  Future<List<Character>> _downloadInFolder(
    drive.DriveApi api,
    String folderId, {
    String? ownerHint,
  }) async {
    final listed = await _listChildren(api, folderId, jsonOnly: true);
    final result = <Character>[];
    for (final f in listed) {
      if (f.id == null) continue;
      try {
        final parsed = await _readPayload(api, f.id!);
        if (parsed.character != null) {
          final ch = parsed.character!;
          if (ownerHint != null &&
              ownerHint != 'players' &&
              (ch.drivePlayerName == null || ch.drivePlayerName!.isEmpty)) {
            ch.drivePlayerName = ownerHint;
          }
          result.add(ch);
        }
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  Future<String> _createFolder(
    drive.DriveApi api, {
    required String name,
    String? parentId,
    String? vtmTag,
  }) async {
    final meta = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parentId != null) meta.parents = [parentId];
    if (vtmTag != null) meta.appProperties = {'vtm': vtmTag};
    final folder = await api.files.create(meta);
    final id = folder.id;
    if (id == null || id.isEmpty) {
      throw StateError('Drive не вернул id папки');
    }
    return id;
  }

  Future<String?> _findFolder(
    drive.DriveApi api, {
    required String parentId,
    required String name,
  }) async {
    final listed = await api.files.list(
      q: "'${_q(parentId)}' in parents and name = '${_q(name)}' and trashed = false and mimeType = 'application/vnd.google-apps.folder'",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    if (listed.files == null || listed.files!.isEmpty) return null;
    return listed.files!.first.id;
  }

  Future<String> _ensureFolder(
    drive.DriveApi api, {
    required String parentId,
    required String name,
    String? vtmTag,
  }) async {
    final existing = await _findFolder(api, parentId: parentId, name: name);
    if (existing != null) {
      if (vtmTag != null) {
        try {
          await api.files.update(
            drive.File()..appProperties = {'vtm': vtmTag},
            existing,
          );
        } catch (_) {}
      }
      return existing;
    }
    return _createFolder(
      api,
      name: name,
      parentId: parentId,
      vtmTag: vtmTag,
    );
  }

  Future<void> _upsert(
    drive.DriveApi api, {
    required String folderId,
    required String fileName,
    required String body,
    String? vtmTag,
  }) async {
    final found = await api.files.list(
      q: "'${_q(folderId)}' in parents and name = '${_q(fileName)}' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final raw = utf8.encode(body);
    final media = drive.Media(Stream<List<int>>.fromIterable([raw]), raw.length);
    final meta = drive.File()
      ..name = fileName
      ..mimeType = 'application/json';
    if (vtmTag != null) meta.appProperties = {'vtm': vtmTag};
    final existingId =
        found.files?.isNotEmpty == true ? found.files!.first.id : null;
    if (existingId == null) {
      meta.parents = [folderId];
      await api.files.create(meta, uploadMedia: media);
    } else {
      await api.files.update(meta, existingId, uploadMedia: media);
    }
  }

  static const _infoFileName = 'chronicle_info.json';

  static String _q(String value) => value.replaceAll("'", r"\'");

  Future<void> _writePlayerManifest(
    drive.DriveApi api, {
    required String playerFolderId,
    required PlayerChronicleInfo info,
  }) async {
    await _upsert(
      api,
      folderId: playerFolderId,
      fileName: _infoFileName,
      body: SyncPayload.wrapChronicleInfo(info),
      vtmTag: 'chronicleInfo',
    );
  }

  Future<PlayerChronicleInfo?> _readPlayerManifest(
    drive.DriveApi api,
    String playerFolderId,
  ) async {
    try {
      final fileId = await _findFileId(
        api,
        folderId: playerFolderId,
        fileName: _infoFileName,
      );
      if (fileId == null) return null;
      final parsed = await _readPayloadRaw(api, fileId);
      return SyncPayload.parseChronicleInfo(parsed);
    } catch (_) {
      return null;
    }
  }

  Future<String> _readPayloadRaw(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
      supportsAllDrives: true,
    ) as drive.Media;
    final bytes = await media.stream.fold<List<int>>(
      <int>[],
      (p, e) => p..addAll(e),
    );
    return utf8.decode(bytes);
  }

  Future<DriveRestoreResult> _restoreOnSignInBody({
    required bool interactive,
  }) async {
    final granted = await ensureDriveAccess(interactive: interactive);
    if (!granted) {
      return DriveRestoreResult.needsConsent();
    }
    try {
      return await _restoreOnSignInBodyAfterAuth(interactive: interactive);
    } catch (e) {
      final msg = e.toString();
      if (!interactive &&
          (msg.contains('401') ||
              msg.contains('invalid authentication') ||
              e is DriveException)) {
        return DriveRestoreResult.needsConsent();
      }
      rethrow;
    }
  }

  Future<DriveRestoreResult> _restoreOnSignInBodyAfterAuth({
    required bool interactive,
  }) async {
    final discovered = await _discoverChronicles(interactive: interactive);
    final found = discovered.items;
    final storage = StorageService();
    final chronicles = await storage.loadChronicles();
    var addedChronicles = 0;
    var addedCharacters = 0;
    var updatedCharacters = 0;

    for (final d in found) {
      final idx = chronicles.indexWhere(
        (c) =>
            c.driveFolderId == d.folderId ||
            (d.playerFolderId != null &&
                d.playerFolderId!.isNotEmpty &&
                c.playerFolderId == d.playerFolderId),
      );
      late Chronicle local;
      if (idx == -1) {
        local = Chronicle(
          id: const Uuid().v4(),
          name: d.name,
          role: d.role,
          driveFolderId: d.folderId,
          inviteLink: d.inviteLink,
          playerDisplayName: d.playerDisplayName,
          playerFolderId: d.playerFolderId,
        );
        chronicles.add(local);
        addedChronicles++;
      } else {
        local = chronicles[idx];
        if (d.name.isNotEmpty) local.name = d.name;
        if (d.role == ChronicleRole.storyteller) {
          local.role = ChronicleRole.storyteller;
        } else if (local.role == ChronicleRole.player) {
          local.playerDisplayName = d.playerDisplayName ?? local.playerDisplayName;
          local.playerFolderId = d.playerFolderId ?? local.playerFolderId;
        }
        if (local.inviteLink == null || local.inviteLink!.isEmpty) {
          local.inviteLink = d.inviteLink;
        }
      }

      final incoming = await downloadCharacters(local);
      final existingChars = await storage.loadCharacters();
      for (final ch in incoming) {
        ch.chronicleId = local.id;
        if (local.role != ChronicleRole.storyteller) {
          ch.storytellerPrivateNotes = '';
        }
        final ci = existingChars.indexWhere((x) => x.id == ch.id);
        if (ci == -1) {
          await storage.addCharacter(ch);
          addedCharacters++;
        } else {
          final localChar = existingChars[ci];
          if (local.role == ChronicleRole.storyteller &&
              ch.storytellerPrivateNotes.isEmpty &&
              localChar.storytellerPrivateNotes.isNotEmpty) {
            ch.storytellerPrivateNotes = localChar.storytellerPrivateNotes;
          }
          if (ch.updatedAt > localChar.updatedAt) {
            await storage.updateCharacter(ch);
            updatedCharacters++;
          }
        }
      }
    }

    try {
      final personal = await downloadPersonalCharacters(
        interactive: interactive,
      );
      final existingChars = await storage.loadCharacters();
      for (final ch in personal) {
        ch.chronicleId = null;
        final ci = existingChars.indexWhere((x) => x.id == ch.id);
        if (ci == -1) {
          await storage.addCharacter(ch);
          addedCharacters++;
        } else {
          final localChar = existingChars[ci];
          if (ch.updatedAt > localChar.updatedAt) {
            await storage.updateCharacter(ch);
            updatedCharacters++;
          }
        }
      }
    } catch (_) {}

    await storage.saveChronicles(chronicles);
    await storage.addSyncLog(
      action: 'Восстановление с Диска',
      characterName: email ?? 'Google',
      detail:
          'хроник $addedChronicles, новых листов $addedCharacters, обновлено $updatedCharacters',
    );
    _restoredThisSession = true;
    return DriveRestoreResult(
      chroniclesFound: found.length,
      chroniclesAdded: addedChronicles,
      addedCharacters: addedCharacters,
      updatedCharacters: updatedCharacters,
      detail: discovered.detail,
    );
  }

  Future<({List<_DiscoveredChronicle> items, String detail})>
      _discoverChronicles({bool interactive = false}) async {
    final api = await _api(interactive: interactive);
    final byFolder = <String, _DiscoveredChronicle>{};
    final fileCache = <String, drive.File?>{};
    var ownedCharacterFiles = 0;

    Future<drive.File?> cachedFile(String id) async {
      if (fileCache.containsKey(id)) return fileCache[id];
      final file = await _getFile(api, id);
      fileCache[id] = file;
      return file;
    }

    Future<void> addStoryteller(drive.File folder) async {
      final id = folder.id;
      if (id == null || id.isEmpty) return;
      final existing = byFolder[id];
      if (existing?.role == ChronicleRole.storyteller) return;
      byFolder[id] = _DiscoveredChronicle(
        folderId: id,
        name: _nameFromFolderTitle(folder.name) ?? folder.name ?? 'Хроника',
        role: ChronicleRole.storyteller,
        inviteLink: folder.webViewLink ??
            'https://drive.google.com/drive/folders/$id',
      );
    }

    Future<void> addFromManifest(
      PlayerChronicleInfo info, {
      String? playerFolderId,
    }) async {
      final rootId = info.rootFolderId;
      if (rootId.isEmpty) return;
      if (byFolder[rootId]?.role == ChronicleRole.storyteller) return;
      final existing = byFolder[rootId];
      final folderId = playerFolderId ?? info.playerFolderId ?? existing?.playerFolderId;
      byFolder[rootId] = _DiscoveredChronicle(
        folderId: rootId,
        name: info.chronicleName.trim().isNotEmpty
            ? info.chronicleName.trim()
            : (existing?.name ?? 'Хроника'),
        role: ChronicleRole.player,
        inviteLink: (info.inviteLink != null && info.inviteLink!.isNotEmpty)
            ? info.inviteLink!
            : (existing?.inviteLink ??
                'https://drive.google.com/drive/folders/$rootId'),
        playerFolderId: folderId,
        playerDisplayName:
            info.playerDisplayName ?? existing?.playerDisplayName,
      );
      if (folderId != null && folderId != rootId) {
        byFolder.remove(folderId);
      }
    }

    Future<void> addPlayer(
      drive.File playerFolder, {
      bool fromVtmFile = false,
    }) async {
      final playerId = playerFolder.id;
      if (playerId == null) return;
      if (playerFolder.name == 'players' ||
          _isChronicleRootName(playerFolder.name)) {
        return;
      }
      final manifest = await _readPlayerManifest(api, playerId);
      if (manifest != null) {
        await addFromManifest(manifest, playerFolderId: playerId);
        return;
      }
      var parentId = playerFolder.parents?.isNotEmpty == true
          ? playerFolder.parents!.first
          : null;
      if (parentId == null) {
        final fresh = await cachedFile(playerId);
        parentId =
            fresh?.parents?.isNotEmpty == true ? fresh!.parents!.first : null;
      }
      String? rootId;
      String? rootLink;
      String? chronicleName;
      if (parentId != null) {
        final playersDir = await cachedFile(parentId);
        if (playersDir != null && playersDir.name == 'players') {
          rootId = playersDir.parents?.isNotEmpty == true
              ? playersDir.parents!.first
              : null;
        } else if (playersDir != null && !fromVtmFile) {
          return;
        }
      } else if (!fromVtmFile) {
        return;
      }
      if (rootId != null) {
        if (byFolder[rootId]?.role == ChronicleRole.storyteller) return;
        final root = await cachedFile(rootId);
        rootLink = root?.webViewLink;
        chronicleName = await readChronicleName(rootId) ??
            _nameFromFolderTitle(root?.name);
      }
      final key = rootId ?? playerId;
      if (byFolder[key]?.role == ChronicleRole.storyteller) return;
      if (byFolder.containsKey(key) && byFolder[key]!.playerFolderId != null) {
        return;
      }
      byFolder[key] = _DiscoveredChronicle(
        folderId: key,
        name: chronicleName ??
            (playerFolder.name == null || playerFolder.name!.isEmpty
                ? 'Хроника'
                : 'Хроника (${playerFolder.name})'),
        role: ChronicleRole.player,
        inviteLink: rootLink ??
            'https://drive.google.com/drive/folders/${rootId ?? key}',
        playerFolderId: playerId,
        playerDisplayName: playerFolder.name,
      );
    }

    Future<void> addPlayerFromCharacterFile(drive.File file) async {
      if (file.id == null) return;
      if (!_isCharacterFileName(file.name ?? '') &&
          file.appProperties?['vtm'] != 'character') {
        return;
      }
      ownedCharacterFiles++;
      final pid = file.parents?.isNotEmpty == true ? file.parents!.first : null;
      if (pid == null) return;
      final folder = await cachedFile(pid);
      if (folder != null) {
        await addPlayer(folder, fromVtmFile: true);
      } else {
        final manifest = await _readPlayerManifest(api, pid);
        if (manifest != null) {
          await addFromManifest(manifest, playerFolderId: pid);
        } else {
          byFolder.putIfAbsent(
            pid,
            () => _DiscoveredChronicle(
              folderId: pid,
              name: 'Хроника',
              role: ChronicleRole.player,
              inviteLink: 'https://drive.google.com/drive/folders/$pid',
              playerFolderId: pid,
            ),
          );
        }
      }
    }

    for (final f in await _queryFiles(
      api,
      q: "name = '$_infoFileName' and 'me' in owners and trashed = false",
      fields: 'nextPageToken, files(id, name, parents)',
    )) {
      if (f.id == null) continue;
      try {
        final info = SyncPayload.parseChronicleInfo(
          await _readPayloadRaw(api, f.id!),
        );
        if (info != null) {
          final pid = f.parents?.isNotEmpty == true ? f.parents!.first : null;
          await addFromManifest(info, playerFolderId: pid);
        }
      } catch (_) {}
    }

    for (final f in await _queryFiles(
      api,
      q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and name contains 'VTM'",
      fields: 'nextPageToken, files(id, name, webViewLink, parents, ownedByMe)',
    )) {
      if (_isChronicleRootName(f.name)) await addStoryteller(f);
    }

    try {
      for (final f in await _queryFiles(
        api,
        q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and appProperties has { key='vtm' and value='chronicleRoot' }",
        fields: 'nextPageToken, files(id, name, webViewLink, parents)',
      )) {
        await addStoryteller(f);
      }
    } catch (_) {}

    for (final f in await _queryFiles(
      api,
      q: "name = 'chronicle.json' and 'me' in owners and trashed = false",
      fields: 'nextPageToken, files(id, name, parents)',
    )) {
      final parentId = f.parents?.isNotEmpty == true ? f.parents!.first : null;
      if (parentId == null) continue;
      final folder = await cachedFile(parentId);
      if (folder != null) await addStoryteller(folder);
    }

    try {
      for (final f in await _queryFiles(
        api,
        q: "mimeType = 'application/vnd.google-apps.folder' and 'me' in owners and trashed = false and appProperties has { key='vtm' and value='playerFolder' }",
        fields: 'nextPageToken, files(id, name, parents)',
      )) {
        await addPlayer(f);
      }
    } catch (_) {}

    for (final f in await _queryFiles(
      api,
      q: "'me' in owners and trashed = false and name contains 'character_'",
      fields: 'nextPageToken, files(id, name, parents, mimeType, appProperties)',
    )) {
      await addPlayerFromCharacterFile(f);
    }
    return (
      items: byFolder.values.toList(),
      detail: 'файлов character_*: $ownedCharacterFiles',
    );
  }

  Future<drive.File?> _getFile(drive.DriveApi api, String id) async {
    try {
      return await api.files.get(
        id,
        $fields: 'id, name, parents, webViewLink, ownedByMe',
        supportsAllDrives: true,
      ) as drive.File;
    } catch (_) {
      return null;
    }
  }

  Future<List<drive.File>> _queryFiles(
    drive.DriveApi api, {
    required String q,
    required String fields,
  }) async {
    final out = <drive.File>[];
    String? pageToken;
    do {
      final listed = await api.files.list(
        q: q,
        $fields: fields,
        pageSize: 100,
        pageToken: pageToken,
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      );
      out.addAll(listed.files ?? const <drive.File>[]);
      pageToken = listed.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return out;
  }

  static bool _isChronicleRootName(String? name) {
    if (name == null) return false;
    return name.startsWith('VTM — ') || name.startsWith('VTM - ');
  }

  static final _characterFileName =
      RegExp(r'^character_[0-9a-fA-F-]{8,}\.json$');

  static bool _isCharacterFileName(String name) {
    return _characterFileName.hasMatch(name);
  }
}

class _DiscoveredChronicle {
  final String folderId;
  final String name;
  final ChronicleRole role;
  final String inviteLink;
  final String? playerFolderId;
  final String? playerDisplayName;

  _DiscoveredChronicle({
    required this.folderId,
    required this.name,
    required this.role,
    required this.inviteLink,
    this.playerFolderId,
    this.playerDisplayName,
  });

  _DiscoveredChronicle withName(String n) => _DiscoveredChronicle(
        folderId: folderId,
        name: n,
        role: role,
        inviteLink: inviteLink,
        playerFolderId: playerFolderId,
        playerDisplayName: playerDisplayName,
      );
}

String _describeGoogleSignInError(PlatformException e) {
  final blob = '${e.code} ${e.message} ${e.details}';
  if (RegExp(r'ApiException:\s*10\b').hasMatch(blob) ||
      blob.contains('DEVELOPER_ERROR')) {
    return 'Google Sign-In: ошибка 10 — Android OAuth не узнаёт подпись приложения.\n'
        'В Google Cloud → Credentials нужен OAuth-клиент типа Android:\n'
        '• package: xtended16gmail.com.vtm_helper\n'
        '• SHA-1 debug (flutter run): '
        '67:DD:35:D0:C3:BA:2D:D3:47:86:00:03:4C:52:98:DC:0B:06:81:40\n'
        '• SHA-1 release APK: '
        'B4:BD:76:D7:B8:08:F5:8E:B3:18:0A:C7:F7:88:91:91:F7:3A:0D:30\n'
        'Web-клиент не удаляй (его ID в dart_defines.json). '
        'После сохранения SHA-1 подожди несколько минут.';
  }
  if (RegExp(r'ApiException:\s*7\b').hasMatch(blob)) {
    return 'Нет сети или Google Play services не отвечает.';
  }
  if (e.code == 'sign_in_canceled' ||
      RegExp(r'ApiException:\s*12501\b').hasMatch(blob)) {
    return 'Вход в Google отменён.';
  }
  return e.message ?? e.toString();
}

class DriveException implements Exception {
  final String message;
  DriveException(this.message);
  @override
  String toString() => message;
}

class DriveRestoreResult {
  final int chroniclesFound;
  final int chroniclesAdded;
  final int addedCharacters;
  final int updatedCharacters;
  final bool needsConsent;
  final String? detail;

  DriveRestoreResult({
    required this.chroniclesFound,
    required this.chroniclesAdded,
    required this.addedCharacters,
    required this.updatedCharacters,
    this.needsConsent = false,
    this.detail,
  });

  factory DriveRestoreResult.needsConsent() => DriveRestoreResult(
        chroniclesFound: 0,
        chroniclesAdded: 0,
        addedCharacters: 0,
        updatedCharacters: 0,
        needsConsent: true,
      );

  bool get isEmpty =>
      !needsConsent &&
      chroniclesFound == 0 &&
      addedCharacters == 0 &&
      updatedCharacters == 0;
}

class CreatedChronicleFolder {
  final String folderId;
  final String inviteLink;
  CreatedChronicleFolder({required this.folderId, required this.inviteLink});
}

class JoinedPlayerFolder {
  final String playersDirId;
  final String playerFolderId;
  JoinedPlayerFolder({required this.playersDirId, required this.playerFolderId});
}
