#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Original code-drawn cover artwork, recomposed for the system's square icon mask.
let destination = CommandLine.arguments.count == 2 ? CommandLine.arguments[1] : "DexDuo/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(size)); context.scaleBy(x: 1, y: -1)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
func gradient(_ colors: [CGColor], from: CGPoint, to: CGPoint) {
    context.drawLinearGradient(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
gradient([color(0.96, 0.04, 0.13), color(0.79, 0.01, 0.08), color(0.56, 0.01, 0.06)], from: .zero, to: CGPoint(x: 1024, y: 1024))
context.setStrokeColor(color(0.42, 0.03, 0.06)); context.setLineWidth(7); context.setLineJoin(.round)
context.move(to: CGPoint(x: 0, y: 390)); context.addLine(to: CGPoint(x: 390, y: 390))
context.addLine(to: CGPoint(x: 505, y: 250)); context.addLine(to: CGPoint(x: 1024, y: 250)); context.strokePath()
let lens = CGRect(x: 70, y: 60, width: 288, height: 288)
context.saveGState(); context.setShadow(offset: CGSize(width: 0, height: 5), blur: 7, color: CGColor(gray: 0, alpha: 0.35))
context.setFillColor(color(0.96, 0.96, 0.92)); context.fillEllipse(in: lens); context.restoreGState()
context.saveGState(); context.addEllipse(in: lens.insetBy(dx: 16, dy: 16)); context.clip()
let blue = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.8, 1, 1), color(0, 0.77, 0.92), color(0, 0.35, 0.69)] as CFArray, locations: [0, 0.3, 1])!
context.drawRadialGradient(blue, startCenter: CGPoint(x: 130, y: 110), startRadius: 0, endCenter: CGPoint(x: 210, y: 190), endRadius: 220, options: [.drawsAfterEndLocation]); context.restoreGState()
for (index, tint) in [color(1, 0.15, 0.22), color(1, 0.82, 0), color(0, 0.78, 0.36)].enumerated() {
    let light = CGRect(x: 430 + index * 55, y: 108, width: 32, height: 32)
    context.setFillColor(tint); context.fillEllipse(in: light)
    context.setStrokeColor(color(0.42, 0.03, 0.06)); context.setLineWidth(3); context.strokeEllipse(in: light)
}
context.saveGState(); context.setShadow(offset: CGSize(width: 0, height: 4), blur: 3, color: CGColor(gray: 0, alpha: 0.35))
context.setFillColor(color(1, 0.8, 0.03)); context.move(to: CGPoint(x: 75, y: 600))
context.addLine(to: CGPoint(x: 75, y: 710)); context.addLine(to: CGPoint(x: 170, y: 655)); context.closePath(); context.fillPath(); context.restoreGState()
let url = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
guard CGImageDestinationFinalize(output) else { fatalError("Could not write icon") }
print(url.path)
