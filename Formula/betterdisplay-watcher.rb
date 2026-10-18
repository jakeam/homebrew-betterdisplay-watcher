class BetterdisplayWatcher < Formula
  desc "Opens BetterDisplay only while an external monitor is connected"
  homepage "https://github.com/jakeam/homebrew-betterdisplay-watcher"
  url "https://github.com/jakeam/homebrew-betterdisplay-watcher.git", tag: "v1.0.0"
  license "MIT"
  head "https://github.com/jakeam/homebrew-betterdisplay-watcher.git", branch: "main"

  depends_on arch: :arm64
  depends_on :macos

  def install
    # Login Items shows the executable's name, so keep the readable one in libexec.
    libexec.mkpath
    system "swiftc", "-O", "-swift-version", "5", "display-watcher.swift", "-o", libexec/"BetterDisplay Watcher"
    bin.install_symlink libexec/"BetterDisplay Watcher" => "betterdisplay-watcher"
  end

  service do
    run opt_libexec/"BetterDisplay Watcher"
    keep_alive true
    process_type :background
    log_path var/"log/betterdisplay-watcher.log"
    error_log_path var/"log/betterdisplay-watcher.log"
  end

  def caveats
    <<~EOS
      The watcher expects BetterDisplay at /Applications/BetterDisplay.app:
        brew install --cask betterdisplay

      Turn off BetterDisplay's own "launch at login" setting, then start the watcher:
        brew services start betterdisplay-watcher
    EOS
  end

  test do
    assert_match "monitor connected:", shell_output("#{bin}/betterdisplay-watcher --status")
  end
end
