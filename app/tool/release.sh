#!/usr/bin/env bash
# Publishes a release that installed apps update to (Settings → Service).
# Usage: tool/release.sh 0.2.0 [--brand] [--notes "what changed"]
#   - sets the version in pubspec.yaml (build number +1) and lib/app/app_info.dart
#   - builds the release APKs (signed with android/key.properties; --brand: tool/build_brand.sh)
#   - writes SHA256SUMS and creates GitHub release v<version> with the APKs
# The repository must be public for apps to see it (or set updates= to a public one).
set -euo pipefail
cd "$(dirname "$0")/.."
version=${1:?version, e.g. 0.2.0}; shift
brand=false; notes=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --brand) brand=true; shift ;;
    --notes) notes=$2; shift 2 ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done
[[ -f android/key.properties ]] || { echo "No android/key.properties: refusing to publish a DEBUG-signed build." >&2; exit 1; }
build=$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+)/\1/')
build=$((build + 1))
sed -i -E "s/^version: .*/version: $version+$build/" pubspec.yaml
sed -i -E "s/^const appVersion = .*/const appVersion = '$version';/" lib/app/app_info.dart
if $brand; then tool/build_brand.sh; else flutter build apk --release --split-per-abi; fi
out=build/app/outputs/flutter-apk
(cd $out && sha256sum app-*-release.apk > SHA256SUMS)
repo=$( [[ -f android/brand.properties ]] && grep -E '^updates=' android/brand.properties | cut -d= -f2- || true)
gh release create "v$version" $out/app-*-release.apk $out/SHA256SUMS \
  ${repo:+--repo "$repo"} --title "v$version" --notes "${notes:-Version $version}"
echo "Published v$version. Commit pubspec.yaml and app_info.dart."
