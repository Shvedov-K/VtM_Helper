/// OAuth-клиент типа **Web application** из Google Cloud Console.
/// Нужен и Android (как serverClientId), и Flutter Web (как clientId).
///
/// Значение не хранится в репозитории. Скопируй `dart_defines.json.example`
/// в `dart_defines.json` и запускай:
/// `flutter run --dart-define-from-file=dart_defines.json`
const String kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
);
