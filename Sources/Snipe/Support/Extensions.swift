import AppKit

func copyImageToPasteboard(_ image: NSImage) {
    let pb = NSPasteboard.general
    pb.clearContents()
    if let tiff = image.tiffRepresentation {
        pb.setData(tiff, forType: .tiff)
    }
    if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let rep = NSBitmapImageRep(cgImage: cg)
        if let png = rep.representation(using: .png, properties: [:]) {
            pb.setData(png, forType: .png)
        }
    }
}

func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
    CGRect(
        x: min(a.x, b.x),
        y: min(a.y, b.y),
        width: abs(a.x - b.x),
        height: abs(a.y - b.y)
    )
}

func boundingRect(of points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .zero }
    var r = CGRect(origin: first, size: .zero)
    for p in points {
        r = r.union(CGRect(origin: p, size: .zero))
    }
    return r
}

func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
    var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
    t = min(max(t, 0), 1)
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}

func distanceFromPath(_ p: CGPoint, _ pts: [CGPoint]) -> CGFloat {
    guard pts.count >= 2 else { return .greatestFiniteMagnitude }
    var best = CGFloat.greatestFiniteMagnitude
    for i in 0..<(pts.count - 1) {
        best = min(best, distanceToSegment(p, pts[i], pts[i + 1]))
    }
    return best
}
