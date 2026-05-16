import SwiftUI

/// LidRun 的实心笔记本字形：单一来源，菜单栏图标与界面字标共用。
/// 设计坐标系为 26×20（与已确认方案一致），按传入 rect 等比缩放。
enum LidGlyph {
    /// 参考坐标系尺寸。
    static let referenceSize = CGSize(width: 26, height: 20)

    /// 在给定 rect 内（左上原点、y 向下，CoreGraphics/SwiftUI 默认）生成实心字形路径：
    /// 一个圆角"盖子"矩形 + 一个圆角"底座"矩形，中间留细缝，读作合盖笔记本。
    static func path(in rect: CGRect) -> CGPath {
        let sx = rect.width / referenceSize.width
        let sy = rect.height / referenceSize.height
        let r = min(sx, sy) * 2.0

        func mk(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * sx, y: rect.minY + y * sy, width: w * sx, height: h * sy)
        }

        let lid = mk(5.6, 3.0, 14.8, 9.0)
        let base = mk(2.4, 13.2, 21.2, 4.0)

        let p = CGMutablePath()
        p.addRoundedRect(in: lid, cornerWidth: r, cornerHeight: r)
        p.addRoundedRect(in: base, cornerWidth: r, cornerHeight: r)
        return p
    }
}

/// SwiftUI 包装，供界面字标使用。
struct LidGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(LidGlyph.path(in: rect))
    }
}
