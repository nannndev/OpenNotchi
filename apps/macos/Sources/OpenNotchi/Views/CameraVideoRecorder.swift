import AppKit
import AVFoundation
import SwiftUI

/// Sheet for recording a short webcam video clip to use as the background for lyric videos.
struct CameraVideoRecordSheet: View {
    let onRecordFinished: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = CameraRecorderModel()
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                CameraPreview(
                    effect: .natural,
                    cameraID: AppSettings.shared.mirrorCameraID
                )
                .frame(width: 480, height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(recorder.isRecording ? Color.red : Color.white.opacity(0.15), lineWidth: recorder.isRecording ? 3 : 1)
                )

                if recorder.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        Text(String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(14)
                }
            }

            HStack(spacing: 14) {
                Button("Cancel") {
                    recorder.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if !recorder.isRecording {
                    Button {
                        startRecording()
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 12, height: 12)
                            Text("Start Recording")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        stopRecording()
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.white).frame(width: 10, height: 10)
                            Text("Stop & Use Video")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .onDisappear {
            timer?.invalidate()
            recorder.cleanup()
        }
    }

    private func startRecording() {
        elapsedSeconds = 0
        recorder.startRecording()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        recorder.stopRecording { url in
            if let url = url {
                onRecordFinished(url)
                dismiss()
            }
        }
    }
}

final class CameraRecorderModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var isRecording = false

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var completion: ((URL?) -> Void)?
    private var tempFileURL: URL?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        let cameraID = AppSettings.shared.mirrorCameraID
        let device = CameraPreview.cameras.first { $0.uniqueID == cameraID }
            ?? AVCaptureDevice.default(for: .video)

        if let device = device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("opennotchi_rec_\(UUID().uuidString).mov")
        tempFileURL = fileURL

        try? FileManager.default.removeItem(at: fileURL)

        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        movieOutput.stopRecording()
    }

    func cancel() {
        movieOutput.stopRecording()
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func cleanup() {
        session.stopRunning()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            if error == nil {
                self.completion?(outputFileURL)
            } else {
                self.completion?(nil)
            }
            self.completion = nil
        }
    }
}
