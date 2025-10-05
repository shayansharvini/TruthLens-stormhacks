import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

/// Handles continuous screen capture using ScreenCaptureKit.
class ScreenshotCapture: NSObject {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "screencapture.queue")
    private var lastFrameSent = Date()

    /// Callback whenever a new frame is captured (Base64 JPEG).
    var onFrameCaptured: ((String) -> Void)?

    /// Start capturing the main display.
    func startCapture() {
        Task {
            do {
                // Get shareable content (displays, windows, apps)
                let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                  onScreenWindowsOnly: false)

                guard let display = content.displays.first else {
                    print("❌ No display found")
                    return
                }

                // Configure filter to capture the whole display
                let filter = SCContentFilter(display: display,
                                             excludingApplications: [],
                                             exceptingWindows: [])

                // Stream configuration
                let config = SCStreamConfiguration()
                config.width = 640
                config.height = 480
                config.pixelFormat = kCVPixelFormatType_32BGRA

                // Create stream
                self.stream = SCStream(filter: filter, configuration: config, delegate: self)
                try self.stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)

                // ✅ must await here
                try await self.stream?.startCapture()
                print("✅ Screen capture started")
            } catch {
                print("❌ Error starting capture:", error)
            }
        }
    }


    /// Stop capturing.
    func stopCapture() {
        stream?.stopCapture { error in
            if let error = error {
                print("❌ Error stopping capture:", error)
            } else {
                print("✅ Screen capture stopped")
            }
        }
    }
}

extension ScreenshotCapture: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {

        guard outputType == .screen else { return }

        // Throttle frames (avoid sending too often)
        let now = Date()
        guard now.timeIntervalSince(lastFrameSent) >= 0.5 else { return }
        lastFrameSent = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        // Offload JPEG conversion to a background queue (avoid QoS inversion warning)
        DispatchQueue.global(qos: .utility).async {
            let context = CIContext()
            if let jpegData = context.jpegRepresentation(of: ciImage,
                                                         colorSpace: CGColorSpaceCreateDeviceRGB()) {
                let base64String = jpegData.base64EncodedString()

                // Call back on main thread
                DispatchQueue.main.async {
                    self.onFrameCaptured?(base64String)
                }
            }
        }
    }
}
