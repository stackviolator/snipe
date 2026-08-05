import AppKit
import CoreGraphics

/// Composite of all displays in a single, top-left-origin, point space.
struct CompositeImage {
    let cgImage: CGImage
    let pointRect: CGRect   // union of displays in global top-left coordinates
    let pixelsPerPoint: CGFloat
    var pointSize: CGSize { pointRect.size }
}

enum ScreenCapture {

    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Grabs every display and stitches them into one image.
    static func captureComposite() -> CompositeImage? {
        let screens = NSScreen.screens
        guard let main = screens.first else { return nil }

        var unionTL = CGRect.null
        var entries: [(CGRect, CGImage)] = []
        for s in screens {
            guard let number = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let img = CGDisplayCreateImage(CGDirectDisplayID(number.uint32Value)) else { continue }
            let frame = s.frame
            // Convert AppKit bottom-left frame to global top-left coordinates.
            let tl = CGRect(x: frame.minX, y: main.frame.maxY - frame.maxY,
                            width: frame.width, height: frame.height)
            unionTL = unionTL.union(tl)
            entries.append((tl, img))
        }
        guard !entries.isEmpty, !unionTL.isNull else { return nil }

        let scale = screens.map(\.backingScaleFactor).max() ?? 1
        let pw = Int((unionTL.width * scale).rounded())
        let ph = Int((unionTL.height * scale).rounded())
        guard pw > 0, ph > 0,
              let ctx = CGContext(data: nil, width: pw, height: ph,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        for (tl, img) in entries {
            // Place in CG (y-up) coordinates: top-left offset -> flipped.
            let dest = CGRect(x: (tl.minX - unionTL.minX) * scale,
                              y: CGFloat(ph) - (tl.minY - unionTL.minY + tl.height) * scale,
                              width: tl.width * scale,
                              height: tl.height * scale)
            ctx.draw(img, in: dest)
        }
        guard let image = ctx.makeImage() else { return nil }
        return CompositeImage(cgImage: image, pointRect: unionTL, pixelsPerPoint: scale)
    }
}
