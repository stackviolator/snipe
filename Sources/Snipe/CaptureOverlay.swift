import AppKit
import UniformTypeIdentifiers

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Compact floating toolbar

class OverlayToolbar: NSView {
    var onToolChanged: ((ToolType) -> Void)?
    var onColorChanged: ((NSColor) -> Void)?
    var onWidthChanged: ((CGFloat) -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?

    private var toolButtons: [(tool: ToolType, button: NSButton)] = []
    private var colorDots: [(color: NSColor, button: NSButton)] = []
    private var selectedTool: ToolType = .select
    private var selectedColor: NSColor = .systemRed

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        layer?.cornerRadius = 8
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}

    func selectTool(_ tool: ToolType) {
        selectedTool = tool
        onToolChanged?(tool)
        for (t, btn) in toolButtons {
            btn.layer?.backgroundColor = (t == tool)
                ? NSColor.white.withAlphaComponent(0.25).cgColor
                : NSColor.clear.cgColor
        }
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let tools: [(ToolType, String)] = [
            (.select, "cursorarrow"), (.arrow, "arrow.up.right"),
            (.rectangle, "rectangle"), (.ellipse, "circle"),
            (.line, "line.diagonal"), (.text, "textformat"),
            (.highlight, "highlighter"), (.blur, "rectangle.dashed"),
            (.pen, "pencil.tip"), (.counter, "number"),
        ]
        for (tool, sym) in tools {
            let btn = iconBtn(sym)
            btn.target = self; btn.action = #selector(toolClicked(_:))
            toolButtons.append((tool, btn))
            stack.addArrangedSubview(btn)
        }
        stack.addArrangedSubview(sep())

        let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow,
                                  .systemGreen, .systemBlue, .white, .black]
        for c in colors {
            let dot = colorBtn(c)
            colorDots.append((c, dot))
            stack.addArrangedSubview(dot)
        }

        let slider = NSSlider(value: 3, minValue: 1, maxValue: 12,
                              target: self, action: #selector(widthSlid(_:)))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 50).isActive = true
        stack.addArrangedSubview(slider)

        stack.addArrangedSubview(sep())

        stack.addArrangedSubview(iconBtn("arrow.uturn.backward",
                                         target: self, action: #selector(undoAct)))
        stack.addArrangedSubview(iconBtn("arrow.uturn.forward",
                                         target: self, action: #selector(redoAct)))
        stack.addArrangedSubview(sep())

        let copy = actionBtn(title: "Copy", sym: "doc.on.doc")
        copy.target = self; copy.action = #selector(copyAct)
        stack.addArrangedSubview(copy)
        let save = actionBtn(title: "Save", sym: "square.and.arrow.down")
        save.target = self; save.action = #selector(saveAct)
        stack.addArrangedSubview(save)

        selectTool(.select)
        updateColorHighlight()
    }

    private func iconBtn(_ sym: String, target: AnyObject? = nil,
                         action: Selector? = nil) -> NSButton {
        let b = NSButton(frame: .zero)
        b.wantsLayer = true; b.isBordered = false
        b.imagePosition = .imageOnly
        b.image = NSImage(systemSymbolName: sym, accessibilityDescription: nil)
        b.image?.isTemplate = true
        b.contentTintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 26).isActive = true
        b.heightAnchor.constraint(equalToConstant: 26).isActive = true
        b.layer?.cornerRadius = 4
        if let t = target, let a = action { b.target = t; b.action = a }
        return b
    }

    private func colorBtn(_ c: NSColor) -> NSButton {
        let b = NSButton(frame: .zero)
        b.wantsLayer = true; b.isBordered = false; b.title = ""
        b.layer?.backgroundColor = c.cgColor
        b.layer?.cornerRadius = 8
        b.layer?.borderWidth = 2
        b.layer?.borderColor = NSColor.clear.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 16).isActive = true
        b.heightAnchor.constraint(equalToConstant: 16).isActive = true
        b.target = self; b.action = #selector(colorClicked(_:))
        return b
    }

    private func actionBtn(title: String, sym: String) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.image = NSImage(systemSymbolName: sym, accessibilityDescription: nil)
        b.imagePosition = .imageLeading
        b.bezelStyle = .recessed
        b.contentTintColor = .white
        b.font = .systemFont(ofSize: 11, weight: .medium)
        return b
    }

    private func sep() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return v
    }

