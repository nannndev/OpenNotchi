import AppKit
import SwiftUI

struct CassetteSpool: View {
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
            Circle()
                .fill(Color.black)
                .frame(width: 10, height: 10)
            ForEach(0..<6) { i in
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 2, height: 8)
                    .offset(y: -9)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct VinylDisc: View {
    let artwork: NSImage?
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 100, height: 100)
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 80, height: 80)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: 60, height: 60)

            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle().fill(Color.red).frame(width: 36, height: 36)
            }

            Circle().fill(Color.black).frame(width: 8, height: 8)
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct VHSScanlines: View {
    var offset: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = offset.truncatingRemainder(dividingBy: 4)
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1.5)
                context.fill(Path(rect), with: .color(Color.black.opacity(0.35)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}

struct ReceiptPerforation: Shape {
    var inverted = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth: CGFloat = 8
        let toothHeight = rect.height
        let count = Int(rect.width / toothWidth)

        path.move(to: CGPoint(x: 0, y: inverted ? 0 : toothHeight))
        for i in 0..<count {
            let x = CGFloat(i) * toothWidth
            let mid = x + toothWidth / 2
            let next = x + toothWidth
            if inverted {
                path.addLine(to: CGPoint(x: mid, y: toothHeight))
                path.addLine(to: CGPoint(x: next, y: 0))
            } else {
                path.addLine(to: CGPoint(x: mid, y: 0))
                path.addLine(to: CGPoint(x: next, y: toothHeight))
            }
        }
        return path
    }
}

struct BarcodePattern: View {
    var animatedOffset: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<32) { i in
                let dynamicH: CGFloat = animatedOffset > 0 ? CGFloat(abs(sin(animatedOffset * 3 + Double(i) * 0.7))) : 1.0
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: (i % 3 == 0) ? 2.5 : ((i % 5 == 0) ? 4.0 : 1.2))
                    .scaleEffect(y: 0.6 + dynamicH * 0.4, anchor: .bottom)
            }
        }
    }
}

struct Grain: View {
    let opacity: Double
    var dark = false

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(1 << 31)
            }
            for _ in 0..<2600 {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 0.8, height: 0.8)
                context.fill(Path(rect), with: .color((dark ? Color.black : .white).opacity(opacity * (0.4 + next()))))
            }
        }
        .allowsHitTesting(false)
    }
}
