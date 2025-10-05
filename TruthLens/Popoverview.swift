import SwiftUI

struct PopoverView: View {
    @ObservedObject var gemini: GeminiClient
    var capture: ScreenshotCapture

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🤖 Gemini Live Assistant")
                .font(.headline)
                .foregroundColor(.blue)

            // Larger response area
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(gemini.receivedMessages.indices, id: \.self) { index in
                        let message = gemini.receivedMessages[index]
                        HStack {
                            if message.hasPrefix("🤖") {
                                Text(message)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            } else if message.hasPrefix("📱") {
                                Text(message)
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else if message.hasPrefix("❌") {
                                Text(message)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            } else if message.hasPrefix("⏹️") {
                                Text(message)
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            } else {
                                Text(message)
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
            .frame(height: 200)
            .border(Color.gray.opacity(0.3))

            HStack {
                if gemini.isSessionActive {
                    Button("📸 Start Analysis") {
                        capture.startCapture()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!gemini.isSessionActive)

                    Button("⏹️ Stop Analysis") {
                        capture.stopCapture()
                    }
                    .buttonStyle(.bordered)

                    Button("🔚 End Session") {
                        capture.stopCapture()
                        gemini.stopSession()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("🚀 Start Session") {
                        gemini.startSession()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }

            Text("Messages: \(gemini.receivedMessages.count)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

