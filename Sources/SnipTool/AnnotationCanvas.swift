import AppKit

class AnnotationCanvas: NSView {
    let baseImage: NSImage
    var annotations: [any Annotation] = []
    var currentTool: ToolType = .arrow
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 3
    var onAnnotationAdded: (() -> Void)?

    private var currentAnnotation: (any Annotation)?
    private var dragStart: NSPoint = .zero
    private var counterValue: Int = 1
    private var activeTextField: NSTextField?

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
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        dragStart = pt
        commitTextField()

        switch currentTool {
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
            annotations.append(CounterAnnotation(center: pt, number: counterValue,
                                                  color: currentColor))
            counterValue += 1
            onAnnotationAdded?()
            needsDisplay = true
            return
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        switch currentTool {
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

    override func mouseUp(with event: NSEvent) {
        guard let annotation = currentAnnotation else { return }

        var commit = true
        if let r = annotation as? RectAnnotation, r.rect.width < 2, r.rect.height < 2 {
            commit = false
        }
        if let e = annotation as? EllipseAnnotation, e.rect.width < 2, e.rect.height < 2 {
            commit = false
        }

        if commit {
            annotations.append(annotation)
            onAnnotationAdded?()
        }
        currentAnnotation = nil
        needsDisplay = true
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
            annotations.append(TextAnnotation(position: tf.frame.origin,
                                               text: tf.stringValue,
                                               color: currentColor,
                                               fontSize: 16))
            onAnnotationAdded?()
        }
        tf.removeFromSuperview()
        activeTextField = nil
        needsDisplay = true
    }

    // MARK: Render final image

    func renderFinalImage() -> NSImage {
        let img = NSImage(size: bounds.size)
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            baseImage.draw(in: bounds)
            for a in annotations { a.draw(in: ctx, imageSize: bounds.size, baseImage: baseImage) }
        }
        img.unlockFocus()
        return img
    }

    // MARK: Helpers

    private func rectFrom(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
