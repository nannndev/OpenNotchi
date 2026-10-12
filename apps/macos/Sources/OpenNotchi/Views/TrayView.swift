import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct TrayView: View {
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var vision: VisionService

    var body: some View {
        HStack(spacing: 14) {
            // Left Action Zones: AirDrop & Instant OCR
            VStack(spacing: 8) {
                AirDropDropZone()
                VisionOCRDropZone()
            }
            .frame(width: 130)

            // Right Files Parking Area
            if tray.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 26))
                    Text("Drop files here to keep them handy")
                        .font(.system(size: 13, weight: .medium))
                    Text("Or drop an image on Instant OCR to copy text")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(dashedBox)
            } else {
                VStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tray.items, id: \.self) { url in
                                TrayItemView(url: url)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                    }

                    HStack {
                        Button("AirDrop all") { AirDropService.send(tray.items) }
                        Spacer()
                        if let notification = vision.statusNotification {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                Text(notification)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.indigo)
                            .transition(.opacity)
                        }
                        Spacer()
                        Button("Clear") { tray.clear() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var dashedBox: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(.white.opacity(0.2))
    }
}

// MARK: - AirDrop Drop Zone

private struct AirDropDropZone: View {
    @EnvironmentObject private var airDrop: AirDropService
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                switch airDrop.state {
                case .sending(_, let progress?):
                    AirDropProgressRing(progress: progress, lineWidth: 3)
                        .frame(width: 24, height: 24)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                case .choosing, .sending(_, nil):
                    ProgressView().controlSize(.mini)
                        .frame(width: 24, height: 24)
                case .sent:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                case .idle:
                    Image(systemName: "airplayaudio")
                        .symbolVariant(.circle.fill)
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
            }
            .frame(height: 24)

            Text("AirDrop")
                .font(.system(size: 11, weight: .semibold))

            Text(statusText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(isTargeted ? 0.35 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.blue : .clear, lineWidth: 1.5)
        )
        .scaleEffect(isTargeted ? 1.03 : 1)
        .animation(.spring(response: 0.25), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            TrayStore.loadFileURLs(from: providers) { AirDropService.send($0) }
        }
    }

    private var statusText: String {
        switch airDrop.state {
        case .idle: return "Drop to send"
        case .choosing: return "Pick device…"
        case .sending(let count, _): return count == 1 ? "Sending…" : "Sending \(count)…"
        case .sent: return "Sent"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Vision OCR Drop Zone

private struct VisionOCRDropZone: View {
    @EnvironmentObject private var vision: VisionService
    @EnvironmentObject private var tray: TrayStore
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if vision.isProcessing {
                    ProgressView().controlSize(.mini)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isTargeted ? .indigo : .purple)
                }
            }
            .frame(height: 24)

            Text("Instant OCR")
                .font(.system(size: 11, weight: .semibold))

            Text(vision.isProcessing ? "Reading text…" : "Drop image to copy")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.purple.opacity(isTargeted ? 0.35 : 0.12), Color.indigo.opacity(isTargeted ? 0.4 : 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.purple : .clear, lineWidth: 1.5)
        )
        .scaleEffect(isTargeted ? 1.03 : 1)
        .animation(.spring(response: 0.25), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            TrayStore.loadFileURLs(from: providers) { urls in
                if let first = urls.first {
                    vision.recognizeText(from: first)
                    tray.add(urls)
                }
            }
        }
    }
}

// MARK: - Progress Ring

struct AirDropProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Tray Item View

private struct TrayItemView: View {
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var vision: VisionService
    let url: URL
    @State private var hovering = false
    @State private var thumbnail: NSImage?

    private var isImageOrDoc: Bool {
        vision.isImageOrPDF(url)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                    }
                }
                .frame(width: 48, height: 48)

                // Quick OCR button on hover
                if hovering && isImageOrDoc {
                    Button {
                        vision.recognizeText(from: url)
                    } label: {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Circle().fill(Color.indigo.opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                    .help("Copy text from this image (OCR)")
                    .transition(.scale)
                }
            }
            .task(id: url) { thumbnail = await Self.thumbnail(for: url) }

            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hovering ? 0.1 : 0)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { tray.remove(url) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white, .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("AirDrop") { AirDropService.send([url]) }

            if isImageOrDoc {
                Divider()
                Button("🪄 Copy Text (Vision OCR)") {
                    vision.recognizeText(from: url)
                }
                Menu("⚡ Convert Image") {
                    Button("To WebP") {
                        if let newURL = vision.convertImage(from: url, to: .webp) {
                            tray.add([newURL])
                        }
                    }
                    Button("To PNG") {
                        if let newURL = vision.convertImage(from: url, to: .png) {
                            tray.add([newURL])
                        }
                    }
                    Button("To JPEG") {
                        if let newURL = vision.convertImage(from: url, to: .jpeg) {
                            tray.add([newURL])
                        }
                    }
                }
            }

            Divider()
            Button("Remove from Tray") { tray.remove(url) }
        }
        .help(url.path)
    }

    static func thumbnail(for url: URL) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 96, height: 96), scale: 2, representationTypes: .thumbnail)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
