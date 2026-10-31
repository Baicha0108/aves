#!/usr/bin/env bash
# One-command upstream sync for the Aves Miuix fork:
#   fetch upstream -> apply upstream diff -> re-apply branding -> switch flavor -> analyze/test -> build arm64 APK
#
# NOTE: this repo must NEVER use `git rebase` / `git merge` to sync upstream.
# The clone's history was squashed, so fork `develop` and `upstream/develop`
# are two UNRELATED root commits with no merge base. `git rebase upstream/develop`
# treats our whole tree as new and produces add/add conflicts on every file.
# Instead we diff the two trees and apply the (tiny) result with --3way.
#
# Env: FLUTTER_BIN (defaults to `flutter`, on this machine point it at
#      D:\0AI\BaiCha\Aves\.flutter-sdk\flutter\bin\flutter.bat)
set -euo pipefail
cd "$(dirname "$0")/../.."
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

echo "== 1/6 fetch upstream =="
git fetch upstream develop
echo "   upstream/develop: $(git log --oneline -1 upstream/develop)"

echo "== 2/6 apply upstream diff (NOT a rebase) =="
# Already synced? upstream/develop is explicitly reachable from HEAD.
if git merge-base --is-ancestor upstream/develop HEAD; then
  echo "   already in sync; nothing to apply."
else
  UPSTREAM_PATCH="$(mktemp -t aves-upstream-XXXXXX.patch)"
  # Diff the two trees (never `git log develop..upstream/develop`: upstream is a
  # root commit, so range syntax prints that commit's entire 1813-file diff).
  git diff develop upstream/develop > "$UPSTREAM_PATCH"
  echo "--- upstream delta ---"
  git diff --stat develop upstream/develop
  if [ ! -s "$UPSTREAM_PATCH" ]; then
    echo "   trees already identical; nothing to apply."
  else
    git apply --3way "$UPSTREAM_PATCH" || {
      echo "!! patch did not apply. Conflicts (if any) are in the index."
      echo "   Fix them (see FORK.md '冲突解决速查'), run 'git add -A', then continue from step 3."
      exit 1
    }
  fi
  rm -f "$UPSTREAM_PATCH"
fi

echo "== 3/6 re-apply fork patches =="
scripts/baicha/apply_brand_name.sh

echo "== 4/6 apply libra flavor + dependencies =="
cp flavors/pubspec_libre.yaml pubspec.yaml
cp flavors/pubspec_libre.lock pubspec.lock
if ! "$FLUTTER_BIN" pub get; then
  echo "!! pub get failed: upstream probably changed dependencies."
  echo "   regenerate the flavor files (see FORK.md), then re-run this script."
  exit 1
fi

echo "== 5/6 analyze + tests =="
"$FLUTTER_BIN" analyze --no-pub || true
"$FLUTTER_BIN" test

echo "== 6/6 build arm64 release APK =="
BAICHA_ABIS="arm64-v8a" "$FLUTTER_BIN" build apk --release --flavor libre \
  --target-platform android-arm64 -t lib/main_libre.dart

echo
echo "done → build/app/outputs/flutter-apk/app-libre-release.apk"
echo "note: the upstream delta was applied to the working tree but NOT committed."
echo "      review it with 'git diff --cached' and commit when happy."
