# SnipTool

A fast, lightweight screenshot tool for macOS. Native Swift + AppKit.

## Features

- **Area capture** with movable, resizable selection
- **Full screen capture**
- **Annotation editor**: arrow, rectangle, ellipse, line, text, highlight, blur, freehand pen, numbered counters
- **Copy to clipboard** or **save to file** (PNG)
- **Global hotkey** — Ctrl+Shift+4
- **Menu bar** app (no Dock icon)
- Undo/redo, keyboard shortcuts for all tools

## Install

### Homebrew

```bash
brew tap stackviolator/tap
brew install sniptool
```

### From Source

```bash
git clone https://github.com/stackviolator/sniptool.git
cd sniptool
make build
make install   # copies SnipTool.app to /Applications
```

## Usage

SnipTool lives in your menu bar. Click the camera icon or press **Ctrl+Shift+4** to start a capture.

1. Click and drag to select an area
2. Move or resize the selection with handles
3. Press **Enter** or double-click to capture
4. Annotate in the editor, then **⌘C** to copy or **⌘S** to save

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+Shift+4 | Start capture |
| Enter | Confirm selection |
| Escape | Cancel / close editor |
| A | Arrow |
| R | Rectangle |
| E | Ellipse |
| L | Line |
| T | Text |
| H | Highlight |
| B | Blur |
| P | Pen |
| N | Counter |
| ⌘Z | Undo |
| ⌘⇧Z | Redo |
| ⌘C | Copy to clipboard |
| ⌘S | Save to file |

## Permissions

Grant **Screen Recording** on first launch:
System Settings → Privacy & Security → Screen Recording → enable SnipTool.

## License

MIT
