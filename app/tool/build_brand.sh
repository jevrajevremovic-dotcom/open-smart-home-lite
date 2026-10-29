#!/usr/bin/env bash
# Builds the release APKs with the installer's brand from android/brand.properties.
# Usage: tool/build_brand.sh [extra flutter build args]
set -euo pipefail
cd "$(dirname "$0")/.."
props=android/brand.properties
if [[ ! -f $props ]]; then
  echo "No $props (copy android/brand.properties.example)." >&2
  exit 1
fi
get() { grep -E "^$1=" "$props" | head -1 | cut -d= -f2- || true; }
name=$(get name); accent=$(get accent); support=$(get support); logo=$(get logo)
updates=$(get updates)
defines=(--dart-define="BRAND_NAME=$name" --dart-define="BRAND_ACCENT=$accent"
  --dart-define="BRAND_SUPPORT=$support")
[[ -n $updates ]] && defines+=(--dart-define="UPDATE_REPO=$updates")
if [[ -n $logo ]]; then
  cp "$logo" assets/brand/logo.png
  defines+=(--dart-define=BRAND_LOGO=true)
else
  rm -f assets/brand/logo.png
fi
if [[ ! -f android/key.properties ]]; then
  echo "Warning: no android/key.properties — this build is signed with the DEBUG key." >&2
fi
flutter build apk --release --split-per-abi "${defines[@]}" "$@"
