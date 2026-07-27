#!/usr/bin/env bash
set -euo pipefail

export FLUTTER_HOME="${FLUTTER_HOME:-.vercel/flutter}"
export FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    git clone --depth 1 --branch "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi

  export PATH="$PWD/$FLUTTER_HOME/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
