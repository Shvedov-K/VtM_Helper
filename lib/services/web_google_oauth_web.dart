import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:google_identity_services_web/loader.dart' as gis_loader;
import 'package:google_identity_services_web/oauth2.dart' as gis;
import 'package:http/http.dart' as http;
import 'package:vtm_helper/services/google_config.dart';
import 'package:web/web.dart' as web;

class WebGoogleSession {
  final String accessToken;
  final String email;
  final DateTime expiresAt;
  WebGoogleSession({
    required this.accessToken,
    required this.email,
    required this.expiresAt,
  });
}

const _tokenKey = 'vtm_google_token';
const _emailKey = 'vtm_google_email';
const _expKey = 'vtm_google_exp';

const _scopes = <String>[
  'openid',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/drive',
];

gis.TokenClient? _tokenClient;
Completer<WebGoogleSession?>? _pending;
bool _sdkReady = false;
Future<void>? _sdkLoad;

WebGoogleSession? webGoogleRestoreSession() {
  final token = web.window.sessionStorage.getItem(_tokenKey);
  final email = web.window.sessionStorage.getItem(_emailKey);
  final expRaw = web.window.sessionStorage.getItem(_expKey);
  if (token == null || token.isEmpty || email == null || expRaw == null) {
    return null;
  }
  final exp = DateTime.fromMillisecondsSinceEpoch(int.tryParse(expRaw) ?? 0);
  if (DateTime.now().isAfter(exp.subtract(const Duration(minutes: 2)))) {
    webGoogleClearSession();
    return null;
  }
  return WebGoogleSession(accessToken: token, email: email, expiresAt: exp);
}

void webGoogleClearSession() {
  web.window.sessionStorage.removeItem(_tokenKey);
  web.window.sessionStorage.removeItem(_emailKey);
  web.window.sessionStorage.removeItem(_expKey);
}

void _save(WebGoogleSession s) {
  web.window.sessionStorage.setItem(_tokenKey, s.accessToken);
  web.window.sessionStorage.setItem(_emailKey, s.email);
  web.window.sessionStorage.setItem(
    _expKey,
    s.expiresAt.millisecondsSinceEpoch.toString(),
  );
}

bool _gisOauthReady() {
  try {
    final google = globalContext.getProperty('google'.toJS);
    if (google == null || google.isUndefinedOrNull) return false;
    final accounts = (google as JSObject).getProperty('accounts'.toJS);
    if (accounts == null || accounts.isUndefinedOrNull) return false;
    final oauth2 = (accounts as JSObject).getProperty('oauth2'.toJS);
    return oauth2 != null && !oauth2.isUndefinedOrNull;
  } catch (_) {
    return false;
  }
}

void _initTokenClient() {
  if (_tokenClient != null || kGoogleServerClientId.isEmpty) return;
  _tokenClient = gis.oauth2.initTokenClient(
    gis.TokenClientConfig(
      client_id: kGoogleServerClientId,
      scope: _scopes,
      callback: _onToken,
      error_callback: _onGisError,
      prompt: 'select_account',
      include_granted_scopes: true,
    ),
  );
  _sdkReady = true;
}

Future<void> webGoogleEnsureSdk() {
  return _sdkLoad ??= _loadSdk();
}

Future<void> _loadSdk() async {
  if (kGoogleServerClientId.isEmpty) return;
  if (_gisOauthReady()) {
    _initTokenClient();
    return;
  }
  for (var i = 0; i < 40; i++) {
    if (_gisOauthReady()) {
      _initTokenClient();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (!_gisOauthReady()) {
    await gis_loader.loadWebSdk();
  }
  _initTokenClient();
}

void _onToken(gis.TokenResponse response) {
  final pending = _pending;
  _pending = null;
  if (pending == null || pending.isCompleted) return;
  final err = response.error;
  if (err != null && err.isNotEmpty) {
    pending.completeError(
      StateError(response.error_description ?? err),
    );
    return;
  }
  final token = response.access_token ?? '';
  if (token.isEmpty) {
    pending.complete(null);
    return;
  }
  final seconds = response.expires_in ?? 3600;
  unawaited(() async {
    try {
      final email = await _emailForToken(token);
      final session = WebGoogleSession(
        accessToken: token,
        email: email,
        expiresAt: DateTime.now().add(Duration(seconds: seconds)),
      );
      _save(session);
      if (!pending.isCompleted) pending.complete(session);
    } catch (e) {
      if (!pending.isCompleted) pending.completeError(e);
    }
  }());
}

void _onGisError(gis.GoogleIdentityServicesError? error) {
  final pending = _pending;
  _pending = null;
  if (pending == null || pending.isCompleted) return;
  if (error == null) {
    pending.complete(null);
    return;
  }
  gis.GoogleIdentityServicesErrorType? type;
  try {
    type = error.type;
  } catch (_) {}
  if (type == gis.GoogleIdentityServicesErrorType.popup_closed) {
    pending.complete(null);
    return;
  }
  if (type == gis.GoogleIdentityServicesErrorType.popup_failed_to_open) {
    pending.completeError(
      StateError(
        'Браузер заблокировал окно Google. '
        'Разреши всплывающие окна для этого сайта и нажми «Войти» ещё раз.',
      ),
    );
    return;
  }
  pending.completeError(
    StateError(error.message ?? type?.name ?? 'Ошибка входа Google'),
  );
}

Future<WebGoogleSession?> webGoogleSignIn() async {
  if (kGoogleServerClientId.isEmpty) {
    throw StateError('Не задан GOOGLE_SERVER_CLIENT_ID');
  }
  if (!_sdkReady || _tokenClient == null) {
    unawaited(webGoogleEnsureSdk());
    throw StateError(
      'Скрипт Google ещё загружается. Подожди секунду и нажми «Войти» ещё раз.',
    );
  }
  final completer = Completer<WebGoogleSession?>();
  _pending = completer;
  _tokenClient!.requestAccessToken();
  return completer.future.timeout(
    const Duration(minutes: 4),
    onTimeout: () => null,
  );
}

Future<String> _emailForToken(String token) async {
  final res = await http.get(
    Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) {
    throw StateError('userinfo ${res.statusCode}');
  }
  final body = json.decode(res.body);
  if (body is! Map) return '';
  return body['email']?.toString() ?? '';
}
