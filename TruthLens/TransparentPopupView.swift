import SwiftUI

struct TransparentPopupView: View {
    @ObservedObject var gemini: GeminiClient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let latestMessage = gemini.receivedMessages.last {
                let cleanMessage = cleanMessage(latestMessage)

                // Show TRUE/FALSE or connection messages
                let isTrueFalse = cleanMessage.uppercased() == "TRUE" || cleanMessage.uppercased() == "FALSE"
                let isConnectionMessage = cleanMessage.lowercased().contains("connected") ||
                                        cleanMessage.lowercased().contains("session started") ||
                                        latestMessage.contains("📱")

                if isTrueFalse || isConnectionMessage {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("llm response")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .opacity(0.8)

                            if isTrueFalse {
                                Text(cleanMessage.uppercased())
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(cleanMessage.uppercased() == "TRUE" ? .green : .red)
                                    .multilineTextAlignment(.leading)
                            } else {
                                Text(cleanMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .opacity(0.9)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    // Don't show anything if not TRUE/FALSE or connection message
                    EmptyView()
                }
            } else {
                // Empty state
                EmptyView()
            }
        }
        .frame(maxWidth: 280)
        .padding(10)
        .animation(.easeInOut(duration: 0.3), value: gemini.receivedMessages.count)
    }

    private func cleanMessage(_ message: String) -> String {
        // Remove emoji prefixes like "🤖 ", "📱 ", etc.
        let cleaned = message.replacingOccurrences(of: "^[\\p{Emoji}\\s]+", with: "", options: .regularExpression)
        return cleaned.isEmpty ? message : cleaned
    }
}

#Preview {
    TransparentPopupView(gemini: GeminiClient())
        .preferredColorScheme(.light)
}