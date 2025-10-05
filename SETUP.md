# TruthLens Setup Guide

## Quick Setup

### 1. Backend Setup
```bash
cd backend/
pip3 install -r requirements.txt

# Copy and edit environment file
cp .env.example .env
# Edit .env and add your Google API key
```

### 2. Get Google AI API Key
1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Create an API key
3. Add it to `backend/.env`:
   ```
   GOOGLE_API_KEY=your_api_key_here
   ```

### 3. Start Backend Server
```bash
cd backend/
python3 main_bridge.py
```
Server will start on `localhost:9083`

**Note**: `main_bridge.py` is the re-engineered version of the original Live API code, optimized for screen-only analysis with text responses.

### 4. Run macOS App
1. Open `TruthLens.xcodeproj` in Xcode
2. Build and run the app
3. Click the menu bar icon
4. Click "🚀 Start Session" to begin
5. Click "📸 Start Analysis" to start screen capture
6. Gemini will analyze your screen and provide text responses

## How It Works

1. **Swift App** captures your screen at 2fps (640x480 JPEG)
2. **WebSocket Server** (`websocket_server.py`) receives frames
3. **Google Gemini AI** analyzes the screen content
4. **Text responses** are sent back to the Swift app and displayed

## Protocol

The WebSocket server expects these message types:

- `{"type": "start_session"}` - Initialize Gemini session
- `{"type": "screen_frame", "image_data": "base64_jpeg"}` - Send screen capture
- `{"type": "stop_session"}` - End session

Server responds with:

- `{"type": "session_started", "message": "..."}`
- `{"type": "analysis_response", "text": "..."}` - AI analysis
- `{"type": "error", "message": "..."}` - Error messages