import json
import asyncio
import websockets
from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit

app = Flask(__name__)
socketio = SocketIO(app)

# Soniox WebSocket URL for real-time transcription
SONIOX_WS_URL = "wss://stt-rt.soniox.com/transcribe-websocket"
API_KEY = "7af1bd41330b8d95132b4f0e0e0924b6982745e7589d1945a4b4704cc70f581b"

# Store the WebSocket connections to send data to clients
clients = {}

async def transcribe_audio_to_soniox(client_ws, flutter_ws):
    """Handle Soniox transcription WebSocket connection."""
    try:
        # Send the connection parameters to Soniox API
        await client_ws.send(json.dumps({
            "api_key": API_KEY,
            "model": "stt-rt-preview",
            "audio_format": "auto",
            "result_format": "json",
            "enable_endpoint_detection": True
        }))
        
        # Relay audio data from Flutter to Soniox
        while True:
            audio_data = await flutter_ws.recv()  # Receive audio from Flutter
            await client_ws.send(audio_data)  # Send audio to Soniox for transcription
            
            transcription_data = await client_ws.recv()  # Receive transcription from Soniox
            data = json.loads(transcription_data)
            
            if "tokens" in data:
                tokens = data["tokens"]
                if tokens:
                    text = " ".join([token['text'] for token in tokens])
                    # Send transcription to Flutter client
                    socketio.emit("transcription_update", {"text": text}, namespace="/")
                    
                # Check for end of transcription (if Soniox returns <end>)
                if any(token.get('text') == "<end>" for token in tokens):
                    socketio.emit("transcription_complete", {"text": text}, namespace="/")
        
    except Exception as e:
        print(f"Error during transcription: {e}")
    finally:
        # Ensure that the connection is closed when done
        await client_ws.close()

# WebSocket route to communicate with the Flutter app
@socketio.on('connect', namespace='/')
def handle_connect():
    """Handle new WebSocket connection from Flutter."""
    clients[request.sid] = request.namespace
    print(f"Client {request.sid} connected")

# WebSocket route to handle audio stream from Flutter to Soniox
@socketio.on('start_transcription', namespace='/')
def start_transcription(message):
    """Start transcription and connect to Soniox WebSocket."""
    try:
        # Start WebSocket connection to Soniox
        asyncio.create_task(start_soniox_connection())
    except Exception as e:
        print(f"Error starting transcription: {e}")
        emit("error", {"message": "Error starting transcription"})

async def start_soniox_connection():
    """Initiate connection to Soniox WebSocket."""
    try:
        # Connect to Soniox WebSocket
        soniox_ws = await websockets.connect(SONIOX_WS_URL)
        print("Connected to Soniox WebSocket")

        # Use the first connected Flutter WebSocket client (the one that initiated the transcription)
        flutter_ws = clients.get(request.sid)
        if flutter_ws:
            await transcribe_audio_to_soniox(soniox_ws, flutter_ws)
        else:
            print("Flutter WebSocket client not found.")
            emit("error", {"message": "Flutter WebSocket client not found"})
    except Exception as e:
        print(f"Error during Soniox connection: {e}")
        emit("error", {"message": "Error connecting to Soniox"})

if __name__ == '__main__':
    # Run the app on port 5000 with SocketIO enabled
    socketio.run(app, host='0.0.0.0', port=5000)
