import AppKit

/// Full-screen overlay where the user picks the region to capture.
final class OverlayController {
    let composite: CompositeImage
    var onConfirm: ((CGRect) -> Void)?
    var onCopyNow: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var window: NSWindow?
    private var overlayView: SelectionOverlayView?
    private var loupe: LoupeWindow?

    init(composite: CompositeImage) {
        self.composite = composite
    }

    func show() {
        let rect = composite.pointRect
        let window = NSWindow(contentRect: rect, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = SelectionOverlayView(composite: composite)
        view.onConfirm = { [weak self] r in self?.confirm(r) }
        view.onCopyNow = { [weak self] r in self?.copyNow(r) }
        view.onCancel = { [weak self] in self?.cancel() }
        window.contentView = view
        window.setFrame(rect, display: false)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        self.window = window
        self.overlayView = view

        let l = LoupeWindow(composite: composite)
        l.show()
        loupe = l
    }

    func confirm(_ rect: CGRect) {
        teardown()
        onConfirm?(rect)
    }

    func copyNow(_ rect: CGRect) {
        teardown()
        onCopyNow?(rect)
    }

    func cancel() {
        teardown()
        onCancel?()
    }

    private func teardown() {
        loupe?.close()
        loupe = nil
        window?.orderOut(nil)
        window = nil
        overlayView = nil
    }
}

// MARK: - Selection view

final class SelectionOverlayView: NSView {
    let composite: CompositeImage
    var onConfirm: ((CGRect) -> Void)?
    var onCopyNow: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private enum DragMode {
        case none
        case new
        case move
        case resize(Handle)
    }

    private var selection: CGRect?
    private var dragMode: DragMode = .none
    private var dragStart: CGPoint = .zero
    private var originalSelection: CGRect?
    private let image: NSImage

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(composite: CompositeImage) {
        self.composite = composite
        self.image = NSImage(cgImage: composite.cgImage, size: composite.pointSize)
        super.init(frame: composite.pointRect)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)

        if let sel = selection {
            NSColor.black.withAlphaComponent(0.45).setFill()
            let outside = [CGRect(x: 0, y: 0, width: bounds.width, height: sel.minY),
                           CGRect(x: 0, y: sel.maxY, width: bounds.width, height: bounds.height - sel.maxY),
                           CGRect(x: 0, y: sel.minY, width: sel.minX, height: sel.height),
                           CGRect(x: sel.maxX, y: sel.minY, width: bounds.width - sel.maxX, height: sel.height)]
            for r in outside { NSBezierPath(rect: r).fill() }

            // Border: black then white for visibility on any background.
            NSColor.black.setStroke()
            let outer = NSBezierPath(rect: sel.insetBy(dx: -1, dy: -1))
            outer.lineWidth = 1
            outer.stroke()
            NSColor.white.setStroke()
            let inner = NSBezierPath(rect: sel)
            inner.lineWidth = 1
            inner.stroke()

            drawHandles(in: sel)
            drawSizeLabel(for: sel)
        } else {
            NSColor.black.withAlphaComponent(0.30).setFill()
            NSBezierPath(rect: bounds).fill()
        }
        drawHintBar()
    }

    private func drawHandles(in sel: CGRect) {
        let handleSize: CGFloat = 7
        let positions: [(CGFloat, CGFloat)] = [
            (0, 0), (0.5, 0), (1, 0), (1, 0.5), (1, 1), (0.5, 1), (0, 1), (0, 0.5)
        ]
        NSColor.white.setFill()
        NSColor.black.setStroke()
        for (fx, fy) in positions {
            let r = CGRect(x: sel.minX + fx * sel.width - handleSize / 2,
                           y: sel.minY + fy * sel.height - handleSize / 2,
                           width: handleSize, height: handleSize)
            let p = NSBezierPath(rect: r)
            p.fill()
            p.lineWidth = 1
            p.stroke()
        }
    }

