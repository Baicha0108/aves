#!/usr/bin/env bash
# One-command upstream sync for the Aves Miuix fork:
#   fetch upstream -> apply the upstream-only delta -> re-apply branding ->
#   switch flavor -> check/test -> build arm64 APK
#
# `develop` now has real upstream ancestry. Only the delta from the common
# ancestor to `upstream/develop` may be applied; a `git diff develop ...` would
# also contain the reverse of every fork-specific change and must never be used.
#
# Env: FLUTTER_BIN (defaults to `flutter`, on this machine point it at
#      D:\0AI\BaiCha\Aves\.flutter-sdk\flutter\bin\flutter.bat)
set -euo pipefail
cd "$(dirname "$0")/../.."
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
export FLUTTER_BIN

echo "== 1/6 fetch upstream =="
git fetch upstream develop
echo "   upstream/develop: $(git log --oneline -1 upstream/develop)"

echo "== 2/6 apply upstream diff (NOT a rebase) =="
# Already synced? upstream/develop is explicitly reachable from HEAD.
if git merge-base --is-ancestor upstream/develop HEAD; then
  echo "   already in sync; nothing to apply."
else
  BASE="$(git merge-base HEAD upstream/develop)"
  if [ -z "$BASE" ]; then
    echo "!! develop and upstream/develop have no common ancestor." >&2
    exit 1
  fi
  UPSTREAM_PATCH="$(mktemp -t aves-upstream-XXXXXX.patch)"
  # Apply only commits added upstream since the shared base. This preserves all
  # fork changes on the local side of the three-way merge.
  git diff --binary "$BASE" upstream/develop > "$UPSTREAM_PATCH"
  echo "--- upstream delta ---"
  git diff --stat "$BASE" upstream/develop
  if [ ! -s "$UPSTREAM_PATCH" ]; then
    echo "   trees already identical; nothing to apply."
  else
    git apply --3way --binary "$UPSTREAM_PATCH" || {
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
scripts/baicha/check.sh

echo "== 6/6 build arm64 release APK =="
BAICHA_ABIS="arm64-v8a" "$FLUTTER_BIN" build apk --release --flavor libre \
  --target-platform android-arm64 -t lib/main_libre.dart

VERSION="$(awk '/^version:/{print $2; exit}' pubspec.yaml | cut -d+ -f1)"
APK_NAME="aves-miuix-${VERSION}-arm64-release-同步上游更新.apk"
mkdir -p ../_apk
cp build/app/outputs/flutter-apk/app-libre-release.apk "../_apk/$APK_NAME"

echo
echo "done → ../_apk/$APK_NAME"
echo "note: the upstream delta was applied to the working tree but NOT committed."
echo "      review it with 'git diff --cached' and commit when happy."
