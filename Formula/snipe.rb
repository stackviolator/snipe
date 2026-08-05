class Snipe < Formula
  desc "Fast, native screenshot tool for macOS — capture, annotate, copy"
  homepage "https://github.com/stackviolator/snipe"
  url "https://github.com/stackviolator/snipe/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "3567ebc0869de51018e0ee94c036fa810739ad08c01f80471f5e922204fb523a"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    app_contents = prefix/"Snipe.app/Contents"
    (app_contents/"MacOS").mkpath
    (app_contents/"Resources").mkpath
    (app_contents/"MacOS").install ".build/release/snipe"
    app_contents.install "Info.plist"
    (app_contents/"Resources").install "AppIcon.icns" if File.exist?("AppIcon.icns")

    system "codesign", "--force", "--sign", "-", prefix/"Snipe.app"
  end

  def caveats
    <<~EOS
      Snipe has been installed to:
        #{prefix}/Snipe.app

      To add to Applications:
        ln -sf #{prefix}/Snipe.app /Applications/

      Grant Screen Recording permission on first launch:
        System Settings → Privacy & Security → Screen Recording

      Hotkeys:
        ⌘⇧X  — Capture area
        ⌃⇧3  — Capture full screen
    EOS
  end

  test do
    assert_predicate prefix/"Snipe.app/Contents/MacOS/snipe", :exist?
  end
end
