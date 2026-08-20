// draws the app icon. usage: swift makeicon.swift out.png
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let S = 1024

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let paper = NSColor(red: 0.965, green: 0.937, blue: 0.878, alpha: 1)
let paperDim = NSColor(red: 0.925, green: 0.886, blue: 0.812, alpha: 1)
let ink = NSColor(red: 0.11, green: 0.10, blue: 0.10, alpha: 1)
let red = NSColor(red: 0.86, green: 0.25, blue: 0.17, alpha: 1)

// macos-style rounded square, subtle paper gradient
let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                      xRadius: 185, yRadius: 185)
NSGradient(starting: paper, ending: paperDim)!.draw(in: bg, angle: -90)

// open book, two filled pages with a gap at the spine
func page(_ mirror: Bool) -> NSBezierPath {
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: mirror ? 1024 - x : x, y: y)
    }
    let p = NSBezierPath()
    p.move(to: pt(506, 268))
    p.curve(to: pt(268, 348), controlPoint1: pt(418, 268), controlPoint2: pt(330, 300))
    p.line(to: pt(268, 556))
    p.curve(to: pt(506, 476), controlPoint1: pt(330, 508), controlPoint2: pt(418, 476))
    p.close()
    return p
}
ink.setFill()
page(false).fill()
page(true).fill()

// paper inset so it reads as pages inside a cover, not a black slab
func inset(_ mirror: Bool) -> NSBezierPath {
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: mirror ? 1024 - x : x, y: y)
    }
    let p = NSBezierPath()
    p.move(to: pt(498, 306))
    p.curve(to: pt(304, 372), controlPoint1: pt(426, 306), controlPoint2: pt(354, 332))
    p.line(to: pt(304, 514))
    p.curve(to: pt(498, 448), controlPoint1: pt(354, 474), controlPoint2: pt(426, 448))
    p.close()
    return p
}
paper.setFill()
inset(false).fill()
inset(true).fill()

// red arrow hopping from the left page to the right one
let arc = NSBezierPath()
let arcEnd = NSPoint(x: 682, y: 668)
arc.move(to: NSPoint(x: 316, y: 640))
arc.curve(to: arcEnd, controlPoint1: NSPoint(x: 368, y: 852), controlPoint2: NSPoint(x: 630, y: 850))
arc.lineWidth = 62
arc.lineCapStyle = .round
red.setStroke()
arc.stroke()

let dx: CGFloat = 682 - 630, dy: CGFloat = 668 - 850
let len = (dx * dx + dy * dy).squareRoot()
let d = NSPoint(x: dx / len, y: dy / len)
let perp = NSPoint(x: -d.y, y: d.x)
let head = NSBezierPath()
head.move(to: NSPoint(x: arcEnd.x + d.x * 100, y: arcEnd.y + d.y * 100))
head.line(to: NSPoint(x: arcEnd.x + perp.x * 58, y: arcEnd.y + perp.y * 58))
head.line(to: NSPoint(x: arcEnd.x - perp.x * 58, y: arcEnd.y - perp.y * 58))
head.close()
red.setFill()
head.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
