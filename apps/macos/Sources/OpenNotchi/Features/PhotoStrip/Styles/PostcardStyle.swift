import AppKit

/// The Postcard strip style.
extension PhotoStripComposer {
    static func postcardPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let shadowColor = NSColor.black.withAlphaComponent(0.2)
        withShadow(color: shadowColor, blur: 14, offset: CGSize(width: 0, height: 4)) {
            NSColor(white: 0.99, alpha: 1).setFill()
            NSBezierPath(roundedRect: cell, xRadius: 8, yRadius: 8).fill()
        }
        let photoBorder = cell.insetBy(dx: 14, dy: 14)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoBorder, xRadius: 5, yRadius: 5).addClip()
        drawAspectFill(photo, in: photoBorder)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(white: 0.1, alpha: 0.1).setStroke()
        let innerBorder = NSBezierPath(roundedRect: photoBorder, xRadius: 5, yRadius: 5)
        innerBorder.lineWidth = 1.5
        innerBorder.stroke()

        // Photo mounting tabs on corners
        let cornerSize: CGFloat = 22
        NSColor(red: 0.82, green: 0.74, blue: 0.62, alpha: 0.9).setFill()
        for corner in [
            CGPoint(x: cell.minX + 8, y: cell.minY + 8),
            CGPoint(x: cell.maxX - 8, y: cell.minY + 8),
            CGPoint(x: cell.minX + 8, y: cell.maxY - 8),
            CGPoint(x: cell.maxX - 8, y: cell.maxY - 8),
        ] {
            let path = NSBezierPath()
            let signX: CGFloat = corner.x > cell.midX ? -1 : 1
            let signY: CGFloat = corner.y > cell.midY ? -1 : 1
            path.move(to: corner)
            path.line(to: CGPoint(x: corner.x + cornerSize * signX, y: corner.y))
            path.line(to: CGPoint(x: corner.x, y: corner.y + cornerSize * signY))
            path.close()
            path.fill()
        }
    }

    static func postcardBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.985, green: 0.97, blue: 0.94, alpha: 1))
        let borderWidth: CGFloat = 32
        let stripeWidth: CGFloat = 42
        let redColor = NSColor(red: 0.85, green: 0.22, blue: 0.22, alpha: 1)
        let blueColor = NSColor(red: 0.13, green: 0.32, blue: 0.62, alpha: 1)
        let whiteColor = NSColor.white
        drawAirmailBorder(
            canvas: canvas, borderWidth: borderWidth, stripeWidth: stripeWidth, red: redColor, blue: blueColor,
            white: whiteColor)

        let innerCard = canvas.insetBy(dx: borderWidth, dy: borderWidth)
        NSColor(red: 0.985, green: 0.97, blue: 0.94, alpha: 1).setFill()
        NSBezierPath(rect: innerCard).fill()

        NSColor(red: 0.75, green: 0.68, blue: 0.58, alpha: 0.6).setStroke()
        let innerFrame = innerCard.insetBy(dx: 10, dy: 10)
        let framePath = NSBezierPath(rect: innerFrame)
        framePath.lineWidth = 1.5
        framePath.stroke()

        let headerBadge = CGRect(x: innerFrame.minX + 20, y: innerFrame.minY + 14, width: 270, height: 40)
        blueColor.setFill()
        NSBezierPath(roundedRect: headerBadge, xRadius: 6, yRadius: 6).fill()
        let parAvionAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Helvetica-Bold", size: 16) ?? .boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.white,
            .kern: 1.5,
        ]
        let parAvionStr = NSAttributedString(string: "✈  PAR AVION  ·  AIR MAIL", attributes: parAvionAttr)
        let paSize = parAvionStr.size()
        parAvionStr.draw(
            at: CGPoint(x: headerBadge.midX - paSize.width / 2, y: headerBadge.midY - paSize.height / 2))
    }

    static func postcardFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let caption = footer.custom
        let f = DateFormatter()
        let ink = NSColor(red: 0.16, green: 0.2, blue: 0.28, alpha: 1)
        let red = NSColor(red: 0.85, green: 0.22, blue: 0.22, alpha: 1)
        f.dateFormat = "d MMMM yyyy"
        let dateStr = f.string(from: info.date)

        let dividerX = rect.midX
        let topY = rect.minY + 24
        let bottomY = rect.maxY - 24
        NSColor(red: 0.75, green: 0.7, blue: 0.64, alpha: 0.7).setStroke()
        let divLine = NSBezierPath()
        divLine.move(to: CGPoint(x: dividerX, y: topY + 40))
        divLine.line(to: CGPoint(x: dividerX, y: bottomY))
        divLine.lineWidth = 1.5
        divLine.stroke()

        let headerFont = NSFont(name: "Times New Roman Bold", size: 36) ?? .boldSystemFont(ofSize: 36)
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor(red: 0.25, green: 0.22, blue: 0.2, alpha: 0.9),
        ]
        let headerStr = NSAttributedString(string: "CARTE POSTALE  ★  POST CARD", attributes: headerAttr)
        let hSize = headerStr.size()
        headerStr.draw(at: CGPoint(x: dividerX - hSize.width / 2, y: topY))

        // Left Side: Message Area
        let msgLeft = rect.minX + 50
        let msgWidth = dividerX - msgLeft - 30
        var msgY = topY + 54

        draw(
            "MESSAGE / CORRESPONDENCE:", font: .systemFont(ofSize: 18, weight: .bold),
            color: NSColor(white: 0.4, alpha: 0.8), at: CGPoint(x: msgLeft, y: msgY))
        msgY += 34

        let handFont =
            NSFont(name: "Marker Felt Wide", size: 38) ?? NSFont(name: "Noteworthy-Bold", size: 34)
            ?? rounded(34, .bold)
        let message = caption ?? "Greetings from OpenNotchi! Wishing you were here ♡"
        let msgBox = CGRect(x: msgLeft, y: msgY, width: msgWidth, height: 160)
        NSAttributedString(string: message, attributes: [.font: handFont, .foregroundColor: ink]).draw(in: msgBox)

        let dateY = bottomY - 35
        draw(
            "Date: \(dateStr)", font: NSFont(name: "Noteworthy-Bold", size: 24) ?? .systemFont(ofSize: 24),
            color: ink.withAlphaComponent(0.8), at: CGPoint(x: msgLeft, y: dateY))

        // Right Side: Stamp, Postmark & Address Lines
        let rightX = dividerX + 35
        let stampW: CGFloat = 130
        let stampH: CGFloat = 160
        let stampRect = CGRect(x: rect.maxX - 50 - stampW, y: topY + 45, width: stampW, height: stampH)

        drawPerforatedStamp(stampRect, color: red)
        symbol("airplane", color: .white, at: CGPoint(x: stampRect.midX, y: stampRect.minY + 65), size: 48)
        draw(
            "AIR MAIL", font: .boldSystemFont(ofSize: 16), color: .white,
            at: CGPoint(x: stampRect.midX - 35, y: stampRect.minY + 115))
        draw(
            "50¢", font: .boldSystemFont(ofSize: 22), color: .white,
            at: CGPoint(x: stampRect.midX - 18, y: stampRect.minY + 20))

        let postmarkCenter = CGPoint(x: stampRect.minX - 10, y: stampRect.minY + 70)
        drawPostmark(center: postmarkCenter, dateString: f.string(from: info.date).uppercased())

        var addrY = stampRect.maxY + 35
        draw(
            "ADDRESS / DESTINATAIRE:", font: .systemFont(ofSize: 18, weight: .bold),
            color: NSColor(white: 0.4, alpha: 0.8), at: CGPoint(x: rightX, y: addrY))
        addrY += 34

        for line in [
            "To: __________________________________",
            "     __________________________________",
            "     __________________________________",
            "     OpenNotchi · Special Delivery ✈",
        ] {
            draw(
                line,
                font: NSFont(name: "Courier New Bold", size: 22)
                    ?? .monospacedSystemFont(ofSize: 22, weight: .bold), color: NSColor(white: 0.35, alpha: 0.85),
                at: CGPoint(x: rightX, y: addrY))
            addrY += 36
        }
    }

    static func drawAirmailBorder(
        canvas: CGRect, borderWidth: CGFloat, stripeWidth: CGFloat, red: NSColor, blue: NSColor, white: NSColor
    ) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()

        let outerPath = CGMutablePath()
        outerPath.addRect(canvas)
        let innerRect = canvas.insetBy(dx: borderWidth, dy: borderWidth)
        outerPath.addRect(innerRect)
        cg.addPath(outerPath)
        cg.clip(using: .evenOdd)

        white.setFill()
        cg.fill(canvas)

        let stripeGap = stripeWidth * 0.4
        let step = (stripeWidth + stripeGap) * 2
        var x = -canvas.height - 200
        while x < canvas.width + canvas.height + 200 {
            let rPath = NSBezierPath()
            rPath.move(to: CGPoint(x: x, y: 0))
            rPath.line(to: CGPoint(x: x + stripeWidth, y: 0))
            rPath.line(to: CGPoint(x: x + stripeWidth - canvas.height, y: canvas.height))
            rPath.line(to: CGPoint(x: x - canvas.height, y: canvas.height))
            rPath.close()
            red.setFill()
            rPath.fill()

            let bx = x + stripeWidth + stripeGap
            let bPath = NSBezierPath()
            bPath.move(to: CGPoint(x: bx, y: 0))
            bPath.line(to: CGPoint(x: bx + stripeWidth, y: 0))
            bPath.line(to: CGPoint(x: bx + stripeWidth - canvas.height, y: canvas.height))
            bPath.line(to: CGPoint(x: bx - canvas.height, y: canvas.height))
            bPath.close()
            blue.setFill()
            bPath.fill()

            x += step
        }

        cg.restoreGState()
    }

    static func drawPerforatedStamp(_ rect: CGRect, color: NSColor) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()

        withShadow(color: NSColor.black.withAlphaComponent(0.2), blur: 8, offset: CGSize(width: 1, height: 2)) {
            NSColor(white: 0.99, alpha: 1).setFill()
            NSBezierPath(rect: rect).fill()
        }

        let inner = rect.insetBy(dx: 10, dy: 10)
        color.setFill()
        NSBezierPath(rect: inner).fill()

        let paperColor = NSColor(red: 0.985, green: 0.97, blue: 0.94, alpha: 1)
        paperColor.setFill()
        let r: CGFloat = 4.5
        var sx = rect.minX + 8
        while sx < rect.maxX {
            NSBezierPath(ovalIn: CGRect(x: sx - r, y: rect.minY - r, width: r * 2, height: r * 2)).fill()
            NSBezierPath(ovalIn: CGRect(x: sx - r, y: rect.maxY - r, width: r * 2, height: r * 2)).fill()
            sx += 12
        }
        var sy = rect.minY + 8
        while sy < rect.maxY {
            NSBezierPath(ovalIn: CGRect(x: rect.minX - r, y: sy - r, width: r * 2, height: r * 2)).fill()
            NSBezierPath(ovalIn: CGRect(x: rect.maxX - r, y: sy - r, width: r * 2, height: r * 2)).fill()
            sy += 12
        }

        cg.restoreGState()
    }

    static func drawPostmark(center: CGPoint, dateString: String) {
        let postmarkInk = NSColor(red: 0.12, green: 0.18, blue: 0.3, alpha: 0.8)
        postmarkInk.setStroke()

        let circle1 = NSBezierPath(ovalIn: CGRect(x: center.x - 55, y: center.y - 55, width: 110, height: 110))
        circle1.lineWidth = 2.5
        circle1.stroke()

        let circle2 = NSBezierPath(ovalIn: CGRect(x: center.x - 47, y: center.y - 47, width: 94, height: 94))
        circle2.lineWidth = 1.2
        circle2.stroke()

        let stampFont = NSFont(name: "Helvetica-Bold", size: 10) ?? .boldSystemFont(ofSize: 10)
        draw("AIR MAIL POST", font: stampFont, color: postmarkInk, at: CGPoint(x: center.x - 38, y: center.y - 28))
        draw(
            dateString, font: NSFont(name: "Courier New Bold", size: 11) ?? .boldSystemFont(ofSize: 11),
            color: postmarkInk, at: CGPoint(x: center.x - 36, y: center.y - 6))
        draw("★ VERIFIED ★", font: stampFont, color: postmarkInk, at: CGPoint(x: center.x - 35, y: center.y + 16))

        let wavePath = NSBezierPath()
        for dy: CGFloat in [-16, 0, 16] {
            wavePath.move(to: CGPoint(x: center.x - 55, y: center.y + dy))
            wavePath.curve(
                to: CGPoint(x: center.x - 135, y: center.y + dy),
                controlPoint1: CGPoint(x: center.x - 80, y: center.y + dy - 10),
                controlPoint2: CGPoint(x: center.x - 110, y: center.y + dy + 10))
        }
        wavePath.lineWidth = 2
        wavePath.stroke()
    }
}
