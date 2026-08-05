# Snipe

Fast, native screenshot tool for macOS. Capture, annotate, copy — all inline. No separate editor window. Swift + AppKit.

## Features

- **Inline capture + annotate** — select area, annotate directly on the overlay, copy
- **Full screen capture** with editor
- **Annotations**: arrow, rectangle, ellipse, line, text, highlight, blur, freehand pen, numbered counters
- **Select tool**: move, resize, delete any annotation after placing it
- **Copy to clipboard** or **save to file** (PNG)
- **Global hotkeys** — Cmd+Shift+X (area), Ctrl+Shift+3 (full screen)
- **Menu bar app** — no Dock icon, always ready

## Install

### Homebrew — prebuilt app (recommended)

The cask lives in this repo (`Casks/snipe.rb`) and installs the signed prebuilt app:

```bash
brew tap stackviolator/snipe https://github.com/stackviolator/snipe.git
brew install --cask snipe
```

> On Homebrew 6+, the first install may ask to trust the tap:
> `brew trust stackviolator/snipe`
> The shorthand `brew tap stackviolator/snipe` also works and pulls the same
> cask from the legacy `homebrew-snipe` tap repo.

### Homebrew — build from source

A formula is included in `Formula/snipe.rb` (requires Xcode):

```bash
brew tap stackviolator/snipe https://github.com/stackviolator/snipe.git
brew install snipe
```

### From Source

```bash
git clone https://github.com/stackviolator/snipe.git
cd snipe
make install
```

## Usage

Snipe lives in your menu bar. Press **⌘⇧X** to capture.

1. Drag to select an area — toolbar appears instantly
2. Pick a tool and annotate
3. Press **Enter** to copy to clipboard, or **⌘S** to save

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ⌘⇧X | Capture area |
| ⌃⇧3 | Capture full screen |
| V | Select / move tool |
| A | Arrow |
| R | Rectangle |
| E | Ellipse |
| L | Line |
| T | Text |
| H | Highlight |
| B | Blur |
| P | Pen |
| N | Counter |
| Enter | Copy & close |
| ⌘S | Save to file |
| ⌘Z | Undo |
| ⌘⇧Z | Redo |
| Delete | Remove selected annotation |
| Escape | Cancel / deselect |

## Permissions

On first launch, grant **Screen Recording** permission:
System Settings → Privacy & Security → Screen Recording → enable Snipe.

## License

MIT
