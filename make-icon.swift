// Generates Resources/AppIcon.icns (run with: swift make-icon.swift)
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let bgPath = NSBezierPath(roundedRect: rect, xRadius: 230, yRadius: 230)
NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.26, alpha: 1).setFill()
bgPath.fill()
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.22, green: 0.36, blue: 0.85, alpha: 0.55),
    NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.2, alpha: 0.0)
])!
gradient.draw(in: bgPath, angle: -90)

// Camera body
let body = NSBezierPath(roundedRect: NSRect(x: 200, y: 300, width: 624, height: 440), xRadius: 90, yRadius: 90)
NSColor.white.setFill()
body.fill()

// Top button
let topBtn = NSBezierPath(roundedRect: NSRect(x: 560, y: 740, width: 150, height: 78), xRadius: 28, yRadius: 28)
NSColor.white.withAlphaComponent(0.92).setFill()
topBtn.fill()

// Flash
let flash = NSBezierPath(roundedRect: NSRect(x: 250, y: 716, width: 96, height: 96), xRadius: 26, yRadius: 26)
NSColor.white.withAlphaComponent(0.92).setFill()
flash.fill()

// Lens outer
let lensOuter = NSBezierPath(ovalIn: NSRect(x: 352, y: 400, width: 320, height: 320))
NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.32, alpha: 1).setFill()
lensOuter.fill()

// Lens ring
let ring = NSBezierPath(ovalIn: NSRect(x: 402, y: 450, width: 220, height: 220))
NSColor(calibratedRed: 0.35, green: 0.55, blue: 1.0, alpha: 1).setFill()
ring.fill()

// Lens glass
let glass = NSBezierPath(ovalIn: NSRect(x: 452, y: 500, width: 120, height: 120))
NSColor(calibratedRed: 0.75, green: 0.85, blue: 1.0, alpha: 1).setFill()
glass.fill()

// Highlight glint
let glint = NSBezierPath(ovalIn: NSRect(x: 420, y: 610, width: 60, height: 40))
NSColor.white.withAlphaComponent(0.8).setFill()
glint.fill()

image.unlockFocus()

// Write iconset
let fm = FileManager.default
let iconset = "AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let entries: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for (px, name) in entries {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
}

let out = URL(fileURLWithPath: "Resources/AppIcon.icns")
try? fm.removeItem(at: out)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", out.path]
try? p.run()
p.waitUntilExit()
print("Wrote \(out.path)")
