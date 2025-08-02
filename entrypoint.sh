#!/bin/bash

# Start the Ollama server in the background
/usr/bin/ollama serve &

# --- ROBUST HEALTH CHECK ---
# Wait for the Ollama server to be up and running before proceeding.
echo "Waiting for Ollama server to start..."
while ! curl -s http://localhost:11434/ > /dev/null; do
    echo "Ollama server not yet available, waiting..."
    sleep 1
done
echo "Ollama server is up and running."

# Pull the model (this will happen only once during the first startup)
echo "Pulling the Ollama model (llama3:8b)..."
/usr/bin/ollama pull llama3:8b

echo "Model pulled. Starting FastAPI application..."

# Start the FastAPI application with Uvicorn
uvicorn main:app --host 0.0.0.0 --port 8080
