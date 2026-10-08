#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

plutil -lint \
  "${repo_root}/iMacSwitch/Info.plist" \
  "${repo_root}/iMacSwitch/iMacSwitch.entitlements" >/dev/null

if grep -R -n -E \
  'MegaManSec/magic-switch|com\.megamansec\.magic-switch|_magicswitch\._tcp|Magic_Switch' \
  "${repo_root}/iMacSwitch" "${repo_root}/iMacSwitch.xcodeproj"; then
  echo "Found stale Magic Switch project identifiers." >&2
  exit 1
fi

xcodebuild -project "${repo_root}/iMacSwitch.xcodeproj" -scheme iMacSwitch -list >/dev/null
echo "Project metadata checks passed."
