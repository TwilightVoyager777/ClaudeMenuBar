#!/usr/bin/env swift
import AppKit

let width: CGFloat = 600
let height: CGFloat = 400

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Background gradient
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 1),
    NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.94, alpha: 1),
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 270)

// Arrow: from app (left) to Applications (right)
let arrowPath = NSBezierPath()
let arrowY: CGFloat = 195
let arrowLeft: CGFloat = 220
let arrowRight: CGFloat = 380
let headSize: CGFloat = 18

// Shaft
arrowPath.move(to: NSPoint(x: arrowLeft, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowRight - headSize, y: arrowY))
arrowPath.lineWidth = 3.5
arrowPath.lineCapStyle = .round

// Arrowhead
arrowPath.move(to: NSPoint(x: arrowRight - headSize, y: arrowY + headSize * 0.6))
arrowPath.line(to: NSPoint(x: arrowRight, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowRight - headSize, y: arrowY - headSize * 0.6))

NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.50, alpha: 0.8).setStroke()
arrowPath.stroke()

// Title text
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.25, alpha: 1),
]
let title = "Install ClaudeMenuBar" as NSString
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(at: NSPoint(x: (width - titleSize.width) / 2, y: height - 75), withAttributes: titleAttrs)

// Subtitle
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.45, alpha: 1),
]
let sub = "Drag to Applications to install" as NSString
let subSize = sub.size(withAttributes: subAttrs)
sub.draw(at: NSPoint(x: (width - subSize.width) / 2, y: height - 105), withAttributes: subAttrs)

image.unlockFocus()

// Save
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else { exit(1) }

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dmg-bg.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Background saved to \(outputPath)")
