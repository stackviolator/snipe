import AppKit
import CoreText

/// The editor window: toolbar + zoomable/scrollable canvas + export.
final class EditorController: NSObject, NSWindowDelegate {

    let image: EditorImage
    var onClose: (() -> Void)?

    private var window: NSWindow?
    private var canvas: CanvasView!
    private var scrollView: NSScrollView!

    init(image: EditorImage) {
        self.image = image
    }

    func show() {
        canvas = CanvasView(editorImage: image)
        canvas.onRequestCopy = { [weak self] in self?.copyAndClose() }
        canvas.onRequestSave = { [weak self] in self?.save() }
        canvas.onRequestClose = { [weak self] in self?.close() }
        canvas.onZoomIn = { [weak self] in self?.zoom(by: 1.25) }
        canvas.onZoomOut = { [weak self] in self?.zoom(by: 1 / 1.25) }
        canvas.onFit = { [weak self] in self?.fitToWindow() }

        let toolbar = ToolbarView()
        toolbar.onToolChanged = { [weak self] tool in
            self?.canvas.tool = tool
            self?.canvas.window?.makeFirstResponder(self?.canvas)
        }
        toolbar.onColorChanged = { [weak self] c in self?.canvas.color = c }
        toolbar.onWidthChanged = { [weak self] w in self?.canvas.strokeWidth = w }
        toolbar.onFillChanged = { [weak self] f in self?.canvas.fillShapes = f }
        toolbar.onUndo = { [weak self] in self?.canvas.undo() }
        toolbar.onRedo = { [weak self] in self?.canvas.redo() }
        toolbar.onCopy = { [weak self] in self?.copyAndClose() }
        toolbar.onSave = { [weak self] in self?.save() }
        toolbar.onCancel = { [weak self] in self?.close() }
        toolbar.onZoomIn = { [weak self] in self?.zoom(by: 1.25) }
        toolbar.onZoomOut = { [weak self] in self?.zoom(by: 1 / 1.25) }
        toolbar.onFit = { [weak self] in self?.fitToWindow() }

        scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.05
        scrollView.maxMagnification = 8.0
        scrollView.documentView = canvas
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toolbar)
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 88),
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Snipe"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = NSSize(width: 560, height: 400)
        window.contentView = content
        self.window = window

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        var size = image.pointSize
        size.width = min(max(size.width + 48, 560), screen.width * 0.92)
        size.height = min(max(size.height + 48 + 88, 400), screen.height * 0.92)
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(canvas)

        DispatchQueue.main.async { [weak self] in self?.fitToWindow() }
    }

    // MARK: Zoom

    private func zoom(by factor: CGFloat) {
        let mag = scrollView.magnification * factor
        let b = scrollView.contentView.bounds
        scrollView.setMagnification(mag, centeredAt: NSPoint(x: b.midX, y: b.midY))
    }

    private func fitToWindow() {
        let doc = canvas.frame.size
        let view = scrollView.contentView.bounds.size
        guard doc.width > 0, doc.height > 0, view.width > 0, view.height > 0 else { return }
        let mag = min(view.width / doc.width, view.height / doc.height)
        scrollView.setMagnification(min(mag, 1.0), centeredAt: NSPoint(x: doc.width / 2, y: doc.height / 2))
    }

    // MARK: Export

    private func flattenedImage() -> NSImage? {
        Self.flatten(items: canvas.items, image: image)
    }

    /// Pure render path (used by the UI and by `--render-test`).
    static func flatten(items: [Annotation], image: EditorImage) -> NSImage? {
        let scale = image.scale
        let w = image.cgImage.width
        let h = image.cgImage.height
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image.cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        for item in items {
            draw(item, in: ctx, scale: scale, height: CGFloat(h), source: image.cgImage)
        }
        guard let out = ctx.makeImage() else { return nil }
        return NSImage(cgImage: out, size: image.pointSize)
    }

    private static func cgRect(_ r: CGRect, scale: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: r.minX * scale,
               y: height - (r.minY + r.height) * scale,
               width: r.width * scale,
               height: r.height * scale)
    }

    private static func draw(_ item: Annotation, in ctx: CGContext, scale: CGFloat, height: CGFloat, source: CGImage) {
        ctx.saveGState()
        switch item.type {
        case .select:
            break
        case .pen:
            guard item.points.count >= 2 else { break }
            ctx.setStrokeColor(item.color.cg)
            ctx.setLineWidth(item.strokeWidth * scale)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let pts = item.points.map { CGPoint(x: $0.x * scale, y: height - $0.y * scale) }
            ctx.beginPath()
            ctx.move(to: pts[0])
            for p in pts.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        case .line, .arrow:
            guard item.points.count == 2 else { break }
            ctx.setStrokeColor(item.color.cg)
            ctx.setLineWidth(item.strokeWidth * scale)
            ctx.setLineCap(.round)
            let a = CGPoint(x: item.points[0].x * scale, y: height - item.points[0].y * scale)
            let b = CGPoint(x: item.points[1].x * scale, y: height - item.points[1].y * scale)
            ctx.beginPath()
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
            if item.type == .arrow {
                let angle = atan2(b.y - a.y, b.x - a.x)
                let headLen = (10 + item.strokeWidth * 2) * scale
                let h1 = CGPoint(x: b.x - headLen * cos(angle - 0.45), y: b.y - headLen * sin(angle - 0.45))
                let h2 = CGPoint(x: b.x - headLen * cos(angle + 0.45), y: b.y - headLen * sin(angle + 0.45))
                ctx.setFillColor(item.color.cg)
                ctx.beginPath()
                ctx.move(to: b)
                ctx.addLine(to: h1)
                ctx.addLine(to: h2)
                ctx.closePath()
                ctx.fillPath()
            }
        case .rect:
            let r = cgRect(item.rect, scale: scale, height: height)
            ctx.setStrokeColor(item.color.cg)
            ctx.setLineWidth(item.strokeWidth * scale)
            ctx.stroke(r)
            if item.fill {
                ctx.setFillColor(item.color.withAlphaComponent(0.25).cg)
                ctx.fill(r)
            }
        case .ellipse:
            let r = cgRect(item.rect, scale: scale, height: height)
            ctx.setStrokeColor(item.color.cg)
            ctx.setLineWidth(item.strokeWidth * scale)
            ctx.strokeEllipse(in: r)
            if item.fill {
                ctx.setFillColor(item.color.withAlphaComponent(0.25).cg)
                ctx.fillEllipse(in: r)
            }
        case .highlight:
            let r = cgRect(item.rect, scale: scale, height: height)
            ctx.setFillColor(item.color.withAlphaComponent(0.35).cg)
            ctx.fill(r)
        case .blur, .pixelate:
            let r = cgRect(item.rect, scale: scale, height: height)
            if let cg = FilterRenderer.filteredCGImage(for: item, original: source, scale: scale) {
                ctx.draw(cg, in: r)
            }
        case .text:
            drawText(item, in: ctx, scale: scale, height: height)
        case .number:
            let r = cgRect(item.rect, scale: scale, height: height)
            ctx.setFillColor(item.color.cg)
            ctx.fillEllipse(in: r)
            drawNumberCentered(item, in: ctx, scale: scale, height: height)
        }
        ctx.restoreGState()
    }

    private static func drawText(_ item: Annotation, in ctx: CGContext, scale: CGFloat, height: CGFloat) {
        guard !item.text.isEmpty else { return }
        let font = NSFont.systemFont(ofSize: item.textSize * scale)
        let attr = NSAttributedString(string: item.text, attributes: [
            .font: font,
            .foregroundColor: item.color
        ])
        let line = CTLineCreateWithAttributedString(attr)
        let x = item.rect.minX * scale
        let baselineY = height - item.rect.minY * scale - font.ascender * scale
        ctx.textPosition = CGPoint(x: x, y: baselineY)
        CTLineDraw(line, ctx)
    }

    private static func drawNumberCentered(_ item: Annotation, in ctx: CGContext, scale: CGFloat, height: CGFloat) {
        let font = NSFont.boldSystemFont(ofSize: item.rect.height * scale * 0.5)
        let attr = NSAttributedString(string: "\(item.number)", attributes: [
            .font: font,
            .foregroundColor: NSColor.white
        ])
        let line = CTLineCreateWithAttributedString(attr)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let cx = item.rect.midX * scale
        let centerY = height - item.rect.midY * scale
        ctx.textPosition = CGPoint(x: cx - width / 2, y: centerY - (ascent - descent) / 2)
        CTLineDraw(line, ctx)
    }

    // MARK: Actions

    private func copyAndClose() {
        guard let image = flattenedImage() else { close(); return }
        copyImageToPasteboard(image)
        close()
    }

    private func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "Snipe-\(formatter.string(from: Date())).png"
        if panel.runModal() == .OK, let url = panel.url {
            guard let flat = flattenedImage(),
                  let cg = flat.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let rep = NSBitmapImageRep(cgImage: cg)
            let type: NSBitmapImageRep.FileType
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg": type = .jpeg
            case "tif", "tiff": type = .tiff
            default: type = .png
            }
            if let data = rep.representation(using: type, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }

    private func close() {
        window?.orderOut(nil)
        window?.close()
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
