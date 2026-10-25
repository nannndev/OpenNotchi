import AppKit
import CoreImage

/// The Newspaper strip style.
extension PhotoStripComposer {
    static func newspaperPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        withShadow(color: NSColor.black.withAlphaComponent(0.15), blur: 6, offset: CGSize(width: 1, height: 2)) {
            NSColor.white.setFill()
            NSBezierPath(rect: cell).fill()
        }
        let photoRect = cell.insetBy(dx: 4, dy: 4)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: photoRect).addClip()
        drawAspectFill(photo, in: photoRect)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.black.setStroke()
        let nBorder = NSBezierPath(rect: cell)
        nBorder.lineWidth = 2.5
        nBorder.stroke()

        let capFont =
            NSFont(name: "Times-Italic", size: 16) ?? NSFont(name: "Times New Roman Italic", size: 16)
            ?? .systemFont(ofSize: 16)
        let figStr = "Fig. \(index + 1) — Special dispatch from the scene"
        draw(
            figStr, font: capFont, color: NSColor(white: 0.2, alpha: 0.9),
            at: CGPoint(x: cell.minX + 4, y: cell.maxY + 8))
    }

    static func newspaperBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1))
        let mastheadFont =
            NSFont(name: "Didot-Bold", size: 48) ?? NSFont(name: "Times New Roman Bold", size: 46)
            ?? .boldSystemFont(ofSize: 44)
        let titleStr = NSAttributedString(
            string: "✦ THE DAILY CHRONICLE ✦",
            attributes: [
                .font: mastheadFont,
                .foregroundColor: NSColor.black,
                .kern: 3.0,
            ])
        let tSize = titleStr.size()
        titleStr.draw(at: CGPoint(x: canvas.midX - tSize.width / 2, y: 16))

        NSColor.black.setFill()
        NSBezierPath(rect: CGRect(x: 40, y: 68, width: canvas.width - 80, height: 2.5)).fill()
        NSBezierPath(rect: CGRect(x: 40, y: 73, width: canvas.width - 80, height: 1.0)).fill()

        let subFont = NSFont(name: "Times New Roman", size: 15) ?? .systemFont(ofSize: 15)
        let subText = "VOL. CVIII · NO. 42  ·  SPECIAL PHOTO EDITION  ·  PRICE: TWO CENTS"
        draw(subText, font: subFont, color: NSColor(white: 0.2, alpha: 1), at: CGPoint(x: canvas.midX - 240, y: 78))

        NSBezierPath(rect: CGRect(x: 40, y: 98, width: canvas.width - 80, height: 1.5)).fill()
    }

    static func newspaperFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 16
        NSColor.black.setFill()
        NSBezierPath(rect: CGRect(x: rect.minX + 30, y: y, width: rect.width - 60, height: 3)).fill()
        y += 8
        let titleFont =
            NSFont(name: "Didot-Bold", size: 66) ?? NSFont(name: "Times New Roman Bold", size: 62)
            ?? .boldSystemFont(ofSize: 58)
        y +=
            centered(
                footer.title("MOMENTS THAT MADE HISTORY").uppercased(), font: titleFont, color: .black, x: center, y: y)
            + 4

        NSBezierPath(rect: CGRect(x: rect.minX + 30, y: y, width: rect.width - 60, height: 1.5)).fill()
        y += 10
        centered(
            footer.dateString("EEEE, MMMM d, yyyy").uppercased() + "  ·  CITY EDITION  ·  FREE",
            font: NSFont(name: "Times New Roman", size: 22) ?? .systemFont(ofSize: 22),
            color: NSColor(white: 0.2, alpha: 1), x: center, y: y)
        y += 34

        let bodyFont = NSFont(name: "Times New Roman", size: 16) ?? .systemFont(ofSize: 16)
        let colW = (rect.width - 100) / 2
        let col1 =
            "Eyewitnesses confirm today was one for the record books. Spirits remained extraordinary throughout, with genuine laughter echoed across every frame captured."
        let col2 =
            "Analysts predict these memories will remain timeless for decades to come. Special souvenir print issued by OpenNotchi Press."
        NSAttributedString(
            string: col1, attributes: [.font: bodyFont, .foregroundColor: NSColor(white: 0.25, alpha: 1)]
        ).draw(in: CGRect(x: rect.minX + 40, y: y, width: colW - 10, height: 80))
        NSAttributedString(
            string: col2, attributes: [.font: bodyFont, .foregroundColor: NSColor(white: 0.25, alpha: 1)]
        ).draw(in: CGRect(x: center + 10, y: y, width: colW - 10, height: 80))
    }
}
