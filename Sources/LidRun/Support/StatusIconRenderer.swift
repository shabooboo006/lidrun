import AppKit

/// 菜单栏图标：粗实心笔记本字形 + 右上角状态圆点。
///
/// 默认（彩色关闭）渲染为模板图标，由系统在顶栏自动黑/白适配，永远锐利。
/// 彩色开启时：激活=机身系统蓝；其余=机身 labelColor（深色顶栏呈白）；
/// 状态用右上角小圆点表达，图标本体不再整体染色。
enum StatusIconRenderer {
    static func image(active: Bool, colored: Bool, lidState: LidRunState, helperStatus: HelperStatus) -> NSImage {
        let size = NSSize(width: 22, height: 18)

        let needsAttention: Bool = {
            if case .blocked = lidState { return true }
            if case .unavailable = helperStatus { return true }
            return helperStatus == .requiresApproval
        }()
        let isLidRunning = lidState == .running || lidState == .enabling || lidState == .restoring

        // 状态点颜色：绿=合盖运行 / 蓝=已激活 / 橙=需注意；nil=不画点。
        let dotColor: NSColor? = {
            if needsAttention { return .systemOrange }
            if isLidRunning { return .systemGreen }
            if active { return .systemBlue }
            return nil
        }()

        // 机身颜色与是否模板。
        let useColor = colored
        let bodyColor: NSColor = {
            guard useColor else { return .black } // 模板模式下颜色被系统忽略
            if active && !needsAttention { return .systemBlue }
            return .labelColor
        }()

        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current {
            ctx.shouldAntialias = true
            ctx.imageInterpolation = .high
            let cg = ctx.cgContext

            // 字形（设计系 y 向下；NSImage y 向上）→ 垂直翻转。
            let glyphRect = CGRect(x: 1.8, y: 1.5, width: 18.4, height: 15.0)
            cg.saveGState()
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            cg.addPath(LidGlyph.path(in: glyphRect))
            cg.setFillColor(bodyColor.cgColor)
            cg.fillPath()
            cg.restoreGState()

            // 状态点（顶栏坐标，y 向上）：参考中心 (22.5,4.5)/26×20 → 这里右上角。
            if let dotColor {
                let d: CGFloat = 6.4
                let dotRect = CGRect(x: size.width - d - 0.4, y: size.height - d - 0.6, width: d, height: d)
                cg.setFillColor(dotColor.cgColor)
                cg.fillEllipse(in: dotRect)
            }
        }
        image.unlockFocus()

        // 彩色关闭 → 纯模板，系统自动适配顶栏；彩色开启 → 用真实颜色。
        image.isTemplate = !useColor
        return image
    }
}
