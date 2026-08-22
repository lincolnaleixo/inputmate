cask "inputmate" do
  version "0.1.1"
  sha256 "7ffc7384ba07ee4902370551d8149ba7eea62a14357bf8a4ffc1bc5e7ec08ed2"

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
