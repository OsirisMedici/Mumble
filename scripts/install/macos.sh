#!/bin/bash
# Install a pinned Mumble preview without changing macOS security settings.
set -euo pipefail
release='v0.1.0-preview.2'
version='0.1.0'
base="https://github.com/OsirisMedici/Mumble/releases/download/$release"
destination="$HOME/Applications"
verify_only=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --verify-only) verify_only=true; shift ;;
    --destination) [ "$#" -ge 2 ] || exit 2; destination="$2"; shift 2 ;;
    *) echo "Usage: bash macos.sh [--verify-only] [--destination DIRECTORY]" >&2; exit 2 ;;
  esac
done
[ "$(uname -s)" = Darwin ] || { echo 'This script requires macOS.' >&2; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || { echo 'Mumble requires macOS 13 or newer.' >&2; exit 1; }
if [ "$(uname -m)" = arm64 ] || [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then
  target=aarch64-apple-darwin; cpu=arm64
else
  target=x86_64-apple-darwin; cpu=x86_64
fi
asset="Mumble_${version}_${target}.app.zip"
work=$(mktemp -d "${TMPDIR:-/tmp}/mumble-install.XXXXXX")
trap 'rm -rf "$work"' EXIT
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 "$base/$asset" -o "$work/$asset"
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 "$base/SHA256SUMS-$target.txt" -o "$work/sums.txt"
expected=$(awk -v name="$asset" '$2 == name { print $1 }' "$work/sums.txt")
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo 'Release checksum is missing or ambiguous.' >&2; exit 1; }
actual=$(shasum -a 256 "$work/$asset" | awk '{print $1}')
[ "$actual" = "$expected" ] || { echo 'Download checksum mismatch. Nothing installed.' >&2; exit 1; }
ditto -x -k "$work/$asset" "$work/unpacked"
app="$work/unpacked/Mumble.app"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = com.osirismedici.karenvoice ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$app/Contents/Info.plist")" = Mumble ]
lipo -verify_arch "$cpu" "$app/Contents/MacOS/karen-voice"
codesign --verify --deep --strict "$app"
if "$verify_only"; then
  echo "Verified $release for $cpu. No app was installed or launched."
  exit 0
fi
if pgrep -x karen-voice >/dev/null; then
  echo 'Quit Mumble before installing. Your running app has not changed.' >&2
  exit 1
fi
mkdir -p "$destination"
if [ -e "$destination/Mumble.app" ]; then
  backup="$destination/Mumble.backup.$(date +%Y%m%d-%H%M%S).app"
  [ ! -e "$backup" ] || { echo 'Backup already exists. Retry later.' >&2; exit 1; }
  mv "$destination/Mumble.app" "$backup"
  echo "Previous app preserved at $backup"
fi
mv "$app" "$destination/Mumble.app"
echo "Installed $release at $destination/Mumble.app"
echo 'Open Mumble, approve first-launch security and microphone/Accessibility prompts, then download a model.'
echo 'Preview builds are ad-hoc signed, not Apple notarized. Settings and downloaded models are retained.'
