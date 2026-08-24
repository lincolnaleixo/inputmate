#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
package_root="${script_dir:h}"
configuration="${CONFIGURATION:-release}"
app_path="${1:-${package_root}/.build/app/InputMate.app}"
bundle_id="${INPUTMATE_BUNDLE_ID:-com.robot.InputMate}"
team_id="${INPUTMATE_TEAM_ID:-4F3CBH5L9D}"
distribution_identity="${INPUTMATE_DISTRIBUTION_IDENTITY:-Developer ID Application: BUYFROMUS LLC (${team_id})}"

# Public builds default to ad-hoc signing so the project can build on any Mac
# without requiring a private certificate. Developers who need a stable macOS
# designated requirement can provide their own signing identity locally:
#
#   CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" zsh scripts/build-app.sh
#
# CODESIGN_REQUIREMENT is optional and is useful when preserving Accessibility
# grants across local rebuilds with a stable team identity.
identity="${CODESIGN_IDENTITY:--}"
default_requirement="identifier \"$bundle_id\" and anchor apple generic and certificate leaf[subject.OU] = \"$team_id\""
if [[ "$identity" == "-" ]]; then
  requirement="${CODESIGN_REQUIREMENT:-}"
else
  requirement="${CODESIGN_REQUIREMENT:-$default_requirement}"
fi

fail() {
  print -u2 -- "build-app.sh: $*"
  exit 1
}

source_version="$(tr -d '[:space:]' < "$package_root/version.txt")"
version="${INPUTMATE_VERSION:-$source_version}"
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] ||
  fail "invalid application version: $version"

# Sparkle compares CFBundleVersion, not CFBundleShortVersionString. InputMate's
# private/pre-public builds used CFBundleVersion=1, so using the public semver
# directly (for example 0.1.0) makes Sparkle treat the first public release as
# older than those builds. Keep the user-facing semver unchanged and map it to
# a monotonically ordered build version by offsetting the major component.
#
#   0.1.0 -> 1.1.0
#   0.1.1 -> 1.1.1
#   1.0.0 -> 2.0.0
#
# INPUTMATE_BUILD_VERSION remains available for explicit release engineering
# overrides, but normal builds should rely on this deterministic mapping.
version_parts=("${(@s:.:)version}")
default_build_version="$((version_parts[1] + 1)).${version_parts[2]}.${version_parts[3]}"
build_version="${INPUTMATE_BUILD_VERSION:-$default_build_version}"
[[ "$build_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] ||
  fail "invalid build version: $build_version"

if [[ "${INPUTMATE_REQUIRE_DISTRIBUTION:-0}" == 1 ]]; then
  [[ "$identity" == "$distribution_identity" ]] ||
    fail "distribution build requires identity: $distribution_identity"
fi

if [[ "$identity" != "-" ]]; then
  /usr/bin/security find-identity -v -p codesigning |
    /usr/bin/grep -Fq "\"$identity\"" ||
    fail "signing identity is not available: $identity"
fi

cd "$package_root"
swift build --configuration "$configuration" --product InputMate
binary_dir="$(swift build --configuration "$configuration" --show-bin-path)"
sparkle_framework="$(
  find "$package_root/.build/artifacts" \
    -type d -name Sparkle.framework -print -quit 2>/dev/null
)"
[[ -n "$sparkle_framework" ]] || fail "Sparkle.framework was not resolved by SwiftPM"

if [[ -e "$app_path" ]]; then
  rm -rf -- "$app_path"
fi

mkdir -p \
  "$app_path/Contents/MacOS" \
  "$app_path/Contents/Frameworks" \
  "$app_path/Contents/Resources"
cp "$package_root/App/Info.plist" "$app_path/Contents/Info.plist"
cp "$binary_dir/InputMate" "$app_path/Contents/MacOS/InputMate"
cp "$package_root/LICENSE" "$app_path/Contents/Resources/LICENSE"
/usr/bin/ditto \
  "$sparkle_framework" \
  "$app_path/Contents/Frameworks/Sparkle.framework"

# Keep release and signing metadata outside source-controlled machine-specific
# configuration while ensuring every packaged bundle has monotonic versions.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" \
  "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" \
  "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_version" \
  "$app_path/Contents/Info.plist"

/usr/bin/otool -L "$app_path/Contents/MacOS/InputMate" |
  /usr/bin/grep -Fq '@rpath/Sparkle.framework/' ||
  fail "InputMate is not linked to the embedded Sparkle framework"

sign_code() {
  local target="$1"
  local -a arguments

  arguments=(
    --force
    --options runtime
    --timestamp
    --sign "$identity"
  )
  if [[ "$target" != "$app_path" ]]; then
    arguments+=(--preserve-metadata=entitlements)
  fi
  /usr/bin/codesign "${arguments[@]}" "$target"
}

sign_sparkle_components() {
  local framework="$1"
  local version_dir="$framework/Versions/B"
  local path
  local -a bundles

  [[ -d "$version_dir" ]] ||
    version_dir="$framework/Versions/Current"

  # Sparkle contains nested apps and XPC services. Sign every Mach-O leaf
  # first, then each containing bundle, and the framework last. This keeps
  # the nested signatures valid without relying on codesign --deep.
  while IFS= read -r -d '' path; do
    if /usr/bin/file -b "$path" | /usr/bin/grep -Eq 'Mach-O|shared library'; then
      sign_code "$path"
    fi
  done < <(/usr/bin/find "$version_dir" -type f -print0)

  bundles=("${(@f)$(/usr/bin/find "$version_dir" -type d \( -name '*.app' -o -name '*.xpc' \) -print | /usr/bin/awk '{ print length, $0 }' | /usr/bin/sort -rn | /usr/bin/cut -d' ' -f2-)}")
  for path in "${bundles[@]}"; do
    [[ -n "$path" ]] && sign_code "$path"
  done

  sign_code "$framework"
}

if [[ "$identity" != "-" ]]; then
  sign_sparkle_components "$app_path/Contents/Frameworks/Sparkle.framework"
fi

codesign_arguments=(
  --force
  --options runtime
  --entitlements "$package_root/App/InputMate.entitlements"
  --sign "$identity"
)
if [[ -n "$requirement" ]]; then
  codesign_arguments+=(--requirements "$requirement")
fi
if [[ "$identity" != "-" ]]; then
  codesign_arguments+=(--timestamp)
fi

/usr/bin/codesign "${codesign_arguments[@]}" "$app_path"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"

print -r -- "$app_path"
