import Foundation

class GeminiClient: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)

    // Published so SwiftUI will react to updates
    @Published var receivedMessages: [String] = []
    @Published var isSessionActive: Bool = false

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

        receive()
    }

    func startSession() {
        let message: [String: Any] = [
            "type": "start_session"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: data, encoding: .utf8) {
            send(jsonString)
        }
    }

    func stopSession() {
        let message: [String: Any] = [
            "type": "stop_session"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: message),
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

    func sendFrame(_ base64: String) {
        let message: [String: Any] = [
            "type": "screen_frame",
            "image_data": base64
        ]

        if let data = try? JSONSerialization.data(withJSONObject: message),
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
                    print("🔍 Raw message received: \(text)")

                    // Parse JSON messages from the server
                    if let data = text.data(using: .utf8) {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                print("🔍 Parsed JSON: \(json)")

                                let messageType = json["type"] as? String
                                print("🔍 Message type: \(String(describing: messageType))")

                                switch messageType {
                                case "session_started":
                                    let message = json["message"] as? String ?? "Session started"
                                    print("✅ \(message)")
                                    DispatchQueue.main.async {
                                        self?.isSessionActive = true
                                        self?.receivedMessages.append("📱 \(message)")
                                    }

                                case "session_stopped":
                                    let message = json["message"] as? String ?? "Session stopped"
                                    print("⏹️ \(message)")
                                    DispatchQueue.main.async {
                                        self?.isSessionActive = false
                                        self?.receivedMessages.append("⏹️ \(message)")
                                    }

                                case "analysis_response":
                                    if let responseText = json["text"] as? String {
                                        print("🤖 Gemini: \(responseText)")
                                        DispatchQueue.main.async {
                                            self?.receivedMessages.append("🤖 \(responseText)")
                                        }
                                    } else {
                                        print("❌ Analysis response missing text field")
                                        DispatchQueue.main.async {
                                            self?.receivedMessages.append("❌ Invalid analysis response")
                                        }
                                    }

                                case "error":
                                    let errorMsg = json["message"] as? String ?? "Unknown error"
                                    print("❌ Error: \(errorMsg)")
                                    DispatchQueue.main.async {
                                        self?.receivedMessages.append("❌ \(errorMsg)")
                                    }

                                case "warning":
                                    let warningMsg = json["message"] as? String ?? "Unknown warning"
                                    print("⚠️ Warning: \(warningMsg)")
                                    DispatchQueue.main.async {
                                        self?.receivedMessages.append("⚠️ \(warningMsg)")
                                    }

                                case nil:
                                    print("❌ Error: Message type is null")
                                    print("❌ Full JSON: \(json)")
                                    DispatchQueue.main.async {
                                        self?.receivedMessages.append("❌ Error: Unknown message type: None")
                                    }

                                default:
                                    print("❓ Unknown message type: \(messageType ?? "nil")")
                                    print("❓ Full message: \(text)")
                                    DispatchQueue.main.async {
                                        self?.receivedMessages.append("❓ Unknown: \(messageType ?? "nil")")
                                    }
                                }
                            } else {
                                print("❌ Failed to parse as JSON dictionary")
                                DispatchQueue.main.async {
                                    self?.receivedMessages.append("❌ Invalid JSON format")
                                }
                            }
                        } catch {
                            print("❌ JSON parsing error: \(error)")
                            print("❌ Raw text: \(text)")
                            DispatchQueue.main.async {
                                self?.receivedMessages.append("❌ JSON Error: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        print("❌ Failed to convert text to data")
                        DispatchQueue.main.async {
                            self?.receivedMessages.append("❌ Text encoding error")
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
