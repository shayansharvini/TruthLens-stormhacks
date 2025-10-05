"""
TruthLens News Detector Bridge
"""

import asyncio
import base64
import json
import logging
import os
import traceback
import websockets

from dotenv import load_dotenv
from google import genai
from google.genai import types

# ----------------------------
# Setup
# ----------------------------
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TruthLensNews")

MODEL = "gemini-2.5-pro" 

client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"), http_options={"api_version": "v1"})

# ----------------------------
# Utils
# ----------------------------
def decode_base64_image(image_b64: str) -> bytes:
    """Decode base64 image data, stripping data URI prefix if present."""
    if image_b64.startswith("data:image"):
        # Remove "data:image/jpeg;base64," prefix
        image_b64 = image_b64.split(",", 1)[1]
    try:
        return base64.b64decode(image_b64)
    except Exception as e:
        logger.error(f"Base64 decode failed: {e}")
        return b""


async def analyze_screenshot(image_bytes: bytes) -> str:
    """Send screenshot to Gemini for fact checking news articles."""
    if not image_bytes:
        return "ERROR: Empty image data"

    try:

        grounding_tool = types.Tool(
            google_search=types.GoogleSearch()
        )

        config = types.GenerateContentConfig(
            tools=[grounding_tool]
        )
    
        resp = client.models.generate_content(
            model=MODEL,
            contents=[
                {
                    "role": "user",
                    "parts": [
                        {
                            "text": (
                                "** The only two words you are allowed to use is 'TRUE' and 'FASLE'.**\n"
                                "** Always do research before claiming soemthing is 'TRUE' OR 'FALSE'**"
                                "You are a news fact checker.\n"
                                "You will recieve screen shots, your job is too look for anything related to news"
                                "- If you see a news article, use the Google Search tool"
                                "to verify if the article is True or False.\n"
                                "- If you can find vaild information to prove the article is real (you need at least 1 different sources per news article), respond exactly with 'TRUE'.\n"
                                "- If you cant find vaild information to prove the article is real (you need at least 1 different sources per news article), respond exactly with 'FALSE'.\n"
                                "- If you do not see a news article, Do not output text\n"
                                "- Do not have a bais you will recieve many different news articles you last answer should dont dictate your next answer.\n"
                                "- There is only two possible answers when you see a news artical 'TRUE' and 'FALSE' its your job to figure out what news is true and what news is false."
                            )
                        },
                        {"inline_data": {"mime_type": "image/jpeg", "data": image_bytes}},
                    ],
                }
            ],
            
        )

        return resp.text.strip() if resp.text else "NO RESPONSE"
    except Exception as e:
        logger.error(f"Gemini analysis failed: {e}")
        return "ERROR: Gemini failed"


# ----------------------------
# WebSocket Server
# ----------------------------
class TruthLensNewsBridge:
    def __init__(self):
        self.websocket_clients = set()

    async def handle_client(self, websocket):
        client_id = f"{websocket.remote_address}"
        logger.info(f"Swift connected: {client_id}")
        self.websocket_clients.add(websocket)

        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                except json.JSONDecodeError:
                    await self.send_error(websocket, "Invalid JSON")
                    continue

                msg_type = data.get("type")

                if msg_type == "screen_frame":
                    image_b64 = data.get("image_data")
                    if not image_b64:
                        await self.send_error(websocket, "No image_data in message")
                        continue

                    image_bytes = decode_base64_image(image_b64)
                    result_text = await analyze_screenshot(image_bytes)

                    await self.send_to_client(websocket, {
                        "type": "analysis_response",
                        "text": result_text
                    })

                elif msg_type == "start_session":
                    await self.send_to_client(websocket, {
                        "type": "session_started",
                        "message": "Connected to News Detector Bridge"
                    })

                elif msg_type == "stop_session":
                    await self.send_to_client(websocket, {
                        "type": "session_stopped",
                        "message": "Stopped session"
                    })

                else:
                    await self.send_error(websocket, f"Unknown message type: {msg_type}")

        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Swift disconnected: {client_id}")
        finally:
            self.websocket_clients.discard(websocket)

    async def send_to_client(self, websocket, message):
        try:
            await websocket.send(json.dumps(message))
        except Exception as e:
            logger.error(f"Send error: {e}")

    async def send_error(self, websocket, msg: str):
        await self.send_to_client(websocket, {"type": "error", "message": msg})

    async def run(self):
        await websockets.serve(
            self.handle_client,
            "localhost",
            9083,
            max_size=10 * 1024 * 1024
        )
        logger.info("News Detector Bridge running at ws://localhost:9083")
        await asyncio.Future()  # run forever

# ----------------------------
# Entrypoint
# ----------------------------
if __name__ == "__main__":
    if not os.getenv("GOOGLE_API_KEY"):
        logger.error("GOOGLE_API_KEY not set in .env")
        exit(1)

    try:
        asyncio.run(TruthLensNewsBridge().run())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        traceback.print_exc()
