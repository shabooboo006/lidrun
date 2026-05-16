import AppKit

enum StatusIconRenderer {
    private enum IconMode {
        case idle
        case active
        case lidRun
    }

    private static let idleTemplate = loadTemplate(named: "MenuBarIconIdleTemplate")
    private static let activeTemplate = loadTemplate(named: "MenuBarIconActiveTemplate")
    private static let lidRunTemplate = loadTemplate(named: "MenuBarIconLidRunTemplate")

    static func image(active: Bool, colored: Bool, lidState: LidRunState, helperStatus: HelperStatus) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        NSGraphicsContext.current?.imageInterpolation = .high

        let isBlocked: Bool = {
            if case .blocked = lidState { return true }
            if case .unavailable = helperStatus { return true }
            return false
        }()
        let needsAttention = isBlocked || helperStatus == .requiresApproval
        let shouldUseSemanticColor = colored && (active || needsAttention)
        let bodyColor: NSColor = {
            if needsAttention && colored { return .systemOrange }
            if active && colored { return .systemBlue }
            return .labelColor
        }()
        let iconMode = iconMode(active: active, lidState: lidState)

        drawTemplateIcon(mode: iconMode, color: bodyColor)

        if active || needsAttention {
            (needsAttention ? NSColor.systemOrange : NSColor.systemGreen).setFill()
            let statusDot = NSBezierPath(ovalIn: NSRect(x: 16.8, y: 3.0, width: 3.8, height: 3.8))
            statusDot.fill()
        }

        image.unlockFocus()
        image.isTemplate = !shouldUseSemanticColor
        return image
    }

    private static func loadTemplate(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func iconMode(active: Bool, lidState: LidRunState) -> IconMode {
        if lidState == .running || lidState == .enabling || lidState == .restoring {
            return .lidRun
        }
        if active {
            return .active
        }
        return .idle
    }

    private static func drawTemplateIcon(mode: IconMode, color: NSColor) {
        guard let templateIcon = template(for: mode) else {
            drawFallbackIcon(mode: mode, color: color)
            return
        }

        let rect = NSRect(x: 2.2, y: 2.0, width: 17.6, height: 14.4)
        color.setFill()
        rect.fill()
        templateIcon.draw(
            in: rect,
            from: NSRect(origin: .zero, size: templateIcon.size),
            operation: .destinationIn,
            fraction: 1
        )
    }

    private static func template(for mode: IconMode) -> NSImage? {
        switch mode {
        case .idle:
            return idleTemplate
        case .active:
            return activeTemplate
        case .lidRun:
            return lidRunTemplate
        }
    }

    private static func drawFallbackIcon(mode: IconMode, color: NSColor) {
        color.setStroke()

        let screen = NSBezierPath()
        screen.lineWidth = 1.5
        screen.lineCapStyle = .round
        screen.lineJoinStyle = .round
        switch mode {
        case .idle:
            screen.move(to: NSPoint(x: 6.0, y: 13.0))
            screen.line(to: NSPoint(x: 16.0, y: 13.0))
            screen.line(to: NSPoint(x: 14.8, y: 7.5))
            screen.line(to: NSPoint(x: 7.2, y: 7.5))
        case .active:
            screen.move(to: NSPoint(x: 5.8, y: 14.0))
            screen.line(to: NSPoint(x: 16.2, y: 14.0))
            screen.line(to: NSPoint(x: 14.8, y: 7.2))
            screen.line(to: NSPoint(x: 7.2, y: 7.2))
        case .lidRun:
            screen.move(to: NSPoint(x: 5.1, y: 9.8))
            screen.line(to: NSPoint(x: 16.9, y: 9.8))
            screen.line(to: NSPoint(x: 15.8, y: 8.4))
            screen.line(to: NSPoint(x: 6.2, y: 8.4))
        }
        screen.close()
        screen.stroke()

        let base = NSBezierPath()
        base.lineWidth = 1.5
        base.lineCapStyle = .round
        base.lineJoinStyle = .round
        base.move(to: NSPoint(x: 7.2, y: 7.5))
        base.line(to: NSPoint(x: 4.8, y: 4.5))
        base.line(to: NSPoint(x: 17.2, y: 4.5))
        base.line(to: NSPoint(x: 14.8, y: 7.5))
        base.stroke()
    }
}
