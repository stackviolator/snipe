import AppKit

// MARK: - Capture coordinator

class CaptureOverlay {
    private var windows: [NSWindow] = []
    private let onCapture: (NSImage) -> Void

    init(onCapture: @escaping (NSImage) -> Void) {
        self.onCapture = onCapture
    }

    func show() {
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: .borderless,
                                  backing: .buffered,
                                  defer: false,
                                  screen: screen)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let localFrame = NSRect(origin: .zero, size: screen.frame.size)
            let view = SelectionOverlayView(frame: localFrame)
            view.onConfirm = { [weak self] rect in
                self?.captureArea(rect: rect, screen: screen)
            }
            view.onCancel = { [weak self] in
                self?.close()
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSCursor.crosshair.push()
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
    }

    private func captureArea(rect: NSRect, screen: NSScreen) {
        NSCursor.pop()

        let screenRect = NSRect(
            x: screen.frame.origin.x + rect.origin.x,
            y: screen.frame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        for w in windows { w.orderOut(nil) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }

            let maxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
            let cgRect = CGRect(x: screenRect.origin.x,
                                y: maxY - screenRect.maxY,
                                width: screenRect.width,
                                height: screenRect.height)

            if let cgImage = CGWindowListCreateImage(cgRect, .optionOnScreenOnly,
                                                      kCGNullWindowID, [.bestResolution]) {
                let image = NSImage(cgImage: cgImage, size: screenRect.size)
                self.onCapture(image)
            }

            self.windows.removeAll()
        }
    }

    func close() {
        NSCursor.pop()
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
    }
}

// MARK: - Selection overlay view

class SelectionOverlayView: NSView {

    enum State {
        case idle
        case selecting(start: NSPoint)
        case selected
        case moving(last: NSPoint)
        case resizing(handle: Handle, last: NSPoint)
    }

    enum Handle: CaseIterable {
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
    }

    var onConfirm: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var state: State = .idle
    private var selectionRect: NSRect = .zero
    private var mousePosition: NSPoint?
    private let handleSize: CGFloat = 8
    private let overlayColor = NSColor.black.withAlphaComponent(0.4)

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        mousePosition = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Dimmed overlay
        ctx.setFillColor(overlayColor.cgColor)
        ctx.fill(bounds)

        // Crosshair guides (idle only)
        if case .idle = state {
            drawCrosshair(ctx)
        }

