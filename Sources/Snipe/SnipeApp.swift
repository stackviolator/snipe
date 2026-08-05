import SwiftUI
import AppKit

@main
struct SnipeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Capture Screen Area") {
                CaptureManager.shared.startCapture()
            }
            Divider()
            Button("Quit Snipe") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "camera.viewfinder")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.register()
        if CommandLine.arguments.contains("--render-test") {
            runRenderTest()
            NSApplication.shared.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--diag") {
            runDiag()
            NSApplication.shared.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--capture") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                CaptureManager.shared.startCapture()
            }
        }
    }

    /// Renders one of every annotation type onto a synthetic image and writes a PNG.
    private func runRenderTest() {
        let w = 900, h = 640
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        let colors = [NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.45, alpha: 1),
                      NSColor(calibratedRed: 0.90, green: 0.62, blue: 0.20, alpha: 1)]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors.map(\.cg) as CFArray,
                                     locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
        }
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cg)
        ctx.setLineWidth(1)
        for x in stride(from: 0, to: w, by: 50) {
            ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: h))
        }
        for y in stride(from: 0, to: h, by: 50) {
            ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: w, y: y))
        }
        ctx.strokePath()
        guard let base = ctx.makeImage() else { return }

        let editorImage = EditorImage(cgImage: base, pointSize: CGSize(width: w, height: h))
        var items: [Annotation] = []
        items.append(Annotation(type: .rect, rect: CGRect(x: 40, y: 40, width: 200, height: 140), color: .systemRed, strokeWidth: 4))
        items.append(Annotation(type: .ellipse, rect: CGRect(x: 300, y: 40, width: 180, height: 140), color: .systemGreen, strokeWidth: 4, fill: true))
        items.append(Annotation(type: .blur, rect: CGRect(x: 600, y: 40, width: 220, height: 150), strokeWidth: 4))
        items.append(Annotation(type: .arrow, rect: CGRect(x: 100, y: 220, width: 200, height: 100),
                                points: [CGPoint(x: 100, y: 220), CGPoint(x: 300, y: 330)], color: .systemBlue, strokeWidth: 5))
        items.append(Annotation(type: .pen, rect: CGRect(x: 380, y: 220, width: 240, height: 120),
                                points: [CGPoint(x: 380, y: 220), CGPoint(x: 420, y: 270), CGPoint(x: 460, y: 240),
                                         CGPoint(x: 500, y: 310), CGPoint(x: 560, y: 250), CGPoint(x: 620, y: 330)],
                                color: .systemOrange, strokeWidth: 4))
        items.append(Annotation(type: .pixelate, rect: CGRect(x: 640, y: 220, width: 200, height: 140), strokeWidth: 4))
        items.append(Annotation(type: .highlight, rect: CGRect(x: 120, y: 430, width: 420, height: 60), color: .systemYellow))
        items.append(Annotation(type: .text, rect: CGRect(x: 40, y: 530, width: 300, height: 60), color: .white, text: "Hello Snipe!", textSize: 44))
        items.append(Annotation(type: .number, rect: CGRect(x: 620, y: 500, width: 70, height: 70), color: .systemPurple, number: 1))

        guard let flat = EditorController.flatten(items: items, image: editorImage),
              let cg = flat.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        let out = URL(fileURLWithPath: "/tmp/snipe-render-test.png")
        try? png.write(to: out)
        print("render-test wrote \(out.path)")
    }

    /// Renders individual annotation types on a solid background and reports sampled pixels.
    private func runDiag() {
        let w = 400, h = 300
        func makeImage() -> CGImage? {
            guard let ctx = CGContext(data: nil, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.setFillColor(NSColor(calibratedWhite: 0.5, alpha: 1).cg)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            return ctx.makeImage()
        }
        func sample(_ items: [Annotation], _ name: String, _ points: [(String, Int, Int)]) {
            guard let base = makeImage() else { return }
            let ei = EditorImage(cgImage: base, pointSize: CGSize(width: w, height: h))
            guard let flat = EditorController.flatten(items: items, image: ei),
                  let cg = flat.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            let data = ctx.data!.bindMemory(to: UInt8.self, capacity: cg.width * cg.height * 4)
            func px(_ x: Int, _ y: Int) -> (Int, Int, Int) {
                let i = (y * cg.width + x) * 4
                return (Int(data[i]), Int(data[i+1]), Int(data[i+2]))
            }
            print("== \(name)")
            for (label, x, y) in points {
                let p = px(x, y)
                print(String(format: "   %@ (%d,%d) r=%d g=%d b=%d", label, x, y, p.0, p.1, p.2))
            }
        }

        sample([Annotation(type: .text, rect: CGRect(x: 50, y: 120, width: 300, height: 60),
                           color: .white, text: "Hello", textSize: 48)],
               "text white", [("glyph1", 70, 140), ("glyph2", 95, 145), ("above rect", 200, 100), ("inside", 200, 140)])

        sample([Annotation(type: .number, rect: CGRect(x: 150, y: 100, width: 80, height: 80),
                           color: .systemPurple, number: 7)],
               "number purple", [("circle center", 190, 140), ("circle edge", 155, 105), ("digit area", 190, 138)])

        sample([Annotation(type: .arrow, rect: .zero,
                           points: [CGPoint(x: 50, y: 200), CGPoint(x: 300, y: 250)],
                           color: .systemBlue, strokeWidth: 6)],
               "arrow blue", [("line mid", 175, 225), ("head", 292, 247)])

        sample([Annotation(type: .rect, rect: CGRect(x: 50, y: 50, width: 200, height: 120),
                           color: .systemRed, strokeWidth: 5)],
               "rect red", [("left edge", 50, 110), ("inside", 150, 110)])
    }
}
