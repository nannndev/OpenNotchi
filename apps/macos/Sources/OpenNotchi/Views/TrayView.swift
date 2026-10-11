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
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplayaudio")
                .symbolVariant(.circle.fill)
                .font(.system(size: 30))
                .foregroundStyle(.blue)
            Text("AirDrop")
                .font(.system(size: 13, weight: .semibold))
            Text("Drop to send")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
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
}

private struct TrayItemView: View {
    @EnvironmentObject private var tray: TrayStore
    let url: URL
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 48, height: 48)
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
}
