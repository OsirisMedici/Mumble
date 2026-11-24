#!/bin/bash
# Install a pinned Mumble preview without changing macOS security settings.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C
umask 077
release='v0.1.0-preview.2'
version='0.1.0'
base="https://github.com/OsirisMedici/Mumble/releases/download/$release"
destination="$HOME/Applications"
verify_only=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) echo "Usage: bash macos.sh [--verify-only] [--destination /absolute/DIRECTORY]"; exit 0 ;;
    --verify-only) verify_only=true; shift ;;
    --destination) [ "$#" -ge 2 ] || exit 2; destination="$2"; shift 2 ;;
    *) echo "Usage: bash macos.sh [--verify-only] [--destination DIRECTORY]" >&2; exit 2 ;;
  esac
done
case "$destination" in /*) ;; *) echo "Destination must be an absolute path." >&2; exit 2 ;; esac
[ ! -L "$destination" ] || { echo "Destination must not be a symlink." >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || { echo 'This script requires macOS.' >&2; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || { echo 'Mumble requires macOS 13 or newer.' >&2; exit 1; }
if [ "$(uname -m)" = arm64 ] || [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then
  target=aarch64-apple-darwin; cpu=arm64
else
  target=x86_64-apple-darwin; cpu=x86_64
fi
asset="Mumble_${version}_${target}.app.zip"
work=$(mktemp -d "${TMPDIR:-/tmp}/mumble-install.XXXXXX")
stage=''
lock=''
backup=''
activated=false
success=false
cleanup() {
  status=$?
  trap - EXIT
  if ! "$success"; then
    if "$activated" && [ -e "$destination/Mumble.app" ]; then
      mv "$destination/Mumble.app" "$stage/failed.app" || true
    fi
    if [ -n "$backup" ] && [ -e "$backup" ] && [ ! -e "$destination/Mumble.app" ]; then
      mv "$backup" "$destination/Mumble.app" || echo "Restore the previous app from $backup" >&2
    fi
  fi
  [ -z "$stage" ] || rm -rf "$stage"
  [ -z "$lock" ] || rmdir "$lock"
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
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
case "$(file -b "$app/Contents/MacOS/karen-voice")" in
  *"Mach-O 64-bit executable $cpu"*) ;;
  *) echo 'Downloaded app has the wrong CPU architecture.' >&2; exit 1 ;;
esac
codesign --verify --deep --strict "$app"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$version" ]
[ -f "$app/Contents/Resources/resources/licenses/LICENSE" ]
[ -f "$app/Contents/Resources/resources/licenses/THIRD_PARTY_NOTICES.md" ]
if "$verify_only"; then
  echo "Verified $release for $cpu. No app was installed or launched."
  exit 0
fi
if pgrep -x karen-voice >/dev/null; then
  echo 'Quit Mumble before installing. Your running app has not changed.' >&2
  exit 1
fi
mkdir -p "$destination"
[ -w "$destination" ] || { echo "Destination is not writable." >&2; exit 1; }
# Stage on the destination filesystem, then activate with a rename.
if ! mkdir "$destination/.mumble-install.lock"; then
  echo 'Another install may be running. Inspect the install lock before retrying.' >&2
  exit 1
fi
lock="$destination/.mumble-install.lock"
stage=$(mktemp -d "$destination/.mumble-stage.XXXXXX")
ditto --rsrc --extattr "$app" "$stage/Mumble.app"
codesign --verify --deep --strict "$stage/Mumble.app"
if [ -L "$destination/Mumble.app" ]; then
  echo 'Existing app is a symlink. Keep it and review the destination manually.' >&2
  exit 1
fi
if [ -e "$destination/Mumble.app" ]; then
  existing="$destination/Mumble.app"
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$existing/Contents/Info.plist")" = com.osirismedici.karenvoice ]
  old=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$existing/Contents/Info.plist")
  [[ "$old" =~ ^[0-9]{1,9}\.[0-9]{1,9}\.[0-9]{1,9}$ ]] || { echo 'Unrecognized installed version. Review manually.' >&2; exit 1; }
  IFS=. read -r oa ob oc <<< "$old"
  IFS=. read -r na nb nc <<< "$version"
  if ((10#$oa > 10#$na || (10#$oa == 10#$na && 10#$ob > 10#$nb) || (10#$oa == 10#$na && 10#$ob == 10#$nb && 10#$oc > 10#$nc))); then
    echo "Refusing downgrade from $old to $version." >&2; exit 1
  fi
  if cmp -s "$existing/Contents/MacOS/karen-voice" "$app/Contents/MacOS/karen-voice" && diff -qr "$existing/Contents/Resources" "$app/Contents/Resources" >/dev/null && codesign --verify --deep --strict "$existing"; then
    success=true
    echo "The verified preview is already installed at $existing. Nothing replaced."
    exit 0
  fi
  backup="$destination/Mumble.backup.$(date +%Y%m%d-%H%M%S).app"
  [ ! -e "$backup" ] || { echo 'Backup already exists. Retry later.' >&2; exit 1; }
  mv "$destination/Mumble.app" "$backup"
  echo "Previous app preserved at $backup"
fi
if pgrep -x karen-voice >/dev/null; then
  echo 'Mumble started during installation. Quit it and retry.' >&2; exit 1
fi
mv "$stage/Mumble.app" "$destination/Mumble.app"
activated=true
codesign --verify --deep --strict "$destination/Mumble.app"
success=true
echo "Installed $release at $destination/Mumble.app"
echo 'Open Mumble, approve first-launch security and microphone/Accessibility prompts, then download a model.'
echo 'Preview builds are ad-hoc signed, not Apple notarized. Settings and downloaded models are retained.'
