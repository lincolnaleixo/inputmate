cask "inputmate" do
  version "0.5.0"
  sha256 "d0d542c69a4580d282ceea6589f67bdb62bddd80f52597ca294d49ee78b5aa88"

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
