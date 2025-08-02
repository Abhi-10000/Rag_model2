# Start with an official NVIDIA CUDA base image. This includes the necessary drivers.
FROM nvidia/cuda:12.1.0-base-ubuntu22.04

# Set environment variables to be non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install Python, pip, and all other necessary system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    curl \
    poppler-utils \
    tesseract-ocr \
    libglib2.0-0 \
    libgl1-mesa-glx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Ollama (it will automatically detect and use the GPU drivers)
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the rest of the application source code
COPY . .

# Expose the port for the FastAPI application
EXPOSE 8080

# The entrypoint script will start Ollama and then the FastAPI app
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# The command to run when the container starts
CMD ["/app/entrypoint.sh"]
