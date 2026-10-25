import SwiftUI

/// Save, copy, AirDrop and print buttons at the bottom of the studio.
struct StudioActionsBar: View {
    let onSave: () -> Void
    let onCopy: () -> Void
    let onAirDrop: () -> Void
    let onPrint: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onSave) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("Save & Keep")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white))
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Copy strip image to clipboard")

                Button(action: onAirDrop) {
                    HStack(spacing: 4) {
                        Image(systemName: "airdrop")
                        Text("AirDrop")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Send strip via AirDrop")

                Button(action: onPrint) {
                    Image(systemName: "printer")
                        .font(.system(size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Print photo strip")
            }
        }
    }
}
