# Start with a base image that has Python
FROM python:3.10

# Set environment variables to be non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies, including curl for Ollama
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    poppler-utils \
    tesseract-ocr \
    libglib2.0-0 \
    libgl1-mesa-glx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Ollama
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application source code
COPY . .

# Expose the port for the FastAPI application
EXPOSE 8080

# --- The Entrypoint Script ---
# This script will start the Ollama server in the background, pull the model,
# and then start our FastAPI application.
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# The command to run when the container starts
CMD ["/app/entrypoint.sh"]
