#!/usr/bin/env bash
# Run the checks that match the current Libre flavor and exercise the vendored
# Miuix package separately, because the root `flutter test` command only covers
# the app's own test directory.
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ -z "${FLUTTER_BIN:-}" ]; then
  if [ -x ./flutterw ]; then
    FLUTTER_BIN=./flutterw
  else
    FLUTTER_BIN=flutter
  fi
fi

"$FLUTTER_BIN" gen-l10n
"$FLUTTER_BIN" analyze --no-pub
"$FLUTTER_BIN" test --no-pub
(cd plugins/flutter_miuix && "$FLUTTER_BIN" test --no-pub)
