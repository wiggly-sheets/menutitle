// Draws Assets/AppIcon-1024.png. Run: swift Tools/make_icon.swift
import AppKit

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let squircle = rounded(NSRect(x: 100, y: 100, width: 824, height: 824), 186)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.29, alpha: 1),
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1),
])!
background.draw(in: squircle, angle: -90)

NSColor.white.withAlphaComponent(0.08).setStroke()
squircle.lineWidth = 3
squircle.stroke()

let strip = rounded(NSRect(x: 168, y: 464, width: 688, height: 104), 52)
NSColor.white.withAlphaComponent(0.16).setFill()
strip.fill()

let pillRect = NSRect(x: 212, y: 428, width: 600, height: 176)
let pill = rounded(pillRect, 88)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()

let glass = NSGradient(colors: [
    NSColor(calibratedRed: 0.82, green: 0.90, blue: 1.0, alpha: 0.42),
    NSColor(calibratedRed: 0.55, green: 0.68, blue: 0.86, alpha: 0.20),
])!
glass.draw(in: pill, angle: -90)

NSShadow().set()
NSColor.white.withAlphaComponent(0.55).setStroke()
pill.lineWidth = 3
pill.stroke()

let bars: [(CGFloat, CGFloat)] = [(530, 250), (490, 320), (450, 210)]
for (y, width) in bars {
    let bar = rounded(NSRect(x: 292, y: y, width: width, height: 26), 13)
    NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.11, alpha: 0.82).setFill()
    bar.fill()
}

let highlight = rounded(NSRect(x: 232, y: 560, width: 560, height: 22), 11)
NSColor.white.withAlphaComponent(0.22).setFill()
highlight.fill()

NSGraphicsContext.current = nil
NSGraphicsContext.restoreGraphicsState()

let output = URL(fileURLWithPath: "Assets/AppIcon-1024.png")
try FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try rep.representation(using: .png, properties: [:])!.write(to: output)
print(output.path)
