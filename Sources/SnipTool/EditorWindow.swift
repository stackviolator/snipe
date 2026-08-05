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
        let actionBarH: CGFloat = 48
        let winSize = NSSize(width: max(display.width, 560),
                             height: display.height + toolbarH + actionBarH)

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
        buildUI(toolbarHeight: toolbarH, actionBarHeight: actionBarH)
        wireToolbar()
        installKeyHandler()

        canvas.onAnnotationAdded = { [weak self] in
            guard let self else { return }
            self.undoHistory.append(self.canvas.annotations.map { $0 })
            self.redoHistory.removeAll()
        }
    }

    deinit {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout

    private func buildUI(toolbarHeight: CGFloat, actionBarHeight: CGFloat) {
        let root = NSView(frame: window.contentView!.bounds)
        root.autoresizingMask = [.width, .height]

        // Top toolbar (tools + color + width)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(toolbar)

        // Canvas in scroll view
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.documentView = canvas
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(white: 0.15, alpha: 1)
        root.addSubview(scroll)

        // Bottom action bar
        let actionBar = buildActionBar()
        root.addSubview(actionBar)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight),

            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: actionBar.topAnchor),

            actionBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            actionBar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            actionBar.heightAnchor.constraint(equalToConstant: actionBarHeight),
        ])

        window.contentView = root
    }

    private func buildActionBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.translatesAutoresizingMaskIntoConstraints = false

        // Top border
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.separatorColor.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(border)

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        bar.addSubview(stack)

        // Undo / Redo
        let undo = NSButton(title: "Undo", target: self, action: #selector(undoAction))
        undo.image = NSImage(systemSymbolName: "arrow.uturn.backward",
                              accessibilityDescription: "Undo")
        undo.imagePosition = .imageLeading
        undo.bezelStyle = .recessed
        undo.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(undo)

        let redo = NSButton(title: "Redo", target: self, action: #selector(redoAction))
        redo.image = NSImage(systemSymbolName: "arrow.uturn.forward",
                              accessibilityDescription: "Redo")
        redo.imagePosition = .imageLeading
        redo.bezelStyle = .recessed
        redo.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(redo)

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        // Copy (primary action — Enter triggers it)
        let copy = NSButton(title: "  Copy to Clipboard  ", target: self,
                            action: #selector(copyAction))
        copy.image = NSImage(systemSymbolName: "doc.on.doc",
                              accessibilityDescription: "Copy")
        copy.imagePosition = .imageLeading
        copy.bezelStyle = .rounded
        copy.font = .systemFont(ofSize: 13, weight: .semibold)
        copy.keyEquivalent = "\r"
        copy.contentTintColor = .controlAccentColor
        stack.addArrangedSubview(copy)

        // Save
        let save = NSButton(title: "Save", target: self, action: #selector(saveAction))
        save.image = NSImage(systemSymbolName: "square.and.arrow.down",
                              accessibilityDescription: "Save")
        save.imagePosition = .imageLeading
        save.bezelStyle = .rounded
        save.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(save)

        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: bar.topAnchor),
            border.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),

            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])

        return bar
    }

    // MARK: - Toolbar wiring

    private func wireToolbar() {
        toolbar.onToolChanged = { [weak self] t in self?.canvas.currentTool = t }
        toolbar.onColorChanged = { [weak self] c in self?.canvas.currentColor = c }
        toolbar.onLineWidthChanged = { [weak self] w in self?.canvas.currentLineWidth = w }
    }

    // MARK: - Keyboard shortcuts

    private func installKeyHandler() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }

            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "z":
                    if event.modifierFlags.contains(.shift) { self.redoAction() }
                    else { self.undoAction() }
                    return nil
                case "c":
                    self.copyAction(); return nil
                case "s":
                    self.saveAction(); return nil
                default: break
                }
            }

            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
               !(self.window.firstResponder is NSText) {
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

            if event.keyCode == 53 { self.window.close(); return nil }
            return event
        }
    }

    // MARK: - Actions

    @objc private func undoAction() {
        guard !canvas.annotations.isEmpty else { return }
        redoHistory.append(canvas.annotations.map { $0 })
        canvas.annotations = undoHistory.popLast() ?? []
        canvas.needsDisplay = true
    }

    @objc private func redoAction() {
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(canvas.annotations.map { $0 })
        canvas.annotations = next
        canvas.needsDisplay = true
    }

    @objc private func copyAction() {
        let image = canvas.renderFinalImage()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        window.close()
    }

    @objc private func saveAction() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "screenshot.png"
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] resp in
            guard resp == .OK, let url = panel.url, let self else { return }
            let img = self.canvas.renderFinalImage()
            if let tiff = img.tiffRepresentation,
               let bmp = NSBitmapImageRep(data: tiff),
               let data = bmp.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
            }
            self.window.close()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        (NSApp.delegate as? AppDelegate)?.editorController = nil
    }
}
