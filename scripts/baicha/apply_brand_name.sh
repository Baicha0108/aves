#!/usr/bin/env bash
# Re-applies the "Aves Miuix" branding to every Android string resource and ARB file.
# Idempotent: safe to run after every upstream merge (upstream keeps adding new locales).
set -euo pipefail
cd "$(dirname "$0")/../.."

count=0

# Android string resources: app_name = "Aves Miuix" (+ optional [Debug]/[Profile] suffix)
while IFS= read -r -d '' f; do
  perl -0pi -e 's{(<string name="app_name">)([^<]*)(</string>)}{
    my $suffix = "";
    $suffix = " [Debug]"   if $2 =~ /\[Debug\]/;
    $suffix = " [Profile]" if $2 =~ /\[Profile\]/;
    $1 . "Aves Miuix" . $suffix . $3;
  }ge' "$f"
  count=$((count + 1))
done < <(find android/app/src -name strings.xml -print0)

# Flutter localizations: appName + welcomeMessage
for f in lib/l10n/app_*.arb; do
  perl -0pi -e 's{("appName"\s*:\s*")[^"]*(")}{${1}Aves Miuix${2}}g' "$f"
  perl -0pi -e 's{("welcomeMessage"\s*:\s*")([^"]*)(")}{
    my ($prefix, $v, $suffix) = ($1, $2, $3);
    $v =~ s/(?<!Miuix )Aves(?! Miuix)/Aves Miuix/g;
    $prefix . $v . $suffix;
  }ge' "$f"
  count=$((count + 1))
done

echo "brand name re-applied to $count files"
