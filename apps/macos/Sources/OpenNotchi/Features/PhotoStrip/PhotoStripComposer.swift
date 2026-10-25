import AppKit
import CoreImage

/// Lays four photos out as a photobox strip (or a 2×2 grid) in one of the `StripStyle`s.
enum PhotoStripComposer {
    static let ciContext = CIContext()

    /// Placeholder portraits for previews: soft silhouettes on colorful backdrops.
    static let samplePhotos: [CGImage] = [(0.02, 0.08), (0.55, 0.62), (0.9, 0.97), (0.33, 0.42)].compactMap { hues in
        let w = 800
        let h = 600
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let ctx = CGContext(
                data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let gradient = CGGradient(
                colorsSpace: space,
                colors: [
                    NSColor(hue: hues.0, saturation: 0.45, brightness: 0.95, alpha: 1).cgColor,
                    NSColor(hue: hues.1, saturation: 0.6, brightness: 0.55, alpha: 1).cgColor,
                ] as CFArray, locations: nil)
        else { return nil }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])
        ctx.setFillColor(NSColor(white: 1, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: 310, y: 230, width: 180, height: 210))  // head
        ctx.fillEllipse(in: CGRect(x: 200, y: -170, width: 400, height: 380))  // shoulders
        return ctx.makeImage()
    }

    /// Lays out every photo given (one per cell) in `format`.
    static func compose(
        _ photos: [CGImage],
        style: StripStyle,
        format: StripFormat = .strip,
        info: StripInfo,
        stickers: [PlacedSticker] = []
    ) -> CGImage? {
        guard !photos.isEmpty else { return nil }
        let photos = photos.map { filtered($0, style: style) }
        let count = photos.count

        let width: CGFloat = 1200
        let side: CGFloat
        switch style {
        case .film: side = 120
        case .social: side = 0
        case .receipt: side = 100
        case .postcard: side = 65
        case .newspaper: side = 80
        case .classic: side = 70
        case .polaroid: side = 65
        default: side = 70
        }
        let header: CGFloat
        switch style {
        case .social: header = 150
        case .postcard: header = 85
        case .newspaper: header = 125
        case .classic: header = 65
        case .film: header = 50
        default: header = 0
        }
        var footer = footerHeight(style)
        let gap: CGFloat
        switch style {
        case .film: gap = 28
        case .social: gap = 6
        case .newspaper: gap = 44
        case .polaroid: gap = 30
        default: gap = 34
        }
        var footerScale: CGFloat = 1.3
        var cells: [CGRect] = []
        let height: CGFloat

        if let ratio = format.heightRatio {
            // Fixed canvas: the footer gives up space if needed, then the photos share the rest in the
            // grid whose cells come closest to the camera's 4:3.
            height = (width * ratio).rounded()
            let fit = min(1, height * 0.3 / footer)
            footer *= fit
            footerScale *= fit
            let area = CGRect(
                x: side, y: header + side, width: width - 2 * side,
                height: height - header - footer - side - (style == .social ? 0 : 10))
            let columns =
                (1...min(3, count)).filter { count % $0 == 0 }.min { a, b in
                    abs(log(cellAspect(area, count: count, columns: a, gap: gap) / (4 / 3)))
                        < abs(log(cellAspect(area, count: count, columns: b, gap: gap) / (4 / 3)))
                } ?? 1
            cells = grid(area, count: count, columns: columns, gap: gap)
        } else {
            // Classic strip: 4:3 photos, one column (two for grid styles), as tall as it needs to be.
            let columns = style.isGrid && count % 2 == 0 ? 2 : 1
            let rows = count / columns
            let cellW = (width - 2 * side - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let cellH = cellW * 3 / 4
            let area = CGRect(
                x: side, y: header + side, width: width - 2 * side,
                height: CGFloat(rows) * cellH + CGFloat(rows - 1) * gap)
            cells = grid(area, count: count, columns: columns, gap: gap)
            height = area.maxY + footer
        }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        let footerRect = CGRect(x: 0, y: height - footer, width: width, height: footer)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let cg = CGContext(
                data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Top-left origin, like the layout above.
        cg.translateBy(x: 0, y: height)
        cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }

        drawBackground(style, canvas: canvas, info: info, photos: photos)
        for (i, cell) in cells.enumerated() {
            drawPhoto(photos[i % photos.count], in: cell, style: style, index: i)
        }
        if style == .social {
            drawSocialHeader(avatar: photos[0], width: width, caption: info.caption)
        }
        // Keep decorations off the photos and the footer text.
        let textArea = CGRect(x: 120, y: footerRect.minY + 20, width: width - 240, height: footerRect.height - 20)
        drawDecorations(style, canvas: canvas, avoid: cells + [textArea])

        // Footer text is laid out at a base size and scaled up so it reads well on a phone.
        cg.saveGState()
        cg.translateBy(x: footerRect.midX, y: footerRect.minY)
        cg.scaleBy(x: footerScale, y: footerScale)
        cg.translateBy(x: -footerRect.midX, y: -footerRect.minY)
        let scaledFooter = CGRect(
            x: footerRect.midX - footerRect.width / footerScale / 2,
            y: footerRect.minY,
            width: footerRect.width / footerScale,
            height: footerRect.height / footerScale
        )
        drawFooter(style, rect: scaledFooter, info: info)
        cg.restoreGState()

        // Draw user stickers & stamps placed in the photobox studio!
        drawStickers(stickers, canvas: canvas)

        return cg.makeImage()
    }

    static func drawStickers(_ stickers: [PlacedSticker], canvas: CGRect) {
        guard !stickers.isEmpty else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        for sticker in stickers {
            let posX = sticker.x * canvas.width
            let posY = sticker.y * canvas.height

            ctx.saveGState()
            ctx.translateBy(x: posX, y: posY)
            ctx.rotate(by: CGFloat(sticker.rotation * .pi / 180.0))
            let s = sticker.scale * 1.6
            ctx.scaleBy(x: s, y: s)

            if sticker.isBadge {
                drawStampBadge(sticker)
            } else {
                let font = NSFont.systemFont(ofSize: 64)
                let str = NSAttributedString(
                    string: sticker.content,
                    attributes: [
                        .font: font,
                        .shadow: {
                            let sh = NSShadow()
                            sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
                            sh.shadowOffset = NSSize(width: 0, height: -3)
                            sh.shadowBlurRadius = 8
                            return sh
                        }(),
                    ])
                let size = str.size()
                str.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
            }

            ctx.restoreGState()
        }
    }

    static func drawStampBadge(_ sticker: PlacedSticker) {
        let font = NSFont.systemFont(ofSize: 22, weight: .black)
        let color: NSColor
        switch sticker.badgeColor.lowercased() {
        case "pink": color = NSColor(red: 0.95, green: 0.25, blue: 0.60, alpha: 1)
        case "green": color = NSColor(red: 0.12, green: 0.55, blue: 0.35, alpha: 1)
        case "black": color = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        case "gold": color = NSColor(red: 0.90, green: 0.60, blue: 0.12, alpha: 1)
        case "blue": color = NSColor(red: 0.18, green: 0.55, blue: 0.92, alpha: 1)
        case "purple": color = NSColor(red: 0.65, green: 0.32, blue: 0.88, alpha: 1)
        default: color = NSColor(red: 0.88, green: 0.18, blue: 0.18, alpha: 1)  // red
        }

        let str = NSAttributedString(
            string: sticker.content.uppercased(),
            attributes: [
                .font: font,
                .foregroundColor: color,
                .kern: 1.8,
            ])
        let textSize = str.size()
        let padX: CGFloat = 16
        let padY: CGFloat = 8
        let badgeRect = CGRect(
            x: -textSize.width / 2 - padX, y: -textSize.height / 2 - padY, width: textSize.width + 2 * padX,
            height: textSize.height + 2 * padY)

        // Drop shadow for realistic physical stamp feel
        withShadow(color: NSColor.black.withAlphaComponent(0.2), blur: 6, offset: CGSize(width: 0, height: 2)) {
            color.withAlphaComponent(0.08).setFill()
            let bgPath = NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7)
            bgPath.fill()
        }

        // Outer border
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7)
        path.lineWidth = 3
        color.withAlphaComponent(0.9).setStroke()
        path.stroke()

        // Inner hairline border
        let inner = badgeRect.insetBy(dx: 3.5, dy: 3.5)
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: 4.5, yRadius: 4.5)
        innerPath.lineWidth = 1
        color.withAlphaComponent(0.45).setStroke()
        innerPath.stroke()

        str.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2 + 1))
    }

    static func grid(_ area: CGRect, count: Int, columns: Int, gap: CGFloat) -> [CGRect] {
        let rows = max(1, count / columns)
        let w = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let h = (area.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        return (0..<count).map { i in
            CGRect(
                x: area.minX + CGFloat(i % columns) * (w + gap), y: area.minY + CGFloat(i / columns) * (h + gap),
                width: w, height: h)
        }
    }

    static func cellAspect(_ area: CGRect, count: Int, columns: Int, gap: CGFloat) -> CGFloat {
        let rows = max(1, count / columns)
        let w = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let h = (area.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        return max(w, 1) / max(h, 1)
    }

    // MARK: - Photos

    static func filtered(_ photo: CGImage, style: StripStyle) -> CGImage {
        let image = CIImage(cgImage: photo)
        let output: CIImage
        switch style {
        case .newspaper:
            output = image.applyingFilter("CIPhotoEffectNoir")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.3, kCIInputBrightnessKey: 0.02])
        case .receipt:
            // Thermal-print look: grayscale, punchy, a little faded.
            output = image.applyingFilter("CIPhotoEffectMono")
                .applyingFilter(
                    "CIColorControls", parameters: [kCIInputContrastKey: 1.35, kCIInputBrightnessKey: 0.06])
        case .retro:
            output = image.applyingFilter("CIPhotoEffectTransfer")
                .applyingFilter(
                    "CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.15])
        case .postcard:
            output = image.applyingFilter("CIPhotoEffectInstant")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.1])
        case .polaroid:
            output = image.applyingFilter("CIPhotoEffectInstant")
                .applyingFilter(
                    "CIColorControls",
                    parameters: [kCIInputContrastKey: 1.1, kCIInputSaturationKey: 1.05, kCIInputBrightnessKey: 0.02])
        case .film:
            output = image.applyingFilter("CIPhotoEffectChrome")
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.55, kCIInputRadiusKey: 1.8])
        case .midnight:
            output = image.applyingFilter(
                "CIColorControls", parameters: [kCIInputContrastKey: 1.15, kCIInputSaturationKey: 0.95]
            )
            .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.4, kCIInputRadiusKey: 1.9])
        case .sakura:
            output = image.applyingFilter(
                "CIColorControls",
                parameters: [kCIInputSaturationKey: 1.12, kCIInputBrightnessKey: 0.03, kCIInputContrastKey: 1.02])
        case .y2k:
            output = image.applyingFilter(
                "CIColorControls", parameters: [kCIInputSaturationKey: 1.25, kCIInputContrastKey: 1.12])
        case .classic:
            output = image.applyingFilter(
                "CIColorControls", parameters: [kCIInputContrastKey: 1.05, kCIInputSaturationKey: 1.02])
        default:
            return photo
        }
        return ciContext.createCGImage(output.cropped(to: image.extent), from: image.extent) ?? photo
    }

    static func drawAspectFill(_ image: CGImage, in rect: CGRect) {
        let size = CGSize(width: image.width, height: image.height)
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let target = CGRect(
            x: rect.midX - drawn.width / 2, y: rect.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
        NSImage(cgImage: image, size: size).draw(
            in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue])
    }

    // MARK: - Background
}
