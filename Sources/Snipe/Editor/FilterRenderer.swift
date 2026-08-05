import AppKit
import CoreImage

/// Shared blur / pixelate rendering so the canvas and the exporter agree.
enum FilterRenderer {
    static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func filteredCGImage(for item: Annotation, original: CGImage, scale: CGFloat) -> CGImage? {
        let cropRect = CGRect(x: item.rect.minX * scale,
                              y: item.rect.minY * scale,
                              width: item.rect.width * scale,
                              height: item.rect.height * scale)
        guard let cropped = original.cropping(to: cropRect) else { return nil }
        let ci = CIImage(cgImage: cropped).clampedToExtent()
        let filter: CIFilter
        if item.type == .blur {
            filter = CIFilter(name: "CIGaussianBlur")!
            filter.setValue(ci, forKey: kCIInputImageKey)
            filter.setValue(max(6, item.strokeWidth * 2) as NSNumber, forKey: kCIInputRadiusKey)
        } else {
            filter = CIFilter(name: "CIPixellate")!
            filter.setValue(ci, forKey: kCIInputImageKey)
            filter.setValue(max(4, item.strokeWidth * 2) as NSNumber, forKey: kCIInputScaleKey)
        }
        guard let output = filter.outputImage?.cropped(to: ci.extent) else { return nil }
        return context.createCGImage(output, from: ci.extent)
    }
}

extension NSColor {
    var cg: CGColor { cgColor }
}
