import AppKit

/// The annotation canvas: drawing, hit-testing, move/resize, undo/redo, inline text.
final class CanvasView: NSView {

    let editorImage: EditorImage
    private(set) var items: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    var tool: Tool = .select
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 3
    var fillShapes = false
    var textSize: CGFloat = 24
    private var numberCounter = 1

    // Callbacks
    var onRequestCopy: (() -> Void)?
    var onRequestSave: (() -> Void)?
    var onRequestClose: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onFit: (() -> Void)?

    // Interaction state
    private enum DragState {
        case none
        case drawing(Tool)
        case moving(original: CGRect)
        case resizing(original: CGRect, handle: Handle)
    }
    private var dragState: DragState = .none
    private var dragStart: CGPoint = .zero
    private var pending: Annotation?
    private var selectedIndex: Int?
    private var textField: NSTextField?

    private let image: NSImage

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(editorImage: EditorImage) {
        self.editorImage = editorImage
        self.image = NSImage(cgImage: editorImage.cgImage, size: editorImage.pointSize)
        super.init(frame: CGRect(origin: .zero, size: editorImage.pointSize))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Undo / Redo

    private func pushUndo() {
        undoStack.append(items)
        if undoStack.count > 120 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(items)
        items = previous
        selectedIndex = nil
        needsDisplay = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(items)
        items = next
        selectedIndex = nil
        needsDisplay = true
    }

    func canUndo() -> Bool { !undoStack.isEmpty }
    func canRedo() -> Bool { !redoStack.isEmpty }

    private func commit(new item: Annotation) {
        pushUndo()
        items.append(item)
        selectedIndex = items.count - 1
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        for item in items {
            draw(item)
        }
        if let pending {
            draw(pending)
        }
        drawSelectionUI()
    }

    private func draw(_ item: Annotation) {
        switch item.type {
        case .select: break
        case .pen: drawPen(item)
        case .arrow: drawArrow(item)
        case .line: drawLine(item)
        case .rect: drawRect(item)
        case .ellipse: drawEllipse(item)
        case .text: drawText(item)
        case .number: drawNumber(item)
        case .highlight: drawHighlight(item)
        case .blur, .pixelate: drawFiltered(item)
        }
    }

    private func drawPen(_ item: Annotation) {
        guard item.points.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: item.points[0])
        for p in item.points.dropFirst() { path.line(to: p) }
        item.color.setStroke()
        path.lineWidth = item.strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawArrow(_ item: Annotation) {
        guard item.points.count >= 2 else { return }
        drawLine(item)
        let start = item.points[0], end = item.points[1]
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen = 10 + item.strokeWidth * 2
        let h1 = CGPoint(x: end.x - headLen * cos(angle - 0.45), y: end.y - headLen * sin(angle - 0.45))
        let h2 = CGPoint(x: end.x - headLen * cos(angle + 0.45), y: end.y - headLen * sin(angle + 0.45))
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: h1)
        head.line(to: h2)
        head.close()
        item.color.setFill()
        head.fill()
    }

    private func drawLine(_ item: Annotation) {
        guard item.points.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: item.points[0])
        path.line(to: item.points[1])
        item.color.setStroke()
        path.lineWidth = item.strokeWidth
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawRect(_ item: Annotation) {
        let path = NSBezierPath(rect: item.rect)
        item.color.setStroke()
        path.lineWidth = item.strokeWidth
        path.stroke()
        if item.fill {
            item.color.withAlphaComponent(0.25).setFill()
            path.fill()
        }
    }

    private func drawEllipse(_ item: Annotation) {
        let path = NSBezierPath(ovalIn: item.rect)
        item.color.setStroke()
        path.lineWidth = item.strokeWidth
        path.stroke()
        if item.fill {
            item.color.withAlphaComponent(0.25).setFill()
            path.fill()
        }
    }