    private func drawSizeLabel(for sel: CGRect) {
        let px = Int((sel.width * composite.pixelsPerPoint).rounded())
        let py = Int((sel.height * composite.pixelsPerPoint).rounded())
        let text = "\(px) × \(py) px" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let pad: CGFloat = 6
        var box = CGRect(x: sel.midX - size.width / 2 - pad,
                         y: sel.minY - size.height - 14,
                         width: size.width + pad * 2,
                         height: size.height + pad * 2)
        // Keep on screen.
        box.origin.x = min(max(box.origin.x, 4), bounds.width - box.width - 4)
        if box.minY < 4 {
            box.origin.y = sel.maxY + 6
        }
        let bg = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.65).setFill()
        bg.fill()
        text.draw(at: CGPoint(x: box.minX + pad, y: box.minY + pad), withAttributes: attrs)
    }

    private func drawHintBar() {
        let text = "Drag: select   ·   Drag inside: move   ·   Handles: resize   ·   Space: window   ·   ⏎: edit & copy   ·   C: copy now   ·   Esc: cancel" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let pad: CGFloat = 10
        let box = CGRect(x: bounds.midX - size.width / 2 - pad,
                         y: 18,
                         width: size.width + pad * 2,
                         height: size.height + pad * 2)
        let bg = NSBezierPath(roundedRect: box, xRadius: 7, yRadius: 7)
        NSColor.black.withAlphaComponent(0.55).setFill()
        bg.fill()
        text.draw(at: CGPoint(x: box.minX + pad, y: box.minY + pad), withAttributes: attrs)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        if let sel = selection, sel.contains(p) {
            if let h = handle(at: p, in: sel) {
                dragMode = .resize(h)
                originalSelection = sel
            } else {
                dragMode = .move
                originalSelection = sel
                dragStart = p
            }
        } else {
            dragMode = .new
            dragStart = p
            selection = nil
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch dragMode {
        case .new:
            selection = normalizedRect(from: dragStart, to: p)
        case .move:
            guard let orig = originalSelection else { break }
            var r = orig
            r.origin.x = min(max(orig.minX + p.x - dragStart.x, 0), bounds.width - orig.width)
            r.origin.y = min(max(orig.minY + p.y - dragStart.y, 0), bounds.height - orig.height)
            selection = r
        case .resize(let handle):
            guard let orig = originalSelection else { break }
            selection = resized(orig, handle: handle, to: p)
        case .none:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if case .new = dragMode, let sel = selection,
           sel.width < 3 || sel.height < 3 {
            selection = nil
        }
        dragMode = .none
        dragStart = .zero
        originalSelection = nil
        needsDisplay = true
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53: // esc
            onCancel?()
        case 36, 76: // return / enter
            if let sel = selection, sel.width > 2, sel.height > 2 {
                onConfirm?(sel)
            } else {
                onConfirm?(bounds) // full screen
            }
        case 8: // c
            if let sel = selection, sel.width > 2, sel.height > 2 {
                onCopyNow?(sel)
            }
        case 49: // space
            snapToWindowUnderCursor()
        case 123, 124, 125, 126: // arrows
            nudgeSelection(dx: event.keyCode == 124 ? 1 : (event.keyCode == 123 ? -1 : 0),
                           dy: event.keyCode == 125 ? 1 : (event.keyCode == 126 ? -1 : 0),
                           large: flags.contains(.shift))
        default:
            super.keyDown(with: event)
        }
    }

    private func nudgeSelection(dx: CGFloat, dy: CGFloat, large: Bool) {
        guard var sel = selection else { return }
        let step: CGFloat = large ? 10 : 1
        sel.origin.x = min(max(sel.origin.x + dx * step, 0), bounds.width - sel.width)
        sel.origin.y = min(max(sel.origin.y + dy * step, 0), bounds.height - sel.height)
        selection = sel
        needsDisplay = true
    }

    // MARK: Window snapping

    private func snapToWindowUnderCursor() {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let mouse = NSEvent.mouseLocation
        let mainMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let mouseTL = CGPoint(x: mouse.x, y: mainMaxY - mouse.y)

        var candidates: [(CGRect, CGFloat)] = []
        for w in info {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let onscreen = w[kCGWindowIsOnscreen as String] as? Bool, onscreen else { continue }
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            if owner == "Snipe" { continue }
            guard let b = w[kCGWindowBounds as String] as? [String: Any],
                  let x = (b["X"] as? NSNumber)?.doubleValue,
                  let y = (b["Y"] as? NSNumber)?.doubleValue,
                  let wd = (b["Width"] as? NSNumber)?.doubleValue,
                  let ht = (b["Height"] as? NSNumber)?.doubleValue else { continue }
            var r = CGRect(x: x, y: y, width: wd, height: ht).standardized
        r = r.standardized
            if r.width < 40 || r.height < 40 { continue }
            if r.contains(mouseTL) {
                candidates.append((r, r.width * r.height))
            }
        }
        guard let best = candidates.sorted(by: { $0.1 < $1.1 }).first?.0 else { return }
        var r = best
        r.origin.x -= composite.pointRect.minX
        r.origin.y -= composite.pointRect.minY
        r = r.intersection(bounds)
        if !r.isNull && r.width > 2 && r.height > 2 {
            selection = r
            needsDisplay = true
        }
    }

    // MARK: Helpers

    private enum Handle: Int, CaseIterable {
        case minXMinY, midXMinY, maxXMinY, maxXMidY, maxXMaxY, midXMaxY, minXMaxY, minXMidY
    }

    private func handle(at p: CGPoint, in sel: CGRect) -> Handle? {
        let pad: CGFloat = 6
        for h in Handle.allCases {
            var r: CGRect
            switch h {
            case .minXMinY: r = CGRect(x: sel.minX - pad, y: sel.minY - pad, width: pad * 2, height: pad * 2)
            case .midXMinY: r = CGRect(x: sel.midX - pad, y: sel.minY - pad, width: pad * 2, height: pad * 2)
            case .maxXMinY: r = CGRect(x: sel.maxX - pad, y: sel.minY - pad, width: pad * 2, height: pad * 2)
            case .maxXMidY: r = CGRect(x: sel.maxX - pad, y: sel.midY - pad, width: pad * 2, height: pad * 2)
            case .maxXMaxY: r = CGRect(x: sel.maxX - pad, y: sel.maxY - pad, width: pad * 2, height: pad * 2)
            case .midXMaxY: r = CGRect(x: sel.midX - pad, y: sel.maxY - pad, width: pad * 2, height: pad * 2)
            case .minXMaxY: r = CGRect(x: sel.minX - pad, y: sel.maxY - pad, width: pad * 2, height: pad * 2)
            case .minXMidY: r = CGRect(x: sel.minX - pad, y: sel.midY - pad, width: pad * 2, height: pad * 2)
            }
            if r.contains(p) { return h }
        }
        return nil
    }

    private func resized(_ orig: CGRect, handle: Handle, to p: CGPoint) -> CGRect {
        var r = orig
        switch handle {
        case .minXMinY:
            r.origin.x = p.x; r.origin.y = p.y
            r.size.width = orig.maxX - p.x; r.size.height = orig.maxY - p.y
        case .midXMinY:
            r.origin.y = p.y; r.size.height = orig.maxY - p.y
        case .maxXMinY:
            r.origin.y = p.y; r.size.height = orig.maxY - p.y
            r.size.width = p.x - orig.minX
        case .maxXMidY:
            r.size.width = p.x - orig.minX
        case .maxXMaxY:
            r.size.width = p.x - orig.minX; r.size.height = p.y - orig.minY
        case .midXMaxY:
            r.size.height = p.y - orig.minY
        case .minXMaxY:
            r.origin.x = p.x; r.size.width = orig.maxX - p.x
            r.size.height = p.y - orig.minY
        case .minXMidY:
            r.origin.x = p.x; r.size.width = orig.maxX - p.x
        }
        let minSide: CGFloat = 8
        if r.width < minSide {
            if r.minX == orig.minX { r.size.width = minSide } else { r.origin.x = r.maxX - minSide; r.size.width = minSide }
        }
        if r.height < minSide {
            if r.minY == orig.minY { r.size.height = minSide } else { r.origin.y = r.maxY - minSide; r.size.height = minSide }
        }
        return r
    }
}

