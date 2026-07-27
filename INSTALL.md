# Install And Run

Lake Command is a Flutter app with a prebuilt web demo included in `public` for
easy review hosting.

## Requirements

- Flutter 3.35 or newer
- Dart SDK provided by Flutter
- Docker Desktop or Docker Engine, optional

## Install Dependencies

```bash
flutter pub get
```

## Run Locally From Source

```bash
flutter run -d chrome
```

## Test

```bash
flutter test
```

## Build Web

```bash
flutter build web --release
```

To refresh the included static demo after building:

```bash
cp -R build/web/* public/
```

## Run The Included Static Demo

```bash
python3 -m http.server 4173 -d public
```

Open:

```text
http://127.0.0.1:4173/
```

## Docker

```bash
docker build -t lake-command-review .
docker run --rm -p 4173:4173 lake-command-review
```

