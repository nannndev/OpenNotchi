import SwiftUI

/// Bottom deck: style, text, duration, media and export buttons.
extension LyricsShareView {
    var controlDeck: some View {
        VStack(spacing: 12) {
            // Style Selector Row
            styleSelector
            textControls

            Divider().opacity(0.15)

            // Dynamic Context Controls
            if mode == .video {
                VStack(spacing: 10) {
                    // Duration Selector
                    HStack(spacing: 6) {
                        Text("Duration:")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)

                        let autoD = autoDuration
                        Button {
                            duration = autoD
                            if previewElapsed > autoD { previewElapsed = 0 }
                        } label: {
                            Text("Auto (\(Int(autoD))s)")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(
                                        abs(duration - autoD) < 0.5 ? Color.accentColor : Color.white.opacity(0.08))
                                )
                                .foregroundStyle(abs(duration - autoD) < 0.5 ? .white : .secondary)
                        }
                        .buttonStyle(.plain)

                        ForEach([10.0, 15.0, 30.0], id: \.self) { d in
                            Button {
                                duration = d
                                if previewElapsed > d { previewElapsed = 0 }
                            } label: {
                                Text("\(Int(d))s")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(duration == d ? Color.accentColor : Color.white.opacity(0.08))
                                    )
                                    .foregroundStyle(duration == d ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        videoSourceMenu
                        photoMenu("Photo", icon: "photo", target: .backdrop, isCustom: backdrop != nil)
                        photoMenu(
                            "Cover", icon: "music.note.list", target: .cover,
                            isCustom: song.artwork !== originalArtwork.0)
                        musicMenu
                        Spacer()
                        if customVideoURL != nil || backdrop != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "drop.halffull").foregroundStyle(.secondary).font(.system(size: 11))
                                Slider(value: $backdropBlur, in: 0...40)
                                    .frame(width: 80)
                                    .help("Background blur")
                                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary).font(
                                    .system(size: 11))
                                Slider(value: $backdropZoom, in: 1...3)
                                    .frame(width: 80)
                                    .help("Background zoom")
                            }
                        }
                    }
                    .frame(height: 28)
                }
            } else {
                HStack(spacing: 14) {
                    photoMenu(
                        "Cover Art", icon: "music.note.list", target: .cover,
                        isCustom: song.artwork !== originalArtwork.0)
                    photoMenu("Background", icon: "photo", target: .backdrop, isCustom: backdrop != nil)

                    if backdrop != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.halffull").foregroundStyle(.secondary).font(.system(size: 11))
                            Slider(value: $backdropBlur, in: 0...40)
                                .frame(width: 90)
                                .help("Background blur")
                        }
                    }

                    Spacer()
                }
                .frame(height: 28)
            }

            // Action Buttons
            HStack(spacing: 12) {
                if mode == .photo {
                    Button {
                        copyImage()
                    } label: {
                        Label("Copy Image", systemImage: "doc.on.doc")
                    }
                    Button {
                        saveImage()
                    } label: {
                        Label("Save Image", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        shareImage()
                    } label: {
                        Label("Share…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        exportVideo()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isRendering ? "hourglass" : "film.fill")
                            Text(isRendering ? "Rendering Video…" : "Export Video (MP4)")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(minWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRendering)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    var videoSourceMenu: some View {
        HStack(spacing: 6) {
            Menu {
                Button {
                    chooseVideoFile()
                } label: {
                    Label("Upload Video File…", systemImage: "arrow.up.circle")
                }
                Button {
                    showRecordVideoSheet = true
                } label: {
                    Label("Record from Webcam…", systemImage: "record.circle")
                }
                if customVideoURL != nil {
                    Divider()
                    Button("Reset to Motion Canvas") {
                        setVideoURL(nil)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: customVideoURL != nil ? "checkmark.circle.fill" : "video.badge.plus")
                        .foregroundStyle(customVideoURL != nil ? Color.green : Color.primary)
                    Text(customVideoURL != nil ? "Video Attached" : "Video Background")
                        .font(.system(size: 11.5, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(customVideoURL != nil ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(
                        customVideoURL != nil ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if customVideoURL != nil {
                Button {
                    setVideoURL(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove custom video")
            }
        }
    }

    var autoDuration: Double {
        let startIdx = selection.lowerBound
        let endIdx = selection.upperBound
        if let startTime = song.times[startIdx], let endTime = song.times[endIdx] {
            return max(5.0, min(30.0, (endTime - startTime) + 3.5))
        }
        return 15.0
    }

    var textControls: some View {
        HStack(spacing: 12) {
            Picker("Font", selection: $lyricFont) {
                ForEach(LyricFont.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 170)

            Picker("Align", selection: $textAlign) {
                Text("Auto").tag(TextAlignment?.none)
                Image(systemName: "text.alignleft").tag(TextAlignment?.some(.leading))
                Image(systemName: "text.aligncenter").tag(TextAlignment?.some(.center))
                Image(systemName: "text.alignright").tag(TextAlignment?.some(.trailing))
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Image(systemName: "textformat.size").foregroundStyle(.secondary).font(.system(size: 11))
            Slider(value: $fontScale, in: 0.6...1.6)
                .frame(width: 100)
                .help("Lyric size")
            Spacer()
        }
        .font(.system(size: 11.5))
        .controlSize(.small)
    }

    var styleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LyricCardStyle.allCases) { item in
                    let isSelected = style == item
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            style = item
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.name)
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor : Color.white.opacity(0.06))
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 36)
    }

    func photoMenu(_ title: String, icon: String, target: PhotoTarget, isCustom: Bool) -> some View {
        Menu {
            Button {
                choosePhoto(for: target)
            } label: {
                Label("Choose Photo…", systemImage: "photo.on.rectangle")
            }
            Button {
                cameraTarget = target
            } label: {
                Label("Take Photo…", systemImage: "camera")
            }
            if isCustom {
                Divider()
                Button(target == .cover ? "Use Song Artwork" : "Remove Photo") { setPhoto(nil, for: target) }
            }
        } label: {
            Label(title, systemImage: isCustom ? "checkmark.circle.fill" : icon)
                .font(.system(size: 11))
        }
        .fixedSize()
    }

    var musicMenu: some View {
        Menu {
            Button {
                chooseMusicFile()
            } label: {
                Label("Choose Song File…", systemImage: "music.note")
            }
            if musicURL != nil {
                Divider()
                Button("Remove Music") { musicURL = nil }
            }
        } label: {
            Label("Music", systemImage: musicURL != nil ? "checkmark.circle.fill" : "music.note")
                .font(.system(size: 11))
        }
        .fixedSize()
        .help("Audio file of the song; the part matching the chosen lines is added to the video")
    }
}
