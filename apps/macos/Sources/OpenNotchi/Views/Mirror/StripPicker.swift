import SwiftUI

/// Pick a strip style right in the mirror, then start the photobox.
struct StripPicker: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @ObservedObject private var previews = StripPreviews.shared
    let onStart: () -> Void
    let onOpenStudio: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Format, number of photos and text on one line, so the strips get the rest of the height.
            HStack(spacing: 10) {
                Menu {
                    Picker("Format", selection: $settings.stripFormat) {
                        ForEach(StripFormat.allCases) { Label($0.displayName, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(settings.stripFormat.displayName, systemImage: settings.stripFormat.icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.14)))
                .help("Size of the picture: a classic strip, or ready for a story or post")

                HStack(spacing: 3) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 10)).foregroundStyle(.secondary)
                    ForEach(StripShots.choices, id: \.self) { n in
                        Button {
                            settings.stripShots = n
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(settings.stripShots == n ? Color.white : Color.white.opacity(0.12)))
                                .foregroundStyle(settings.stripShots == n ? .black : .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .help("Number of photos")

                // Typed right here: a separate window would open behind the tall notch.
                TextField("Your text", text: $settings.stripCaption)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .frame(maxWidth: 170)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .onChange(of: settings.stripCaption) { _, value in
                        if value.count > 40 { settings.stripCaption = String(value.prefix(40)) }
                    }
                    .onSubmit(onStart)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)

            HStack(spacing: 12) {
                // Thumbnails are sized to the mirror's height so whole strips and their names stay visible.
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 12) {
                                ForEach(StripStyle.allCases) { style in
                                    chip(style, height: max(30, geo.size.height - 22)).id(style)
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: geo.size.height)
                        }
                        .onAppear { proxy.scrollTo(settings.stripStyle, anchor: .center) }
                    }
                }

                VStack(spacing: 7) {
                    Button(action: onStart) {
                        Label("Start", systemImage: "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.white))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenStudio) {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                            Text("Studio 🎀")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Decorate strip with stickers & stamps")

                    Button(action: onClose) {
                        Text("Cancel").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 14)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.72))
        .onExitCommand(perform: onClose)
        .onAppear(perform: refreshPreviews)
        .onChange(of: settings.stripCaption) { refreshPreviews() }
        .onChange(of: settings.stripShots) { refreshPreviews() }
        .onChange(of: settings.stripFormat) { refreshPreviews() }
    }

    private func refreshPreviews() {
        previews.update(caption: settings.stripCaption, info: StripInfo(media: media, sample: true), shots: settings.stripShots, format: settings.stripFormat)
    }

    private func chip(_ style: StripStyle, height: CGFloat) -> some View {
        let selected = settings.stripStyle == style
        return Button {
            withAnimation(.spring(response: 0.3)) { settings.stripStyle = style }
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let image = previews.images[style] {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: style.swatch, startPoint: .top, endPoint: .bottom))
                            .aspectRatio(style.isGrid ? 1 : 0.33, contentMode: .fit)
                    }
                }
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white, lineWidth: selected ? 2 : 0))
                .opacity(selected ? 1 : 0.75)
                Text(style.displayName)
                    .font(.system(size: 9, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? .white : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
    }
}
