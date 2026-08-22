#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
package_root="${script_dir:h}"
app_path="${1:-${package_root}/.build/app/InputMate.app}"
output_path="${2:-${package_root}/dist/InputMate.dmg}"
volume_name="${INPUTMATE_DMG_VOLUME_NAME:-InputMate}"

fail() {
  print -u2 -- "create-dmg.sh: $*"
  exit 1
}

[[ -d "$app_path" ]] || fail "app bundle not found: $app_path"
[[ "$output_path" == *.dmg ]] || fail "output path must end in .dmg"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"

output_dir="${output_path:h}"
mkdir -p "$output_dir"
output_path="${output_path:A}"

work_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/inputmate-dmg.XXXXXX")"
staging_dir="$work_dir/staging"

cleanup() {
  /bin/rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

mkdir -p "$staging_dir"
/usr/bin/ditto "$app_path" "$staging_dir/InputMate.app"
/bin/ln -s /Applications "$staging_dir/Applications"

/bin/rm -f -- "$output_path"
/usr/bin/hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$output_path" >/dev/null

/usr/bin/hdiutil verify "$output_path" >/dev/null
print -r -- "$output_path"
