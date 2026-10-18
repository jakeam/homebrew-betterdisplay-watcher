# BetterDisplay Watcher

A macOS background agent that opens BetterDisplay when you connect an external monitor and quits it when you disconnect the last one.

## Why

While BetterDisplay runs, it keeps WindowServer busy even with no monitor attached. WindowServer is the macOS process that draws the screen, and keeping it busy drains the battery.

If you only need BetterDisplay with a monitor connected, you can quit it every time you unplug, but that's easy to forget. The watcher does it for you.

## How it works

macOS notifies the watcher whenever displays change, so it never polls. After a change it waits 3 seconds for the displays to settle, then checks for a physical external monitor. BetterDisplay's virtual displays don't count.

When the watcher starts, it opens BetterDisplay if a monitor is connected and quits it if not. After that, it acts only when a monitor connects or the last one disconnects. If you open BetterDisplay by hand with no monitor attached, it stays open until the watcher next starts, for example at your next login.

When idle, the watcher uses no measurable CPU or energy and about 10 MB of memory.

## Requirements

- A Mac with Apple Silicon.
- BetterDisplay at `/Applications/BetterDisplay.app`.
- The Swift compiler from Xcode or the Command Line Tools. Homebrew needs the Command Line Tools too, so a Mac with Homebrew already has the compiler.

## Install with Homebrew

```sh
brew install --cask betterdisplay   # skip if BetterDisplay is already installed
brew install jakeam/betterdisplay-watcher/betterdisplay-watcher
brew services start betterdisplay-watcher
```

`brew services start` makes the watcher start at login. Turn off BetterDisplay's own "launch at login" setting, so it doesn't open when no monitor is attached.

To check what the watcher detects, run `betterdisplay-watcher --status`. The log is at `$(brew --prefix)/var/log/betterdisplay-watcher.log`.

To remove it:

```sh
brew services stop betterdisplay-watcher
brew uninstall betterdisplay-watcher
```

## Install by hand

launchd needs absolute paths, so the plist has a `__HOME__` placeholder that the `sed` step below replaces with your home folder.

```sh
swiftc -O -swift-version 5 display-watcher.swift -o "BetterDisplay Watcher"
mkdir -p ~/Library/Application\ Support/BetterDisplayWatcher
cp "BetterDisplay Watcher" ~/Library/Application\ Support/BetterDisplayWatcher/
sed "s|__HOME__|$HOME|g" local.betterdisplay-watcher.plist > ~/Library/LaunchAgents/local.betterdisplay-watcher.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.betterdisplay-watcher.plist
```

The log is at `~/Library/Logs/betterdisplay-watcher.log`. System Settings lists the watcher as "BetterDisplay Watcher" under Allow in the Background, in Login Items & Extensions. Leave it switched on, or macOS won't start it at login.

To remove it:

```sh
launchctl bootout gui/$(id -u)/local.betterdisplay-watcher
rm ~/Library/LaunchAgents/local.betterdisplay-watcher.plist
rm -r ~/Library/Application\ Support/BetterDisplayWatcher
```

Don't run a manual install and a Homebrew install at the same time. Both copies would open and quit BetterDisplay.

## Limitations

The watcher doesn't detect monitors on a DisplayLink USB dock, because DisplayLink doesn't use the Mac's own display hardware.

## Releasing a new version

The formula in `Formula/betterdisplay-watcher.rb` builds from a git tag.

1. Push your changes to `main`.
2. Tag the commit and push the tag, for example `git tag v1.0.1 && git push origin v1.0.1`.
3. Set `tag:` in the formula to the new tag, then commit and push.
