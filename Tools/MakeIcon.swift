// Renders the TrackMyIllness app icon.
//
// One mark: an ECG trace, which reads as "health log" at 40pt and doesn't collide
// with the tab bar's own glyphs. The light variant is full-bleed over the app's
// accent blue; the dark and tinted variants sit on a transparent background,
// which is what iOS 18+ composites its own backdrop behind.
//
// Writes two things into the asset catalog given as the only argument:
//
//   AppIcon.appiconset   the three 1024×1024 home-screen variants
//   AppIconArt.imageset  a small copy of the light variant, because iOS can't load
//                        an app icon out of the catalog by name — About needs its
//                        own image, and generating both here keeps them in step.
//
//   swift Tools/MakeIcon.swift TrackMyIllness/Assets.xcassets

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// The icon is authored at this size; everything scales off it.
let canvas: CGFloat = 1024

/// Big enough for About's 88pt slot on a 3× screen, small enough not to ship a
/// megabyte twice.
let artworkSide = 384

enum Variant {
    case light, dark, tinted

    /// Only the light icon paints its own background.
    var gradient: (top: CGColor, bottom: CGColor)? {
        switch self {
        case .light:
            return (CGColor(red: 0.247, green: 0.475, blue: 0.722, alpha: 1),
                    CGColor(red: 0.075, green: 0.184, blue: 0.322, alpha: 1))
        case .dark, .tinted:
            return nil
        }
    }

    var trace: CGColor {
        switch self {
        case .light: return CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        // A touch of blue keeps the dark icon from looking like a stencil.
        case .dark: return CGColor(red: 0.925, green: 0.953, blue: 0.988, alpha: 1)
        // Tinted must be greyscale: iOS derives the tint from luminance.
        case .tinted: return CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }

    var filename: String {
        switch self {
        case .light: return "AppIcon.png"
        case .dark: return "AppIcon-Dark.png"
        case .tinted: return "AppIcon-Tinted.png"
        }
    }
}

/// The trace, in top-down coordinates on the 1024 canvas: flat line, a small P
/// wave, the tall R spike, the S dip, then a T wave and flat again.
let tracePoints: [CGPoint] = [
    CGPoint(x: 150, y: 512),
    CGPoint(x: 292, y: 512),
    CGPoint(x: 340, y: 452),
    CGPoint(x: 388, y: 512),
    CGPoint(x: 436, y: 512),
    CGPoint(x: 486, y: 236),
    CGPoint(x: 542, y: 736),
    CGPoint(x: 590, y: 512),
    CGPoint(x: 648, y: 512),
    CGPoint(x: 700, y: 436),
    CGPoint(x: 752, y: 512),
    CGPoint(x: 874, y: 512),
]

func render(_ variant: Variant, side: Int = Int(canvas)) -> CGImage {
    // The light icon must be fully opaque — App Store validation rejects an alpha
    // channel on the marketing icon. The dark and tinted ones need one, because
    // iOS composites its own backdrop behind them.
    let alpha: CGImageAlphaInfo = variant.gradient == nil ? .premultipliedLast : .noneSkipLast
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: side, height: side,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: alpha.rawValue) else {
        fatalError("could not create the bitmap context")
    }

    // Work top-down at the authoring size, whatever we're rasterising to.
    let scale = CGFloat(side) / canvas
    ctx.translateBy(x: 0, y: CGFloat(side))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.setAllowsAntialiasing(true)

    if let (top, bottom) = variant.gradient {
        let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray,
                                  locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: .zero,
                               end: CGPoint(x: canvas, y: canvas), options: [])

        // A soft highlight off the top-left corner, so the flat gradient has some
        // depth at large sizes without muddying it at small ones.
        ctx.saveGState()
        let highlight = CGGradient(
            colorsSpace: space,
            colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.16),
                     CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
            locations: [0, 1])!
        ctx.drawRadialGradient(highlight, startCenter: CGPoint(x: 240, y: 190),
                               startRadius: 0, endCenter: CGPoint(x: 240, y: 190),
                               endRadius: 620, options: [])
        ctx.restoreGState()
    }

    // The trace, drawn twice: a soft dark pass underneath so it still separates
    // from the background at the very top of the gradient.
    let path = CGMutablePath()
    path.addLines(between: tracePoints)

    if variant.gradient != nil {
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(red: 0.043, green: 0.106, blue: 0.192, alpha: 0.22))
        ctx.setLineWidth(66)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.translateBy(x: 0, y: 10)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    ctx.setStrokeColor(variant.trace)
    ctx.setLineWidth(58)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(path)
    ctx.strokePath()

    guard let image = ctx.makeImage() else { fatalError("could not render") }
    return image
}

func write(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("could not create \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("could not write \(url.lastPathComponent)")
    }
}

let catalog = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

let iconSet = catalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
for variant in [Variant.light, .dark, .tinted] {
    write(render(variant), to: iconSet.appendingPathComponent(variant.filename))
    print("wrote AppIcon.appiconset/\(variant.filename)")
}

let artSet = catalog.appendingPathComponent("AppIconArt.imageset", isDirectory: true)
try? FileManager.default.createDirectory(at: artSet, withIntermediateDirectories: true)
write(render(.light, side: artworkSide), to: artSet.appendingPathComponent("AppIconArt.png"))
print("wrote AppIconArt.imageset/AppIconArt.png")
