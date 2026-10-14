import SwiftUI

/// Notch silhouette: flat top with outward "ears" and rounded bottom corners (for physical notches),
/// or a fully rounded capsule/island pill (for displays without a physical notch).
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// When false the top edge is left open, for drawing a border.
    var closed = true
    var isIsland = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        if isIsland {
            let tr = min(topRadius, rect.height / 2, rect.width / 2)
            let br = min(bottomRadius, rect.height / 2, rect.width / 2)
            var p = Path()
            p.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                           control: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                           control: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - br),
                           control: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
            p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY),
                           control: CGPoint(x: rect.minX, y: rect.minY))
            p.closeSubpath()
            return p
        }

        let t = topRadius
        let b = min(bottomRadius, (rect.height - t) / 2, (rect.width - 2 * t) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t),
                       control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
                       control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
                       control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - t, y: rect.minY))
        if closed { p.closeSubpath() }
        return p
    }
}
