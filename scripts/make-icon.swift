#!/usr/bin/env swift
// Generates Resources/AppIcon.icns from scratch — no design tool needed.
// Renders a 1024×1024 PNG (rounded-square red badge with a white collar ring
// and a leash curve) at every icon size, then runs iconutil.

import AppKit
import CoreGraphics

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Rounded-square mask (Big Sur radius ≈ 22.37% of side)
    let radius = size * 0.2237
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Background gradient — red/orange "you are being summoned"
    let colorspace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorspace,
        colors: [
            CGColor(red: 1.0, green: 0.34, blue: 0.22, alpha: 1.0),
            CGColor(red: 0.78, green: 0.10, blue: 0.18, alpha: 1.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // Collar ring (white, thick stroke)
    let ringRadius = size * 0.22
    let ringRect = CGRect(
        x: size / 2 - ringRadius,
        y: size / 2 - ringRadius,
        width: ringRadius * 2,
        height: ringRadius * 2
    )
    ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 1.0))
    ctx.setLineWidth(size * 0.06)
    ctx.strokeEllipse(in: ringRect)

    // Leash curve — bezier sweep up-right from the ring
    ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.95))
    ctx.setLineWidth(size * 0.045)
    ctx.setLineCap(.round)
    let leash = CGMutablePath()
    leash.move(to: CGPoint(x: size * 0.5 + ringRadius * 0.7, y: size * 0.5 + ringRadius * 0.7))
    leash.addCurve(
        to: CGPoint(x: size * 0.86, y: size * 0.88),
        control1: CGPoint(x: size * 0.78, y: size * 0.58),
        control2: CGPoint(x: size * 0.72, y: size * 0.82)
    )
    ctx.addPath(leash)
    ctx.strokePath()

    // Handle dot at the end of the leash
    ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(
        x: size * 0.86 - size * 0.04,
        y: size * 0.88 - size * 0.04,
        width: size * 0.08,
        height: size * 0.08
    ))

    return image
}

func writePNG(_ image: NSImage, to url: URL, pixelSize: Int) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "icon", code: 1)
    }
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2)
    }
    try data.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (px, name) in sizes {
    let image = draw(size: CGFloat(px))
    try writePNG(image, to: iconset.appendingPathComponent(name), pixelSize: px)
    print("wrote \(name) @ \(px)px")
}

let icns = root.appendingPathComponent("Resources/AppIcon.icns")
try? FileManager.default.removeItem(at: icns)
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
print("wrote \(icns.path)")
