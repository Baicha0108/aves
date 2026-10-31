#!/usr/bin/env bash
# Re-applies this fork's two local patches to a vendored copy of flutter_miuix.
# Usage: scripts/baicha/repatch_flutter_miuix.sh [path-to-flutter_miuix]
#
# Patch 1: route `package:flutter/material.dart` / `package:flutter/widgets.dart`
#          through Aves' `material_ui` copy (material_ui is a *source copy* of Flutter's
#          Material library, so its Material/Theme/MaterialLocalizations are distinct types;
#          without this, Miuix widgets that host a Material widget, e.g. MiuixTextField,
#          fail with "No Material widget found").
# Patch 2: pubspec constraints (dynamic_color ^2.1.0, resolution: workspace, material_ui dep).
set -euo pipefail
cd "$(dirname "$0")/../.."
target="${1:-plugins/flutter_miuix}"

[ -d "$target/lib" ] || { echo "error: $target/lib not found"; exit 1; }

grep -rl -e "package:flutter/material.dart" -e "package:flutter/widgets.dart" "$target/lib" | while read -r f; do
  sed -i -e "s|package:flutter/material\.dart|package:material_ui/material_ui.dart|g" \
         -e "s|package:flutter/widgets\.dart|package:material_ui/material_ui.dart|g" "$f"
done

perl -0pi -e 's{dynamic_color: \^1\.9\.0}{dynamic_color: ^2.1.0}' "$target/pubspec.yaml"
grep -q 'dynamic_color: \^2.1.0' "$target/pubspec.yaml" || echo "WARN: check the dynamic_color constraint in $target/pubspec.yaml"
grep -q '^resolution: workspace' "$target/pubspec.yaml" || \
  perl -0pi -e 's{(environment:\n  sdk: [^\n]*\n)}{$1\nresolution: workspace\n}' "$target/pubspec.yaml"
grep -q '^  material_ui:' "$target/pubspec.yaml" || echo "WARN: add a 'material_ui:' dependency to $target/pubspec.yaml"

# duplicate imports may remain when a file imported both flutter/material and flutter/widgets
dupes=$(grep -rc "package:material_ui/material_ui.dart" "$target/lib" | awk -F: '$2 > 1 {print $1}' || true)
[ -z "$dupes" ] || echo "NOTE: remove duplicate material_ui imports in:\n$dupes"

echo "flutter_miuix patches re-applied (target: $target)"
