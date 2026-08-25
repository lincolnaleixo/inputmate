cask "inputmate" do
  version "0.2.1"
  sha256 "2e22fcb023869747881816802c4af626986c7d7801844e605f92c302e405efd7"

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
