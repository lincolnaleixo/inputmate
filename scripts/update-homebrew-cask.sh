#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
package_root="${script_dir:h}"
version="${1:-}"
sha256="${2:-}"

fail() {
  print -u2 -- "update-homebrew-cask.sh: $*"
  exit 1
}

[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] ||
  fail "expected a semantic version, got: $version"
[[ "$sha256" =~ '^[0-9a-f]{64}$' ]] ||
  fail "expected a lowercase SHA-256 checksum"

mkdir -p "$package_root/Casks"
cat > "$package_root/Casks/inputmate.rb" <<EOF
cask "inputmate" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/matrix-hq/inputmate/releases/download/v#{version}/InputMate.dmg",
      verified: "github.com/matrix-hq/inputmate/"
  name "InputMate"
  desc "Menu bar utility for mouse input, shortcuts, and text transformations"
  homepage "https://github.com/matrix-hq/inputmate"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :ventura

  app "InputMate.app"

  zap trash: [
    "~/Library/Caches/com.robot.InputMate",
    "~/Library/Preferences/com.robot.InputMate.plist",
    "~/Library/Saved Application State/com.robot.InputMate.savedState",
  ]

  caveats <<~EOS
    InputMate is ad-hoc signed and is not notarized by Apple. On first launch,
    macOS may require approval in System Settings > Privacy & Security.

    Because InputMate uses Accessibility permissions, macOS may ask you to
    re-enable access after an update.
  EOS
end
EOF

print -r -- "$package_root/Casks/inputmate.rb"
