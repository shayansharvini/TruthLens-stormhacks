import SwiftUI

struct PopoverView: View {
    @ObservedObject var gemini: GeminiClient
    var capture: ScreenshotCapture

    var body: some View {
        VStack(spacing: 12) {
            Text("TruthLens")
                .font(.headline)

            // Show Gemini responses
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(gemini.messages, id: \.self) { msg in
                        Text(msg)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .frame(height: 100)

            Button("Start Session") {
                gemini.connect()
                capture.startCapture()
            }

            Button("Stop Capture") {
                capture.stopCapture()
                gemini.disconnect()
            }

            Button("Quit App") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280, height: 220)
    }
}
