#!/bin/bash

# Start the Ollama server in the background
/usr/bin/ollama serve &

# Wait a few seconds for the server to be ready
sleep 5

# Pull the model (this will happen only once during the first startup)
echo "Pulling the Ollama model (llama3:8b)..."
/usr/bin/ollama pull llama3:8b

echo "Model pulled. Starting FastAPI application..."

# Start the FastAPI application with Uvicorn
uvicorn main:app --host 0.0.0.0 --port 8080
