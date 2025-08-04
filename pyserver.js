const express = require("express");
const ws = require("ws");
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs"); // To handle file saving (temporary storage for audio data)

const app = express();

// WebSocket server setup
const wsServer = new ws.Server({ noServer: true });

// Soniox API key (make sure this is correct and secured)
const SONIOX_API_KEY = "7af1bd41330b8d95132b4f0e0e0924b6982745e7589d1945a4b4704cc70f581b";

// WebSocket connection handling
wsServer.on("connection", (socket) => {
  console.log("WebSocket connected");

  socket.on("message", async (message) => {
    console.log("Received audio data");

    // For testing, save the incoming audio data to a temporary file
    const audioFilePath = "temp_audio.wav"; // Temporary file to hold audio data
    fs.writeFileSync(audioFilePath, message);

    try {
      // Transcribe the audio file using Soniox API
      const transcription = await transcribeWithSoniox(audioFilePath);
      console.log("Transcription from Soniox: ", transcription);

      // Send the transcription back to the client via WebSocket
      socket.send(JSON.stringify({ transcription }));
    } catch (error) {
      console.error("Error transcribing with Soniox:", error);
      socket.send(JSON.stringify({ error: "Transcription failed" }));
    } finally {
      // Clean up the temporary file after processing
      fs.unlinkSync(audioFilePath);
    }
  });
});

// Function to transcribe audio with Soniox API (using HTTP POST)
async function transcribeWithSoniox(audioFilePath) {
  const form = new FormData();
  
  // Attach the audio file to the form data
  form.append("file", fs.createReadStream(audioFilePath), {
    filename: "audio.wav", // You can adjust this based on the file format
    contentType: "audio/wav", // Make sure this matches the file format
  });

  try {
    // Send the audio data to Soniox's transcription API
    const response = await axios.post("https://stt-rt.soniox.com/v1/transcribe", form, {
      headers: {
        ...form.getHeaders(),
        "Authorization": `Bearer ${SONIOX_API_KEY}`,
      },
    });

    // Return the transcription text from the Soniox response
    return response.data.text;  // Adjust this according to Soniox API response format
  } catch (error) {
    console.error("Error in Soniox API call:", error);
    throw new Error("Error transcribing with Soniox");
  }
}

// Setting up the HTTP server with WebSocket upgrade handling
const server = app.listen(3000, () => {
  console.log("Server is running on port 3000");
});

server.on("upgrade", (request, socket, head) => {
  wsServer.handleUpgrade(request, socket, head, (socket) => {
    wsServer.emit("connection", socket, request);
  });
});
