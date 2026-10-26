import SwiftUI

struct ColorPickerCard: View {
    @EnvironmentObject private var colorPicker: ColorPickerManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Color Eyedropper", systemImage: "eyedropper.halffull")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    colorPicker.sampleColor()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 9, weight: .bold))
                        Text("Pick")
                            .font(.system(size: 9, weight: .semibold))
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .help("Pick a color from anywhere on screen")
            }

            if let current = colorPicker.currentColor {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(current.color)
                        .frame(width: 24, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: current.color.opacity(0.3), radius: 3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(current.hex)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text(current.rgb)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 2)

                    Menu {
                        Button("Copy HEX (\(current.hex))") {
                            colorPicker.copyFormat(current, format: .hex)
                        }
                        Button("Copy RGB (\(current.rgb))") {
                            colorPicker.copyFormat(current, format: .rgb)
                        }
                        Button("Copy HSL (\(current.hsl))") {
                            colorPicker.copyFormat(current, format: .hsl)
                        }
                        Button("Copy Swift Snippet") {
                            colorPicker.copyFormat(current, format: .swift)
                        }
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Copy color in different formats")
                }

                if !colorPicker.recentColors.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(colorPicker.recentColors.prefix(6)) { item in
                            Button {
                                colorPicker.copyFormat(item, format: .hex)
                            } label: {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Copy \(item.hex)")
                        }
                    }
                    .padding(.top, 1)
                }
            } else {
                Button {
                    colorPicker.sampleColor()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 9))
                        Text("Click to pick pixel color")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }

            if let feedback = colorPicker.copiedFeedback {
                Text(feedback)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)))
    }
}
