import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var captureOverlay: CaptureOverlay?
    var editorController: EditorWindowController?
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerHotKey()
        checkPermissionOnLaunch()
    }

    // MARK: - Permission

    private func checkPermissionOnLaunch() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            showPermissionAlert()
        }
    }

    private func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "SnipTool needs Screen Recording permission to capture your windows.\n\nEnable it in System Settings → Privacy & Security → Screen Recording, then relaunch SnipTool."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "SnipTool")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture Area",
                                     action: #selector(startAreaCapture),
                                     keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        let fullItem = NSMenuItem(title: "Capture Full Screen",
                                  action: #selector(startFullScreenCapture),
                                  keyEquivalent: "")
        fullItem.target = self
        menu.addItem(fullItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit SnipTool",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Global hot key (Ctrl+Shift+4)

    private func registerHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x534E_4950
        hotKeyID.id = 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.startAreaCapture()
            }
            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), handler,
                            1, &eventType, nil, &handlerRef)

        RegisterEventHotKey(UInt32(kVK_ANSI_4),
                            UInt32(controlKey | shiftKey),
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    // MARK: - Capture actions

    @objc func startAreaCapture() {
        guard hasScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        captureOverlay = CaptureOverlay { [weak self] image in
            self?.openEditor(with: image)
        }
        captureOverlay?.show()
    }

    @objc private func startFullScreenCapture() {
        guard hasScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        guard let screen = NSScreen.main else { return }
        let cgRect = CGRect(x: 0, y: 0,
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
