cask "inputmate" do
  version "0.2.0"
  sha256 "4531bc64f9e3e2957e2364810a92bb562f9cb64d922a1c87083ce5aad0dfc071"

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
