#!/usr/bin/env bash
set -eo pipefail

# Installe Flutter si le plugin Netlify ou le cache ne l’a pas déjà fourni.
if ! command -v flutter &>/dev/null; then
  FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
  if [ ! -d "$FLUTTER_ROOT/bin" ]; then
    echo "▶ Installation du SDK Flutter (stable)…"
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_ROOT"
  fi
  export PATH="$FLUTTER_ROOT/bin:$PATH"
fi

flutter --version
flutter config --enable-web

# Origine publique : variable Netlify UI, sinon URL du déploiement ($URL).
WEB_ORIGIN="${KELEGANCE_WEB_ORIGIN:-${URL:-https://cheerful-salamander-565dfc.netlify.app}}"
echo "▶ KELEGANCE_WEB_ORIGIN=${WEB_ORIGIN}"

flutter pub get
flutter build web --release \
  --base-href=/ \
  --dart-define=KELEGANCE_WEB_ORIGIN="${WEB_ORIGIN}"

node scripts/inject-pwa-cache.mjs
