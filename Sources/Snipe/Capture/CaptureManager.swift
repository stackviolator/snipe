import AppKit

/// Orchestrates the capture flow: overlay selection -> editor.
final class CaptureManager {
    static let shared = CaptureManager()
    private init() {}

    private(set) var isCapturing = false
    private var overlay: OverlayController?
    private var editor: EditorController?

    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        NSApp.activate(ignoringOtherApps: true)

        if !ScreenCapture.hasPermission() {
            ScreenCapture.requestPermission()
            presentPermissionAlert()
            isCapturing = false
            return
        }
        guard let composite = ScreenCapture.captureComposite() else {
            presentCaptureFailureAlert()
            isCapturing = false
            return
        }

        let controller = OverlayController(composite: composite)
        controller.onConfirm = { [weak self] cropRect in
            self?.beginEditor(composite: composite, cropRect: cropRect)
        }
        controller.onCopyNow = { [weak self] cropRect in
            self?.copySelection(composite: composite, cropRect: cropRect)
        }
        controller.onCancel = { [weak self] in
            self?.overlay = nil
            self?.isCapturing = false
        }
        overlay = controller
        controller.show()
    }

    private func cropImage(composite: CompositeImage, cropRect: CGRect) -> EditorImage? {
        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }
        let scale = composite.pixelsPerPoint
        let pixelRect = CGRect(x: cropRect.minX * scale,
                               y: cropRect.minY * scale,
                               width: cropRect.width * scale,
                               height: cropRect.height * scale)
        guard let cg = composite.cgImage.cropping(to: pixelRect) else { return nil }
        return EditorImage(cgImage: cg, pointSize: cropRect.size)
    }

    private func beginEditor(composite: CompositeImage, cropRect: CGRect) {
        overlay = nil
        guard let image = cropImage(composite: composite, cropRect: cropRect) else {
            isCapturing = false
            return
        }
        let controller = EditorController(image: image)
        controller.onClose = { [weak self] in
            self?.editor = nil
            self?.isCapturing = false
        }
        editor = controller
        controller.show()
    }

    private func copySelection(composite: CompositeImage, cropRect: CGRect) {
        overlay = nil
        defer { isCapturing = false }
        guard let image = cropImage(composite: composite, cropRect: cropRect) else { return }
        copyImageToPasteboard(NSImage(cgImage: image.cgImage, size: image.pointSize))
    }

    private func presentPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Snipe needs Screen Recording permission"
        alert.informativeText = "Enable Screen Recording for Snipe in System Settings → Privacy & Security → Screen Recording, then try again."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func presentCaptureFailureAlert() {
        let alert = NSAlert()
        alert.messageText = "Couldn't capture the screen"
        alert.informativeText = "Make sure Snipe has Screen Recording permission, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
