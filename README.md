# VTM Helper

Лист персонажа Vampire: the Masquerade (V20) с локальным сохранением и опциональной синхронизацией хроник через Google Drive.

## Запуск

Скопируй `dart_defines.json.example` в `dart_defines.json` и вставь Web client ID из Google Cloud Console (`GOOGLE_SERVER_CLIENT_ID`).

```
flutter run --dart-define-from-file=dart_defines.json
```

Веб (порт фиксирован — его же надо указать в Google Cloud как origin):

```
flutter run -d chrome --dart-define-from-file=dart_defines.json --web-hostname=localhost --web-port=7357
```

В Google Cloud Console → APIs & Services → Credentials → OAuth-клиент типа **Web application** (не Android):

Authorized JavaScript origins:

```
http://localhost
http://localhost:7357
```

Web client ID достаточно в `dart_defines.json`: его подхватывает `GOOGLE_SERVER_CLIENT_ID` и передаёт в `GoogleSignIn`. В `web/index.html` его класть не нужно.

## Релиз Android

Подпись читается из `key.properties` в корне репозитория (файл в `.gitignore`):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` — относительный путь от корня проекта или от `android/`. Сам `.jks` тоже в `.gitignore`.

```
flutter build apk --release --dart-define-from-file=dart_defines.json
```
