// Renders the OpenNotchi showcase video from captures of the real app (demo mode).
//
// Usage: render <shots folder> <strips folder> <output.mp4> <landing page screenshot.png>
// See brand/BRAND.md (Marketing) for how the shots are captured.
import AppKit
import AVFoundation

let shots = CommandLine.arguments[1]
let strips = CommandLine.arguments[2]
let output = URL(fileURLWithPath: CommandLine.arguments[3])
/// Full-page screenshot of the landing page at 1440 px wide, 2x.
let landingPage = NSImage(contentsOfFile: CommandLine.arguments[4])!

let W = 1920, H = 1080, FPS = 60
/// The website preview runs first; the app scenes start after it.
let webLength = 7.0
/// The app scenes begin while the website fades out, so there's no empty beat between them.
let mainStart = webLength - 0.7
let duration = mainStart + 40.0

// MARK: - Assets

func image(_ path: String) -> NSImage {
    guard let img = NSImage(contentsOfFile: path) else { fatalError("missing \(path)") }
    return img
}
func shot(_ name: String) -> NSImage { image("\(shots)/\(name).png") }

let closed = shot("closed-music"), home = shot("home"), lyrics = shot("lyrics"), markets = shot("markets")
let meeting = shot("meeting"), prayer = shot("prayer"), mirror = shot("mirror"), picker = shot("picker")
let peeks = ["peek-charging", "peek-airpods", "peek-volume"].map(shot)
let themes: [(String, NSImage)] = [
    ("Album Art", shot("theme-albumArt")), ("Music Adaptive", shot("theme-adaptive")), ("Aurora", shot("theme-aurora")),
    ("Midnight", shot("theme-midnight")), ("Classic Black", shot("theme-classic")),
]
let stripImages = ["receipt", "player", "coquette", "scrapbook", "film", "social"].map { image("\(strips)/\($0).jpg") }

// Window captures are 2x (1560 px wide); drawn 1:1, centered, hanging from the top edge.
let shotWidth: CGFloat = 1560
func shotRect(_ img: NSImage, scale: CGFloat = 1) -> CGRect {
    let w = shotWidth * scale, h = w * img.size.height / img.size.width
    return CGRect(x: (CGFloat(W) - w) / 2, y: 0, width: w, height: h)
}

// MARK: - Easing

func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }
func easeInOut(_ x: Double) -> Double { let x = clamp(x); return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func easeOutBack(_ x: Double) -> Double { let x = clamp(x), c1 = 1.5, c3 = c1 + 1; return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2) }
/// 0→1 over `fade` after `start`, 1→0 over `fade` before `end`.
func window(_ t: Double, _ start: Double, _ end: Double, fade: Double = 0.35) -> Double {
    guard t >= start, t <= end else { return 0 }
    return min(easeInOut((t - start) / fade), easeInOut((end - t) / fade))
}

// MARK: - Drawing helpers

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
}

func draw(_ img: NSImage, in rect: CGRect, alpha: Double) {
    guard alpha > 0.001 else { return }
    img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
}

func text(_ string: String, font: NSFont, color: NSColor, centerX: CGFloat, y: CGFloat, alpha: Double) {
    guard alpha > 0.001 else { return }
    let attr = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color.withAlphaComponent(color.alphaComponent * alpha)])
    let size = attr.size()
    attr.draw(at: CGPoint(x: centerX - size.width / 2, y: y))
}

/// Title + subtitle that rise in and fade out.
func caption(_ title: String, _ subtitle: String?, t: Double, start: Double, end: Double, y: CGFloat = 820) {
    let a = window(t, start, end, fade: 0.45)
    guard a > 0 else { return }
    let rise = CGFloat(1 - easeOut((t - start) / 0.6)) * 26
    text(title, font: rounded(68, .heavy), color: .white, centerX: CGFloat(W) / 2, y: y + rise, alpha: a)
    if let subtitle {
        text(subtitle, font: .systemFont(ofSize: 30, weight: .medium), color: NSColor(white: 0.62, alpha: 1), centerX: CGFloat(W) / 2, y: y + 92 + rise, alpha: a)
    }
}

