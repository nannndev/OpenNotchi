import SwiftUI

/// Script editor with quick templates; saves into settings on Done.
struct PrompterEditor: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent

    @Binding var scriptDraft: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent.color)
                    Text("Edit Script")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Preset Templates Menu
                Menu {
                    Section("Quick Templates") {
                        ForEach(PrompterPresets.all) { template in
                            Button {
                                scriptDraft = template.script
                            } label: {
                                Label(template.title, systemImage: template.icon)
                            }
                        }
                    }
                    Divider()
                    Button("Clear Script") {
                        scriptDraft = ""
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("Templates")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundStyle(.white)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                // Save & Done Button
                Button {
                    settings.prompterScript =
                        scriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? PrompterPresets.all[0].script
                        : scriptDraft
                    onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accent.color))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Text Editor
            TextEditor(text: $scriptDraft)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .lineSpacing(4)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14), lineWidth: 1))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .background(Color.black.opacity(0.85))
    }
}
