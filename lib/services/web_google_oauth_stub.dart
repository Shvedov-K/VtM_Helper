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

Future<WebGoogleSession?> webGoogleSignIn() async => null;

WebGoogleSession? webGoogleRestoreSession() => null;

void webGoogleClearSession() {}

Future<void> webGoogleEnsureSdk() async {}
