import Foundation

class GeminiClient: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)

    // Published so SwiftUI will react to updates
    @Published var receivedMessages: [String] = []

    init() {
        connect()
    }

    func connect() {
        guard let url = URL(string: "ws://127.0.0.1:9083") else {
            print("❌ Invalid WebSocket URL")
            return
        }

        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()

        // Send initial setup message as expected by the Python backend
        sendSetupMessage()
        receive()
    }

    private func sendSetupMessage() {
        let setupPayload: [String: Any] = [
            "setup": [
                "response_modalities": ["AUDIO", "TEXT"]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: setupPayload),
           let jsonString = String(data: data, encoding: .utf8) {
            send(jsonString)
        }
    }

    func send(_ text: String) {
        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("❌ WebSocket send error: \(error)")
            }
        }
    }

    func sendText(_ text: String) {
        let payload = ["text": text]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            send(jsonString)
        }
    }

    func sendFrame(_ base64: String) {
        let payload: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    ["mime_type": "image/jpeg", "data": base64]
                ]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            send(jsonString)
        }
    }

    private func receive() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("❌ WebSocket receive error: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    // Try to parse as JSON first to handle status messages
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                        if let status = json["status"] as? String,
                           let message = json["message"] as? String {
                            print("📋 Status: \(status) - \(message)")
                            DispatchQueue.main.async {
                                self?.receivedMessages.append("Status: \(message)")
                            }
                        } else if let errorMsg = json["error"] as? String {
                            print("❌ Server Error: \(errorMsg)")
                            DispatchQueue.main.async {
                                self?.receivedMessages.append("Error: \(errorMsg)")
                            }
                        } else if let responseText = json["text"] as? String {
                            print("🤖 Gemini Response: \(responseText)")
                            DispatchQueue.main.async {
                                self?.receivedMessages.append("Gemini: \(responseText)")
                            }
                        } else {
                            // Fallback for other JSON messages
                            DispatchQueue.main.async {
                                self?.receivedMessages.append("Server: \(text)")
                            }
                        }
                    } else {
                        // Fallback for non-JSON messages
                        DispatchQueue.main.async {
                            self?.receivedMessages.append("Gemini: \(text)")
                        }
                    }
                case .data(let data):
                    print("📦 Received binary data: \(data.count) bytes")
                @unknown default:
                    print("❓ Unknown message type")
                }
            }

            // Keep listening
            self?.receive()
        }
    }
}
