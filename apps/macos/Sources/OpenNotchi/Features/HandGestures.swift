import Vision

/// Hand poses the mirror reacts to.
enum MirrorGesture: String {
    case peace      // ✌️ take a photo
    case thumbsUp   // 👍 confetti
    case openPalm   // ✋ toggle the ring light
}

/// Recognizes `MirrorGesture`s from camera frames with Vision's hand pose detection.
/// A pose has to be held for a moment before it counts, then there's a short cooldown.
final class HandGestureDetector {
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    private var candidate: MirrorGesture?
    private var streak = 0
    private var cooldownUntil = Date.distantPast

    /// Consecutive detections needed (frames are sampled about 8 times a second).
    private let requiredStreak = 3
    private let cooldown: TimeInterval = 2.5

    /// Returns a gesture once it has been held long enough.
    func process(_ pixelBuffer: CVPixelBuffer) -> MirrorGesture? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        let pose = request.results?.first.flatMap(Self.classify)

        guard let pose, Date.now >= cooldownUntil else {
            candidate = nil
            streak = 0
            return nil
        }
        if pose == candidate {
            streak += 1
        } else {
            candidate = pose
            streak = 1
        }
        guard streak >= requiredStreak else { return nil }
        candidate = nil
        streak = 0
        cooldownUntil = Date.now.addingTimeInterval(cooldown)
        return pose
    }

    static func classify(_ hand: VNHumanHandPoseObservation) -> MirrorGesture? {
        guard let points = try? hand.recognizedPoints(.all),
              let wrist = points[.wrist], wrist.confidence > 0.3 else { return nil }

        func point(_ name: VNHumanHandPoseObservation.JointName) -> VNRecognizedPoint? {
            guard let p = points[name], p.confidence > 0.3 else { return nil }
            return p
        }
        func distance(_ a: VNRecognizedPoint, _ b: VNRecognizedPoint) -> Double {
            hypot(a.location.x - b.location.x, a.location.y - b.location.y)
        }
        /// A finger is extended when its tip is clearly farther from the wrist than its middle joint.
        func extended(_ tip: VNHumanHandPoseObservation.JointName, _ pip: VNHumanHandPoseObservation.JointName) -> Bool? {
            guard let t = point(tip), let p = point(pip) else { return nil }
            return distance(t, wrist) > distance(p, wrist) * 1.15
        }

        guard let index = extended(.indexTip, .indexPIP),
              let middle = extended(.middleTip, .middlePIP),
              let ring = extended(.ringTip, .ringPIP),
              let little = extended(.littleTip, .littlePIP),
              let thumb = extended(.thumbTip, .thumbIP) else { return nil }

        if index && middle && ring && little && thumb {
            return .openPalm
        }
        if index && middle && !ring && !little {
            return .peace
        }
        // Thumbs up: other fingers curled and the thumb tip clearly above the knuckles.
        if !index && !middle && !ring && !little && thumb,
           let tip = point(.thumbTip), let knuckle = point(.indexMCP), let palm = point(.middleMCP),
           tip.location.y > max(knuckle.location.y, palm.location.y) + distance(knuckle, wrist) * 0.4 {
            return .thumbsUp
        }
        return nil
    }
}
