//
//  ContentView.swift
//  TruthLens
//
//  Created by Shayan Sharvini on 2025-10-04.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var geminiClient = GeminiClient()
    private let capture = ScreenshotCapture()

    var body: some View {
        VStack {
            Text("TruthLens News Detector")
                .font(.title)
                .padding(.bottom, 10)

            // List of received responses from Python/Gemini
            List(geminiClient.receivedMessages, id: \.self) { msg in
                Text(msg)
                    .font(.body)
            }
            .frame(minHeight: 300)

            HStack {
                Button(action: {
                    geminiClient.startSession()
                    capture.onFrameCaptured = { base64 in
                        geminiClient.sendFrame(base64)
                    }
                    capture.startCapture()
                }) {
                    Label("Start Capture", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    capture.stopCapture()
                    geminiClient.stopSession()
                }) {
                    Label("Stop Capture", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
