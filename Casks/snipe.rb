cask "snipe" do
  version "2.0.0"
  sha256 "d4397f30758424468350e16876cdd9b972ad07e2505fd3220a5cd57c31a7bed9"

  url "https://github.com/stackviolator/snipe/releases/download/v#{version}/snipe-#{version}-macos.tar.gz"
  name "Snipe"
  desc "Fast, professional screenshot capture and annotation tool for macOS"
  homepage "https://github.com/stackviolator/snipe"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Snipe.app"

  zap trash: [
    "~/Library/Preferences/com.snipe.app.plist",
  ]
end
