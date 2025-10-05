# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TruthLens is a macOS application that provides AI-powered real-time screen analysis using Google's Gemini AI. The architecture consists of:

- **Swift macOS app**: Menu bar application with screen capture capabilities
- **Python backend**: WebSocket server that bridges to Google Gemini API
- **Communication**: WebSocket connection between Swift app and Python backend

## Development Commands

### Backend (Python)
```bash
# Install dependencies
cd backend/
pip install --upgrade google-genai==0.3.0 websockets python-dotenv

# Run the WebSocket server
python3 main.py
# Server runs on localhost:9083
```

### iOS/macOS App (Swift)
```bash
# Build and run from Xcode
open ../TruthLens.xcodeproj

# Or build from command line
xcodebuild -project ../TruthLens.xcodeproj -scheme TruthLens build
```

## Architecture Details

### Core Data Flow
1. **ScreenshotCapture.swift** → Captures screen at 640x480, converts to base64 JPEG
2. **AppDelegate.swift** → Routes captured frames to Gemini client
3. **Gemini.swift** → WebSocket client that sends data to Python backend
4. **backend/main.py** → WebSocket server that forwards to Google Gemini API

### Key Components

**AppDelegate.swift** (`TruthLens/AppDelegate.swift`)
- Menu bar application lifecycle
- Connects ScreenshotCapture and GeminiClient via callback: `capture.onFrameCaptured = { [weak self] base64Image in ... }`
- Creates popover UI with `MyPopoverView` (but references `PopoverView` - naming inconsistency)

**ScreenshotCapture.swift** (`TruthLens/ScreenshotCapture.swift`)
- Uses ScreenCaptureKit for continuous capture
- Throttles frames to 2fps (0.5 second intervals)
- Implements `SCStreamOutput` and `SCStreamDelegate` protocols
- **Important**: Uses async/await for `startCapture()` method

**Gemini.swift** (`TruthLens/Gemini.swift`)
- WebSocket client with `@Published` messages for SwiftUI reactivity
- Hardcoded ngrok URL: `wss://punchiest-medieval-amira.ngrok-free.dev`
- Sends setup message with response modalities: `["AUDIO", "TEXT"]`

**PopoverView.swift** (`TruthLens/Popoverview.swift`)
- SwiftUI interface with Start/Stop controls
- Displays Gemini responses in scrollable list
- Takes `@ObservedObject var gemini: GeminiClient` parameter

### Backend WebSocket Server (`backend/main.py`)
- Handles bidirectional communication with Gemini API
- Processes both audio (`audio/pcm`) and image (`image/jpeg`) inputs
- Uses Google Gemini 2.0 Flash model
- Requires `GOOGLE_API_KEY` environment variable

## Configuration

### Required Environment Variables
```bash
# backend/.env or backend/.env.local
GOOGLE_API_KEY=your_api_key_here
```

### macOS Permissions Required
- Screen Recording permission (for ScreenCaptureKit)
- Microphone access (for AudioRecorder, though not fully integrated)

### App Entitlements (`TruthLens/TruthLens.entitlements`)
- Sandboxed app with user-selected read-only file access
- **Note**: May need additional entitlements for screen capture in production

## Development Notes

### Common Issues
- Backend dependencies: Ensure `google-genai==0.3.0` is installed
- ngrok URL: Update hardcoded WebSocket URL in `Gemini.swift:11`
- Async/await: ScreenCaptureKit methods require proper async handling
- Naming inconsistency: `AppDelegate` references `MyPopoverView` but actual struct is `PopoverView`

### Testing the Pipeline
1. Start backend: `cd backend && python3 main.py`
2. Build and run iOS app from Xcode
3. Click menu bar icon → "Start Session"
4. Backend should show "Connected to Gemini API" and screen capture will begin

### Architecture Considerations
- The app runs as an accessory (no dock icon) via `NSApp.setActivationPolicy(.accessory)`
- Screen capture is throttled to prevent overwhelming the AI service
- JPEG conversion happens on background queue to avoid main thread blocking
- WebSocket reconnection logic is minimal - manual restart required if connection drops