# Debug Information

## Current Issue: "Unknown message type: None"

### What we've added:
1. **Server-side logging** - Now logs all raw messages received and parsed JSON
2. **Swift client logging** - Now logs all messages received and parsing attempts
3. **Better error handling** - Shows exactly what JSON is being received

### How to debug:

1. **Start the server with logging**:
   ```bash
   cd backend/
   python3 websocket_server.py
   ```

2. **Run the Swift app and watch both**:
   - Look at Xcode console for Swift app debug output
   - Look at terminal for server debug output

3. **What to look for**:
   - Server logs: `Raw message received:` - shows what server gets from Swift
   - Swift logs: `🔍 Raw message received:` - shows what Swift gets from server
   - Swift logs: `🔍 Parsed JSON:` - shows if JSON parsing works
   - Swift logs: `🔍 Message type:` - shows what type field contains

### Expected behavior:
- Server should log messages like: `{"type": "start_session"}` from Swift
- Swift should log messages like: `{"type": "session_started", "message": "..."}` from server

### If you see "Unknown message type: None":
This means the server sent JSON without a "type" field, or with "type": null
Look for the raw message that caused this to see what the server actually sent.