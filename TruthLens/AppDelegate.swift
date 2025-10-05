import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var transparentWindow: NSWindow?

    // Gemini + capture instances
    let gemini = GeminiClient()
    let capture = ScreenshotCapture()

    // Recording state
    private var isRecording = false

    // Auto-hide timer
    private var hideTimer: Timer?

    // Track if this is the initial connection
    private var isInitialConnection = true

    // Popup positioning constants
    private let popupWidth: CGFloat = 300
    private let popupHeight: CGFloat = 150
    private let popupMargin: CGFloat = 20
    private let menuBarHeight: CGFloat = 24

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create the menu-bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarButton()

        // Hook up screenshot → Gemini pipeline
        capture.onFrameCaptured = { [weak self] base64Image in
            self?.gemini.sendFrame(base64Image)
        }

        // Listen for Gemini responses
        setupGeminiResponseObserver()

        // Create transparent popup window
        createTransparentWindow()

        // Configure ScreenshotCapture to exclude popup window
        capture.windowToExclude = transparentWindow

        // Show initial connection popup
        showInitialConnectionPopup()
    }

    // MARK: - Menu Bar Button
    private func updateMenuBarButton() {
        guard let button = statusItem.button else { return }

        if isRecording {
            // Pink tinted camera icon when recording
            if let cameraImage = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil) {
                cameraImage.isTemplate = true
                button.image = cameraImage
                button.contentTintColor = .systemPink
            }
        } else {
            // Default camera icon
            if let cameraImage = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil) {
                cameraImage.isTemplate = true
                button.image = cameraImage
                button.contentTintColor = nil
            } else {
                // fallback if SF Symbol not found
                button.image = NSImage(named: "MyIcon")
            }
        }

        button.action = #selector(toggleRecording)
    }

    // MARK: - Gemini Observer
    private func setupGeminiResponseObserver() {
        gemini.$receivedMessages
            .dropFirst()
            .sink { [weak self] messages in
                guard let self = self else { return }
                if !messages.isEmpty {
                    if let latestMessage = messages.last {
                        let cleanMessage = self.cleanMessage(latestMessage)

                        // Show connection messages initially, then only TRUE/FALSE when recording
                        let shouldShow = if self.isInitialConnection {
                            // Allow connection-related messages initially
                            cleanMessage.lowercased().contains("connected") ||
                            cleanMessage.lowercased().contains("session started") ||
                            cleanMessage.uppercased() == "TRUE" ||
                            cleanMessage.uppercased() == "FALSE"
                        } else {
                            // After initial connection, only TRUE/FALSE when recording
                            self.isRecording && (cleanMessage.uppercased() == "TRUE" || cleanMessage.uppercased() == "FALSE")
                        }

                        if shouldShow {
                            self.showTransparentPopup()
                            self.startHideTimer()

                            // Mark that we're past initial connection after first message
                            if self.isInitialConnection {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    self.isInitialConnection = false
                                }
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func cleanMessage(_ message: String) -> String {
        // Remove emoji prefixes and trim whitespace
        let cleaned = message.replacingOccurrences(of: "^[\\p{Emoji}\\s]+", with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Recording Control
    @objc func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
        updateMenuBarButton()
    }

    private func startRecording() {
        isRecording = true
        gemini.startSession()
        capture.startCapture()
        hideTransparentPopup()
        print("✅ Recording started")
    }

    private func stopRecording() {
        isRecording = false
        gemini.stopSession()
        capture.stopCapture()
        hideTransparentPopup()
        print("⏹️ Recording stopped")
    }

    // MARK: - Transparent Window
    private func createTransparentWindow() {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1680, height: 1050)

        // Position: top right, under menu bar
        let rect = NSRect(
            x: screen.maxX - popupWidth - popupMargin,
            y: screen.maxY - popupHeight - menuBarHeight - popupMargin,
            width: popupWidth,
            height: popupHeight
        )

        transparentWindow = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = transparentWindow else { return }

        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.animationBehavior = .none

        // Lock size
        window.setContentSize(NSSize(width: popupWidth, height: popupHeight))
        window.minSize = NSSize(width: popupWidth, height: popupHeight)
        window.maxSize = NSSize(width: popupWidth, height: popupHeight)
        window.isMovable = false
        window.isRestorable = false
        window.styleMask.remove(.resizable)

        let contentView = TransparentPopupView(gemini: gemini)
        window.contentView = NSHostingController(rootView: contentView).view

        window.orderOut(nil)
    }

    private func showTransparentPopup() {
        DispatchQueue.main.async {
            guard let window = self.transparentWindow else { return }
            let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1680, height: 1050)

            let frame = NSRect(
                x: screen.maxX - self.popupWidth - self.popupMargin,
                y: screen.maxY - self.popupHeight - self.menuBarHeight - self.popupMargin,
                width: self.popupWidth,
                height: self.popupHeight
            )

            window.setFrame(frame, display: false)
            window.orderFront(nil)
        }
    }

    private func hideTransparentPopup() {
        DispatchQueue.main.async {
            self.transparentWindow?.orderOut(nil)
        }
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.hideTransparentPopup()
        }
    }

    // MARK: - Initial Connection
    private func showInitialConnectionPopup() {
        // Add a "Connected" message to show app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.gemini.receivedMessages.append("📱 Connected to TruthLens")
            self.showTransparentPopup()
            self.startHideTimer()
        }
    }
}
