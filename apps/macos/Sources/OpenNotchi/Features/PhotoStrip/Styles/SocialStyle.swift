import AppKit

/// The Social strip style.
extension PhotoStripComposer {
    static func socialBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, .white)
    }

    static func socialFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let caption = footer.custom
        let f = DateFormatter()
        let x = rect.minX + 24
        var y = rect.minY + 20
        for (i, name) in ["heart.fill", "bubble.right", "paperplane"].enumerated() {
            symbol(
                name, color: i == 0 ? NSColor(red: 0.93, green: 0.22, blue: 0.33, alpha: 1) : .black,
                at: CGPoint(x: x + 20 + CGFloat(i) * 76, y: y + 24), size: 40)
        }
        symbol("bookmark", color: .black, at: CGPoint(x: rect.maxX - 44, y: y + 24), size: 40)
        y += 72
        draw(
            "Liked by you and 1,024 others", font: .systemFont(ofSize: 30, weight: .semibold), color: .black,
            at: CGPoint(x: x, y: y))
        y += 44
        let text = NSMutableAttributedString(
            string: "bestie.diaries ",
            attributes: [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: NSColor.black])
        text.append(
            NSAttributedString(
                string: caption ?? "core memories unlocked ✨",
                attributes: [.font: NSFont.systemFont(ofSize: 30), .foregroundColor: NSColor.black]))
        text.draw(in: CGRect(x: x, y: y, width: rect.width - 48, height: 42))
        y += 44
        draw(
            "View all 128 comments", font: .systemFont(ofSize: 27), color: NSColor(white: 0.5, alpha: 1),
            at: CGPoint(x: x, y: y))
        y += 40
        f.dateFormat = "d MMMM"
        draw(
            f.string(from: info.date).uppercased(), font: .systemFont(ofSize: 21, weight: .medium),
            color: NSColor(white: 0.55, alpha: 1), at: CGPoint(x: x, y: y))
    }

    static func drawSocialHeader(avatar: CGImage, width: CGFloat, caption: String?) {
        let avatarRect = CGRect(x: 30, y: 30, width: 90, height: 90)
        // Story ring around the avatar.
        NSGradient(colors: [.systemYellow, .systemOrange, .systemPink, .systemPurple])!
            .draw(in: NSBezierPath(ovalIn: avatarRect.insetBy(dx: -6, dy: -6)), angle: 45)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: avatarRect.insetBy(dx: -2, dy: -2)).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: avatarRect).addClip()
        drawAspectFill(avatar, in: avatarRect)
        NSGraphicsContext.restoreGraphicsState()
        draw("bestie.diaries", font: .systemFont(ofSize: 34, weight: .bold), color: .black, at: CGPoint(x: 146, y: 32))
        draw(
            "Original audio", font: .systemFont(ofSize: 26), color: NSColor(white: 0.45, alpha: 1),
            at: CGPoint(x: 146, y: 76))
        draw("•••", font: .systemFont(ofSize: 34, weight: .bold), color: .black, at: CGPoint(x: width - 90, y: 46))
    }
}
