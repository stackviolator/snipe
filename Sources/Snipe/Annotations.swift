import AppKit
import CoreImage

// MARK: - Tool types

enum ToolType: String, CaseIterable {
    case select    = "Select"
    case arrow     = "Arrow"
    case rectangle = "Rectangle"
    case ellipse   = "Ellipse"
    case line      = "Line"
    case text      = "Text"
    case highlight = "Highlight"
    case blur      = "Blur"
    case pen       = "Pen"
    case counter   = "Counter"
}

// MARK: - Annotation protocol

protocol Annotation {
    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage)
    var boundingRect: NSRect { get }
    mutating func offset(dx: CGFloat, dy: CGFloat)
    mutating func resize(from oldRect: NSRect, to newRect: NSRect)
}

extension Annotation {
    func mapPoint(_ pt: CGPoint, from old: NSRect, to new: NSRect) -> CGPoint {
        let sx = old.width > 0 ? new.width / old.width : 1
        let sy = old.height > 0 ? new.height / old.height : 1
        return CGPoint(x: new.minX + (pt.x - old.minX) * sx,
                       y: new.minY + (pt.y - old.minY) * sy)
    }
}

// MARK: - Arrow

struct ArrowAnnotation: Annotation {
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat

    var boundingRect: NSRect {
        let r = NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                       width: abs(end.x - start.x), height: abs(end.y - start.y))
        return r.insetBy(dx: -lineWidth, dy: -lineWidth)
    }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        start.x += dx; start.y += dy
        end.x += dx; end.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        start = mapPoint(start, from: oldRect, to: newRect)
        end = mapPoint(end, from: oldRect, to: newRect)
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)

        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let len = max(lineWidth * 4, 12)
        let spread: CGFloat = .pi / 6
        let p1 = CGPoint(x: end.x - len * cos(angle - spread),
                          y: end.y - len * sin(angle - spread))
        let p2 = CGPoint(x: end.x - len * cos(angle + spread),
                          y: end.y - len * sin(angle + spread))
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()

        ctx.restoreGState()
    }
}

// MARK: - Rectangle

struct RectAnnotation: Annotation {
    var rect: NSRect
    var color: NSColor
    var lineWidth: CGFloat

    var boundingRect: NSRect { rect.insetBy(dx: -lineWidth, dy: -lineWidth) }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        rect.origin.x += dx; rect.origin.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        let o = mapPoint(rect.origin, from: oldRect, to: newRect)
        let c = mapPoint(CGPoint(x: rect.maxX, y: rect.maxY), from: oldRect, to: newRect)
        rect = NSRect(x: o.x, y: o.y, width: c.x - o.x, height: c.y - o.y)
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.stroke(rect)
        ctx.restoreGState()
    }
}

// MARK: - Ellipse

struct EllipseAnnotation: Annotation {
    var rect: NSRect
    var color: NSColor
    var lineWidth: CGFloat

    var boundingRect: NSRect { rect.insetBy(dx: -lineWidth, dy: -lineWidth) }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        rect.origin.x += dx; rect.origin.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        let o = mapPoint(rect.origin, from: oldRect, to: newRect)
        let c = mapPoint(CGPoint(x: rect.maxX, y: rect.maxY), from: oldRect, to: newRect)
        rect = NSRect(x: o.x, y: o.y, width: c.x - o.x, height: c.y - o.y)
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()
    }
}

// MARK: - Line

struct LineAnnotation: Annotation {
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat

    var boundingRect: NSRect {
        let r = NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                       width: abs(end.x - start.x), height: abs(end.y - start.y))
        return r.insetBy(dx: -lineWidth, dy: -lineWidth)
    }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        start.x += dx; start.y += dy
        end.x += dx; end.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        start = mapPoint(start, from: oldRect, to: newRect)
        end = mapPoint(end, from: oldRect, to: newRect)
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

// MARK: - Text

struct TextAnnotation: Annotation {
    var position: CGPoint
    var text: String
    var color: NSColor
    var fontSize: CGFloat

