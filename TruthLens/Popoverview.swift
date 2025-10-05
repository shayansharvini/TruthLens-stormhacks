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
                            if message.hasPrefix("Gemini:") {
                                Text("🤖")
                                Text(message)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            } else if message.hasPrefix("Status:") {
                                Text("📋")
                                Text(message)
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else if message.hasPrefix("Error:") {
                                Text("❌")
                                Text(message)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            } else {
                                Text("ℹ️")
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
                Button("💬 Send Test") {
                    gemini.sendText("Hello! Can you see my screen? Please describe what you observe.")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("📸 Start Capture") {
                    capture.startCapture()
                }
                .buttonStyle(.bordered)

                Button("⏹️ Stop") {
                    capture.stopCapture()
                }
                .buttonStyle(.bordered)
            }

            Text("Messages: \(gemini.receivedMessages.count)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

