# Deployment

## Free Vercel Static Hosting

This repo includes a prebuilt Flutter web app in `public`, so Vercel can host it
on the free tier without installing Flutter during deployment.

Recommended Vercel settings:

- Framework preset: Other
- Build command: leave empty
- Output directory: `public`

## Rebuilding The Static Output

Reviewers can rebuild from source with:

```bash
flutter pub get
flutter test
flutter build web --release
```

Then copy the refreshed build output into `public`.

## Docker

Docker serves the included static build:

```bash
docker build -t lake-command-review .
docker run --rm -p 4173:4173 lake-command-review
```

