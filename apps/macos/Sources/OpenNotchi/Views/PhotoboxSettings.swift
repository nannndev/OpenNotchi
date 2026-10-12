import SwiftUI

/// Photobox settings with live previews: every style as a thumbnail, and a close-up of the chosen one.
struct PhotoboxSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @ObservedObject private var cache = StripPreviews.shared
    private var previews: [StripStyle: NSImage] { cache.images }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(StripStyle.allCases) { style in
                    thumbnail(style)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }

        if let image = previews[settings.stripStyle] {
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.stripStyle.displayName).font(.headline)
                    // The bottom of the strip, large enough to read the text.
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 300, height: 190, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.1)))
                    Text("Preview with sample photos. Your strip is 1200 px wide, made for stories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        TextField("Text on the strip", text: $settings.stripCaption, prompt: Text("Style's own title"))
            .onChange(of: settings.stripCaption) { _, value in
                if value.count > 40 { settings.stripCaption = String(value.prefix(40)) }
            }
        Text("Take a strip from the Mirror tab with the photobox button. Strips are saved to Pictures › OpenNotchi and added to the Tray.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .onAppear(perform: render)
            .onChange(of: settings.stripCaption) { render() }
            .onChange(of: media.info?.title) { render() }
    }

    private func thumbnail(_ style: StripStyle) -> some View {
        let selected = settings.stripStyle == style
        return Button {
            settings.stripStyle = style
        } label: {
            VStack(spacing: 5) {
                Group {
                    if let image = previews[style] {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: style.swatch, startPoint: .top, endPoint: .bottom))
                            .aspectRatio(style.isGrid ? 1 : 0.33, contentMode: .fit)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(3)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? Color.accentColor : .clear, lineWidth: 2.5))
                Text(style.displayName)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func render() {
        cache.update(caption: settings.stripCaption, info: StripInfo(media: media, sample: true))
    }
}
