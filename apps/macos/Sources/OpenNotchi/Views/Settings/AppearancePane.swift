import SwiftUI

struct AppearancePane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        Form {
            Section("Theme") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(NotchTheme.allCases) { theme in
                        ThemeCard(theme: theme, isSelected: settings.theme == theme) {
                            settings.theme = theme
                        }
                    }
                }
                if settings.theme == .adaptive || settings.theme == .albumArt {
                    Text("Changes with the artwork of the song that's playing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Accent color") {
                HStack(spacing: 10) {
                    ForEach(AccentChoice.allCases) { choice in
                        AccentSwatch(choice: choice, isSelected: settings.accent == choice) {
                            settings.accent = choice
                        }
                    }
                }
                .padding(.vertical, 2)
                Text(settings.accent.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shape & border") {
                Picker("Border", selection: $settings.borderStyle) {
                    ForEach(BorderStyle.allCases) { Text($0.displayName).tag($0) }
                }
                if settings.borderStyle != .none {
                    LabeledContent("Border width") {
                        HStack {
                            Slider(value: $settings.borderWidth, in: 0.5...4, step: 0.5)
                            Text(String(format: "%.1f", settings.borderWidth))
                                .monospacedDigit()
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                LabeledContent("Corner radius") {
                    HStack {
                        Slider(value: $settings.cornerRadius, in: 12...48, step: 2)
                        Text("\(Int(settings.cornerRadius))")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }

            Section("Open Animation") {
                VStack(spacing: 5) {
                    ForEach(NotchAnimationStyle.allCases) { style in
                        AnimationRowView(
                            style: style,
                            isSelected: settings.openAnimation == style,
                            onSelect: {
                                settings.openAnimation = style
                            },
                            onPreview: {
                                settings.openAnimation = style
                                AppDelegate.shared?.previewNotch()
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct AnimationRowView: View {
    let style: NotchAnimationStyle
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: style.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(
                                    isSelected
                                        ? AnyShapeStyle(Color.accentColor.gradient)
                                        : AnyShapeStyle(Color.white.opacity(0.08)))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(style.displayName)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(.primary)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text(style.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPreview) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    Text("Test")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.08))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Preview this open animation on the notch")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

struct ThemeCard: View {
    @EnvironmentObject private var media: MediaManager
    let theme: NotchTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Busy backdrop so glass and frosted themes read as translucent.
                    LinearGradient(colors: [.orange, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    NotchBackground(
                        theme: theme,
                        isOpen: true,
                        shape: RoundedRectangle(cornerRadius: 10),
                        artwork: media.artwork,
                        palette: media.palette
                    )
                    .padding(6)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.85)).frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            Capsule().fill(.white.opacity(0.85)).frame(width: 34, height: 4)
                            Capsule().fill(.white.opacity(0.45)).frame(width: 24, height: 4)
                        }
                    }
                }
                .frame(height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? Color.accentColor : .primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
                )

                Text(theme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AccentSwatch: View {
    let choice: AccentChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if choice == .artwork {
                    Circle().fill(
                        AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center)
                    )
                    .overlay(
                        Image(systemName: "music.note").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                } else {
                    Circle().fill(choice.color)
                }
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(.primary.opacity(0.2), lineWidth: 1))
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .padding(-4)
                    .opacity(isSelected ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .help(choice.displayName)
    }
}
