import AppKit

enum BrandingIcon {
    static func makeStatusBarIcon(pointSize: CGFloat) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let glassesRect = NSRect(
            x: pointSize * 0.07,
            y: pointSize * 0.30,
            width: pointSize * 0.86,
            height: pointSize * 0.46
        )
        drawGlasses(in: glassesRect, color: .black, includeTopBar: true)
        image.isTemplate = true
        return image
    }

    static func makeAppIcon(pointSize: CGFloat) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let bgRect = NSRect(
            x: pointSize * 0.04,
            y: pointSize * 0.04,
            width: pointSize * 0.92,
            height: pointSize * 0.92
        )
        let bgRadius = pointSize * 0.21
        let bg = NSBezierPath(roundedRect: bgRect, xRadius: bgRadius, yRadius: bgRadius)
        let honeyBase = NSColor(calibratedRed: 0.89, green: 0.62, blue: 0.20, alpha: 1.0)
        honeyBase.setFill()
        bg.fill()

        NSColor(calibratedRed: 0.73, green: 0.46, blue: 0.10, alpha: 0.30).setStroke()
        bg.lineWidth = max(2.5, pointSize * 0.014)
        bg.stroke()

        let glassesRect = NSRect(
            x: pointSize * 0.18,
            y: pointSize * 0.37,
            width: pointSize * 0.64,
            height: pointSize * 0.36
        )
        drawGlasses(
            in: glassesRect,
            color: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
            includeTopBar: true
        )

        image.isTemplate = false
        return image
    }

    private static func drawGlasses(in rect: NSRect, color: NSColor, includeTopBar: Bool) {
        color.setFill()

        let lensWidth = rect.width * 0.40
        let lensHeight = rect.height * 0.62
        let bridgeWidth = rect.width * 0.13
        let bridgeHeight = rect.height * 0.17
        let lensY = rect.minY + (rect.height - lensHeight) * 0.48
        let leftX = rect.minX
        let rightX = rect.maxX - lensWidth
        let radius = lensHeight * 0.30

        NSBezierPath(
            roundedRect: NSRect(x: leftX, y: lensY, width: lensWidth, height: lensHeight),
            xRadius: radius,
            yRadius: radius
        ).fill()

        NSBezierPath(
            roundedRect: NSRect(x: rightX, y: lensY, width: lensWidth, height: lensHeight),
            xRadius: radius,
            yRadius: radius
        ).fill()

        NSBezierPath(
            roundedRect: NSRect(
                x: rect.midX - bridgeWidth * 0.5,
                y: lensY + (lensHeight - bridgeHeight) * 0.5,
                width: bridgeWidth,
                height: bridgeHeight
            ),
            xRadius: bridgeHeight * 0.35,
            yRadius: bridgeHeight * 0.35
        ).fill()

        if includeTopBar {
            let topBar = NSBezierPath(
                roundedRect: NSRect(
                    x: leftX + lensWidth * 0.10,
                    y: lensY + lensHeight * 0.70,
                    width: rect.width - lensWidth * 0.20,
                    height: lensHeight * 0.17
                ),
                xRadius: lensHeight * 0.08,
                yRadius: lensHeight * 0.08
            )
            topBar.fill()
        }
    }
}
