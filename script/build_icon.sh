#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/Packaging/macOS/AppIcon.appiconset}"
OUTPUT_PATH="${2:-$ROOT_DIR/Packaging/macOS/AppIcon.icns}"
TMP_DIR="$(mktemp -d)"
GENERATOR="$TMP_DIR/generate_lidrun_icon.swift"
ICONSET_DIR="$TMP_DIR/AppIcon.iconset"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$SOURCE_DIR" "$ICONSET_DIR" "$(dirname "$OUTPUT_PATH")"

# 应用图标与菜单栏图标/界面字标共用同一字形（LidGlyph，单一来源）。
# 这里按 LidRunShared 的 LidGlyph 设计坐标（26×20，盖子矩形 + 底座矩形，
# 中间留细缝）直接程序化绘制，不再依赖任何旧的 PNG 模板，
# 保证通知/Dock/启动台图标与菜单栏图标是同一套设计。
cat >"$GENERATOR" <<'SWIFT'
import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func fillRoundedRect(_ rect: NSRect, radius: CGFloat, with color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

// LidGlyph 设计坐标系（与 Sources/LidRun/Support/LidGlyphShape.swift 完全一致）：
// 参考尺寸 26×20，y 向下；lid=(5.6,3.0,14.8,9.0)，base=(2.4,13.2,21.2,4.0)，
// 圆角 r = min(sx,sy)*2.0。这里在 1024 画布内、y 向上坐标系中等比绘制。
let glyphRefW: CGFloat = 26, glyphRefH: CGFloat = 20
let glyphBoxW: CGFloat = 600
let glyphBoxH: CGFloat = glyphBoxW * glyphRefH / glyphRefW   // 保持比例
let glyphX0: CGFloat = (1024 - glyphBoxW) / 2
let glyphY0: CGFloat = (1024 - glyphBoxH) / 2
let sx = glyphBoxW / glyphRefW
let sy = glyphBoxH / glyphRefH
let glyphRadius = min(sx, sy) * 2.0

/// 设计坐标（y 向下，从顶部量）映射到 1024 画布的 y 向上 NSRect。
func glyphRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(
        x: glyphX0 + x * sx,
        y: glyphY0 + (glyphRefH - (y + h)) * sy,
        width: w * sx,
        height: h * sy
    )
}

func drawIcon(size: Int) throws {
    let scale = CGFloat(size) / 1024
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

    // 背景圆角方块（深色渐变，沿用已确认的应用图标风格）。
    let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 218, yRadius: 218)
    let backgroundGradient = NSGradient(colorsAndLocations:
        (color(33, 44, 60), 0.0),
        (color(16, 23, 34), 0.58),
        (color(9, 13, 20), 1.0)
    )!
    backgroundGradient.draw(in: background, angle: 90)

    // 字形后方柔光，居中跟随字形。
    if size >= 64 {
        let glow = NSBezierPath(roundedRect: NSRect(x: 152, y: 332, width: 720, height: 360), xRadius: 150, yRadius: 150)
        let glowGradient = NSGradient(colorsAndLocations:
            (color(35, 211, 180, 0.18), 0.0),
            (color(35, 211, 180, 0.08), 1.0)
        )!
        glowGradient.draw(in: glow, angle: 90)
    }

    // LidGlyph：盖子矩形 + 底座矩形（与菜单栏图标同款），近白色。
    let glyphColor = color(246, 250, 255)
    glyphColor.setFill()
    let lid = NSBezierPath(roundedRect: glyphRect(5.6, 3.0, 14.8, 9.0), xRadius: glyphRadius, yRadius: glyphRadius)
    let base = NSBezierPath(roundedRect: glyphRect(2.4, 13.2, 21.2, 4.0), xRadius: glyphRadius, yRadius: glyphRadius)
    lid.fill()
    base.fill()

    // 右上角绿色状态点，落在盖子右上角处（与菜单栏图标语义一致）。
    // 先用 .clear 挖一圈透明环，让圆点与字形之间留出干净缝隙。
    if size >= 32 {
        let lidRight = glyphX0 + 20.4 * sx
        let lidTop = glyphY0 + 17.0 * sy
        let d: CGFloat = 168
        let dotRect = NSRect(x: lidRight - d / 2, y: lidTop - d / 2, width: d, height: d)
        let ring = dotRect.insetBy(dx: -34, dy: -34)
        context.cgContext.setBlendMode(.clear)
        context.cgContext.fillEllipse(in: ring)
        context.cgContext.setBlendMode(.normal)
        color(52, 211, 153).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
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

swift "$GENERATOR" "$SOURCE_DIR"

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
