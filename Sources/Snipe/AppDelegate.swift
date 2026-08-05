import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var captureOverlay: CaptureOverlay?
    var editorController: EditorWindowController?
    private var hotKeyRef1: EventHotKeyRef?
    private var hotKeyRef2: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerHotKeys()
    }

    // MARK: - Status bar

    private func makeMenuBarIcon() -> NSImage {
        let s: CGFloat = 18
        let img = NSImage(size: NSSize(width: s, height: s))
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let cx = s / 2, cy = s / 2
            let r: CGFloat = 6.0
            let gap: CGFloat = 1.8
            let arm: CGFloat = 8.2
            let lw: CGFloat = 1.3

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(lw)
            ctx.setLineCap(.round)

            ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

            for (dx, dy) in [(0,1),(0,-1),(1,0),(-1,0)] as [(CGFloat, CGFloat)] {
                ctx.move(to: CGPoint(x: cx + dx * gap, y: cy + dy * gap))
                ctx.addLine(to: CGPoint(x: cx + dx * arm, y: cy + dy * arm))
            }
            ctx.strokePath()

            let dot: CGFloat = 1.2
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - dot, y: cy - dot, width: dot * 2, height: dot * 2))
        }
        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = makeMenuBarIcon()
        }

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture Area  (⌘⇧X)",
                                     action: #selector(startAreaCapture),
                                     keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        let fullItem = NSMenuItem(title: "Capture Full Screen  (⌃⇧3)",
                                  action: #selector(startFullScreenCapture),
                                  keyEquivalent: "")
        fullItem.target = self
        menu.addItem(fullItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Snipe",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Global hot keys

    private func registerHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async {
                let ad = NSApp.delegate as? AppDelegate
                switch hkID.id {
                case 1: ad?.startAreaCapture()
                case 2: ad?.startFullScreenCapture()
                default: break
                }
            }
            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), handler,
                            1, &eventType, nil, &handlerRef)

        // Cmd+Shift+X — area capture (flameshot style)
        let hk1 = EventHotKeyID(signature: 0x534E_4950, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_X), UInt32(cmdKey | shiftKey),
                            hk1, GetApplicationEventTarget(), 0, &hotKeyRef1)

        // Ctrl+Shift+3 — full screen capture
        let hk2 = EventHotKeyID(signature: 0x534E_4950, id: 2)
        RegisterEventHotKey(UInt32(kVK_ANSI_3), UInt32(controlKey | shiftKey),
                            hk2, GetApplicationEventTarget(), 0, &hotKeyRef2)
    }

    // MARK: - Capture actions

    @objc func startAreaCapture() {
        captureOverlay = CaptureOverlay()
        captureOverlay?.onDismiss = { [weak self] in self?.captureOverlay = nil }
        captureOverlay?.show()
    }

    @objc func startFullScreenCapture() {
        guard let screen = NSScreen.main else { return }
        let primaryMaxY = NSScreen.screens[0].frame.maxY
        let cgRect = CGRect(x: screen.frame.origin.x,
                            y: primaryMaxY - screen.frame.maxY,
                            width: screen.frame.width,
                            height: screen.frame.height)

        if let cgImage = CGWindowListCreateImage(cgRect, .optionOnScreenOnly,
                                                  kCGNullWindowID, [.bestResolution]) {
            let image = NSImage(cgImage: cgImage, size: screen.frame.size)
            openEditor(with: image)
        }
    }

    private func openEditor(with image: NSImage) {
        editorController = EditorWindowController(image: image)
        editorController?.showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
