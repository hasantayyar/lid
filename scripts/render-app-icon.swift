#!/usr/bin/env swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let canvas = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: canvas,
    height: canvas,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create graphics context\n", stderr)
    exit(1)
}

let background = CGRect(x: 96, y: 96, width: 832, height: 832)
let corner: CGFloat = 186

context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: CGColor(gray: 0, alpha: 0.35))
context.setFillColor(CGColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1))
context.addPath(CGPath(roundedRect: background, cornerWidth: corner, cornerHeight: corner, transform: nil))
context.fillPath()
context.setShadow(offset: .zero, blur: 0, color: nil)

let highlight = CGMutablePath()
highlight.addRoundedRect(in: background, cornerWidth: corner, cornerHeight: corner)
context.saveGState()
context.addPath(highlight)
context.clip()
let colors = [
    CGColor(red: 0.22, green: 0.28, blue: 0.36, alpha: 0.9),
    CGColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 0),
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: 928),
        end: CGPoint(x: 512, y: 560),
        options: []
    )
}
context.restoreGState()

let hinge = CGPoint(x: 318, y: 392)
let chrome = CGColor(red: 0.90, green: 0.93, blue: 0.96, alpha: 1)
let chromeDark = CGColor(red: 0.70, green: 0.75, blue: 0.82, alpha: 1)
let screenFill = CGColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1)
let glow = CGColor(red: 0.37, green: 0.91, blue: 0.83, alpha: 1)

context.setFillColor(chrome)
context.addPath(CGPath(roundedRect: CGRect(x: 286, y: 348, width: 452, height: 58), cornerWidth: 16, cornerHeight: 16, transform: nil))
context.fillPath()
context.setFillColor(chromeDark)
context.addPath(CGPath(roundedRect: CGRect(x: 304, y: 360, width: 416, height: 18), cornerWidth: 6, cornerHeight: 6, transform: nil))
context.fillPath()

context.saveGState()
context.translateBy(x: hinge.x, y: hinge.y)
context.rotate(by: .pi / 3.15)

let lid = CGRect(x: -18, y: 10, width: 428, height: 278)
context.setFillColor(chrome)
context.addPath(CGPath(roundedRect: lid, cornerWidth: 22, cornerHeight: 22, transform: nil))
context.fillPath()

let screen = lid.insetBy(dx: 18, dy: 18)
context.setFillColor(screenFill)
context.addPath(CGPath(roundedRect: screen, cornerWidth: 14, cornerHeight: 14, transform: nil))
context.fillPath()

context.saveGState()
context.addPath(CGPath(roundedRect: screen, cornerWidth: 14, cornerHeight: 14, transform: nil))
context.clip()
if let screenGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.37, green: 0.91, blue: 0.83, alpha: 0.55),
        CGColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0),
    ] as CFArray,
    locations: [0, 1]
) {
    context.drawLinearGradient(
        screenGradient,
        start: CGPoint(x: screen.minX, y: screen.maxY),
        end: CGPoint(x: screen.midX, y: screen.minY),
        options: []
    )
}
context.restoreGState()
context.restoreGState()

context.setStrokeColor(glow)
context.setLineWidth(10)
context.setLineCap(.round)
context.addArc(
    center: hinge,
    radius: 118,
    startAngle: 0.08,
    endAngle: 1.02,
    clockwise: false
)
context.strokePath()

context.setFillColor(glow)
context.addEllipse(in: CGRect(x: hinge.x - 11, y: hinge.y - 11, width: 22, height: 22))
context.fillPath()

guard let image = context.makeImage() else {
    fputs("Failed to create icon image\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: render-app-icon.swift <output.png>\n", stderr)
    exit(1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
guard let destination = CGImageDestinationCreateWithURL(
    output as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("Failed to create PNG destination\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
if !CGImageDestinationFinalize(destination) {
    fputs("Failed to write \(output.path)\n", stderr)
    exit(1)
}
