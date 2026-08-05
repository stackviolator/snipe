# Snipe

A fast, professional screenshot capture & annotation tool for macOS. Menu-bar native, zero dependencies, built with Swift + AppKit.

Snipe is a free, open-source alternative to Flameshot / CleanShot / Shottr for when you want something simple, reliable, and right on your menu bar.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **One-key capture** — global hotkey `⌘⇧A`, menu bar icon, or `open -a Snipe --args --capture`
- **Full-screen selection overlay** with:
  - Drag to select, **drag inside to move** the selection, 8 resize handles
  - **Magnifier loupe** for pixel-perfect selection
  - **Window snap** (`Space`) — instantly selects the window under the cursor
  - Live pixel-size label, dimmed surround, arrow-key nudging
- **Pro annotation editor**:
  - Pen, arrow, line, rectangle, ellipse, text, numbered steps, highlight, blur, pixelate
  - Move / resize / nudge any annotation, inline text editing
  - Undo / redo, delete, fill mode, color picker, stroke width
  - Zoom (`⌘=` / `⌘-` / `⌘0`), pan, scroll & pinch zoom
- **Export**:
  - Copy to clipboard as **PNG + TIFF** (pastes everywhere, `Enter` or `⌘C`)
  - Save as PNG / JPEG / TIFF
- Multi-display capture, Retina (2x) resolution output

## Install

### Homebrew (recommended)

```sh
brew tap stackviolator/homebrew-snipe
brew install --cask snipe
```

### Manual

Download the latest `Snipe-<version>.zip` from [Releases](https://github.com/stackviolator/snipe/releases), unzip, and drag `Snipe.app` to Applications.

> **First launch:** right-click `Snipe.app` → **Open** (or run `xattr -cr /Applications/Snipe.app`), then grant **Screen Recording** permission in System Settings → Privacy & Security → Screen Recording. This is required by macOS for any screenshot tool.

### Build from source

```sh
git clone https://github.com/stackviolator/snipe.git
cd snipe
./build.sh        # requires Xcode command line tools (swift)
open dist/Snipe.app
```

## Usage

1. Trigger capture with `⌘⇧A` (or the menu bar icon).
2. Drag to select an area. Fine-tune with handles / arrows, or press `Space` to grab the window under the cursor.
3. Press `Enter` to open the editor, `C` to copy immediately, or `Esc` to cancel.
4. Annotate with the toolbar, then `Enter` / Copy to clipboard, or Save.

### Hotkeys

| Key | Action |
| --- | --- |
| `⌘⇧A` | Start capture (global) |
| `Space` | Snap selection to window under cursor |
| `⏎` | Confirm selection / copy & close editor |
| `C` | Copy selection immediately (no editor) |
| `Esc` | Cancel |
| `⌘Z` / `⇧⌘Z` | Undo / redo |
| `⌘=`, `⌘-`, `⌘0` | Zoom in / out / fit |
| `⌘C` | Copy & close |
| `⌘S` | Save as… |

## Development

- `swift build` — build
- `./build.sh` — build release `.app` bundle into `dist/`
- `.build/debug/Snipe --render-test` — render one of every annotation type to `/tmp/snipe-render-test.png` (smoke test)
- `swift make-icon.swift` — regenerate `Resources/AppIcon.icns`

The app is a single Swift Package with no third-party dependencies: `AppKit` (UI), `CoreImage` (blur/pixelate), `Carbon` (global hotkey), `CoreText` (export text rendering).

## Roadmap / ideas

- Configurable hotkey (currently hardcoded `⌘⇧A`)
- Scrolling capture (long pages)
- OCR copy text
- Pin to screen

## License

[MIT](LICENSE)