    private func drawText(_ item: Annotation) {
        guard !item.text.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: item.textSize),
            .foregroundColor: item.color
        ]
        (item.text as NSString).draw(at: item.rect.origin, withAttributes: attrs)
    }

    private func drawNumber(_ item: Annotation) {
        let circle = NSBezierPath(ovalIn: item.rect)
        item.color.setFill()
        circle.fill()
        let text = "\(item.number)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: item.rect.height * 0.5),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: item.rect.midX - size.width / 2,
                              y: item.rect.midY - size.height / 2),
                  withAttributes: attrs)
    }

    private func drawHighlight(_ item: Annotation) {
        let path = NSBezierPath(roundedRect: item.rect, xRadius: 6, yRadius: 6)
        item.color.withAlphaComponent(0.35).setFill()
        path.fill()
    }

    private func drawFiltered(_ item: Annotation) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: item.rect).addClip()
        let scale = editorImage.scale
        if let cg = FilterRenderer.filteredCGImage(for: item, original: editorImage.cgImage, scale: scale) {
            NSImage(cgImage: cg, size: item.rect.size).draw(in: item.rect)
        }
        NSGraphicsContext.restoreGraphicsState()
        // subtle border so the affected region is visible while editing
        let border = NSBezierPath(rect: item.rect)
        NSColor.black.withAlphaComponent(0.35).setStroke()
        border.lineWidth = 0.5
        border.stroke()
    }

    private func drawSelectionUI() {
        guard let idx = selectedIndex, items.indices.contains(idx) else { return }
        let item = items[idx]
        let rect = item.rect
        let path = NSBezierPath(rect: rect)
        NSColor.systemBlue.setStroke()
        path.lineWidth = 1
        let pattern: [CGFloat] = [4, 3]
        path.setLineDash(pattern, count: 2, phase: 0)
        path.stroke()

        if item.type != .pen && item.type != .line && item.type != .arrow {
            drawHandles(in: rect)
        }
    }

    private func drawHandles(in rect: CGRect) {
        let size: CGFloat = 7
        let positions: [(CGFloat, CGFloat)] = [
            (0, 0), (0.5, 0), (1, 0), (1, 0.5), (1, 1), (0.5, 1), (0, 1), (0, 0.5)
        ]
        NSColor.white.setFill()
        NSColor.systemBlue.setStroke()
        for (fx, fy) in positions {
            let r = CGRect(x: rect.minX + fx * rect.width - size / 2,
                           y: rect.minY + fy * rect.height - size / 2,
                           width: size, height: size)
            let p = NSBezierPath(rect: r)
            p.fill()
            p.lineWidth = 1
            p.stroke()
        }
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        switch tool {
        case .select:
            if let idx = hitTestItem(at: p) {
                selectedIndex = idx
                let rect = items[idx].rect
                if itemHasHandles(items[idx]), let h = handle(at: p, in: rect) {
                    dragState = .resizing(original: rect, handle: h)
                } else {
                    dragState = .moving(original: rect)
                }
                dragStart = p
            } else {
                selectedIndex = nil
            }
        case .text:
            pushUndo()
            var item = Annotation(type: .text, rect: CGRect(x: p.x, y: p.y, width: 80, height: textSize + 10),
                                  color: color, text: "Text", textSize: textSize)
            item.text = ""
            items.append(item)
            selectedIndex = items.count - 1
            beginEditingText(at: selectedIndex!)
        case .number:
            let side: CGFloat = 30
            var item = Annotation(type: .number,
                                  rect: CGRect(x: p.x - side / 2, y: p.y - side / 2, width: side, height: side),
                                  color: color, strokeWidth: 2)
            item.number = numberCounter
            numberCounter += 1
            commit(new: item)
        default:
            dragState = .drawing(tool)
            dragStart = p
            pending = Annotation(type: tool, rect: CGRect(origin: p, size: .zero),
                                 points: [p], color: color, strokeWidth: strokeWidth,
                                 fill: fillShapes, textSize: textSize)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch dragState {
        case .drawing(let t):
            guard var item = pending else { break }
            if t == .pen {
                item.points.append(p)
                item.rect = boundingRect(of: item.points)
            } else if t == .line || t == .arrow {
                item.points = [dragStart, p]
                item.rect = boundingRect(of: item.points)
            } else {
                item.rect = normalizedRect(from: dragStart, to: p)
            }
            pending = item
        case .moving(let orig):
            guard let idx = selectedIndex else { break }
            let dx = p.x - dragStart.x
            let dy = p.y - dragStart.y
            var r = orig
            r.origin.x = min(max(orig.minX + dx, 0), max(bounds.width - orig.width, 0))
            r.origin.y = min(max(orig.minY + dy, 0), max(bounds.height - orig.height, 0))
            apply(rect: r, toItemAt: idx)
        case .resizing(let orig, let handle):
            guard let idx = selectedIndex else { break }
            apply(rect: resized(orig, handle: handle, to: p), toItemAt: idx)
        case .none:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragState = .none
            pending = nil
            needsDisplay = true
        }
        guard case .drawing(let t) = dragState, let item = pending else { return }
        switch t {
        case .pen:
            guard item.points.count >= 2 else { return }
            commit(new: item)
        case .line, .arrow:
            guard item.points.count == 2, item.points[0] != item.points[1] else { return }
            commit(new: item)
        default:
            guard item.rect.width >= 3, item.rect.height >= 3 else { return }
            commit(new: item)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Re-applies a moved/resized rect, keeping line/arrow/pen geometry consistent.
    private func apply(rect r: CGRect, toItemAt idx: Int) {
        var item = items[idx]
        let old = item.rect
        item.rect = r
        switch item.type {
        case .line, .arrow:
            if item.points.count == 2 {
                item.points = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY)]
            }
        case .pen:
            let dx = r.minX - old.minX
            let dy = r.minY - old.minY
            item.points = item.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        default:
            break
        }
        items[idx] = item
    }

    // MARK: - Hit testing

    private func itemHasHandles(_ item: Annotation) -> Bool {
        item.type != .pen && item.type != .line && item.type != .arrow
    }

    private func hitTestItem(at p: CGPoint) -> Int? {
        for (i, item) in items.enumerated().reversed() {
            switch item.type {
            case .text, .number, .rect, .ellipse, .highlight, .blur, .pixelate:
                if item.rect.insetBy(dx: -5, dy: -5).contains(p) { return i }
            case .pen:
                if distanceFromPath(p, item.points) < max(10, item.strokeWidth + 4) { return i }
            case .line, .arrow:
                if item.points.count == 2,
                   distanceToSegment(p, item.points[0], item.points[1]) < max(10, item.strokeWidth + 4) { return i }
            case .select:
                break
            }
        }
        return nil
    }

    private enum Handle: Int, CaseIterable {
        case minXMinY, midXMinY, maxXMinY, maxXMidY, maxXMaxY, midXMaxY, minXMaxY, minXMidY
    }

    private func handle(at p: CGPoint, in rect: CGRect) -> Handle? {
        let pad: CGFloat = 6
        for h in Handle.allCases {
            var r: CGRect
            switch h {
            case .minXMinY: r = CGRect(x: rect.minX - pad, y: rect.minY - pad, width: pad * 2, height: pad * 2)
            case .midXMinY: r = CGRect(x: rect.midX - pad, y: rect.minY - pad, width: pad * 2, height: pad * 2)
            case .maxXMinY: r = CGRect(x: rect.maxX - pad, y: rect.minY - pad, width: pad * 2, height: pad * 2)
            case .maxXMidY: r = CGRect(x: rect.maxX - pad, y: rect.midY - pad, width: pad * 2, height: pad * 2)
            case .maxXMaxY: r = CGRect(x: rect.maxX - pad, y: rect.maxY - pad, width: pad * 2, height: pad * 2)
            case .midXMaxY: r = CGRect(x: rect.midX - pad, y: rect.maxY - pad, width: pad * 2, height: pad * 2)
            case .minXMaxY: r = CGRect(x: rect.minX - pad, y: rect.maxY - pad, width: pad * 2, height: pad * 2)
            case .minXMidY: r = CGRect(x: rect.minX - pad, y: rect.midY - pad, width: pad * 2, height: pad * 2)
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

    // MARK: - Inline text editing

    private func beginEditingText(at index: Int) {
        guard items.indices.contains(index), items[index].type == .text else { return }
        let item = items[index]
        let width = max(item.rect.width, 90)
        let field = NSTextField(frame: CGRect(x: item.rect.minX, y: item.rect.minY - 2,
                                              width: width, height: item.rect.height + 6))
        field.stringValue = item.text
        field.font = NSFont.systemFont(ofSize: item.textSize)
        field.textColor = item.color
        field.isBordered = false
        field.drawsBackground = false
        field.isBezeled = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.target = self
        field.action = #selector(textFieldAction(_:))
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
        field.currentEditor()?.selectedRange = NSRange(location: (field.stringValue as NSString).length, length: 0)
    }

    @objc private func textFieldAction(_ sender: NSTextField) {
        commitTextField(sender)
    }

    private func commitTextField(_ sender: NSTextField) {
        guard textField === sender, let idx = selectedIndex, items.indices.contains(idx) else { return }
        var item = items[idx]
        item.text = sender.stringValue
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: item.textSize)]
        let size = (item.text as NSString).size(withAttributes: attrs)
        item.rect = CGRect(x: item.rect.minX, y: item.rect.minY,
                           width: max(size.width + 4, 8), height: max(size.height + 4, 8))
        items[idx] = item
        sender.removeFromSuperview()
        textField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53: // esc
            onRequestClose?()
        case 36, 76: // return / enter
            onRequestCopy?()
        case 51, 117: // delete / forward delete
            if let idx = selectedIndex, items.indices.contains(idx) {
                pushUndo()
                items.remove(at: idx)
                selectedIndex = nil
                needsDisplay = true
            }
        case 123, 124, 125, 126: // arrows
            guard let idx = selectedIndex, items.indices.contains(idx) else { break }
            let step: CGFloat = flags.contains(.shift) ? 10 : 1
            var r = items[idx].rect
            switch event.keyCode {
            case 123: r.origin.x -= step
            case 124: r.origin.x += step
            case 125: r.origin.y += step
            case 126: r.origin.y -= step
            default: break
            }
            apply(rect: r, toItemAt: idx)
            needsDisplay = true
        case 6: // z
            if flags.contains(.command) {
                if flags.contains(.shift) { redo() } else { undo() }
            }
        case 8: // c
            if flags.contains(.command) { onRequestCopy?() }
        case 0: // a — select all? no-op for now
            break
        case 24: // =
            if flags.contains(.command) { onZoomIn?() }
        case 27: // -
            if flags.contains(.command) { onZoomOut?() }
        case 29: // 0
            if flags.contains(.command) { onFit?() }
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - NSTextFieldDelegate

extension CanvasView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            commitTextField(field)
        }
    }
}
