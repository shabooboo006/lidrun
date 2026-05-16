#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/Packaging/macOS/AppIcon.appiconset}"
OUTPUT_PATH="${2:-$ROOT_DIR/Packaging/macOS/AppIcon.icns}"
GLYPH_PATH="${3:-$ROOT_DIR/Packaging/macOS/Generated/LidRunHalfOpenTemplate.png}"
TMP_DIR="$(mktemp -d)"
GENERATOR="$TMP_DIR/generate_lidrun_icon.swift"
ICONSET_DIR="$TMP_DIR/AppIcon.iconset"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$SOURCE_DIR" "$ICONSET_DIR" "$(dirname "$OUTPUT_PATH")"

if [[ ! -f "$GLYPH_PATH" ]]; then
  echo "Missing glyph template: $GLYPH_PATH" >&2
  exit 1
fi

cat >"$GENERATOR" <<'SWIFT'
import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let glyphURL = URL(fileURLWithPath: CommandLine.arguments[2])
let sizes = [16, 32, 64, 128, 256, 512, 1024]

guard let sourceGlyph = NSImage(contentsOf: glyphURL) else {
    throw NSError(domain: "LidRunIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取图标模板：\(glyphURL.path)"])
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func fillRoundedRect(_ rect: NSRect, radius: CGFloat, with color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func tintedGlyph(size: NSSize, color: NSColor) -> NSImage {
    let glyph = NSImage(size: size)
    glyph.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true
    NSGraphicsContext.current?.imageInterpolation = .high

    let rect = NSRect(origin: .zero, size: size)
    color.setFill()
    rect.fill()
    sourceGlyph.draw(
        in: rect,
        from: NSRect(origin: .zero, size: sourceGlyph.size),
        operation: .destinationIn,
        fraction: 1
    )

    glyph.unlockFocus()
    return glyph
}

func drawIcon(size: Int) throws {
    let side = CGFloat(size)
    let scale = side / 1024
    guard let bitmap = NSBitmapImageRep(
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
    ) else {
        throw NSError(domain: "LidRunIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建 \(size).png 位图"])
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "LidRunIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建 \(size).png 绘图上下文"])
    }
    context.shouldAntialias = true
    context.imageInterpolation = .high
    NSGraphicsContext.current = context

    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 218, yRadius: 218)
    let backgroundGradient = NSGradient(colorsAndLocations:
        (color(33, 44, 60), 0.0),
        (color(16, 23, 34), 0.58),
        (color(9, 13, 20), 1.0)
    )!
    backgroundGradient.draw(in: background, angle: 90)

    if size >= 64 {
        let glow = NSBezierPath(roundedRect: NSRect(x: 180, y: 246, width: 664, height: 240), xRadius: 106, yRadius: 106)
        let glowGradient = NSGradient(colorsAndLocations:
            (color(35, 211, 180, 0.18), 0.0),
            (color(35, 211, 180, 0.08), 1.0)
        )!
        glowGradient.draw(in: glow, angle: 90)
    }

    let glyph = tintedGlyph(size: NSSize(width: 1024, height: 1024), color: color(246, 250, 255))
    glyph.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), from: .zero, operation: .sourceOver, fraction: 1)

    if size >= 32 {
        fillRoundedRect(NSRect(x: 724, y: 660, width: 78, height: 78), radius: 39, with: color(52, 211, 153))
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LidRunIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法生成 \(size).png"])
    }

    try data.write(to: outputURL.appendingPathComponent("\(size).png"))
}

for size in sizes {
    try drawIcon(size: size)
}
SWIFT

swift "$GENERATOR" "$SOURCE_DIR" "$GLYPH_PATH"

cp "$SOURCE_DIR/16.png" "$ICONSET_DIR/icon_16x16.png"
cp "$SOURCE_DIR/32.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$SOURCE_DIR/32.png" "$ICONSET_DIR/icon_32x32.png"
cp "$SOURCE_DIR/64.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$SOURCE_DIR/128.png" "$ICONSET_DIR/icon_128x128.png"
cp "$SOURCE_DIR/256.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$SOURCE_DIR/256.png" "$ICONSET_DIR/icon_256x256.png"
cp "$SOURCE_DIR/512.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$SOURCE_DIR/512.png" "$ICONSET_DIR/icon_512x512.png"
cp "$SOURCE_DIR/1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_PATH"
echo "$OUTPUT_PATH"
