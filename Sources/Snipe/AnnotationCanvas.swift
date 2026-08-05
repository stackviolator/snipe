import AppKit

class AnnotationCanvas: NSView {
    let baseImage: NSImage
    var annotations: [any Annotation] = []
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 3
    var onBeforeMutation: (() -> Void)?

    var currentTool: ToolType = .arrow {
        didSet {
            if currentTool != .select {
                selectedIndex = nil
                selectInteraction = .idle
            }
            commitTextField()
        }
    }

    // Drawing state
    private var currentAnnotation: (any Annotation)?
    private var dragStart: NSPoint = .zero
    private var counterValue: Int = 1
    private var activeTextField: NSTextField?

    // Selection state
    var selectedIndex: Int? {
        didSet { needsDisplay = true }
    }
    private var selectInteraction: SelectInteraction = .idle
    private let handleSize: CGFloat = 8

    private enum SelectInteraction {
        case idle
        case moving(lastPoint: NSPoint)
        case resizing(handle: SelectHandle, startRect: NSRect)
    }

    enum SelectHandle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    init(image: NSImage) {
        self.baseImage = image
        super.init(frame: NSRect(origin: .zero, size: image.size))
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        baseImage.draw(in: bounds)
        for a in annotations { a.draw(in: ctx, imageSize: bounds.size, baseImage: baseImage) }
        currentAnnotation?.draw(in: ctx, imageSize: bounds.size, baseImage: baseImage)

        if let idx = selectedIndex, idx < annotations.count {
            drawSelection(ctx, rect: annotations[idx].boundingRect)
        }
    }