        if selectionRect.width > 0, selectionRect.height > 0 {
            // Clear selection area
            ctx.setBlendMode(.clear)
            ctx.fill(selectionRect)
            ctx.setBlendMode(.normal)

            // White border
            ctx.setStrokeColor(CGColor.white)
            ctx.setLineWidth(1.5)
            ctx.stroke(selectionRect)

            // Rule-of-thirds guides
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(0.5)
            let dash: [CGFloat] = [5, 5]
            ctx.setLineDash(phase: 0, lengths: dash)
            for i in 1...2 {
                let x = selectionRect.minX + selectionRect.width / 3 * CGFloat(i)
                ctx.move(to: CGPoint(x: x, y: selectionRect.minY))
                ctx.addLine(to: CGPoint(x: x, y: selectionRect.maxY))
                let y = selectionRect.minY + selectionRect.height / 3 * CGFloat(i)
                ctx.move(to: CGPoint(x: selectionRect.minX, y: y))
                ctx.addLine(to: CGPoint(x: selectionRect.maxX, y: y))
            }
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])

            // Resize handles
            if case .idle = state {} else if case .selecting = state {} else {
                drawHandles(ctx)
            }

            // Dimensions label
            drawDimensions(ctx)
        }

        // Instruction banner
        drawInstructions(ctx)
    }

    private func drawCrosshair(_ ctx: CGContext) {
        guard let pos = mousePosition else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [6, 4])

        ctx.move(to: CGPoint(x: pos.x, y: 0))
        ctx.addLine(to: CGPoint(x: pos.x, y: bounds.height))
        ctx.move(to: CGPoint(x: 0, y: pos.y))
        ctx.addLine(to: CGPoint(x: bounds.width, y: pos.y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawInstructions(_ ctx: CGContext) {
        let text: String
        switch state {
        case .idle, .selecting:
            text = "Click and drag to select area  \u{2022}  Esc to cancel"
        case .selected, .moving, .resizing:
            text = "Drag to move  \u{2022}  Drag handles to resize  \u{2022}  Enter to capture  \u{2022}  Esc to cancel"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let pad: CGFloat = 12
        let bgRect = NSRect(
            x: bounds.midX - size.width / 2 - pad,
            y: bounds.maxY - size.height - pad * 2 - 24,
            width: size.width + pad * 2,
            height: size.height + pad * 2
        )

        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
        ctx.addPath(CGPath(roundedRect: bgRect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        (text as NSString).draw(at: CGPoint(x: bgRect.minX + pad, y: bgRect.minY + pad),
                                withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawHandles(_ ctx: CGContext) {
        for handle in Handle.allCases {
            let r = handleRect(for: handle)
            ctx.setFillColor(CGColor.white)
            ctx.setStrokeColor(NSColor.gray.cgColor)
            ctx.setLineWidth(1)
            ctx.fillEllipse(in: r)
            ctx.strokeEllipse(in: r)
        }
    }

    private func drawDimensions(_ ctx: CGContext) {
        let text = "\(Int(selectionRect.width)) \u{00d7} \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let pad: CGFloat = 6

        var origin = CGPoint(x: selectionRect.midX - size.width / 2 - pad,
                             y: selectionRect.minY - size.height - pad * 2 - 4)
        if origin.y < 0 { origin.y = selectionRect.maxY + 4 }

        let bg = NSRect(x: origin.x, y: origin.y,
                        width: size.width + pad * 2,
                        height: size.height + pad * 2)

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        ctx.addPath(CGPath(roundedRect: bg, cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        (text as NSString).draw(at: CGPoint(x: bg.minX + pad, y: bg.minY + pad),
                                withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Handle geometry

    private func handleRect(for handle: Handle) -> NSRect {
        let s = handleSize
        let r = selectionRect
        let pt: CGPoint
        switch handle {
        case .topLeft:     pt = CGPoint(x: r.minX, y: r.maxY)
        case .top:         pt = CGPoint(x: r.midX, y: r.maxY)
        case .topRight:    pt = CGPoint(x: r.maxX, y: r.maxY)
        case .left:        pt = CGPoint(x: r.minX, y: r.midY)
        case .right:       pt = CGPoint(x: r.maxX, y: r.midY)
        case .bottomLeft:  pt = CGPoint(x: r.minX, y: r.minY)
        case .bottom:      pt = CGPoint(x: r.midX, y: r.minY)
        case .bottomRight: pt = CGPoint(x: r.maxX, y: r.minY)
        }
        return NSRect(x: pt.x - s / 2, y: pt.y - s / 2, width: s, height: s)
    }

    private func hitHandle(at point: NSPoint) -> Handle? {
        let tolerance: CGFloat = 6
        for h in Handle.allCases {
            if handleRect(for: h).insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                return h
            }
        }
        return nil
    }

    // MARK: Mouse events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        switch state {
        case .idle:
            state = .selecting(start: pt)
            selectionRect = NSRect(origin: pt, size: .zero)

        case .selected:
            if let h = hitHandle(at: pt) {
                state = .resizing(handle: h, last: pt)
            } else if selectionRect.contains(pt) {
                state = .moving(last: pt)
            } else {
                state = .selecting(start: pt)
                selectionRect = NSRect(origin: pt, size: .zero)
            }

        default: break
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        switch state {
        case .selecting(let start):
            selectionRect = rectFrom(start, pt)

        case .moving(let last):
            let dx = pt.x - last.x
            let dy = pt.y - last.y
            selectionRect = selectionRect.offsetBy(dx: dx, dy: dy)
            selectionRect.origin.x = max(0, min(selectionRect.origin.x,
                                                  bounds.width - selectionRect.width))
            selectionRect.origin.y = max(0, min(selectionRect.origin.y,
                                                  bounds.height - selectionRect.height))
            state = .moving(last: pt)

        case .resizing(let handle, _):
            applyResize(handle: handle, to: pt)
            state = .resizing(handle: handle, last: pt)

        default: break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch state {
        case .selecting:
            state = (selectionRect.width > 5 && selectionRect.height > 5)
                ? .selected : .idle
            if case .idle = state { selectionRect = .zero }

        case .moving, .resizing:
            state = .selected

        case .selected:
            let pt = convert(event.locationInWindow, from: nil)
            if event.clickCount == 2, selectionRect.contains(pt) {
                onConfirm?(selectionRect)
            }

        default: break
        }

        needsDisplay = true
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return / Enter
            if selectionRect.width > 0, selectionRect.height > 0 {
                onConfirm?(selectionRect)
            }
        case 53: // Escape
            if case .selected = state {
                state = .idle
                selectionRect = .zero
                needsDisplay = true
            } else {
                onCancel?()
            }
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: Helpers

    private func rectFrom(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func applyResize(handle: Handle, to pt: NSPoint) {
        var r = selectionRect
        switch handle {
        case .topLeft:
            r.size.width  = r.maxX - pt.x; r.origin.x = pt.x
            r.size.height = pt.y - r.minY
        case .top:
            r.size.height = pt.y - r.minY
        case .topRight:
            r.size.width  = pt.x - r.minX
            r.size.height = pt.y - r.minY
        case .left:
            r.size.width = r.maxX - pt.x; r.origin.x = pt.x
        case .right:
            r.size.width = pt.x - r.minX
        case .bottomLeft:
            r.size.width  = r.maxX - pt.x; r.origin.x = pt.x
            r.size.height = r.maxY - pt.y; r.origin.y = pt.y
        case .bottom:
            r.size.height = r.maxY - pt.y; r.origin.y = pt.y
        case .bottomRight:
            r.size.width  = pt.x - r.minX
            r.size.height = r.maxY - pt.y; r.origin.y = pt.y
        }
        if r.width < 0 { r.origin.x += r.width; r.size.width = -r.width }
        if r.height < 0 { r.origin.y += r.height; r.size.height = -r.height }
        selectionRect = r
    }
}
