#!/usr/bin/env bash
# Builds the demo APK: the app with its built-in demo home (no Home Assistant,
# no network), as "Open Smart Home Demo" with its own id, so it installs next
# to the real app. A profile build: the demo server is never in release builds.
# Usage: tool/build_demo.sh   → build/app/outputs/flutter-apk/app-*-profile.apk
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build apk --profile --split-per-abi --target-platform android-arm64,android-arm \
  --dart-define=SMARTHOME_MOCK=true --android-project-arg=demo=true "$@"
