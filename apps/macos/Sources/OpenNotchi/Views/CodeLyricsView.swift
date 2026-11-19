import SwiftUI

// MARK: - Code Lyrics Syntax & Live Typing Engine

enum CodeLyricsStyle {
    enum TokenRole {
        case keyword
        case typeName
        case function
        case identifier
        case attribute
        case op
        case punctuation
        case quote
    }

    struct CodeToken {
        let text: String
        let role: TokenRole
    }

    struct CodeLineTemplate {
        let prefix: [CodeToken]
        let suffix: [CodeToken]
    }

    /// Formats artist & title into a pseudo source-code path, e.g. `hindia/everything_u_are.swift`.
    static func fileSlug(title: String, artist: String) -> String {
        let a = slugPart(artist, fallback: "track")
        let t = slugPart(title, fallback: "lyrics")
        return "\(a)/\(t).swift"
    }

    private static func slugPart(_ raw: String, fallback: String) -> String {
        let lower = raw.lowercased()
        var out = ""
        var prevUnderscore = false
        for ch in lower.unicodeScalars {
            if CharacterSet.alphanumerics.contains(ch) {
                out.unicodeScalars.append(ch)
                prevUnderscore = false
            } else if !prevUnderscore && !out.isEmpty {
                out.append("_")
                prevUnderscore = true
            }
            if out.count >= 20 { break }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Deterministically picks a varied, authentic source-code statement template for each lyric line.
    static func template(for index: Int, text: String, compact: Bool = false) -> CodeLineTemplate {
        let ln = String(format: "%02d", index + 1)
        let selector = abs(index &* 3 &+ text.count) % (compact ? 10 : 14)

        if compact {
            switch selector {
            case 0:
                return CodeLineTemplate(
                    prefix: [.init(text: "let ", role: .keyword), .init(text: "l\(ln)", role: .identifier), .init(text: " = ", role: .op), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ";", role: .punctuation)]
                )
            case 1:
                return CodeLineTemplate(
                    prefix: [.init(text: "await ", role: .keyword), .init(text: "sing", role: .function), .init(text: "(", role: .punctuation), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
                )
            case 2:
                return CodeLineTemplate(
                    prefix: [.init(text: "lyrics", role: .identifier), .init(text: ".", role: .punctuation), .init(text: "push", role: .function), .init(text: "(", role: .punctuation), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ")", role: .punctuation)]
                )
            case 3:
                return CodeLineTemplate(
                    prefix: [.init(text: "return ", role: .keyword), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ";", role: .punctuation)]
                )
            case 4:
                return CodeLineTemplate(
                    prefix: [.init(text: "const ", role: .keyword), .init(text: "v", role: .identifier), .init(text: " = ", role: .op), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ";", role: .punctuation)]
                )
            case 5:
                return CodeLineTemplate(
                    prefix: [.init(text: "Heart", role: .typeName), .init(text: ".", role: .punctuation), .init(text: "echo", role: .function), .init(text: "(", role: .punctuation), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ")", role: .punctuation)]
                )
            case 6:
                return CodeLineTemplate(
                    prefix: [.init(text: "@Live ", role: .attribute), .init(text: "var ", role: .keyword), .init(text: "s", role: .identifier), .init(text: " = ", role: .op), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote)]
                )
            case 7:
                return CodeLineTemplate(
                    prefix: [.init(text: "yield ", role: .keyword), .init(text: "-> ", role: .op), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote)]
                )
            case 8:
                return CodeLineTemplate(
                    prefix: [.init(text: "Pulse", role: .typeName), .init(text: "::", role: .op), .init(text: "emit", role: .function), .init(text: "(", role: .punctuation), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
                )
            default:
                return CodeLineTemplate(
                    prefix: [.init(text: "log", role: .function), .init(text: "(", role: .punctuation), .init(text: "\"", role: .quote)],
                    suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
                )
            }
        }

        switch selector {
        case 0:
            // let line_01 = "...";
            return CodeLineTemplate(
                prefix: [
                    .init(text: "let ", role: .keyword),
                    .init(text: "line_\(ln)", role: .identifier),
                    .init(text: " = ", role: .op),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ";", role: .punctuation)]
            )
        case 1:
            // await stream.emit("...");
            return CodeLineTemplate(
                prefix: [
                    .init(text: "await ", role: .keyword),
                    .init(text: "stream", role: .identifier),
                    .init(text: ".", role: .punctuation),
                    .init(text: "emit", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
            )
        case 2:
            // lyrics.push("...");
            return CodeLineTemplate(
                prefix: [
                    .init(text: "lyrics", role: .identifier),
                    .init(text: ".", role: .punctuation),
                    .init(text: "push", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
            )
        case 3:
            // return Heart.echo("...");
            return CodeLineTemplate(
                prefix: [
                    .init(text: "return ", role: .keyword),
                    .init(text: "Heart", role: .typeName),
                    .init(text: ".", role: .punctuation),
                    .init(text: "echo", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
            )
        case 4:
            // const verse: String = "...";
            return CodeLineTemplate(
                prefix: [
                    .init(text: "const ", role: .keyword),
                    .init(text: "verse", role: .identifier),
                    .init(text: ": ", role: .op),
                    .init(text: "String", role: .typeName),
                    .init(text: " = ", role: .op),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ";", role: .punctuation)]
            )
        case 5:
            // if playing { sing("...") }
            return CodeLineTemplate(
                prefix: [
                    .init(text: "if ", role: .keyword),
                    .init(text: "playing ", role: .identifier),
                    .init(text: "{ ", role: .punctuation),
                    .init(text: "sing", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ") }", role: .punctuation)]
            )
        case 6:
            // memory.append(note: "...")
            return CodeLineTemplate(
                prefix: [
                    .init(text: "memory", role: .identifier),
                    .init(text: ".", role: .punctuation),
                    .init(text: "append", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "note", role: .identifier),
                    .init(text: ": ", role: .op),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ")", role: .punctuation)]
            )
        case 7:
            // @Live var chorus = "..."
            return CodeLineTemplate(
                prefix: [
                    .init(text: "@Live ", role: .attribute),
                    .init(text: "var ", role: .keyword),
                    .init(text: "chorus", role: .identifier),
                    .init(text: " = ", role: .op),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote)]
            )
        case 8:
            // console.log("...");
            return CodeLineTemplate(
                prefix: [
                    .init(text: "console", role: .typeName),
                    .init(text: ".", role: .punctuation),
                    .init(text: "log", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
            )
        case 9:
            // yield -> Verse("...")
            return CodeLineTemplate(
                prefix: [
                    .init(text: "yield ", role: .keyword),
                    .init(text: "-> ", role: .op),
                    .init(text: "Verse", role: .typeName),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ")", role: .punctuation)]
            )
        case 10:
            // Pulse::dispatch("...");
            return CodeLineTemplate(
                prefix: [
                    .init(text: "Pulse", role: .typeName),
                    .init(text: "::", role: .op),
                    .init(text: "dispatch", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ");", role: .punctuation)]
            )
        case 11:
            // guard voice else { return "..." }
            return CodeLineTemplate(
                prefix: [
                    .init(text: "guard ", role: .keyword),
                    .init(text: "voice ", role: .identifier),
                    .init(text: "else ", role: .keyword),
                    .init(text: "{ ", role: .punctuation),
                    .init(text: "return ", role: .keyword),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: " }", role: .punctuation)]
            )
        case 12:
            // track.render(line: "...")
            return CodeLineTemplate(
                prefix: [
                    .init(text: "track", role: .identifier),
                    .init(text: ".", role: .punctuation),
                    .init(text: "render", role: .function),
                    .init(text: "(", role: .punctuation),
                    .init(text: "line", role: .identifier),
                    .init(text: ": ", role: .op),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ")", role: .punctuation)]
            )
        default:
            // export default "...";
            return CodeLineTemplate(
                prefix: [
                    .init(text: "export ", role: .keyword),
                    .init(text: "default ", role: .keyword),
                    .init(text: "\"", role: .quote),
                ],
                suffix: [.init(text: "\"", role: .quote), .init(text: ";", role: .punctuation)]
            )
        }
    }

    /// Splits a lyric line at the current playback `position` into:
    /// - `typed`: characters already sung/typed
    /// - `ghost`: Copilot-style dimmed inline completion for remaining characters
    /// - `column`: 1-based IDE cursor column
    /// - `isComplete`: whether the full line has finished typing
    static func typingSplit(
        text: String,
        lineStart: Double,
        nextStart: Double?,
        position: Double
    ) -> (typed: String, ghost: String, column: Int, isComplete: Bool) {
        guard !text.isEmpty else {
            return ("", "", 1, true)
        }
        let rawSpan = max(0.6, (nextStart ?? (lineStart + 4.0)) - lineStart)
        let span = max(0.85, min(rawSpan, 6.5) * 0.78)
        let elapsed = position - lineStart
        let progress = min(1.0, max(0.0, elapsed / span))
        let total = text.count
        let count = min(total, max(0, Int((Double(total) * progress).rounded())))
        let typed = String(text.prefix(count))
        let ghost = String(text.dropFirst(count))
        return (typed, ghost, count + 1, count >= total)
    }

    /// Cursor blink phase (true = visible).
    static func cursorVisible(at date: Date, isPlaying: Bool) -> Bool {
        if !isPlaying {
            return Int(date.timeIntervalSinceReferenceDate * 1.6) % 2 == 0
        }
        return Int(date.timeIntervalSinceReferenceDate * 2.4) % 2 == 0
    }

    // MARK: - Syntax Palette (One Dark / Tokyo Night inspired)

    static let workspaceBg = Color(red: 0.055, green: 0.067, blue: 0.094)
    static let sidebarBg = Color(red: 0.043, green: 0.051, blue: 0.074)
    static let headerBg = Color(red: 0.072, green: 0.086, blue: 0.120)
    static let activeLineBg = Color(red: 0.12, green: 0.15, blue: 0.22)

    static let keywordColor = Color(red: 0.78, green: 0.57, blue: 0.92)     // purple
    static let typeColor = Color(red: 0.90, green: 0.75, blue: 0.48)        // warm gold
    static let functionColor = Color(red: 0.38, green: 0.69, blue: 0.94)    // sky blue
    static let identifierColor = Color(red: 0.34, green: 0.71, blue: 0.76)  // cyan
    static let attributeColor = Color(red: 0.85, green: 0.58, blue: 0.38)   // coral/orange
    static let operatorColor = Color(red: 0.54, green: 0.87, blue: 1.00)    // light cyan
    static let stringQuoteColor = Color(red: 0.60, green: 0.76, blue: 0.47) // soft green
    static let typedTextColor = Color(red: 0.95, green: 0.97, blue: 1.00)   // crisp white
    static let pastStringColor = Color(red: 0.66, green: 0.82, blue: 0.68)  // muted green
    static let commentColor = Color(red: 0.48, green: 0.56, blue: 0.68)     // slate
    static let translationCommentColor = Color(red: 0.95, green: 0.79, blue: 0.45) // amber
    static let punctColor = Color.white.opacity(0.50)

    static func color(for role: TokenRole) -> Color {
        switch role {
        case .keyword: return keywordColor
        case .typeName: return typeColor
        case .function: return functionColor
        case .identifier: return identifierColor
        case .attribute: return attributeColor
        case .op: return operatorColor
        case .punctuation: return punctColor
        case .quote: return stringQuoteColor
        }
    }

    static func renderTokens(_ tokens: [CodeToken], fontSize: CGFloat, weight: Font.Weight, opacity: Double) -> Text {
        tokens.reduce(Text("")) { acc, tok in
            let w: Font.Weight = (tok.role == .keyword || tok.role == .attribute) ? .semibold : weight
            return acc + Text(tok.text)
                .font(.system(size: fontSize, weight: w, design: .monospaced))
                .foregroundColor(color(for: tok.role).opacity(opacity))
        }
    }

    static func activeCodeText(
        template: CodeLineTemplate,
        typed: String,
        ghost: String,
        fontSize: CGFloat,
        cursorOn: Bool,
        accent: Color
    ) -> Text {
        let prefix = renderTokens(template.prefix, fontSize: fontSize, weight: .semibold, opacity: 0.92)
        let body = Text(typed)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundColor(typedTextColor)
        let cursor = Text("▋")
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundColor(cursorOn ? accent : accent.opacity(0.14))
        let ghostPart = Text(ghost)
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.28))
        let suffix = renderTokens(template.suffix, fontSize: fontSize, weight: .regular, opacity: 0.85)

        return prefix + body + cursor + ghostPart + suffix
    }

    static func idleCodeText(
        template: CodeLineTemplate,
        text: String,
        isPast: Bool,
        fontSize: CGFloat
    ) -> Text {
        let tokenAlpha = isPast ? 0.52 : 0.32
        let strAlpha = isPast ? 0.68 : 0.36
        let prefix = renderTokens(template.prefix, fontSize: fontSize, weight: .medium, opacity: tokenAlpha)
        let body = Text(text)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundColor(isPast ? pastStringColor.opacity(strAlpha) : Color.white.opacity(strAlpha))
        let suffix = renderTokens(template.suffix, fontSize: fontSize, weight: .regular, opacity: tokenAlpha)

        return prefix + body + suffix
    }

    static func formatTimestamp(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - 1. Floating On-Top Desktop Code Lyrics Overlay (Clean / No IDE Box Background)

struct DesktopCodeLyricsView: View {
    let hovering: Bool
    let boxSize: CGSize

    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let resolved = ResolvedAccent.resolve(settings.accent, palette: media.palette)
        let accentColor = resolved.isNeutral ? Color(red: 0.38, green: 0.72, blue: 1.0) : resolved.color

        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let info = media.info
            let pos = info?.position(at: context.date) ?? 0
            let idx: Int? = info.flatMap { i in
                i.isPlaying ? lyrics.currentIndex(at: pos) : nil
            }
            let curLine: LyricLine? = idx.flatMap { i in
                lyrics.lines.indices.contains(i) ? lyrics.lines[i] : nil
            }
            let nextLine: LyricLine? = idx.flatMap { i in
                lyrics.lines.indices.contains(i + 1) ? lyrics.lines[i + 1] : nil
            }
            let scale = max(0.75, min(2.4, boxSize.height / 82.0))
            let codeFont = round(16.5 * scale)
            let subFont = round(12.0 * scale)
            let cursorOn = CodeLyricsStyle.cursorVisible(at: context.date, isPlaying: info?.isPlaying ?? false)

            VStack(alignment: .leading, spacing: max(4, round(5 * scale))) {
                if let idx, let curLine {
                    let displayText = curLine.text.isEmpty ? "♪" : curLine.text
                    let split = CodeLyricsStyle.typingSplit(
                        text: displayText,
                        lineStart: curLine.time,
                        nextStart: nextLine?.time,
                        position: pos
                    )
                    let tmpl = CodeLyricsStyle.template(for: idx, text: displayText, compact: false)
                    let translated: String? = {
                        guard settings.lyricsTranslate, !curLine.text.isEmpty else { return nil }
                        return lyrics.translations[curLine.text]
                    }()

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(format: "%02d", idx + 1))
                            .font(.system(size: codeFont, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.85))
                            .frame(minWidth: max(24, round(codeFont * 1.5)), alignment: .trailing)

                        CodeLyricsStyle.activeCodeText(
                            template: tmpl,
                            typed: split.typed,
                            ghost: split.ghost,
                            fontSize: codeFont,
                            cursorOn: cursorOn,
                            accent: accentColor
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    }

                    if let translated, !translated.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("  ")
                                .font(.system(size: subFont, design: .monospaced))
                                .frame(width: max(20, round(22 * scale)), alignment: .trailing)
                            Text("// ↳ \(translated)")
                                .font(.system(size: subFont, weight: .semibold, design: .monospaced))
                                .foregroundStyle(CodeLyricsStyle.translationCommentColor.opacity(0.95))
                                .lineLimit(1)
                        }
                    } else if settings.lyricsOverlayNextLine, let nextText = nextLine?.text, !nextText.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(String(format: "%02d", idx + 2))
                                .font(.system(size: subFont, weight: .regular, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(width: max(20, round(22 * scale)), alignment: .trailing)
                            Text("// next: \"\(nextText)\"")
                                .font(.system(size: subFont, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                } else if hovering {
                    Text(info == nil ? "// awaiting playback…" : "// syncing lyrics stream…")
                        .font(.system(size: round(13 * scale), weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .shadow(color: .black.opacity(0.85), radius: 5, y: 1)
            .padding(.horizontal, max(14, round(16 * scale)))
            .padding(.vertical, max(8, round(10 * scale)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background {
                if idx != nil || hovering {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black.opacity(max(settings.lyricsOverlayOpacity, hovering ? 0.35 : 0)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(hovering ? 0.22 : 0), lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - 2. Full-Screen Floating Code Lyrics (No Box Background, Pure Syntax Over Backdrop)

struct FullScreenCodeLyricsView: View {
    let info: NowPlayingInfo
    let tint: Color
    let textScale: Double

    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let pos = info.position(at: context.date)
            let activeIdx = lyrics.currentIndex(at: pos)
            let curLine: LyricLine? = activeIdx.flatMap { i in
                lyrics.lines.indices.contains(i) ? lyrics.lines[i] : nil
            }
            let nextLine: LyricLine? = activeIdx.flatMap { i in
                lyrics.lines.indices.contains(i + 1) ? lyrics.lines[i + 1] : nil
            }
            let activeSplit = CodeLyricsStyle.typingSplit(
                text: curLine?.text ?? "",
                lineStart: curLine?.time ?? pos,
                nextStart: nextLine?.time,
                position: pos
            )
            let cursorOn = CodeLyricsStyle.cursorVisible(at: context.date, isPlaying: info.isPlaying)
            let codeFontSize = round(22.0 * textScale)
            let commentFontSize = round(16.0 * textScale)
            let gutterWidth = round(codeFontSize * 1.65)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Color.clear.frame(height: 150)

                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { idx, line in
                            let isCurrent = idx == activeIdx
                            let isPast = (activeIdx ?? -1) > idx
                            let displayText = line.text.isEmpty ? "♪" : line.text
                            let tmpl = CodeLyricsStyle.template(for: idx, text: displayText, compact: false)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(String(format: "%02d", idx + 1))
                                        .font(.system(size: codeFontSize, weight: isCurrent ? .bold : .regular, design: .monospaced))
                                        .foregroundStyle(isCurrent ? tint : .white.opacity(isPast ? 0.34 : 0.22))
                                        .frame(width: gutterWidth, alignment: .trailing)

                                    if isCurrent {
                                        CodeLyricsStyle.activeCodeText(
                                            template: tmpl,
                                            typed: activeSplit.typed,
                                            ghost: activeSplit.ghost,
                                            fontSize: codeFontSize,
                                            cursorOn: cursorOn,
                                            accent: tint
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        CodeLyricsStyle.idleCodeText(
                                            template: tmpl,
                                            text: displayText,
                                            isPast: isPast,
                                            fontSize: codeFontSize
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                if settings.lyricsTranslate,
                                   let translated = lyrics.translations[line.text],
                                   !translated.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Spacer().frame(width: 28)
                                        Text("// ↳ \(translated)")
                                            .font(.system(size: commentFontSize, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(
                                                CodeLyricsStyle.translationCommentColor
                                                    .opacity(isCurrent ? 0.95 : (isPast ? 0.45 : 0.28))
                                            )
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.leading, isCurrent ? 12 : 4)
                            .padding(.vertical, isCurrent ? 6 : 2)
                            .overlay(alignment: .leading) {
                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(tint)
                                        .frame(width: 3)
                                        .padding(.vertical, 4)
                                }
                            }
                            .shadow(color: .black.opacity(0.65), radius: 8, y: 2)
                            .opacity(isCurrent ? 1.0 : (isPast ? 0.55 : 0.48))
                            .scaleEffect(isCurrent ? 1.0 : 0.98, anchor: .leading)
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCurrent)
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                media.seek(to: line.time)
                            }
                        }

                        Color.clear.frame(height: 240)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.16),
                            .init(color: .black, location: 0.78),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: activeIdx) { _, target in
                    guard let target, lyrics.lines.indices.contains(target) else { return }
                    let id = lyrics.lines[target].id
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) {
                        proxy.scrollTo(id, anchor: UnitPoint(x: 0, y: 0.38))
                    }
                }
                .onAppear {
                    if let target = activeIdx, lyrics.lines.indices.contains(target) {
                        proxy.scrollTo(lyrics.lines[target].id, anchor: UnitPoint(x: 0, y: 0.38))
                    }
                }
            }
        }
    }
}

// MARK: - 3. Compact Open-Notch Home Code Lyrics (Clean / No Box Background, Varied Syntax)

struct NotchCodeLyricsView: View {
    let info: NowPlayingInfo

    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent

    var body: some View {
        let accentColor = accent.isNeutral ? Color(red: 0.38, green: 0.72, blue: 1.0) : accent.color

        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let pos = info.position(at: context.date)
            let activeIdx = lyrics.currentIndex(at: pos)
            let curLine: LyricLine? = activeIdx.flatMap { i in
                lyrics.lines.indices.contains(i) ? lyrics.lines[i] : nil
            }
            let nextLine: LyricLine? = activeIdx.flatMap { i in
                lyrics.lines.indices.contains(i + 1) ? lyrics.lines[i + 1] : nil
            }
            let split = CodeLyricsStyle.typingSplit(
                text: curLine?.text ?? "",
                lineStart: curLine?.time ?? pos,
                nextStart: nextLine?.time,
                position: pos
            )
            let cursorOn = CodeLyricsStyle.cursorVisible(at: context.date, isPlaying: info.isPlaying)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { idx, line in
                            let isCurrent = idx == activeIdx
                            let isPast = (activeIdx ?? -1) > idx
                            let displayText = line.text.isEmpty ? "♪" : line.text
                            let tmpl = CodeLyricsStyle.template(for: idx, text: displayText, compact: true)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(String(format: "%02d", idx + 1))
                                        .font(.system(size: 12.0, weight: isCurrent ? .bold : .regular, design: .monospaced))
                                        .foregroundStyle(isCurrent ? accentColor : .white.opacity(0.26))
                                        .frame(width: 22, alignment: .trailing)

                                    if isCurrent {
                                        CodeLyricsStyle.activeCodeText(
                                            template: tmpl,
                                            typed: split.typed,
                                            ghost: split.ghost,
                                            fontSize: 12.0,
                                            cursorOn: cursorOn,
                                            accent: accentColor
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        CodeLyricsStyle.idleCodeText(
                                            template: tmpl,
                                            text: displayText,
                                            isPast: isPast,
                                            fontSize: 12.0
                                        )
                                        .lineLimit(1)
                                    }
                                }

                                if isCurrent,
                                   settings.lyricsTranslate,
                                   let translated = lyrics.translations[line.text],
                                   !translated.isEmpty {
                                    Text("    // ↳ \(translated)")
                                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(CodeLyricsStyle.translationCommentColor.opacity(0.92))
                                }
                            }
                            .padding(.leading, isCurrent ? 6 : 2)
                            .padding(.vertical, isCurrent ? 3 : 0.5)
                            .overlay(alignment: .leading) {
                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(accentColor)
                                        .frame(width: 2)
                                        .padding(.vertical, 2)
                                }
                            }
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                media.seek(to: line.time)
                            }
                        }
                    }
                    .padding(.vertical, 52)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.22),
                            .init(color: .black, location: 0.78),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: activeIdx) { _, target in
                    guard let target, lyrics.lines.indices.contains(target) else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                        proxy.scrollTo(lyrics.lines[target].id, anchor: .center)
                    }
                }
                .onAppear {
                    if let target = activeIdx, lyrics.lines.indices.contains(target) {
                        proxy.scrollTo(lyrics.lines[target].id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - 4. Dedicated Full-Screen IDE Workspace CodeLyric Mode

struct FullWorkspaceCodeLyricsView: View {
    let info: NowPlayingInfo
    let tint: Color
    let size: CGSize
    let controlsVisible: Bool
    let onClose: () -> Void
    let onCapturePhoto: () -> Void

    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let sidebarWidth: CGFloat = size.width < 1200 ? 260 : 300
        let textScale = settings.nowPlayingScreenTextScale

        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let pos = info.position(at: context.date)
            let activeIdx = lyrics.currentIndex(at: pos)
            let curLine: LyricLine? = activeIdx.flatMap { i in
                lyrics.lines.indices.contains(i) ? lyrics.lines[i] : nil
            }
            let nextLine: LyricLine? = activeIdx.flatMap { i in
                lyrics.lines.indices.contains(i + 1) ? lyrics.lines[i + 1] : nil
            }
            let activeSplit = CodeLyricsStyle.typingSplit(
                text: curLine?.text ?? "",
                lineStart: curLine?.time ?? pos,
                nextStart: nextLine?.time,
                position: pos
            )
            let cursorOn = CodeLyricsStyle.cursorVisible(at: context.date, isPlaying: info.isPlaying)
            let slug = CodeLyricsStyle.fileSlug(title: info.title, artist: info.artist)
            let fileName = slug.split(separator: "/").last.map(String.init) ?? "lyrics.swift"

            VStack(spacing: 0) {
                // 1. Top IDE Titlebar
                workspaceTitleBar(slug: slug, date: context.date)

                Divider().background(Color.white.opacity(0.08))

                // 2. Main Split: Activity/Explorer Sidebar + Code Editor + Terminal
                HStack(spacing: 0) {
                    workspaceSidebar(
                        width: sidebarWidth,
                        fileName: fileName,
                        pos: pos,
                        activeIdx: activeIdx
                    )

                    Divider().background(Color.white.opacity(0.08))

                    VStack(spacing: 0) {
                        // Editor Tab Bar
                        editorTabBar(fileName: fileName, slug: slug)

                        Divider().background(Color.white.opacity(0.07))

                        // Main Code Buffer
                        workspaceEditorBuffer(
                            activeIdx: activeIdx,
                            activeSplit: activeSplit,
                            cursorOn: cursorOn,
                            textScale: textScale
                        )

                        Divider().background(Color.white.opacity(0.08))

                        // Compact Bottom Output / Terminal Panel
                        workspaceOutputPanel(pos: pos, activeIdx: activeIdx, curText: curLine?.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider().background(Color.white.opacity(0.10))

                // 3. Bottom IDE Status Bar
                workspaceStatusBar(activeIdx: activeIdx, column: activeSplit.column)
            }
            .frame(width: size.width, height: size.height)
            .background(CodeLyricsStyle.workspaceBg)
        }
    }

    private func workspaceTitleBar(slug: String, date: Date) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Button(action: onClose) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 11, height: 11)
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 11, height: 11)
            }

            Spacer()

            // Center Command Center Pill
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Text("OpenNotchi — \(slug)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            Spacer()

            HStack(spacing: 12) {
                if settings.nowPlayingScreenClock {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Button {
                    settings.lyricsCodeWorkspace = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Exit Workspace")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Switch back to floating code lyrics (K)")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(CodeLyricsStyle.headerBg)
    }

    private func workspaceSidebar(width: CGFloat, fileName: String, pos: Double, activeIdx: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Explorer header
            HStack {
                Text("EXPLORER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(1.2)
                Spacer()
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(info.isPlaying ? .green : .orange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // File tree
            VStack(alignment: .leading, spacing: 4) {
                sidebarTreeRow(icon: "chevron.down", name: "NOW-PLAYING", indent: 0, isFolder: true, active: false)
                sidebarTreeRow(icon: "swift", name: fileName, indent: 1, isFolder: false, active: true)
                sidebarTreeRow(icon: "doc.text", name: "synced.lrc", indent: 1, isFolder: false, active: false)
                sidebarTreeRow(icon: "waveform", name: "AudioStream.rs", indent: 1, isFolder: false, active: false)
                sidebarTreeRow(icon: "photo", name: "cover_art.png", indent: 1, isFolder: false, active: false)
                sidebarTreeRow(icon: "curlybraces", name: "metadata.json", indent: 1, isFolder: false, active: false)
            }
            .padding(.horizontal, 10)

            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 14)

            // Inspector: Album Cover & Now Playing Card
            VStack(alignment: .leading, spacing: 12) {
                Text("INSPECTOR · TRACK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(1.0)

                if let art = media.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: width - 36)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title.isEmpty ? "Unknown Track" : info.title)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("// \(info.artist.isEmpty ? "Unknown Artist" : info.artist)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(tint.opacity(0.9))
                        .lineLimit(1)
                }

                // Interactive Progress Scrubber
                VStack(spacing: 5) {
                    GeometryReader { geo in
                        let frac = info.duration > 0 ? min(1, max(0, pos / info.duration)) : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(tint).frame(width: geo.size.width * frac)
                        }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            guard info.duration > 0 else { return }
                            let p = max(0, min(1, value.location.x / max(1, geo.size.width)))
                            media.seek(to: p * info.duration)
                        })
                    }
                    .frame(height: 5)

                    HStack {
                        Text(CodeLyricsStyle.formatTimestamp(pos))
                        Spacer()
                        Text(CodeLyricsStyle.formatTimestamp(info.duration))
                    }
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                }

                // Transport Controls
                HStack(spacing: 18) {
                    Spacer()
                    sidebarIconBtn("backward.fill", size: 15) { media.previousTrack() }
                    sidebarIconBtn(info.isPlaying ? "pause.circle.fill" : "play.circle.fill", size: 30, color: tint) {
                        media.playPause()
                    }
                    sidebarIconBtn("forward.fill", size: 15) { media.nextTrack() }
                    Spacer()
                }
                .padding(.top, 2)

                // Quick actions row
                HStack(spacing: 10) {
                    sidebarChip("T", icon: "character.bubble", active: settings.lyricsTranslate, help: "Translate (T)") {
                        settings.lyricsTranslate.toggle()
                    }
                    sidebarChip("C", icon: "camera.fill", active: false, help: "Capture Photo (C)") {
                        onCapturePhoto()
                    }
                    sidebarChip("K", icon: "chevron.left.forwardslash.chevron.right", active: true, help: "Cycle Lyrics Mode (K)") {
                        settings.lyricsCodeMode = false
                        settings.lyricsCodeWorkspace = false
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Mini stats footer inside sidebar
            VStack(alignment: .leading, spacing: 3) {
                Text("lines: \(lyrics.lines.count) · synced")
                Text("cursor: line \((activeIdx ?? 0) + 1)")
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: width)
        .background(CodeLyricsStyle.sidebarBg)
    }

    private func sidebarTreeRow(icon: String, name: String, indent: Int, isFolder: Bool, active: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: isFolder ? .bold : .medium))
                .foregroundStyle(active ? tint : .white.opacity(isFolder ? 0.5 : 0.45))
                .frame(width: 14)
            Text(name)
                .font(.system(size: 11.5, weight: active ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(active ? .white : .white.opacity(isFolder ? 0.72 : 0.55))
                .lineLimit(1)
            Spacer()
        }
        .padding(.leading, CGFloat(indent) * 14 + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(active ? tint.opacity(0.16) : Color.clear)
        )
    }

    private func sidebarIconBtn(_ icon: String, size: CGFloat, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    private func sidebarChip(_ key: String, icon: String, active: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(key).font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(active ? tint : .white.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? tint.opacity(0.16) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func editorTabBar(fileName: String, slug: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // Active file tab
                HStack(spacing: 6) {
                    Image(systemName: "swift")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                    Text(fileName)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Circle().fill(tint).frame(width: 6, height: 6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(CodeLyricsStyle.workspaceBg)
                .overlay(alignment: .top) {
                    Rectangle().fill(tint).frame(height: 2)
                }

                // Inactive tab
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("synced.lrc")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                Spacer()
            }
            .background(CodeLyricsStyle.headerBg.opacity(0.8))

            // Breadcrumb bar
            HStack(spacing: 6) {
                Text("opennotchi")
                Text("›")
                Text("now_playing")
                Text("›")
                Text(slug)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.40))
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CodeLyricsStyle.workspaceBg)
        }
    }

    private func workspaceEditorBuffer(
        activeIdx: Int?,
        activeSplit: (typed: String, ghost: String, column: Int, isComplete: Bool),
        cursorOn: Bool,
        textScale: Double
    ) -> some View {
        let codeFontSize = round(18.5 * textScale)
        let commentFontSize = round(14.0 * textScale)
        let gutterWidth = round(codeFontSize * 1.65)

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer().frame(height: 36)

                    // JSDoc file header
                    VStack(alignment: .leading, spacing: 3) {
                        Text("/**")
                        Text(" * @track   \(info.title.isEmpty ? "Unknown" : info.title)")
                        Text(" * @artist  \(info.artist.isEmpty ? "Unknown" : info.artist)")
                        Text(" * @lines   \(lyrics.lines.count) synced statements")
                        Text(" */")
                    }
                    .font(.system(size: commentFontSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(CodeLyricsStyle.commentColor)
                    .padding(.horizontal, 26)
                    .padding(.bottom, 14)

                    if lyrics.state == .synced, !lyrics.lines.isEmpty {
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { idx, line in
                            let isCurrent = idx == activeIdx
                            let isPast = (activeIdx ?? -1) > idx
                            let displayText = line.text.isEmpty ? "♪" : line.text
                            let tmpl = CodeLyricsStyle.template(for: idx, text: displayText, compact: false)

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    HStack(spacing: 6) {
                                        Text(isCurrent ? "▸" : " ")
                                            .font(.system(size: codeFontSize, weight: .bold, design: .monospaced))
                                            .foregroundStyle(tint)
                                            .frame(width: round(codeFontSize * 0.7))
                                        Text(String(format: "%02d", idx + 1))
                                            .font(.system(size: codeFontSize, weight: isCurrent ? .bold : .regular, design: .monospaced))
                                            .foregroundStyle(isCurrent ? tint : .white.opacity(isPast ? 0.36 : 0.22))
                                            .frame(width: gutterWidth, alignment: .trailing)
                                    }

                                    if isCurrent {
                                        CodeLyricsStyle.activeCodeText(
                                            template: tmpl,
                                            typed: activeSplit.typed,
                                            ghost: activeSplit.ghost,
                                            fontSize: codeFontSize,
                                            cursorOn: cursorOn,
                                            accent: tint
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        CodeLyricsStyle.idleCodeText(
                                            template: tmpl,
                                            text: displayText,
                                            isPast: isPast,
                                            fontSize: codeFontSize
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer(minLength: 12)

                                    Text("// \(CodeLyricsStyle.formatTimestamp(line.time))")
                                        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                                        .foregroundStyle(CodeLyricsStyle.commentColor.opacity(isCurrent ? 0.85 : 0.35))
                                }

                                if settings.lyricsTranslate,
                                   let translated = lyrics.translations[line.text],
                                   !translated.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                                        Spacer().frame(width: 44)
                                        Text("// ↳ \(translated)")
                                            .font(.system(size: commentFontSize, weight: .medium, design: .monospaced))
                                            .foregroundStyle(
                                                CodeLyricsStyle.translationCommentColor
                                                    .opacity(isCurrent ? 0.95 : (isPast ? 0.48 : 0.30))
                                            )
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, isCurrent ? 10 : 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isCurrent ? CodeLyricsStyle.activeLineBg.opacity(0.92) : Color.clear)
                            )
                            .overlay(alignment: .leading) {
                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(tint)
                                        .frame(width: 3.5)
                                        .padding(.vertical, 4)
                                }
                            }
                            .padding(.horizontal, 10)
                            .animation(.easeOut(duration: 0.22), value: isCurrent)
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                media.seek(to: line.time)
                            }
                        }
                    } else if let plain = lyrics.plainText, !plain.isEmpty {
                        Text(plain)
                            .font(.system(size: codeFontSize, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 28)
                    } else {
                        Text("// \(lyrics.state == .loading ? "fetching synced lyrics…" : "instrumental or no synced lyrics")")
                            .font(.system(size: codeFontSize, weight: .medium, design: .monospaced))
                            .foregroundStyle(CodeLyricsStyle.commentColor)
                            .padding(.horizontal, 28)
                    }

                    Text("// ── EOF (\(CodeLyricsStyle.formatTimestamp(info.duration))) ──")
                        .font(.system(size: commentFontSize, weight: .regular, design: .monospaced))
                        .foregroundStyle(CodeLyricsStyle.commentColor.opacity(0.55))
                        .padding(.horizontal, 26)
                        .padding(.top, 16)

                    Spacer().frame(height: 160)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: activeIdx) { _, target in
                guard let target, lyrics.lines.indices.contains(target) else { return }
                let id = lyrics.lines[target].id
                withAnimation(.easeInOut(duration: 0.38)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onAppear {
                if let target = activeIdx, lyrics.lines.indices.contains(target) {
                    proxy.scrollTo(lyrics.lines[target].id, anchor: .center)
                }
            }
        }
        .background(CodeLyricsStyle.workspaceBg)
    }

    private func workspaceOutputPanel(pos: Double, activeIdx: Int?, curText: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Text("OUTPUT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)
                    .overlay(alignment: .bottom) { Rectangle().fill(tint).frame(height: 1.5) }
                Text("AUDIO STREAM")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Text("SHORTCUTS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Space play · ←/→ skip · T translate · K cycle mode · Esc close")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.38))
            }

            HStack(spacing: 8) {
                Text("[\(CodeLyricsStyle.formatTimestamp(pos)) / \(CodeLyricsStyle.formatTimestamp(info.duration))]")
                    .foregroundStyle(tint.opacity(0.9))
                Text(info.isPlaying ? "▶" : "⏸")
                    .foregroundStyle(info.isPlaying ? .green : .orange)
                Text(curText?.isEmpty == false ? "\"\(curText!)\"" : "\(info.title) — \(info.artist)")
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer()
            }
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(CodeLyricsStyle.sidebarBg)
    }

    private func workspaceStatusBar(activeIdx: Int?, column: Int) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text(info.isPlaying ? "INSERT" : "PAUSED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(tint))

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text("main*")
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Text("Ln \((activeIdx ?? 0) + 1)/\(max(1, lyrics.lines.count)), Col \(column)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            Text("Spaces: 4")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            Text("UTF-8")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            Text("IDE Workspace (K)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(CodeLyricsStyle.headerBg)
    }
}
