#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${CONFIGURATION:-Debug}"
derived_data="${DERIVED_DATA:-${repo_root}/.build/DerivedData}"
code_signing_allowed="${CODE_SIGNING_ALLOWED:-NO}"

xcodebuild clean build \
  -project "${repo_root}/iMacSwitch.xcodeproj" \
  -scheme iMacSwitch \
  -configuration "${configuration}" \
  -derivedDataPath "${derived_data}" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED="${code_signing_allowed}"