// MARK: - Loupe

final class LoupeWindow: NSWindow {
    private let composite: CompositeImage
    private let loupeView = LoupeView()
    private var timer: Timer?

    init(composite: CompositeImage) {
        self.composite = composite
        super.init(contentRect: NSRect(x: 0, y: 0, width: 148, height: 148),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver + 1
        hasShadow = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        contentView = loupeView
        loupeView.composite = composite
    }

    func show() {
        orderFrontRegardless()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        refresh()
    }

    private func refresh() {
        let mouse = NSEvent.mouseLocation
        let mainMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let viewPoint = CGPoint(x: mouse.x - composite.pointRect.minX,
                                y: mainMaxY - mouse.y - composite.pointRect.minY)
        loupeView.sampleCenter = viewPoint
        loupeView.needsDisplay = true

        // Position near cursor, offset so it doesn't cover the selection point.
        var x = mouse.x + 26
        var y = mouse.y - frame.height - 26
        if let screen = NSScreen.main {
            if x + frame.width > screen.visibleFrame.maxX { x = mouse.x - frame.width - 26 }
            if y < screen.visibleFrame.minY { y = mouse.y + 26 }
        }
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

final class LoupeView: NSView {
    var composite: CompositeImage?
    var sampleCenter: CGPoint = .zero

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let composite else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let scale = composite.pixelsPerPoint
        let cx = sampleCenter.x * scale
        let cy = sampleCenter.y * scale
        let half = 16 * scale
        let full = CGRect(x: 0, y: 0, width: composite.cgImage.width, height: composite.cgImage.height)
        let crop = CGRect(x: cx - half, y: cy - half, width: half * 2, height: half * 2).intersection(full)
        guard crop.width > 0, crop.height > 0 else { return }

        ctx.saveGState()
        ctx.interpolationQuality = .none
        if let sub = composite.cgImage.cropping(to: crop) {
            let dest = bounds.insetBy(dx: 6, dy: 6)
            ctx.draw(sub, in: dest)
        }
        ctx.restoreGState()

        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10)
        NSColor.black.withAlphaComponent(0.9).setStroke()
        border.lineWidth = 2
        border.stroke()

        NSColor.black.setStroke()
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: bounds.midX - 9, y: bounds.midY))
        cross.line(to: NSPoint(x: bounds.midX + 9, y: bounds.midY))
        cross.move(to: NSPoint(x: bounds.midX, y: bounds.midY - 9))
        cross.line(to: NSPoint(x: bounds.midX, y: bounds.midY + 9))
        cross.lineWidth = 1
        cross.stroke()
    }
}
