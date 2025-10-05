# pip install --upgrade google-genai==0.3.0
import asyncio
import json
import os
import websockets
from google import genai
import base64
from dotenv import load_dotenv

# Load .env file
load_dotenv()

# Get API key from environment
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY not found in .env file!")

# Choose model
MODEL = "gemini-2.0-flash-exp"

# Create client with API key
client = genai.Client(
    api_key=api_key,
    http_options={"api_version": "v1alpha"},
)

async def gemini_session_handler(client_websocket):
    """Handles the interaction with Gemini API within a websocket session."""
    try:
        config_message = await client_websocket.recv()
        config_data = json.loads(config_message)
        config = config_data.get("setup", {})
        config["system_instruction"] = (
            "You are a helpful assistant for screen sharing sessions. Your role is to:\n"
            "1) Analyze and describe the content being shared on screen\n"
            "2) Answer questions about the shared content\n"
            "3) Provide relevant information and context about what's being shown\n"
            "4) Assist with technical issues related to screen sharing\n"
            "5) Maintain a professional and helpful tone. Focus on being concise and clear."
        )

        async with client.aio.live.connect(model=MODEL, config=config) as session:
            print("Connected to Gemini API")

            async def send_to_gemini():
                try:
                    async for message in client_websocket:
                        try:
                            data = json.loads(message)
                            if "realtime_input" in data:
                                for chunk in data["realtime_input"]["media_chunks"]:
                                    if chunk["mime_type"] == "audio/pcm":
                                        await session.send({
                                            "mime_type": "audio/pcm",
                                            "data": chunk["data"]
                                        })
                                    elif chunk["mime_type"] == "image/jpeg":
                                        await session.send({
                                            "mime_type": "image/jpeg",
                                            "data": chunk["data"]
                                        })
                        except Exception as e:
                            print(f"Error sending to Gemini: {e}")
                    print("Client connection closed (send)")
                except Exception as e:
                    print(f"Error sending to Gemini: {e}")
                finally:
                    print("send_to_gemini closed")

            async def receive_from_gemini():
                try:
                    while True:
                        try:
                            print("Receiving from Gemini")
                            async for response in session.receive():
                                if response.server_content is None:
                                    print(f'Unhandled server message! - {response}')
                                    continue

                                model_turn = response.server_content.model_turn
                                if model_turn:
                                    for part in model_turn.parts:
                                        if hasattr(part, "text") and part.text is not None:
                                            await client_websocket.send(
                                                json.dumps({"text": part.text})
                                            )
                                        elif hasattr(part, "inline_data") and part.inline_data is not None:
                                            print("Audio mime_type:", part.inline_data.mime_type)
                                            base64_audio = base64.b64encode(
                                                part.inline_data.data
                                            ).decode("utf-8")
                                            await client_websocket.send(
                                                json.dumps({"audio": base64_audio})
                                            )
                                            print("Audio received")

                                if response.server_content.turn_complete:
                                    print("\n<Turn complete>")
                        except websockets.exceptions.ConnectionClosedOK:
                            print("Client connection closed normally (receive)")
                            break
                        except Exception as e:
                            print(f"Error receiving from Gemini: {e}")
                            break
                except Exception as e:
                    print(f"Error receiving from Gemini: {e}")
                finally:
                    print("Gemini connection closed (receive)")

            # Start loops
            send_task = asyncio.create_task(send_to_gemini())
            receive_task = asyncio.create_task(receive_from_gemini())
            await asyncio.gather(send_task, receive_task)

    except Exception as e:
        print(f"Error in Gemini session: {e}")
    finally:
        print("Gemini session closed.")

async def main() -> None:
    async with websockets.serve(gemini_session_handler, "0.0.0.0", 9083):
        print("Running websocket server on localhost:9083...")
        await asyncio.Future()  # keep running forever

if __name__ == "__main__":
    asyncio.run(main())
