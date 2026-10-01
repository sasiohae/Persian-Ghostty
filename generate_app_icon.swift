import AppKit
import CoreGraphics

func hexColor(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func createMasterIcon() -> NSImage {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)

    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // 1. Drop shadow behind the squircle
    ctx.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.shadowBlurRadius = 38
    shadow.set()

    // 2. macOS Big Sur Squircle Dimensions
    // Standard icon content rect inside 1024: (100, 100, 824, 824) with radius ~185
    let squircleRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)
    hexColor(0x181825).setFill()
    squirclePath.fill()
    ctx.restoreGState()

    // 3. Clip to Squircle for inner background and gradients
    ctx.saveGState()
    squirclePath.addClip()

    // Background Gradient: Deep sleek terminal dark (#1E1E2E -> #11111B)
    let bgGradient = NSGradient(
        starting: hexColor(0x232438),
        ending: hexColor(0x11111B)
    )
    bgGradient?.draw(in: squircleRect, angle: -90)

    // Subtle Radial Vignette / Glow behind central motif
    let centerGlow = NSGradient(
        starting: hexColor(0x89DCEB, alpha: 0.18),
        ending: hexColor(0x181825, alpha: 0.0)
    )
    centerGlow?.draw(
        fromCenter: NSPoint(x: 512, y: 480), radius: 0,
        toCenter: NSPoint(x: 512, y: 480), radius: 380,
        options: []
    )

    // 4. Stylized Terminal Header Bar
    let headerHeight: CGFloat = 84
    let headerRect = NSRect(x: 100, y: squircleRect.maxY - headerHeight, width: squircleRect.width, height: headerHeight)
    let headerGradient = NSGradient(
        starting: hexColor(0x2A2B3D, alpha: 0.85),
        ending: hexColor(0x1E1E2E, alpha: 0.85)
    )
    headerGradient?.draw(in: headerRect, angle: -90)

    // Header divider line
    let dividerPath = NSBezierPath()
    dividerPath.move(to: NSPoint(x: 100, y: headerRect.minY))
    dividerPath.line(to: NSPoint(x: squircleRect.maxX, y: headerRect.minY))
    dividerPath.lineWidth = 1.5
    hexColor(0x313244, alpha: 0.8).setStroke()
    dividerPath.stroke()

    // Traffic light dots
    let dotRadius: CGFloat = 10
    let dotY: CGFloat = headerRect.midY
    let dotColors: [NSColor] = [
        hexColor(0xF38BA8), // Red (Close)
        hexColor(0xF9E2AF), // Yellow (Minimize)
        hexColor(0xA6E3A1)  // Green (Zoom)
    ]
    let startX: CGFloat = 160
    let dotSpacing: CGFloat = 30

    for (index, color) in dotColors.enumerated() {
        let dotCenter = NSPoint(x: startX + CGFloat(index) * dotSpacing, y: dotY)
        let dotRect = NSRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
        color.setFill()
        let dotPath = NSBezierPath(ovalIn: dotRect)
        dotPath.fill()

        // Inner specular highlight
        let highlightRect = NSRect(x: dotRect.minX + 2, y: dotRect.midY, width: dotRadius * 1.2, height: dotRadius * 0.7)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: highlightRect).fill()
    }

    // Terminal prompt indicator in header: ghostty ❯ persian
    let headerFont = NSFont.monospacedSystemFont(ofSize: 22, weight: .semibold)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: headerFont,
        .foregroundColor: hexColor(0xA6ADC8, alpha: 0.75)
    ]
    let titleString = "ghostty ❯_ persian"
    let titleSize = titleString.size(withAttributes: titleAttrs)
    let titlePoint = NSPoint(x: squircleRect.maxX - titleSize.width - 50, y: dotY - titleSize.height / 2)
    titleString.draw(at: titlePoint, withAttributes: titleAttrs)

    // 5. Central Graphic: Fusion of Ghostty Ghost Motif & Glowing Persian Letter "ف"
    // Center point around (512, 440)
    ctx.saveGState()

    // Outer glow for the ghost motif
    let ghostGlow = NSShadow()
    ghostGlow.shadowColor = hexColor(0x89DCEB, alpha: 0.55)
    ghostGlow.shadowOffset = .zero
    ghostGlow.shadowBlurRadius = 40
    ghostGlow.set()

    // Ghost body path (smooth rounded dome head, floating torso, wavy skirt)
    let ghostPath = NSBezierPath()
    let gx: CGFloat = 512
    let gy: CGFloat = 430
    let gw: CGFloat = 210
    let gh: CGFloat = 240

    // Top dome
    ghostPath.move(to: NSPoint(x: gx - gw, y: gy))
    ghostPath.curve(
        to: NSPoint(x: gx, y: gy + gh),
        controlPoint1: NSPoint(x: gx - gw, y: gy + gh * 0.7),
        controlPoint2: NSPoint(x: gx - gw * 0.5, y: gy + gh)
    )
    ghostPath.curve(
        to: NSPoint(x: gx + gw, y: gy),
        controlPoint1: NSPoint(x: gx + gw * 0.5, y: gy + gh),
        controlPoint2: NSPoint(x: gx + gw, y: gy + gh * 0.7)
    )

    // Right flank descending to bottom wavy ruffle
    ghostPath.curve(
        to: NSPoint(x: gx + gw * 0.95, y: gy - gh * 0.65),
        controlPoint1: NSPoint(x: gx + gw * 1.05, y: gy - gh * 0.1),
        controlPoint2: NSPoint(x: gx + gw * 0.95, y: gy - gh * 0.4)
    )

    // Bottom playful wavy tentacles (3 waves)
    let bY = gy - gh * 0.65
    // Wave 3 (Right)
    ghostPath.curve(
        to: NSPoint(x: gx + gw * 0.35, y: bY),
        controlPoint1: NSPoint(x: gx + gw * 0.8, y: bY - 35),
        controlPoint2: NSPoint(x: gx + gw * 0.5, y: bY + 30)
    )
    // Wave 2 (Middle)
    ghostPath.curve(
        to: NSPoint(x: gx - gw * 0.35, y: bY),
        controlPoint1: NSPoint(x: gx + gw * 0.15, y: bY - 45),
        controlPoint2: NSPoint(x: gx - gw * 0.15, y: bY + 35)
    )
    // Wave 1 (Left)
    ghostPath.curve(
        to: NSPoint(x: gx - gw * 0.95, y: bY),
        controlPoint1: NSPoint(x: gx - gw * 0.5, y: bY - 40),
        controlPoint2: NSPoint(x: gx - gw * 0.8, y: bY + 25)
    )

    // Left flank ascending back to top dome start
    ghostPath.curve(
        to: NSPoint(x: gx - gw, y: gy),
        controlPoint1: NSPoint(x: gx - gw * 0.95, y: gy - gh * 0.4),
        controlPoint2: NSPoint(x: gx - gw * 1.05, y: gy - gh * 0.1)
    )
    ghostPath.close()

    // Ghost body gradient: Electric Cyan (#89DCEB) to Vibrant Lavender (#CBA6F7)
    let ghostGradient = NSGradient(
        colors: [
            hexColor(0x89DCEB, alpha: 0.92),
            hexColor(0x74C7EC, alpha: 0.90),
            hexColor(0xCBA6F7, alpha: 0.88)
        ],
        atLocations: [0.0, 0.45, 1.0],
        colorSpace: .sRGB
    )
    ghostGradient?.draw(in: ghostPath, angle: -55)
    ctx.restoreGState()

    // 6. Ghost Eyes (Playful, friendly modern cutouts)
    let eyeY = gy + gh * 0.32
    let eyeSpacing: CGFloat = 82
    let eyeWidth: CGFloat = 36
    let eyeHeight: CGFloat = 46

    let leftEyeRect = NSRect(x: gx - eyeSpacing - eyeWidth / 2, y: eyeY - eyeHeight / 2, width: eyeWidth, height: eyeHeight)
    let rightEyeRect = NSRect(x: gx + eyeSpacing - eyeWidth / 2, y: eyeY - eyeHeight / 2, width: eyeWidth, height: eyeHeight)

    hexColor(0x181825, alpha: 0.95).setFill()
    NSBezierPath(ovalIn: leftEyeRect).fill()
    NSBezierPath(ovalIn: rightEyeRect).fill()

    // Eye catchlights (sparkle)
    let sparkleRadius: CGFloat = 6.5
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: leftEyeRect.maxX - 15, y: leftEyeRect.maxY - 18, width: sparkleRadius * 2, height: sparkleRadius * 2)).fill()
    NSBezierPath(ovalIn: NSRect(x: rightEyeRect.maxX - 15, y: rightEyeRect.maxY - 18, width: sparkleRadius * 2, height: sparkleRadius * 2)).fill()

    // 7. Glowing Persian Calligraphy Letter "ف" Motif intertwined across the body
    ctx.saveGState()
    let faGlow = NSShadow()
    faGlow.shadowColor = hexColor(0xF9E2AF, alpha: 0.85) // Amber/Gold glow
    faGlow.shadowOffset = NSSize(width: 0, height: 2)
    faGlow.shadowBlurRadius = 26
    faGlow.set()

    let faPath = NSBezierPath()
    // Elegant sweeping Persian Nastaliq "ف" bowl & loop
    // Head loop of "ف"
    let loopCenter = NSPoint(x: gx + 55, y: gy + 15)
    let loopRect = NSRect(x: loopCenter.x - 42, y: loopCenter.y - 36, width: 84, height: 72)
    faPath.appendOval(in: loopRect)

    // Sweeping calligraphic body and tail of "ف" flowing right-to-left
    faPath.move(to: NSPoint(x: loopCenter.x + 36, y: loopCenter.y - 12))
    faPath.curve(
        to: NSPoint(x: gx - 20, y: gy - 75),
        controlPoint1: NSPoint(x: loopCenter.x + 10, y: loopCenter.y - 50),
        controlPoint2: NSPoint(x: gx + 35, y: gy - 72)
    )
    faPath.curve(
        to: NSPoint(x: gx - 145, y: gy - 25),
        controlPoint1: NSPoint(x: gx - 90, y: gy - 78),
        controlPoint2: NSPoint(x: gx - 140, y: gy - 58)
    )

    faPath.lineWidth = 18
    faPath.lineCapStyle = .round
    faPath.lineJoinStyle = .round

    // Stroke with Persian Gold gradient
    hexColor(0xF9E2AF).setStroke()
    faPath.stroke()

    // The iconic Persian Dot (Nuqta / نقطه) of "ف" hovering above the loop like a diamond star
    let dotCenter = NSPoint(x: loopCenter.x, y: loopCenter.y + 75)
    let dotSize: CGFloat = 26
    let dotDiamond = NSBezierPath()
    dotDiamond.move(to: NSPoint(x: dotCenter.x, y: dotCenter.y + dotSize))
    dotDiamond.line(to: NSPoint(x: dotCenter.x + dotSize * 0.85, y: dotCenter.y))
    dotDiamond.line(to: NSPoint(x: dotCenter.x, y: dotCenter.y - dotSize))
    dotDiamond.line(to: NSPoint(x: dotCenter.x - dotSize * 0.85, y: dotCenter.y))
    dotDiamond.close()

    hexColor(0xF9E2AF).setFill()
    dotDiamond.fill()
    ctx.restoreGState()

    // 8. Subtle inner rim highlight on the squircle (macOS continuous depth stroke)
    let innerBorder = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 184, yRadius: 184)
    innerBorder.lineWidth = 2.0
    hexColor(0xFFFFFF, alpha: 0.14).setStroke()
    innerBorder.stroke()

    ctx.restoreGState() // unclip squircle

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, targetSize: Int, destinationURL: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetSize,
        pixelsHigh: targetSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
    guard let bitmapRep = rep else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep"])
    }

    bitmapRep.size = NSSize(width: targetSize, height: targetSize)
    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
        throw NSError(domain: "IconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
    }
    NSGraphicsContext.current = ctx
    ctx.cgContext.interpolationQuality = .high

    image.draw(
        in: NSRect(x: 0, y: 0, width: targetSize, height: targetSize),
        from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get PNG data"])
    }

    try pngData.write(to: destinationURL)
}

// Execution
let outputDir: URL
if CommandLine.arguments.count > 1 {
    outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
} else {
    outputDir = URL(fileURLWithPath: "GhosttyPersian/Resources/Assets.xcassets/AppIcon.appiconset")
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("🎨 Rendering master 1024x1024 Ghostty Persian application icon...")
let master = createMasterIcon()

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, targetPixelSize) in specs {
    let targetURL = outputDir.appendingPathComponent(filename)
    try savePNG(image: master, targetSize: targetPixelSize, destinationURL: targetURL)
    print("  ✓ Generated \(filename) (\(targetPixelSize)x\(targetPixelSize))")
}

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsURL = outputDir.appendingPathComponent("Contents.json")
try contentsJSON.write(to: contentsURL, atomically: true, encoding: .utf8)
print("  ✓ Updated Contents.json")
print("✨ Complete! All icons and catalog entries created successfully.")