func wordmark(centerY: CGFloat, size: CGFloat, alpha: Double) {
    let open = NSAttributedString(string: "Open", attributes: [.font: rounded(size, .heavy), .foregroundColor: NSColor.white.withAlphaComponent(alpha)])
    let notchi = NSAttributedString(string: "Notchi", attributes: [.font: rounded(size, .heavy), .foregroundColor: NSColor(white: 0.56, alpha: alpha)])
    let total = open.size().width + notchi.size().width
    let y = centerY - open.size().height / 2
    open.draw(at: CGPoint(x: (CGFloat(W) - total) / 2, y: y))
    notchi.draw(at: CGPoint(x: (CGFloat(W) - total) / 2 + open.size().width, y: y))
}

// MARK: - Frame

func background(_ t: Double) {
    NSGradient(colors: [NSColor(white: 0.13, alpha: 1), NSColor(white: 0.035, alpha: 1)])!.draw(in: CGRect(x: 0, y: 0, width: W, height: H), angle: 90)
    // Soft light from the notch, drifting slowly and tinted like the demo song's artwork.
    let drift = CGFloat(sin(t * 0.4)) * 120
    let glow = NSGradient(colors: [NSColor(red: 0.55, green: 0.25, blue: 0.75, alpha: 0.28), NSColor(red: 0.55, green: 0.25, blue: 0.75, alpha: 0)])!
    glow.draw(fromCenter: CGPoint(x: CGFloat(W) / 2 + drift, y: 0), radius: 0, toCenter: CGPoint(x: CGFloat(W) / 2 + drift, y: 0), radius: 900, options: [])
    let warm = NSGradient(colors: [NSColor(red: 1, green: 0.5, blue: 0.25, alpha: 0.10), NSColor(red: 1, green: 0.5, blue: 0.25, alpha: 0)])!
    warm.draw(fromCenter: CGPoint(x: CGFloat(W) * 0.8 - drift, y: CGFloat(H)), radius: 0, toCenter: CGPoint(x: CGFloat(W) * 0.8 - drift, y: CGFloat(H)), radius: 800, options: [])
}

/// The open notch growing out of the closed one.
func expand(_ img: NSImage, t: Double, start: Double, length: Double = 0.7) {
    let p = (t - start) / length
    let full = shotRect(img)
    let sx = 0.32 + 0.68 * easeOutBack(p), sy = 0.15 + 0.85 * easeOutBack(p)
    let rect = CGRect(x: full.midX - full.width * sx / 2, y: 0, width: full.width * sx, height: full.height * sy)
    draw(img, in: rect, alpha: easeOut(p * 2.2))
}

/// A banner dropping out of the closed notch: revealed from the top down.
func drop(_ img: NSImage, t: Double, start: Double, alpha: Double) {
    let p = easeOutBack((t - start) / 0.55)
    let rect = shotRect(img)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: CGRect(x: 0, y: 0, width: CGFloat(W), height: 64 + (rect.height - 64) * CGFloat(p))).addClip()
    draw(img, in: rect, alpha: alpha)
    NSGraphicsContext.restoreGraphicsState()
}

/// Opening: the landing page in a browser window, scrolling from the hero to the photobox.
func website(_ t: Double, alpha: Double) {
    guard alpha > 0.001 else { return }
    let frame = CGRect(x: 200, y: 90 + CGFloat(1 - easeOut(t / 0.8)) * 40, width: 1520, height: 900)
    let bar: CGFloat = 52
    // Window with shadow.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.6 * alpha)
    shadow.shadowBlurRadius = 50
    shadow.shadowOffset = CGSize(width: 0, height: -20)
    shadow.set()
    NSColor(white: 0.14, alpha: alpha).setFill()
    NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16).fill()
    NSGraphicsContext.restoreGraphicsState()
    // Toolbar: traffic lights and the address.
    for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(ovalIn: CGRect(x: frame.minX + 22 + CGFloat(i) * 24, y: frame.minY + 19, width: 14, height: 14)).fill()
    }
    let field = CGRect(x: frame.midX - 260, y: frame.minY + 11, width: 520, height: 30)
    NSColor(white: 0.24, alpha: alpha).setFill()
    NSBezierPath(roundedRect: field, xRadius: 9, yRadius: 9).fill()
    text("🔒 opennotchi.vercel.app", font: .systemFont(ofSize: 17, weight: .medium), color: NSColor(white: 0.85, alpha: 1), centerX: field.midX, y: field.minY + 5, alpha: alpha)
    // The page, scrolled.
    let content = CGRect(x: frame.minX, y: frame.minY + bar, width: frame.width, height: frame.height - bar)
    let scale = content.width / landingPage.size.width
    let stops: [(Double, CGFloat)] = [(0, 0), (1.6, 0), (3.2, 880), (3.9, 880), (5.6, 2250), (7.5, 2250)]
    var offset: CGFloat = 0
    for i in 1..<stops.count where t >= stops[i - 1].0 {
        let (t0, y0) = stops[i - 1], (t1, y1) = stops[i]
        offset = y0 + (y1 - y0) * CGFloat(easeInOut((t - t0) / (t1 - t0)))
    }
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(roundedRect: content, xRadius: 16, yRadius: 16)
    clip.append(NSBezierPath(rect: CGRect(x: content.minX, y: content.minY, width: content.width, height: 20)))
    clip.addClip()
    let page = CGRect(x: content.minX, y: content.minY - offset, width: content.width, height: landingPage.size.height * scale)
    draw(landingPage, in: page, alpha: alpha)
    NSGraphicsContext.restoreGraphicsState()
}

