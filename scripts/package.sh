#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <path-to-iMacSwitch.app> <output-directory>" >&2
  exit 1
fi

app_path="$1"
output_dir="$2"

if [[ ! -d "${app_path}" ]]; then
  echo "app not found: ${app_path}" >&2
  exit 1
fi

version="$(plutil -extract CFBundleShortVersionString raw "${app_path}/Contents/Info.plist")"
mkdir -p "${output_dir}"

zip_path="${output_dir}/iMacSwitch-${version}.app.zip"
dmg_path="${output_dir}/iMacSwitch-${version}.dmg"
staging_dir="$(mktemp -d)"
trap 'rm -rf "${staging_dir}"' EXIT

ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${zip_path}"
ditto "${app_path}" "${staging_dir}/iMacSwitch.app"
ln -s /Applications "${staging_dir}/Applications"
hdiutil create \
  -volname iMacSwitch \
  -srcfolder "${staging_dir}" \
  -ov \
  -format UDZO \
  "${dmg_path}"

echo "${zip_path}"
echo "${dmg_path}"
