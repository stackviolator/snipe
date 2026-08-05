import AppKit
import UniformTypeIdentifiers

class EditorWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let canvas: AnnotationCanvas
    private let toolbar: EditorToolbar
    private var undoHistory: [[any Annotation]] = []
    private var redoHistory: [[any Annotation]] = []
    private var localMonitor: Any?

    init(image: NSImage) {
        let maxW: CGFloat = 1200, maxH: CGFloat = 800
        let scale = min(maxW / image.size.width,
                        maxH / image.size.height, 1)
        let display = NSSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let toolbarH: CGFloat = 44
        let winSize = NSSize(width: max(display.width, 500),
                             height: display.height + toolbarH)

        let screen = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(x: screen.midX - winSize.width / 2,
                             y: screen.midY - winSize.height / 2)

        window = NSWindow(contentRect: NSRect(origin: origin, size: winSize),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "SnipTool Editor"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        canvas = AnnotationCanvas(image: image)
        toolbar = EditorToolbar()

        super.init()
        window.delegate = self
        buildUI(toolbarHeight: toolbarH)
        wireToolbar()
        installKeyHandler()
    }

    deinit {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout

    private func buildUI(toolbarHeight: CGFloat) {
        let root = NSView(frame: window.contentView!.bounds)
        root.autoresizingMask = [.width, .height]

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(toolbar)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.documentView = canvas
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(white: 0.15, alpha: 1)
        root.addSubview(scroll)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        window.contentView = root
    }

    // MARK: - Toolbar wiring

    private func wireToolbar() {
        toolbar.onToolChanged = { [weak self] t in self?.canvas.currentTool = t }
        toolbar.onColorChanged = { [weak self] c in self?.canvas.currentColor = c }
        toolbar.onLineWidthChanged = { [weak self] w in self?.canvas.currentLineWidth = w }
        toolbar.onUndo = { [weak self] in self?.undo() }
        toolbar.onRedo = { [weak self] in self?.redo() }
        toolbar.onCopy = { [weak self] in self?.copyToClipboard() }
        toolbar.onSave = { [weak self] in self?.saveToFile() }

        canvas.onAnnotationAdded = { [weak self] in
            guard let self else { return }
            self.undoHistory.append(self.canvas.annotations.map { $0 })
            self.redoHistory.removeAll()
        }
    }

    // MARK: - Keyboard shortcuts

    private func installKeyHandler() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }

            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "z":
                    if event.modifierFlags.contains(.shift) { self.redo() }
                    else { self.undo() }
                    return nil
                case "c":
                    self.copyToClipboard(); return nil
                case "s":
                    self.saveToFile(); return nil
                default: break
                }
            }

            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                switch event.charactersIgnoringModifiers {
                case "a": self.toolbar.selectTool(.arrow);     return nil
                case "r": self.toolbar.selectTool(.rectangle); return nil
                case "e": self.toolbar.selectTool(.ellipse);   return nil
                case "l": self.toolbar.selectTool(.line);      return nil
                case "t": self.toolbar.selectTool(.text);      return nil
                case "h": self.toolbar.selectTool(.highlight); return nil
                case "b": self.toolbar.selectTool(.blur);      return nil
                case "p": self.toolbar.selectTool(.pen);       return nil
                case "n": self.toolbar.selectTool(.counter);   return nil
                default: break
                }
            }

            if event.keyCode == 53 { // Escape
                self.window.close(); return nil
            }
            return event
        }
    }

    // MARK: - Undo / Redo

    private func undo() {
        guard !canvas.annotations.isEmpty else { return }
        redoHistory.append(canvas.annotations.map { $0 })
        canvas.annotations = undoHistory.popLast() ?? []
        canvas.needsDisplay = true
    }

    private func redo() {
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(canvas.annotations.map { $0 })
        canvas.annotations = next
        canvas.needsDisplay = true
    }

    // MARK: - Export

    private func copyToClipboard() {
        let image = canvas.renderFinalImage()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        showToast("Copied!")
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "screenshot.png"
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] resp in
            guard resp == .OK, let url = panel.url,
                  let self else { return }
            let img = self.canvas.renderFinalImage()
            if let tiff = img.tiffRepresentation,
               let bmp = NSBitmapImageRep(data: tiff),
               let data = bmp.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - Toast

    private func showToast(_ msg: String) {
        let label = NSTextField(labelWithString: msg)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        label.layer?.cornerRadius = 6
        label.sizeToFit()
        label.frame.size.width += 24
        label.frame.size.height += 12

        let bounds = window.contentView!.bounds
        label.frame.origin = CGPoint(x: bounds.midX - label.frame.width / 2,
                                     y: bounds.midY - label.frame.height / 2)
        window.contentView?.addSubview(label)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                label.animator().alphaValue = 0
            }, completionHandler: { label.removeFromSuperview() })
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        (NSApp.delegate as? AppDelegate)?.editorController = nil
    }
}