    private func drawSelection(_ ctx: CGContext, rect: NSRect) {
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.stroke(rect)
        ctx.setLineDash(phase: 0, lengths: [])

        for handle in SelectHandle.allCases {
            let hr = handleRect(for: handle, in: rect)
            ctx.setFillColor(CGColor.white)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1)
            ctx.fill(hr)
            ctx.stroke(hr)
        }
        ctx.restoreGState()
    }

    // MARK: Handle geometry

    private func handleRect(for handle: SelectHandle, in rect: NSRect) -> NSRect {
        let s = handleSize
        let pt: CGPoint
        switch handle {
        case .topLeft:     pt = CGPoint(x: rect.minX, y: rect.maxY)
        case .top:         pt = CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight:    pt = CGPoint(x: rect.maxX, y: rect.maxY)
        case .right:       pt = CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: pt = CGPoint(x: rect.maxX, y: rect.minY)
        case .bottom:      pt = CGPoint(x: rect.midX, y: rect.minY)
        case .bottomLeft:  pt = CGPoint(x: rect.minX, y: rect.minY)
        case .left:        pt = CGPoint(x: rect.minX, y: rect.midY)
        }
        return NSRect(x: pt.x - s / 2, y: pt.y - s / 2, width: s, height: s)
    }

    private func hitHandle(at point: NSPoint, in rect: NSRect) -> SelectHandle? {
        let tolerance: CGFloat = 5
        for h in SelectHandle.allCases {
            if handleRect(for: h, in: rect).insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                return h
            }
        }
        return nil
    }

    private func hitTestAnnotation(at point: NSPoint) -> Int? {
        let tolerance: CGFloat = 4
        for i in annotations.indices.reversed() {
            if annotations[i].boundingRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                return i
            }
        }
        return nil
    }

    // MARK: Mouse events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        dragStart = pt
        commitTextField()

        if currentTool == .select {
            mouseDownSelect(pt)
            return
        }

        switch currentTool {
        case .select: break
        case .arrow:
            currentAnnotation = ArrowAnnotation(start: pt, end: pt,
                                                 color: currentColor,
                                                 lineWidth: currentLineWidth)
        case .rectangle:
            currentAnnotation = RectAnnotation(rect: .init(origin: pt, size: .zero),
                                                color: currentColor,
                                                lineWidth: currentLineWidth)
        case .ellipse:
            currentAnnotation = EllipseAnnotation(rect: .init(origin: pt, size: .zero),
                                                   color: currentColor,
                                                   lineWidth: currentLineWidth)
        case .line:
            currentAnnotation = LineAnnotation(start: pt, end: pt,
                                                color: currentColor,
                                                lineWidth: currentLineWidth)
        case .highlight:
            currentAnnotation = HighlightAnnotation(rect: .init(origin: pt, size: .zero),
                                                     color: currentColor)
        case .blur:
            currentAnnotation = BlurAnnotation(rect: .init(origin: pt, size: .zero))
        case .pen:
            currentAnnotation = PenAnnotation(points: [pt],
                                               color: currentColor,
                                               lineWidth: currentLineWidth)
        case .text:
            showTextField(at: pt)
            return
        case .counter:
            onBeforeMutation?()
            annotations.append(CounterAnnotation(center: pt, number: counterValue,
                                                  color: currentColor))
            counterValue += 1
            needsDisplay = true
            return
        }
    }

    private func mouseDownSelect(_ pt: NSPoint) {
        if let idx = selectedIndex, idx < annotations.count {
            let br = annotations[idx].boundingRect
            if let h = hitHandle(at: pt, in: br) {
                onBeforeMutation?()
                selectInteraction = .resizing(handle: h, startRect: br)
                return
            }
            if br.insetBy(dx: -4, dy: -4).contains(pt) {
                onBeforeMutation?()
                selectInteraction = .moving(lastPoint: pt)
                return
            }
        }
        // Try selecting a different annotation
        selectedIndex = hitTestAnnotation(at: pt)
        selectInteraction = .idle
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        if currentTool == .select {
            mouseDraggedSelect(pt)
            return
        }

        switch currentTool {
        case .select: break
        case .arrow:
            if var a = currentAnnotation as? ArrowAnnotation {
                a.end = pt; currentAnnotation = a
            }
        case .rectangle:
            currentAnnotation = RectAnnotation(rect: rectFrom(dragStart, pt),
                                                color: currentColor,
                                                lineWidth: currentLineWidth)
        case .ellipse:
            currentAnnotation = EllipseAnnotation(rect: rectFrom(dragStart, pt),
                                                   color: currentColor,
                                                   lineWidth: currentLineWidth)
        case .line:
            if var a = currentAnnotation as? LineAnnotation {
                a.end = pt; currentAnnotation = a
            }
        case .highlight:
            currentAnnotation = HighlightAnnotation(rect: rectFrom(dragStart, pt),
                                                     color: currentColor)
        case .blur:
            currentAnnotation = BlurAnnotation(rect: rectFrom(dragStart, pt))
        case .pen:
            if var a = currentAnnotation as? PenAnnotation {
                a.points.append(pt); currentAnnotation = a
            }
        default: break
        }

        needsDisplay = true
    }

    private func mouseDraggedSelect(_ pt: NSPoint) {
        guard let idx = selectedIndex, idx < annotations.count else { return }

        switch selectInteraction {
        case .moving(let last):
            let dx = pt.x - last.x, dy = pt.y - last.y
            annotations[idx].offset(dx: dx, dy: dy)
            selectInteraction = .moving(lastPoint: pt)

        case .resizing(let handle, _):
            let oldRect = annotations[idx].boundingRect
            let newRect = computeResizedRect(oldRect, handle: handle, to: pt)
            annotations[idx].resize(from: oldRect, to: newRect)

        case .idle: break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if currentTool == .select {
            selectInteraction = .idle
            needsDisplay = true
            return
        }

        guard let annotation = currentAnnotation else { return }

        var commit = true
        if let r = annotation as? RectAnnotation, r.rect.width < 2, r.rect.height < 2 {
            commit = false
        }
        if let e = annotation as? EllipseAnnotation, e.rect.width < 2, e.rect.height < 2 {
            commit = false
        }

        if commit {
            onBeforeMutation?()
            annotations.append(annotation)
        }
        currentAnnotation = nil
        needsDisplay = true
    }

    // MARK: Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if currentTool == .select, let idx = selectedIndex, idx < annotations.count {
            // Delete or Backspace removes selected annotation
            if event.keyCode == 51 || event.keyCode == 117 {
                onBeforeMutation?()
                annotations.remove(at: idx)
                selectedIndex = nil
                needsDisplay = true
                return
            }
            // Escape deselects
            if event.keyCode == 53 {
                selectedIndex = nil
                needsDisplay = true
                return
            }
        }
        super.keyDown(with: event)
    }

    // MARK: Resize math

    private func computeResizedRect(_ r: NSRect, handle: SelectHandle, to pt: NSPoint) -> NSRect {
        var n = r
        switch handle {
        case .topLeft:
            n = NSRect(x: pt.x, y: r.minY, width: r.maxX - pt.x, height: pt.y - r.minY)
        case .top:
            n = NSRect(x: r.minX, y: r.minY, width: r.width, height: pt.y - r.minY)
        case .topRight:
            n = NSRect(x: r.minX, y: r.minY, width: pt.x - r.minX, height: pt.y - r.minY)
        case .right:
            n = NSRect(x: r.minX, y: r.minY, width: pt.x - r.minX, height: r.height)
        case .bottomRight:
            n = NSRect(x: r.minX, y: pt.y, width: pt.x - r.minX, height: r.maxY - pt.y)
        case .bottom:
            n = NSRect(x: r.minX, y: pt.y, width: r.width, height: r.maxY - pt.y)
        case .bottomLeft:
            n = NSRect(x: pt.x, y: pt.y, width: r.maxX - pt.x, height: r.maxY - pt.y)
        case .left:
            n = NSRect(x: pt.x, y: r.minY, width: r.maxX - pt.x, height: r.height)
        }
        if n.width < 0 { n.origin.x += n.width; n.size.width = -n.width }
        if n.height < 0 { n.origin.y += n.height; n.size.height = -n.height }
        n.size.width = max(n.width, 5)
        n.size.height = max(n.height, 5)
        return n
    }

    // MARK: Text field

    private func showTextField(at pt: NSPoint) {
        let tf = NSTextField(frame: NSRect(x: pt.x, y: pt.y - 24, width: 200, height: 24))
        tf.font = .systemFont(ofSize: 16, weight: .medium)
        tf.textColor = currentColor
        tf.backgroundColor = NSColor.white.withAlphaComponent(0.85)
        tf.isBezeled = false
        tf.focusRingType = .none
        tf.drawsBackground = true
        tf.target = self
        tf.action = #selector(textFieldDone)
        addSubview(tf)
        window?.makeFirstResponder(tf)
        activeTextField = tf
    }

    @objc private func textFieldDone(_ sender: NSTextField) {
        commitTextField()
    }

    private func commitTextField() {
        guard let tf = activeTextField else { return }
        if !tf.stringValue.isEmpty {
            onBeforeMutation?()
            annotations.append(TextAnnotation(position: tf.frame.origin,
                                               text: tf.stringValue,
                                               color: currentColor,
                                               fontSize: 16))
        }
        tf.removeFromSuperview()
        activeTextField = nil
        needsDisplay = true
    }

    // MARK: Delete selected

    func deleteSelected() {
        guard let idx = selectedIndex, idx < annotations.count else { return }
        onBeforeMutation?()
        annotations.remove(at: idx)
        selectedIndex = nil
        needsDisplay = true
    }

    // MARK: Render final image

    func renderFinalImage() -> NSImage {
        let saved = selectedIndex
        selectedIndex = nil

        let img = NSImage(size: bounds.size)
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            baseImage.draw(in: bounds)
            for a in annotations { a.draw(in: ctx, imageSize: bounds.size, baseImage: baseImage) }
        }
        img.unlockFocus()

        selectedIndex = saved
        return img
    }

    // MARK: Helpers

    private func rectFrom(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
