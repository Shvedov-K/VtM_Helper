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

Authorized JavaScript origins (без них веб-вход не откроется):

```
http://localhost
http://localhost:7357
```

Redirect URI для текущего входа **не нужен**: веб использует Google Identity Services (окно GIS, не свой `oauth_callback.html`). Implicit-поток `response_type=token` Google больше не принимает.

Web client ID достаточно в `dart_defines.json`. Для интернета те же origins надо дополнить продом — см. ниже.

## Веб в интернет (GitHub Pages)

Репозиторий: `https://github.com/Shvedov-K/VtM_Helper`.  
Сайт будет: **https://shvedov-k.github.io/VtM_Helper/**

Это статика: HTML/JS/Wasm, без своего бэкенда. Client ID попадает в собранный JS (это публичный Web client ID, не `client_secret`). В git по-прежнему только `dart_defines.json.example`.

### 1. Google Cloud

Тот же OAuth-клиент типа **Web application**, что и для localhost.

Authorized JavaScript origins — **добавить**, старые не трогать:

```
http://localhost
http://localhost:7357
https://shvedov-k.github.io
```

Origin — схема + хост, **без** `/VtM_Helper`. Redirect URI по-прежнему не нужен.

После правки origins подожди 5–15 минут.

### 2. Сборка локально (проверка)

`--base-href` обязателен: GitHub Pages кладёт сайт в подпапку имени репо. Без него белый экран (не грузятся `main.dart.js` / `flutter.js`).

```
flutter build web --release --base-href /VtM_Helper/ --dart-define-from-file=dart_defines.json
```

Слеш в конце `/VtM_Helper/` нужен. Готовое лежит в `build/web/` (в git не коммитится).

### 3. Секрет в GitHub (чтобы CI не читал dart_defines.json)

GitHub → репозиторий → **Settings → Secrets and variables → Actions → New repository secret**:

- Name: `GOOGLE_SERVER_CLIENT_ID`
- Value: тот же Web client ID, что в `dart_defines.json`

### 4. Workflow

Создай `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy web

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter build web --release --base-href /VtM_Helper/ --dart-define=GOOGLE_SERVER_CLIENT_ID=${{ secrets.GOOGLE_SERVER_CLIENT_ID }}
      - run: cp build/web/index.html build/web/404.html
      - uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

`404.html` — копия `index.html`, чтобы обновление страницы на GitHub Pages не отдавало голый 404.

### 5. Включить Pages

GitHub → **Settings → Pages**:

- Source: **GitHub Actions** (не branch)

Запушь `deploy-web.yml` в `main` или **Actions → Deploy web → Run workflow**. Первый прогон может попросить Approve у environment `github-pages`.

Через 1–2 минуты открой https://shvedov-k.github.io/VtM_Helper/

### 6. Если белый экран или Google не пускает

| Симптом | Что проверить |
| --- | --- |
| Белая страница, в Network 404 на `flutter.js` / `main.dart.js` | `--base-href /VtM_Helper/` со слешем, URL именно с `/VtM_Helper/` |
| «Не задан GOOGLE_SERVER_CLIENT_ID» | секрет `GOOGLE_SERVER_CLIENT_ID` задан, workflow перезапущен |
| Google: origin mismatch / не открывается вход | в Web-клиенте origin `https://shvedov-k.github.io` |
| `ERR_TIMED_OUT` на `accounts.google.ru` | сеть/гео Google, не хостинг; закрыть окно и войти ещё раз |

Локальные сохранения (IndexedDB) у localhost и у github.io **разные**: это другой origin, листы с `localhost:7357` сами не приедут. Хроники на Диске — те же, если войти тем же Google-аккаунтом.

### Вручную, без Actions

Если CI не нужен:

```
flutter build web --release --base-href /VtM_Helper/ --dart-define-from-file=dart_defines.json
```

В Pages выбери Deploy from a branch → ветка `gh-pages`, folder `/ (root)`. Содержимое `build/web` пушь в `gh-pages` (например [peaceiris/actions-gh-pages](https://github.com/peaceiris/actions-gh-pages) или разовая orphan-ветка). Client ID тогда зашит в эту сборку — не commiть `dart_defines.json`.

### Дальше, не GitHub Pages

Тот же `build/web` можно отдать на Firebase Hosting, Cloudflare Pages, любой nginx. Тогда:

- `--base-href /` (если сайт в корне домена)
- в Google Cloud origin вида `https://твой.домен`

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