func render(_ t: Double) {
    let main = t - mainStart
    if main >= 0 {
        renderMain(main)
    } else {
        background(0)
    }
    if t < webLength + 0.2 {
        website(t, alpha: min(easeOut(t / 0.5), 1 - easeInOut((t - (webLength - 0.6)) / 0.6)))
    }
}

func renderMain(_ t: Double) {
    background(t)
    let cx = CGFloat(W) / 2

    // 1. Intro: closed notch with music, wordmark.
    draw(closed, in: shotRect(closed), alpha: window(t, 0, 3.6, fade: 0.4))
    let introA = window(t, 0.3, 3.4, fade: 0.5)
    wordmark(centerY: 470 - CGFloat(easeOut((t - 0.3) / 0.8)) * 20, size: 150, alpha: introA)
    text("Your notch, but alive.", font: rounded(46, .semibold), color: NSColor(white: 0.82, alpha: 1), centerX: cx, y: 570, alpha: window(t, 0.8, 3.4, fade: 0.5))

    // 2. Music.
    if t >= 3.3 && t < 7.8 { expand(home, t: t, start: 3.3) }
    if t >= 7.8 && t < 8.2 { draw(home, in: shotRect(home), alpha: 1 - easeInOut((t - 7.8) / 0.4)) }
    caption("Your music, in the notch", "Spotify · Apple Music · YouTube, with live controls", t: t, start: 3.6, end: 7.8)

    // 3. Lyrics.
    draw(lyrics, in: shotRect(lyrics), alpha: window(t, 7.8, 11.2, fade: 0.4))
    caption("Synced lyrics", "Lines light up as they're sung", t: t, start: 8.0, end: 11.0)

    // 4. Themes: cycle through the looks.
    let themeStart = 11.2, themeStep = 0.85
    for (i, theme) in themes.enumerated() {
        let s = themeStart + Double(i) * themeStep
        let e = i == themes.count - 1 ? 15.6 : s + themeStep + 0.3
        draw(theme.1, in: shotRect(theme.1), alpha: window(t, s, e, fade: 0.3))
    }
    caption("Make it yours", "Themes that follow your music, borders, colors and shortcuts", t: t, start: 11.4, end: 15.5)
    let themeIndex = min(themes.count - 1, max(0, Int((t - themeStart) / themeStep)))
    if t > 11.4 && t < 15.5 {
        let a = window(t, 11.4, 15.5, fade: 0.3)
        let label = NSAttributedString(string: themes[themeIndex].0, attributes: [.font: rounded(26, .bold), .foregroundColor: NSColor.white.withAlphaComponent(a)])
        let size = label.size()
        let pill = CGRect(x: cx - size.width / 2 - 22, y: 470, width: size.width + 44, height: size.height + 18)
        NSColor.white.withAlphaComponent(0.12 * a).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        label.draw(at: CGPoint(x: pill.minX + 22, y: pill.minY + 9))
    }

    // 5. Markets.
    draw(markets, in: shotRect(markets), alpha: window(t, 15.6, 18.8, fade: 0.4))
    caption("Markets at a glance", "IDX & global stocks, crypto and currencies", t: t, start: 15.8, end: 18.6)

    // 6. Meeting reminder.
    if t >= 18.8 && t < 22.4 {
        draw(closed, in: shotRect(closed), alpha: window(t, 18.8, 19.6, fade: 0.25))
        if t >= 19.3 { drop(meeting, t: t, start: 19.3, alpha: window(t, 19.3, 22.4, fade: 0.25)) }
    }
    caption("Never miss a meeting", "A heads-up before every event, with one-click Join", t: t, start: 19.2, end: 22.3, y: 600)

    // 7. Prayer times.
    if t >= 22.4 && t < 25.8 {
        draw(closed, in: shotRect(closed), alpha: window(t, 22.4, 23.0, fade: 0.2))
        if t >= 22.7 { drop(prayer, t: t, start: 22.7, alpha: window(t, 22.7, 25.8, fade: 0.25)) }
    }
    caption("Prayer times, on time", "The next prayer in the header, a reminder at each one", t: t, start: 22.7, end: 25.7, y: 600)

    // 8. Mirror and the photobox picker.
    if t >= 25.8 && t < 26.8 { expand(mirror, t: t, start: 25.8) }
    draw(mirror, in: shotRect(mirror), alpha: t >= 26.8 ? window(t, 26.4, 27.6, fade: 0.4) : 0)
    draw(picker, in: shotRect(picker), alpha: window(t, 27.2, 29.6, fade: 0.4))
    caption("A photobooth in your notch", "Strike a pose, or just show a ✌️", t: t, start: 26.0, end: 29.5, y: 860)

    // 9. Strips fly in.
    if t >= 29.4 && t < 34.0 {
        let a = window(t, 29.4, 34.0, fade: 0.35)
        let count = stripImages.count
        let height: CGFloat = 520
        let gap: CGFloat = 34
        let widths = stripImages.map { height * $0.size.width / $0.size.height }
        var x = (CGFloat(W) - widths.reduce(0, +) - gap * CGFloat(count - 1)) / 2
        for (i, img) in stripImages.enumerated() {
            let p = easeOutBack((t - 29.5 - Double(i) * 0.09) / 0.7)
            let tilt = CGFloat([-6, 4, -3, 5, -4, 3][i]) * CGFloat(p)
            let y = 170 + (1 - CGFloat(p)) * 700
            guard let cg = NSGraphicsContext.current?.cgContext else { break }
            cg.saveGState()
            cg.translateBy(x: x + widths[i] / 2, y: y + height / 2)
            cg.rotate(by: tilt * .pi / 180)
            let rect = CGRect(x: -widths[i] / 2, y: -height / 2, width: widths[i], height: height)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.55 * a)
            shadow.shadowBlurRadius = 30
            shadow.shadowOffset = CGSize(width: 0, height: -12)
            shadow.set()
            draw(img, in: rect, alpha: a)
            NSGraphicsContext.restoreGraphicsState()
            cg.restoreGState()
            x += widths[i] + gap
        }
    }
    caption("18 trending frames", "Strip, Story, Post or Square · 1 to 6 photos", t: t, start: 29.8, end: 33.9, y: 820)

    // 10. Live activities.
    for (i, peek) in peeks.enumerated() {
        let s = 34.0 + Double(i) * 1.15
        draw(peek, in: shotRect(peek), alpha: window(t, s, s + 1.1, fade: 0.2))
    }
    caption("Live activities", "Charging, AirPods, volume & brightness, right beside the notch", t: t, start: 34.1, end: 37.4, y: 470)

    // 11. Outro.
    let end = duration - mainStart + 1
    let outro = window(t, 37.4, end, fade: 0.6)
    draw(closed, in: shotRect(closed), alpha: outro)
    wordmark(centerY: 440, size: 140, alpha: outro)
    text("Free & open source for macOS", font: rounded(44, .semibold), color: NSColor(white: 0.85, alpha: 1), centerX: cx, y: 540, alpha: window(t, 37.7, end, fade: 0.6))
    text("opennotchi.vercel.app", font: .monospacedSystemFont(ofSize: 34, weight: .medium), color: NSColor(white: 0.55, alpha: 1), centerX: cx, y: 630, alpha: window(t, 38.0, end, fade: 0.6))
}

// MARK: - Encoding

try? FileManager.default.removeItem(at: output)
let writer = try! AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W,
    AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: W,
    kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let frames = Int(duration * Double(FPS))
for frame in 0..<frames {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    guard let buffer else { fatalError("no buffer") }
    CVPixelBufferLockBaseAddress(buffer, [])
    let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer), width: W, height: H, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )!
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    autoreleasepool { render(Double(frame) / Double(FPS)) }
    NSGraphicsContext.restoreGraphicsState()
    CVPixelBufferUnlockBaseAddress(buffer, [])
    adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(FPS)))
    if frame % 300 == 0 { print("frame \(frame)/\(frames)") }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? "wrote \(output.path)" : "failed: \(String(describing: writer.error))")
