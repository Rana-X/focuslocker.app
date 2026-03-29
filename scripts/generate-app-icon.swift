import AppKit

let arguments = CommandLine.arguments.dropFirst()
guard let outputPath = arguments.first else {
    fputs("Usage: swift scripts/generate-app-icon.swift /path/to/output.png\n", stderr)
    exit(1)
}

let canvasSize = CGSize(width: 1024, height: 1024)
let canvasRect = CGRect(origin: .zero, size: canvasSize)
let insetRect = canvasRect.insetBy(dx: 56, dy: 56)

let image = NSImage(size: NSSize(width: canvasSize.width, height: canvasSize.height))
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Failed to acquire graphics context.\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
context.interpolationQuality = .high

let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradientColors = [
    NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.25, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.08, green: 0.63, blue: 0.82, alpha: 1.0).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!

let backgroundPath = NSBezierPath(roundedRect: insetRect, xRadius: 220, yRadius: 220)

context.saveGState()
backgroundPath.addClip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: insetRect.minX, y: insetRect.maxY),
    end: CGPoint(x: insetRect.maxX, y: insetRect.minY),
    options: []
)
context.restoreGState()

let glowGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.24).cgColor,
        NSColor(calibratedWhite: 1.0, alpha: 0.0).cgColor
    ] as CFArray,
    locations: [0.0, 1.0]
)!

context.saveGState()
backgroundPath.addClip()
context.drawRadialGradient(
    glowGradient,
    startCenter: CGPoint(x: insetRect.midX + 110, y: insetRect.maxY - 120),
    startRadius: 20,
    endCenter: CGPoint(x: insetRect.midX + 110, y: insetRect.maxY - 120),
    endRadius: 360,
    options: []
)
context.restoreGState()

NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
backgroundPath.lineWidth = 18
backgroundPath.stroke()

let shackleShadow = NSShadow()
shackleShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.14)
shackleShadow.shadowBlurRadius = 28
shackleShadow.shadowOffset = NSSize(width: 0, height: -16)
shackleShadow.set()

let shackle = NSBezierPath()
shackle.lineWidth = 86
shackle.lineCapStyle = .round
shackle.lineJoinStyle = .round
shackle.move(to: CGPoint(x: 348, y: 612))
shackle.curve(
    to: CGPoint(x: 676, y: 612),
    controlPoint1: CGPoint(x: 348, y: 820),
    controlPoint2: CGPoint(x: 676, y: 820)
)
NSColor(calibratedWhite: 0.98, alpha: 1.0).setStroke()
shackle.stroke()

let bodyShadow = NSShadow()
bodyShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.18)
bodyShadow.shadowBlurRadius = 38
bodyShadow.shadowOffset = NSSize(width: 0, height: -20)
bodyShadow.set()

let bodyRect = CGRect(x: 274, y: 226, width: 476, height: 426)
let body = NSBezierPath(roundedRect: bodyRect, xRadius: 118, yRadius: 118)
NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
body.fill()

context.saveGState()
context.setBlendMode(.clear)
let keyholeCircle = NSBezierPath(ovalIn: CGRect(x: 452, y: 420, width: 120, height: 120))
keyholeCircle.fill()
let keyholeStem = NSBezierPath(roundedRect: CGRect(x: 492, y: 322, width: 40, height: 142), xRadius: 20, yRadius: 20)
keyholeStem.fill()
context.restoreGState()

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
} catch {
    fputs("Failed to write icon PNG: \(error.localizedDescription)\n", stderr)
    exit(1)
}
