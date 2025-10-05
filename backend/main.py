"""
TruthLens Bridge Server

Re-engineered version of main_old.py that:
- Always uses screen mode (but gets frames from Swift app instead of MSS)
- Removes all audio components
- Uses text-only responses
- Adds WebSocket server to communicate with Swift app
- Uses the proven Live API connection from original code

Setup:
pip install google-genai websockets python-dotenv

Usage:
python main_bridge.py
"""

import asyncio
import base64
import json
import logging
import os
import sys
import traceback
import websockets
from google import genai
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if sys.version_info < (3, 11, 0):
    import taskgroup, exceptiongroup
    asyncio.TaskGroup = taskgroup.TaskGroup
    asyncio.ExceptionGroup = exceptiongroup.ExceptionGroup

# Gemini Live API configuration
MODEL = "models/gemini-2.0-flash-live-001"
CONFIG = {"response_modalities": ["TEXT"]}  # Text only, no audio

client = genai.Client(http_options={"api_version": "v1beta"})

class TruthLensBridge:
    def __init__(self):
        self.frame_queue = None
        self.response_queue = None
        self.session = None
        self.websocket_clients = set()
        self.running = False

    async def handle_websocket_client(self, websocket):
        """Handle WebSocket connection from Swift app"""
        client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
        logger.info(f"Swift app connected: {client_id}")

        self.websocket_clients.add(websocket)

        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await self.process_swift_message(websocket, client_id, data)
                except json.JSONDecodeError as e:
                    logger.error(f"Invalid JSON from {client_id}: {e}")
                    await self.send_error(websocket, f"Invalid JSON: {str(e)}")
                except Exception as e:
                    logger.error(f"Error processing message from {client_id}: {e}")
                    await self.send_error(websocket, f"Processing error: {str(e)}")

        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Swift app {client_id} disconnected")
        except Exception as e:
            logger.error(f"WebSocket error with {client_id}: {e}")
        finally:
            self.websocket_clients.discard(websocket)

    async def process_swift_message(self, websocket, client_id, data):
        """Process messages from Swift app"""
        message_type = data.get("type")
        logger.info(f"Processing '{message_type}' from {client_id}")

        if message_type == "start_session":
            await self.send_success(websocket, "session_started", "Connected to Gemini AI Live")

        elif message_type == "screen_frame":
            # Add frame to processing queue
            if self.frame_queue:
                image_data_b64 = data.get("image_data")
                if image_data_b64:
                    frame_data = {
                        "mime_type": "image/jpeg",
                        "data": image_data_b64
                    }
                    try:
                        self.frame_queue.put_nowait(frame_data)
                    except asyncio.QueueFull:
                        logger.warning(f"Frame queue full, dropping frame from {client_id}")
                else:
                    await self.send_error(websocket, "No image_data in screen_frame")
            else:
                await self.send_error(websocket, "Gemini session not active")

        elif message_type == "stop_session":
            await self.send_success(websocket, "session_stopped", "Session ended")

        else:
            # Handle legacy format
            if "realtime_input" in data:
                logger.info(f"Converting legacy format from {client_id}")
                try:
                    media_chunks = data["realtime_input"]["media_chunks"]
                    if media_chunks and len(media_chunks) > 0:
                        image_data = media_chunks[0]["data"]
                        if self.frame_queue:
                            frame_data = {
                                "mime_type": "image/jpeg",
                                "data": image_data
                            }
                            try:
                                self.frame_queue.put_nowait(frame_data)
                            except asyncio.QueueFull:
                                logger.warning("Frame queue full, dropping legacy frame")
                        else:
                            await self.send_error(websocket, "Gemini session not active")
                        return
                except (KeyError, IndexError, TypeError) as e:
                    logger.error(f"Failed to convert legacy format: {e}")

            await self.send_error(websocket, f"Unknown message type: {message_type}")

    async def send_realtime_frames(self):
        """Send frames from queue to Gemini Live API"""
        while self.running:
            try:
                # Get frame from queue (with timeout to allow clean shutdown)
                frame = await asyncio.wait_for(self.frame_queue.get(), timeout=1.0)
                logger.info(f"Sending frame to Gemini (size: {len(frame['data'])} chars)")

                # Send the image frame
                await self.session.send(input=frame)

                # Send a text prompt to trigger analysis
                await self.session.send(
                    input="Please describe what you see in this screen capture in one clear sentence.",
                    end_of_turn=True
                )

            except asyncio.TimeoutError:
                continue  # Normal timeout, keep checking
            except Exception as e:
                logger.error(f"Error sending frame to Gemini: {e}")
                await asyncio.sleep(1)

    async def receive_gemini_responses(self):
        """Receive text responses from Gemini and send to Swift app"""
        while self.running:
            try:
                turn = self.session.receive()
                response_text = ""

                async for response in turn:
                    if text := response.text:
                        response_text += text
                        # Send partial responses as they arrive
                        logger.info(f"Gemini response: {text}")
                        await self.broadcast_to_swift({
                            "type": "analysis_response",
                            "text": text
                        })

                # Send final accumulated response if we have one
                if response_text:
                    logger.info(f"Complete Gemini response: {response_text[:100]}...")

            except Exception as e:
                logger.error(f"Error receiving from Gemini: {e}")
                await asyncio.sleep(1)

    async def broadcast_to_swift(self, message):
        """Send message to all connected Swift apps"""
        if not self.websocket_clients:
            return

        message_json = json.dumps(message)
        disconnected = set()

        for websocket in self.websocket_clients:
            try:
                await websocket.send(message_json)
            except websockets.exceptions.ConnectionClosed:
                disconnected.add(websocket)
            except Exception as e:
                logger.error(f"Error sending to Swift app: {e}")
                disconnected.add(websocket)

        # Clean up disconnected clients
        for websocket in disconnected:
            self.websocket_clients.discard(websocket)

    async def send_success(self, websocket, msg_type, message):
        """Send success message to specific Swift app"""
        response = {
            "type": msg_type,
            "message": message
        }
        await websocket.send(json.dumps(response))

    async def send_error(self, websocket, message):
        """Send error message to specific Swift app"""
        response = {
            "type": "error",
            "message": message
        }
        await websocket.send(json.dumps(response))

    async def run(self):
        """Main run loop with Gemini Live API and WebSocket server"""
        try:
            logger.info("Starting TruthLens Bridge Server")

            # Start WebSocket server
            websocket_server = await websockets.serve(
                self.handle_websocket_client,
                "localhost",
                9083
            )
            logger.info("WebSocket server started on localhost:9083")

            async with (
                client.aio.live.connect(model=MODEL, config=CONFIG) as session,
                asyncio.TaskGroup() as tg,
            ):
                self.session = session
                self.running = True

                # Initialize queues
                self.frame_queue = asyncio.Queue(maxsize=5)
                self.response_queue = asyncio.Queue()

                logger.info("Connected to Gemini Live API")

                # Start processing tasks
                tg.create_task(self.send_realtime_frames())
                tg.create_task(self.receive_gemini_responses())

                # Keep running until interrupted
                logger.info("Bridge server running. Press Ctrl+C to stop.")
                await asyncio.Future()  # Run forever

        except KeyboardInterrupt:
            logger.info("Shutting down...")
        except Exception as e:
            logger.error(f"Server error: {e}")
            traceback.print_exc()
        finally:
            self.running = False
            if hasattr(self, 'websocket_server'):
                websocket_server.close()
                await websocket_server.wait_closed()

async def main():
    """Start the bridge server"""
    if not os.getenv("GOOGLE_API_KEY"):
        logger.error("GOOGLE_API_KEY environment variable not set")
        return

    bridge = TruthLensBridge()
    await bridge.run()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        traceback.print_exc()