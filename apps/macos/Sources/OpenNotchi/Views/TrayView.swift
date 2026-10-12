import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct TrayView: View {
    @EnvironmentObject private var tray: TrayStore

    var body: some View {
        HStack(spacing: 14) {
            AirDropDropZone()
                .frame(width: 130)

            if tray.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 26))
                    Text("Drop files here to keep them handy")
                        .font(.system(size: 13, weight: .medium))
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
                    }
                    HStack {
                        Button("AirDrop all") { AirDropService.send(tray.items) }
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

private struct AirDropDropZone: View {
    @EnvironmentObject private var airDrop: AirDropService
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                switch airDrop.state {
                case .sending(_, let progress?):
                    AirDropProgressRing(progress: progress, lineWidth: 4)
                        .frame(width: 40, height: 40)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                case .choosing, .sending(_, nil):
                    ProgressView().controlSize(.small)
                        .frame(width: 40, height: 40)
                case .sent:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.orange)
                case .idle:
                    Image(systemName: "airplayaudio")
                        .symbolVariant(.circle.fill)
                        .font(.system(size: 30))
                        .foregroundStyle(.blue)
                }
            }
            .frame(height: 40)
            Text("AirDrop")
                .font(.system(size: 13, weight: .semibold))
            Text(statusText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: airDrop.state)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.blue.opacity(isTargeted ? 0.3 : 0.12))
        )
        .scaleEffect(isTargeted ? 1.04 : 1)
        .animation(.spring(response: 0.3), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            TrayStore.loadFileURLs(from: providers) { AirDropService.send($0) }
        }
    }

    private var statusText: String {
        switch airDrop.state {
        case .idle: return "Drop to send"
        case .choosing: return "Pick a device…"
        case .sending(let count, _): return count == 1 ? "Sending…" : "Sending \(count) files…"
        case .sent(let count): return count == 1 ? "Sent" : "Sent \(count) files"
        case .failed: return "Couldn't send"
        }
    }
}

/// Circular progress used by the AirDrop zone and the live activity.
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

private struct TrayItemView: View {
    @EnvironmentObject private var tray: TrayStore
    let url: URL
    @State private var hovering = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                }
            }
            .frame(width: 48, height: 48)
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
                        .font(.system(size: 14))
                        .foregroundStyle(.white, .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("AirDrop") { AirDropService.send([url]) }
            Divider()
            Button("Remove from Tray") { tray.remove(url) }
        }
        .help(url.path)
    }

    /// Quick Look preview of the file (photos, PDFs, videos…), or nil to fall back to the icon.
    static func thumbnail(for url: URL) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 96, height: 96), scale: 2, representationTypes: .thumbnail)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
