import AppKit

/// Photos and strips go to ~/Pictures/OpenNotchi.
enum MirrorPhotos {
    static func save(_ image: CGImage, name: String) -> URL? {
        let folder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenNotchi")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = folder.appendingPathComponent("\(name) \(formatter.string(from: .now)).jpg")
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]),
              (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}
