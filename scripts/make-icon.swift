// Draws the tiempo app icon (1024×1024 PNG): a wireframe globe with clock hands
// on a blue rounded square, in the macOS icon grid.
// Usage: swift scripts/make-icon.swift Resources/AppIcon.png
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let size = 1024
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("bitmap") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Background: 824pt rounded square centered on the 1024 canvas, with a soft drop shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0, 0, 0, 0.35).cgColor)
rgb(20, 40, 90).setFill()
tilePath.fill()
ctx.restoreGState()

ctx.saveGState()
tilePath.addClip()
NSGradient(colors: [rgb(14, 30, 78), rgb(30, 86, 186), rgb(64, 148, 240)])!.draw(in: tile, angle: 90)
// Soft light behind the globe.
NSGradient(colors: [rgb(255, 255, 255, 0.22), rgb(255, 255, 255, 0)])!
    .draw(fromCenter: NSPoint(x: 512, y: 560), radius: 0, toCenter: NSPoint(x: 512, y: 512), radius: 420, options: [])
ctx.restoreGState()

// Wireframe globe.
let center = NSPoint(x: 512, y: 512)
let r: CGFloat = 292
let globe = NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
let line: CGFloat = 16
let white = rgb(255, 255, 255, 0.95)

ctx.saveGState()
globe.addClip()
white.withAlphaComponent(0.85).setStroke()
// Meridians: ellipses of shrinking width, plus the central axis.
for deg in [30.0, 60.0] {
    let w = r * CGFloat(sin(deg * .pi / 180))
    let m = NSBezierPath(ovalIn: CGRect(x: center.x - w, y: center.y - r, width: 2 * w, height: 2 * r))
    m.lineWidth = line * 0.8
    m.stroke()
}
let axis = NSBezierPath()
axis.move(to: NSPoint(x: center.x, y: center.y - r))
axis.line(to: NSPoint(x: center.x, y: center.y + r))
axis.lineWidth = line * 0.8
axis.stroke()
// Parallels: gently curved lines, like latitude seen slightly from above.
for deg in [-55.0, -25.0, 0.0, 25.0, 55.0] {
    let y = center.y + r * CGFloat(sin(deg * .pi / 180))
    let half = r * CGFloat(cos(deg * .pi / 180))
    let sag = half * 0.12
    let p = NSBezierPath()
    p.move(to: NSPoint(x: center.x - half - 4, y: y))
    p.curve(to: NSPoint(x: center.x + half + 4, y: y),
            controlPoint1: NSPoint(x: center.x - half * 0.5, y: y - sag),
            controlPoint2: NSPoint(x: center.x + half * 0.5, y: y - sag))
    p.lineWidth = line * 0.8
    p.stroke()
}
ctx.restoreGState()

white.setStroke()
globe.lineWidth = line * 1.4
globe.stroke()

// Clock hands in warm amber: the "time" in tiempo.
let amber = rgb(255, 184, 64)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: rgb(0, 0, 0, 0.35).cgColor)
amber.setStroke()
for (angleDeg, length, width) in [(120.0, r * 0.52, CGFloat(34)), (30.0, r * 0.78, CGFloat(24))] {
    let a = angleDeg * .pi / 180
    let hand = NSBezierPath()
    hand.move(to: center)
    hand.line(to: NSPoint(x: center.x + length * CGFloat(cos(a)), y: center.y + length * CGFloat(sin(a))))
    hand.lineWidth = width
    hand.lineCapStyle = .round
    hand.stroke()
}
amber.setFill()
NSBezierPath(ovalIn: CGRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60)).fill()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