    var boundingRect: NSRect {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        return NSRect(origin: position, size: size)
    }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        position.x += dx; position.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        position = mapPoint(position, from: oldRect, to: newRect)
        if oldRect.height > 0 {
            fontSize *= newRect.height / oldRect.height
            fontSize = max(6, min(fontSize, 200))
        }
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color,
        ]
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        (text as NSString).draw(at: position, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Highlight

struct HighlightAnnotation: Annotation {
    var rect: NSRect
    var color: NSColor

    var boundingRect: NSRect { rect }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        rect.origin.x += dx; rect.origin.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        let o = mapPoint(rect.origin, from: oldRect, to: newRect)
        let c = mapPoint(CGPoint(x: rect.maxX, y: rect.maxY), from: oldRect, to: newRect)
        rect = NSRect(x: o.x, y: o.y, width: c.x - o.x, height: c.y - o.y)
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        ctx.saveGState()
        ctx.setFillColor(color.withAlphaComponent(0.35).cgColor)
        ctx.fill(rect)
        ctx.restoreGState()
    }
}

// MARK: - Blur

struct BlurAnnotation: Annotation {
    var rect: NSRect
    var radius: CGFloat = 12

    var boundingRect: NSRect { rect }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        rect.origin.x += dx; rect.origin.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        let o = mapPoint(rect.origin, from: oldRect, to: newRect)
        let c = mapPoint(CGPoint(x: rect.maxX, y: rect.maxY), from: oldRect, to: newRect)
        rect = NSRect(x: o.x, y: o.y, width: c.x - o.x, height: c.y - o.y)
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        guard rect.width > 1, rect.height > 1 else { return }
        guard let tiff = baseImage.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let full = bmp.cgImage else { return }

        ctx.saveGState()

        let sx = CGFloat(full.width) / imageSize.width
        let sy = CGFloat(full.height) / imageSize.height
        let pxRect = CGRect(x: rect.origin.x * sx,
                            y: (imageSize.height - rect.maxY) * sy,
                            width: rect.width * sx,
                            height: rect.height * sy)

        guard let crop = full.cropping(to: pxRect) else {
            ctx.restoreGState(); return
        }

        let ci = CIImage(cgImage: crop)
        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            ctx.restoreGState(); return
        }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(radius * sx, forKey: kCIInputRadiusKey)

        if let output = filter.outputImage {
            let ciCtx = CIContext()
            if let blurred = ciCtx.createCGImage(output, from: ci.extent) {
                ctx.clip(to: rect)
                ctx.draw(blurred, in: rect)
            }
        }

        ctx.restoreGState()
    }
}

// MARK: - Pen (freehand)

struct PenAnnotation: Annotation {
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat

    var boundingRect: NSRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return NSRect(x: minX - lineWidth, y: minY - lineWidth,
                      width: maxX - minX + lineWidth * 2,
                      height: maxY - minY + lineWidth * 2)
    }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        for i in points.indices {
            points[i].x += dx; points[i].y += dy
        }
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        for i in points.indices {
            points[i] = mapPoint(points[i], from: oldRect, to: newRect)
        }
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        guard points.count > 1 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: points[0])
        for i in 1..<points.count { ctx.addLine(to: points[i]) }
        ctx.strokePath()
        ctx.restoreGState()
    }
}

// MARK: - Numbered counter

struct CounterAnnotation: Annotation {
    var center: CGPoint
    var number: Int
    var color: NSColor
    var size: CGFloat = 28

    var boundingRect: NSRect {
        NSRect(x: center.x - size / 2, y: center.y - size / 2,
               width: size, height: size)
    }

    mutating func offset(dx: CGFloat, dy: CGFloat) {
        center.x += dx; center.y += dy
    }

    mutating func resize(from oldRect: NSRect, to newRect: NSRect) {
        center = mapPoint(center, from: oldRect, to: newRect)
        if oldRect.width > 0 && oldRect.height > 0 {
            size *= min(newRect.width / oldRect.width, newRect.height / oldRect.height)
            size = max(12, min(size, 120))
        }
    }

    func draw(in ctx: CGContext, imageSize: NSSize, baseImage: NSImage) {
        ctx.saveGState()

        let circle = NSRect(x: center.x - size / 2,
                            y: center.y - size / 2,
                            width: size, height: size)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: circle)

        let text = "\(number)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.55, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let ts = (text as NSString).size(withAttributes: attrs)

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        (text as NSString).draw(at: CGPoint(x: center.x - ts.width / 2,
                                             y: center.y - ts.height / 2),
                                withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()

        ctx.restoreGState()
    }
}
