import Foundation

/// Handles WebSocket connection to your backend / Gemini server.
class GeminiClient: ObservableObject {
    private var socket: URLSessionWebSocketTask?

    /// Messages from Gemini (published so SwiftUI can react)
    @Published var messages: [String] = []

    func connect() {
        guard let url = URL(string: "wss://punchiest-medieval-amira.ngrok-free.dev") else {
            print("❌ Invalid WebSocket URL")
            return
        }

        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        listen()
        sendInitialSetup()
    }

    private func listen() {
        socket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("❌ WebSocket receive error:", error)
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self?.messages.append("Gemini: \(text)")
                    }
                case .data(let data):
                    print("ℹ️ Received binary data length:", data.count)
                @unknown default:
                    break
                }
            }

            // Keep listening
            self?.listen()
        }
    }

    private func sendInitialSetup() {
        let setupMessage: [String: Any] = [
            "setup": [
                "generation_config": ["response_modalities": ["AUDIO", "TEXT"]]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: setupMessage),
           let jsonString = String(data: data, encoding: .utf8) {
            socket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ WebSocket send error:", error)
                }
            }
        }
    }

    func send(payload: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            socket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ WebSocket send error:", error)
                }
            }
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
}
