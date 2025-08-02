# Start with the standard python:3.10 image
FROM python:3.10

# Set working directory
WORKDIR /app

# Install system dependencies for Unstructured and Ollama
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    poppler-utils \
    tesseract-ocr \
    libglib2.0-0 \
    libgl1-mesa-glx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama (will run in CPU mode)
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application source code
COPY . .

# Expose the port for the FastAPI application
EXPOSE 8080

# The entrypoint script remains the same
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# The command to run when the container starts
CMD ["/app/entrypoint.sh"]
