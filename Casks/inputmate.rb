cask "inputmate" do
  version "0.2.2"
  sha256 "285abd1f12a9256410ead978dc1700f4b8c8f73e4960101a12a9df46fe1d1ce8"

  url "https://github.com/lincolnaleixo/inputmate/releases/download/v#{version}/InputMate.dmg",
      verified: "github.com/lincolnaleixo/inputmate/"
  name "InputMate"
  desc "Menu bar utility for mouse input, shortcuts, and text transformations"
  homepage "https://github.com/lincolnaleixo/inputmate"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :ventura

  app "InputMate.app"

  zap trash: [
    "~/Library/Caches/com.robot.InputMate",
    "~/Library/Preferences/com.robot.InputMate.plist",
    "~/Library/Saved Application State/com.robot.InputMate.savedState",
  ]

  caveats <<~EOS
    Because InputMate uses Accessibility permissions, macOS may ask you to
    re-enable access after an update.
  EOS
end
