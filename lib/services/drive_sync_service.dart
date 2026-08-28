import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:vtm_helper/models/character.dart';
import 'package:vtm_helper/models/chronicle.dart';
import 'package:vtm_helper/services/google_auth_client.dart';
import 'package:vtm_helper/services/google_config.dart';
import 'package:vtm_helper/services/sync_payload.dart';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveScope,
    ],
    clientId: kIsWeb && kGoogleServerClientId.isNotEmpty
        ? kGoogleServerClientId
        : null,
    serverClientId:
        kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
  );

  GoogleSignInAccount? get account => _googleSignIn.currentUser;
  bool get isSignedIn => account != null;
  String? get email => account?.email;

  Future<GoogleSignInAccount?> signIn() async {
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
      final existing = await _googleSignIn.signInSilently();
      if (existing != null) return existing;
      return _googleSignIn.signIn();
    } on MissingPluginException {
      throw UnsupportedError(
        'Плагин Google Sign-In не собран для этой платформы. '
        'Нужен полный перезапуск на Android или Flutter Web.',
      );
    }
  }

  Future<void> signOut() async {
    if (!isGoogleSignInSupported) return;
    await _googleSignIn.signOut();
  }

  Future<drive.DriveApi> _api() async {
    var user = _googleSignIn.currentUser ?? await signIn();
    if (user == null) {
      throw StateError('Нет входа в Google');
    }
    final headers = await user.authHeaders;
    return drive.DriveApi(GoogleAuthClient(headers));
  }


  Future<CreatedChronicleFolder> createSharedChronicleFolder(String name) async {
    final api = await _api();
    final root = await _createFolder(api, name: 'VTM — $name');
    await _createFolder(api, name: 'players', parentId: root);
    await api.permissions.create(
      drive.Permission()
        ..type = 'anyone'
        ..role = 'writer'
        ..allowFileDiscovery = false,
      root,
    );
    final fresh = await api.files.get(root, $fields: 'id, webViewLink') as drive.File;
    final link = fresh.webViewLink ??
        'https://drive.google.com/drive/folders/$root';
    return CreatedChronicleFolder(folderId: root, inviteLink: link);
  }

  Future<JoinedPlayerFolder> joinChronicle({
    required String rootFolderId,
    required String playerName,
  }) async {
    final api = await _api();
    final playersId = await _ensureFolder(api, parentId: rootFolderId, name: 'players');
    final mine = await _ensureFolder(api, parentId: playersId, name: playerName);
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
        final joined = await joinChronicle(rootFolderId: rootId, playerName: name);
        folderId = joined.playerFolderId;
      }
      for (final ch in characters) {
        ch.drivePlayerName = chronicle.playerDisplayName;
        await _upsert(
          api,
          folderId: folderId,
          fileName: 'character_${ch.id}.json',
          body: SyncPayload.wrapCharacter(ch),
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
      await _upsert(
        api,
        folderId: dest,
        fileName: 'character_${ch.id}.json',
        body: SyncPayload.wrapCharacter(ch),
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
        dest = (await joinChronicle(rootFolderId: rootId, playerName: name))
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
    await _upsert(
      api,
      folderId: dest,
      fileName: 'character_${character.id}.json',
      body: SyncPayload.wrapCharacter(character),
    );
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
        q: "name = '$fileName' and trashed = false",
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
      q: "'$folderId' in parents and name = '$fileName' and trashed = false",
      $fields: 'files(id)',
      pageSize: 1,
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );
    if (listed.files == null || listed.files!.isEmpty) return null;
    return listed.files!.first.id;
  }

  Future<Character?> _readCharacterFile(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = await media.stream.fold<List<int>>(
      <int>[],
      (p, e) => p..addAll(e),
    );
    final parsed = SyncPayload.parse(utf8.decode(bytes));
    return parsed.character;
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
    var q = "'$folderId' in parents and trashed = false";
    if (foldersOnly) {
      q += " and mimeType = 'application/vnd.google-apps.folder'";
    }
    if (jsonOnly) {
      q += " and name contains 'character_'";
    }
    final listed = await api.files.list(
      q: q,
      $fields: 'files(id, name, mimeType)',
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );
    return listed.files ?? const <drive.File>[];
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
      final media = await api.files.get(
        f.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = await media.stream.fold<List<int>>(
        <int>[],
        (p, e) => p..addAll(e),
      );
      final parsed = SyncPayload.parse(utf8.decode(bytes));
      if (parsed.character != null) {
        final ch = parsed.character!;
        if (ownerHint != null &&
            ownerHint != 'players' &&
            (ch.drivePlayerName == null || ch.drivePlayerName!.isEmpty)) {
          ch.drivePlayerName = ownerHint;
        }
        result.add(ch);
      }
    }
    return result;
  }

  Future<String> _createFolder(
    drive.DriveApi api, {
    required String name,
    String? parentId,
  }) async {
    final meta = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parentId != null) meta.parents = [parentId];
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
    final escaped = name.replaceAll("'", r"\'");
    final listed = await api.files.list(
      q: "'$parentId' in parents and name = '$escaped' and trashed = false and mimeType = 'application/vnd.google-apps.folder'",
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
  }) async {
    return await _findFolder(api, parentId: parentId, name: name) ??
        await _createFolder(api, name: name, parentId: parentId);
  }

  Future<void> _upsert(
    drive.DriveApi api, {
    required String folderId,
    required String fileName,
    required String body,
  }) async {
    final found = await api.files.list(
      q: "'$folderId' in parents and name = '$fileName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final raw = utf8.encode(body);
    final media = drive.Media(Stream<List<int>>.fromIterable([raw]), raw.length);
    final meta = drive.File()
      ..name = fileName
      ..mimeType = 'application/json';
    final existingId =
        found.files?.isNotEmpty == true ? found.files!.first.id : null;
    if (existingId == null) {
      meta.parents = [folderId];
      await api.files.create(meta, uploadMedia: media);
    } else {
      await api.files.update(meta, existingId, uploadMedia: media);
    }
  }
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