    private func updateColorHighlight() {
        for (c, btn) in colorDots {
            btn.layer?.borderColor = (c == selectedColor)
                ? NSColor.white.cgColor : NSColor.clear.cgColor
        }
    }

    @objc private func toolClicked(_ s: NSButton) {
        for (t, btn) in toolButtons where btn === s { selectTool(t); return }
    }
    @objc private func colorClicked(_ s: NSButton) {
        for (c, btn) in colorDots where btn === s {
            selectedColor = c; onColorChanged?(c); updateColorHighlight(); return
        }
    }
    @objc private func widthSlid(_ s: NSSlider) { onWidthChanged?(CGFloat(s.doubleValue)) }
    @objc private func undoAct() { onUndo?() }
    @objc private func redoAct() { onRedo?() }
    @objc private func copyAct() { onCopy?() }
    @objc private func saveAct() { onSave?() }
}

// MARK: - Selection + annotation overlay

class SelectionOverlayView: NSView {

    enum Phase { case selecting, editing }
    enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }
    private enum Interaction {
        case none
        case dragging(start: NSPoint)
        case movingSel(last: NSPoint)
        case resizingSel(handle: Handle)
        case movingAnn(last: NSPoint)
        case resizingAnn(handle: Handle)
        case drawing(start: NSPoint)
    }

    var onDismiss: (() -> Void)?

    private let backgroundImage: NSImage
    private let sourceCGImage: CGImage
    private var phase: Phase = .selecting
    private var selectionRect: NSRect = .zero
    private var interaction: Interaction = .none
    private var mousePos: NSPoint?

    // Editing state
    private var currentTool: ToolType = .select
    private var currentColor: NSColor = .systemRed
    private var currentLineWidth: CGFloat = 3
    private var annotations: [any Annotation] = []
    private var drawingAnnotation: (any Annotation)?
    private var selectedAnnotation: Int?
    private var counterValue: Int = 1
    private var activeTextField: NSTextField?
    private var undoStack: [[any Annotation]] = []
    private var redoStack: [[any Annotation]] = []

    private let toolbar = OverlayToolbar()
    private let handleSize: CGFloat = 8
    private let dimColor = NSColor.black.withAlphaComponent(0.4)

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    init(frame: NSRect, backgroundImage: NSImage, sourceCGImage: CGImage) {
        self.backgroundImage = backgroundImage
        self.sourceCGImage = sourceCGImage
        super.init(frame: frame)
        wireToolbar()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // MARK: Toolbar wiring

    private func wireToolbar() {
        toolbar.onToolChanged = { [weak self] t in
            self?.currentTool = t
            if t != .select { self?.selectedAnnotation = nil; self?.needsDisplay = true }
        }
        toolbar.onColorChanged = { [weak self] c in self?.currentColor = c }
        toolbar.onWidthChanged = { [weak self] w in self?.currentLineWidth = w }
        toolbar.onCopy = { [weak self] in self?.copyAction() }
        toolbar.onSave = { [weak self] in self?.saveAction() }
        toolbar.onUndo = { [weak self] in self?.undo() }
        toolbar.onRedo = { [weak self] in self?.redo() }
    }

    private func enterEditing() {
        phase = .editing
        addSubview(toolbar)
        repositionToolbar()
        needsDisplay = true
    }

    private func repositionToolbar() {
        toolbar.layoutSubtreeIfNeeded()
        let w = max(toolbar.fittingSize.width, 500)
        let h: CGFloat = 36
        let gap: CGFloat = 12
        var x = selectionRect.midX - w / 2
        var y = selectionRect.minY - h - gap
        x = max(8, min(x, bounds.width - w - 8))
        if y < 8 { y = selectionRect.maxY + gap }
        if y + h > bounds.height - 8 { y = selectionRect.minY + gap }
        toolbar.frame = NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        backgroundImage.draw(in: bounds)
        ctx.setFillColor(dimColor.cgColor)
        ctx.fill(bounds)

        if case .selecting = phase, case .none = interaction { drawCrosshair(ctx) }

        if selectionRect.width > 0, selectionRect.height > 0 {
            ctx.saveGState()
            ctx.clip(to: selectionRect)
            backgroundImage.draw(in: bounds)
            ctx.restoreGState()

            // Annotations (clipped to selection)
            if phase == .editing {
                ctx.saveGState()
                ctx.clip(to: selectionRect)
                for a in annotations {
                    a.draw(in: ctx, imageSize: bounds.size, baseImage: backgroundImage)
                }
                drawingAnnotation?.draw(in: ctx, imageSize: bounds.size,
                                         baseImage: backgroundImage)
                ctx.restoreGState()
            }

            // Selection border
            ctx.setStrokeColor(CGColor.white)
            ctx.setLineWidth(1.5)
            ctx.stroke(selectionRect)

            // Selection handles (always in editing, or when selected in selecting phase)
            if phase == .editing || (phase == .selecting && selectionRect.width > 5) {
                drawSelectionHandles(ctx)
            }

            // Annotation selection handles
            if let idx = selectedAnnotation, idx < annotations.count {
                let br = annotations[idx].boundingRect
                ctx.saveGState()
                ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
                ctx.setLineWidth(1.5)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                ctx.stroke(br)
                ctx.setLineDash(phase: 0, lengths: [])
                for h in Handle.allCases {
                    let r = handleRect(for: h, in: br)
                    ctx.setFillColor(CGColor.white)
                    ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
                    ctx.setLineWidth(1)
                    ctx.fill(r); ctx.stroke(r)
                }
                ctx.restoreGState()
            }

            drawDimensions(ctx)
        }

        drawInstructions(ctx)
    }

    private func drawCrosshair(_ ctx: CGContext) {
        guard let p = mousePos else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [6, 4])
        ctx.move(to: CGPoint(x: p.x, y: 0))
        ctx.addLine(to: CGPoint(x: p.x, y: bounds.height))
        ctx.move(to: CGPoint(x: 0, y: p.y))
        ctx.addLine(to: CGPoint(x: bounds.width, y: p.y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawSelectionHandles(_ ctx: CGContext) {
        for h in Handle.allCases {
            let r = handleRect(for: h, in: selectionRect)
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
        let sz = (text as NSString).size(withAttributes: attrs)
        let pad: CGFloat = 6
        var oy = selectionRect.minY - sz.height - pad * 2 - 4
        if oy < 0 { oy = selectionRect.maxY + 4 }
        let bg = NSRect(x: selectionRect.midX - sz.width / 2 - pad, y: oy,
                        width: sz.width + pad * 2, height: sz.height + pad * 2)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        ctx.addPath(CGPath(roundedRect: bg, cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        (text as NSString).draw(at: CGPoint(x: bg.minX + pad, y: bg.minY + pad),
                                withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawInstructions(_ ctx: CGContext) {
        let text: String
        switch phase {
        case .selecting:
            text = "Click and drag to select  \u{2022}  Esc to cancel"
        case .editing:
            text = "Annotate, then Enter to copy  \u{2022}  ⌘S to save  \u{2022}  Esc to cancel"
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let sz = (text as NSString).size(withAttributes: attrs)
        let pad: CGFloat = 12
        let bg = NSRect(x: bounds.midX - sz.width / 2 - pad,
                        y: bounds.maxY - sz.height - pad * 2 - 24,
                        width: sz.width + pad * 2, height: sz.height + pad * 2)
        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
        ctx.addPath(CGPath(roundedRect: bg, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        (text as NSString).draw(at: CGPoint(x: bg.minX + pad, y: bg.minY + pad),
                                withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Handle geometry

    private func handleRect(for h: Handle, in r: NSRect) -> NSRect {
        let s = handleSize
        let pt: CGPoint
        switch h {
        case .topLeft:     pt = CGPoint(x: r.minX, y: r.maxY)
        case .top:         pt = CGPoint(x: r.midX, y: r.maxY)
        case .topRight:    pt = CGPoint(x: r.maxX, y: r.maxY)
        case .right:       pt = CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: pt = CGPoint(x: r.maxX, y: r.minY)
        case .bottom:      pt = CGPoint(x: r.midX, y: r.minY)
        case .bottomLeft:  pt = CGPoint(x: r.minX, y: r.minY)
        case .left:        pt = CGPoint(x: r.minX, y: r.midY)
        }
        return NSRect(x: pt.x - s / 2, y: pt.y - s / 2, width: s, height: s)
    }

    private func hitHandle(at pt: NSPoint, in r: NSRect) -> Handle? {
        let tol: CGFloat = 6
        for h in Handle.allCases {
            if handleRect(for: h, in: r).insetBy(dx: -tol, dy: -tol).contains(pt) { return h }
        }
        return nil
    }

    private func hitAnnotation(at pt: NSPoint) -> Int? {
        for i in annotations.indices.reversed() {
            if annotations[i].boundingRect.insetBy(dx: -4, dy: -4).contains(pt) { return i }
        }
        return nil
    }

    // MARK: Mouse — tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for a in trackingAreas { removeTrackingArea(a) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        mousePos = convert(event.locationInWindow, from: nil)
        if case .selecting = phase { needsDisplay = true }
    }

    // MARK: Mouse — down

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        commitTextField()

        switch phase {
        case .selecting:
            interaction = .dragging(start: pt)
            selectionRect = NSRect(origin: pt, size: .zero)

        case .editing:
            mouseDownEditing(pt)
        }
        needsDisplay = true
    }

    private func mouseDownEditing(_ pt: NSPoint) {
        // 1. Selection handles
        if let h = hitHandle(at: pt, in: selectionRect) {
            interaction = .resizingSel(handle: h)
            return
        }

        if currentTool == .select {
            // 2. Annotation handles (if one is selected)
            if let idx = selectedAnnotation, idx < annotations.count {
                let br = annotations[idx].boundingRect
                if let h = hitHandle(at: pt, in: br) {
                    saveUndo()
                    interaction = .resizingAnn(handle: h)
                    return
                }
            }
            // 3. Hit annotation body
            if let idx = hitAnnotation(at: pt), selectionRect.contains(pt) {
                if idx != selectedAnnotation { selectedAnnotation = idx }
                saveUndo()
                interaction = .movingAnn(last: pt)
                return
            }
            // 4. Inside selection — move selection + annotations
            if selectionRect.contains(pt) {
                selectedAnnotation = nil
                interaction = .movingSel(last: pt)
                return
            }
            // 5. Outside — deselect
            selectedAnnotation = nil
            return
        }

        // Drawing tools
        guard selectionRect.contains(pt) else { return }

        switch currentTool {
        case .select: break
        case .arrow:
            drawingAnnotation = ArrowAnnotation(start: pt, end: pt,
                                                 color: currentColor, lineWidth: currentLineWidth)
        case .rectangle:
            drawingAnnotation = RectAnnotation(rect: NSRect(origin: pt, size: .zero),
                                                color: currentColor, lineWidth: currentLineWidth)
        case .ellipse:
            drawingAnnotation = EllipseAnnotation(rect: NSRect(origin: pt, size: .zero),
                                                   color: currentColor, lineWidth: currentLineWidth)
        case .line:
            drawingAnnotation = LineAnnotation(start: pt, end: pt,
                                                color: currentColor, lineWidth: currentLineWidth)
        case .highlight:
            drawingAnnotation = HighlightAnnotation(rect: NSRect(origin: pt, size: .zero),
                                                     color: currentColor)
        case .blur:
            drawingAnnotation = BlurAnnotation(rect: NSRect(origin: pt, size: .zero))
        case .pen:
            drawingAnnotation = PenAnnotation(points: [pt], color: currentColor,
                                               lineWidth: currentLineWidth)
        case .text:
            showTextField(at: pt); return
        case .counter:
            saveUndo()
            annotations.append(CounterAnnotation(center: pt, number: counterValue,
                                                  color: currentColor))
            counterValue += 1
            needsDisplay = true; return
        }
        interaction = .drawing(start: pt)
    }

    // MARK: Mouse — drag

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        switch interaction {
        case .dragging(let start):
            selectionRect = rectFrom(start, pt)

        case .movingSel(let last):
            let dx = pt.x - last.x, dy = pt.y - last.y
            selectionRect.origin.x += dx; selectionRect.origin.y += dy
            for i in annotations.indices { annotations[i].offset(dx: dx, dy: dy) }
            interaction = .movingSel(last: pt)
            repositionToolbar()

        case .resizingSel(let handle):
            selectionRect = applyResize(selectionRect, handle: handle, to: pt)
            repositionToolbar()

        case .movingAnn(let last):
            guard let idx = selectedAnnotation, idx < annotations.count else { break }
            let dx = pt.x - last.x, dy = pt.y - last.y
            annotations[idx].offset(dx: dx, dy: dy)
            interaction = .movingAnn(last: pt)

        case .resizingAnn(let handle):
            guard let idx = selectedAnnotation, idx < annotations.count else { break }
            let old = annotations[idx].boundingRect
            let new = applyResize(old, handle: handle, to: pt)
            annotations[idx].resize(from: old, to: new)

        case .drawing(let start):
            dragDrawing(start: start, current: pt)

        case .none: break
        }
        needsDisplay = true
    }

    private func dragDrawing(start: NSPoint, current pt: NSPoint) {
        switch currentTool {
        case .arrow:
            if var a = drawingAnnotation as? ArrowAnnotation { a.end = pt; drawingAnnotation = a }
        case .rectangle:
            drawingAnnotation = RectAnnotation(rect: rectFrom(start, pt),
                                                color: currentColor, lineWidth: currentLineWidth)
        case .ellipse:
            drawingAnnotation = EllipseAnnotation(rect: rectFrom(start, pt),
                                                   color: currentColor, lineWidth: currentLineWidth)
        case .line:
            if var a = drawingAnnotation as? LineAnnotation { a.end = pt; drawingAnnotation = a }
        case .highlight:
            drawingAnnotation = HighlightAnnotation(rect: rectFrom(start, pt), color: currentColor)
        case .blur:
            drawingAnnotation = BlurAnnotation(rect: rectFrom(start, pt))
        case .pen:
            if var a = drawingAnnotation as? PenAnnotation {
                a.points.append(pt); drawingAnnotation = a
            }
        default: break
        }
    }

    // MARK: Mouse — up

    override func mouseUp(with event: NSEvent) {
        switch interaction {
        case .dragging:
            if selectionRect.width > 5, selectionRect.height > 5 {
                enterEditing()
            } else {
                selectionRect = .zero
            }

        case .drawing:
            if let ann = drawingAnnotation {
                var commit = true
                if let r = ann as? RectAnnotation, r.rect.width < 2, r.rect.height < 2 {
                    commit = false
                }
                if let e = ann as? EllipseAnnotation, e.rect.width < 2, e.rect.height < 2 {
                    commit = false
                }
                if commit { saveUndo(); annotations.append(ann) }
            }
            drawingAnnotation = nil

        default: break
        }
        interaction = .none
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) { onDismiss?() }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        let noMod = event.modifierFlags.intersection([.command, .option, .control]).isEmpty

        // Enter — copy
        if event.keyCode == 36 || event.keyCode == 76 {
            if phase == .editing { copyAction() }
            return
        }
        // Escape
        if event.keyCode == 53 {
            if let _ = selectedAnnotation {
                selectedAnnotation = nil; needsDisplay = true
            } else {
                onDismiss?()
            }
            return
        }
        // Cmd+S — save
        if cmd && event.charactersIgnoringModifiers == "s" { saveAction(); return }
        // Cmd+Z / Cmd+Shift+Z — undo/redo
        if cmd && event.charactersIgnoringModifiers == "z" {
            if shift { redo() } else { undo() }; return
        }
        // Cmd+C — copy
        if cmd && event.charactersIgnoringModifiers == "c" { copyAction(); return }

        guard phase == .editing, noMod,
              !(window?.firstResponder is NSText) else {
            super.keyDown(with: event); return
        }

        // Delete selected annotation
        if event.keyCode == 51 || event.keyCode == 117 {
            if let idx = selectedAnnotation, idx < annotations.count {
                saveUndo(); annotations.remove(at: idx)
                selectedAnnotation = nil; needsDisplay = true
            }
            return
        }

        // Tool shortcuts
        switch event.charactersIgnoringModifiers {
        case "v": toolbar.selectTool(.select)
        case "a": toolbar.selectTool(.arrow)
        case "r": toolbar.selectTool(.rectangle)
        case "e": toolbar.selectTool(.ellipse)
        case "l": toolbar.selectTool(.line)
        case "t": toolbar.selectTool(.text)
        case "h": toolbar.selectTool(.highlight)
        case "b": toolbar.selectTool(.blur)
        case "p": toolbar.selectTool(.pen)
        case "n": toolbar.selectTool(.counter)
        default: super.keyDown(with: event)
        }
    }

    // MARK: Undo / Redo

    private func saveUndo() {
        undoStack.append(annotations.map { $0 })
        redoStack.removeAll()
    }

    private func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(annotations.map { $0 })
        annotations = undoStack.removeLast()
        selectedAnnotation = nil; needsDisplay = true
    }

    private func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(annotations.map { $0 })
        annotations = redoStack.removeLast()
        selectedAnnotation = nil; needsDisplay = true
    }

    // MARK: Text field

    private func showTextField(at pt: NSPoint) {
        let tf = NSTextField(frame: NSRect(x: pt.x, y: pt.y - 24, width: 200, height: 24))
        tf.font = .systemFont(ofSize: 16, weight: .medium)
        tf.textColor = currentColor
        tf.backgroundColor = NSColor.white.withAlphaComponent(0.85)
        tf.isBezeled = false; tf.focusRingType = .none; tf.drawsBackground = true
        tf.target = self; tf.action = #selector(textDone)
        addSubview(tf)
        window?.makeFirstResponder(tf)
        activeTextField = tf
    }

    @objc private func textDone(_ sender: NSTextField) { commitTextField() }

    private func commitTextField() {
        guard let tf = activeTextField else { return }
        if !tf.stringValue.isEmpty {
            saveUndo()
            annotations.append(TextAnnotation(position: tf.frame.origin,
                                               text: tf.stringValue,
                                               color: currentColor, fontSize: 16))
        }
        tf.removeFromSuperview(); activeTextField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // MARK: Copy / Save

    private func copyAction() {
        guard let image = renderFinalImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        onDismiss?()
    }

    private func saveAction() {
        guard let image = renderFinalImage() else { return }
        onDismiss?()
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "screenshot.png"
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url,
               let tiff = image.tiffRepresentation,
               let bmp = NSBitmapImageRep(data: tiff),
               let data = bmp.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }

    private func renderFinalImage() -> NSImage? {
        guard selectionRect.width > 1, selectionRect.height > 1 else { return nil }
        let sx = CGFloat(sourceCGImage.width) / bounds.width
        let sy = CGFloat(sourceCGImage.height) / bounds.height
        let pxRect = CGRect(x: selectionRect.origin.x * sx,
                            y: (bounds.height - selectionRect.maxY) * sy,
                            width: selectionRect.width * sx,
                            height: selectionRect.height * sy)
        guard let cropped = sourceCGImage.cropping(to: pxRect) else { return nil }

        let cropSize = selectionRect.size
        let baseImg = NSImage(cgImage: cropped, size: cropSize)
        let result = NSImage(size: cropSize)
        result.lockFocus()
        baseImg.draw(in: NSRect(origin: .zero, size: cropSize))
        if let ctx = NSGraphicsContext.current?.cgContext {
            var local = annotations
            for i in local.indices {
                local[i].offset(dx: -selectionRect.origin.x, dy: -selectionRect.origin.y)
            }
            for a in local { a.draw(in: ctx, imageSize: cropSize, baseImage: baseImg) }
        }
        result.unlockFocus()
        return result
    }

    // MARK: Resize math

    private func applyResize(_ r: NSRect, handle: Handle, to pt: NSPoint) -> NSRect {
        var n = r
        switch handle {
        case .topLeft:     n = NSRect(x: pt.x, y: r.minY, width: r.maxX - pt.x, height: pt.y - r.minY)
        case .top:         n = NSRect(x: r.minX, y: r.minY, width: r.width, height: pt.y - r.minY)
        case .topRight:    n = NSRect(x: r.minX, y: r.minY, width: pt.x - r.minX, height: pt.y - r.minY)
        case .right:       n = NSRect(x: r.minX, y: r.minY, width: pt.x - r.minX, height: r.height)
        case .bottomRight: n = NSRect(x: r.minX, y: pt.y, width: pt.x - r.minX, height: r.maxY - pt.y)
        case .bottom:      n = NSRect(x: r.minX, y: pt.y, width: r.width, height: r.maxY - pt.y)
        case .bottomLeft:  n = NSRect(x: pt.x, y: pt.y, width: r.maxX - pt.x, height: r.maxY - pt.y)
        case .left:        n = NSRect(x: pt.x, y: r.minY, width: r.maxX - pt.x, height: r.height)
        }
        if n.width < 0 { n.origin.x += n.width; n.size.width = -n.width }
        if n.height < 0 { n.origin.y += n.height; n.size.height = -n.height }
        n.size.width = max(n.width, 10); n.size.height = max(n.height, 10)
        return n
    }

    private func rectFrom(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}

// MARK: - Capture coordinator

class CaptureOverlay {
    private var windows: [KeyableWindow] = []
    var onDismiss: (() -> Void)?

    func show() {
        let screens = NSScreen.screens
        let primaryMaxY = screens[0].frame.maxY

        for screen in screens {
            let cgRect = CGRect(x: screen.frame.origin.x,
                                y: primaryMaxY - screen.frame.maxY,
                                width: screen.frame.width,
                                height: screen.frame.height)

            guard let cgImage = CGWindowListCreateImage(
                cgRect, .optionOnScreenOnly,
                kCGNullWindowID, [.bestResolution]
            ) else { continue }

            let screenImage = NSImage(cgImage: cgImage, size: screen.frame.size)
            let window = KeyableWindow(contentRect: screen.frame,
                                       styleMask: .borderless,
                                       backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.isOpaque = true; window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size),
                                             backgroundImage: screenImage,
                                             sourceCGImage: cgImage)
            view.onDismiss = { [weak self] in self?.close() }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        windows.first?.makeFirstResponder(windows.first?.contentView)
    }

    func close() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        onDismiss?()
    }
}
