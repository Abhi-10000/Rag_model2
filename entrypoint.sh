#!/bin/bash

# Start the Ollama server in the background. The model is already downloaded.
/usr/bin/ollama serve &

# Wait a few seconds for the server to initialize
sleep 3

echo "Ollama server started. Starting FastAPI application..."

# Start the FastAPI application with Uvicorn
uvicorn main:app --host 0.0.0.0 --port 8080
