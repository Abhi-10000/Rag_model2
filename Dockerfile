# Start with the standard python:3.10 image
FROM python:3.10

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    poppler-utils \
    tesseract-ocr \
    libglib2.0-0 \
    libgl1-mesa-glx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- THIS IS THE KEY FIX ---
# Start the Ollama server in the background, pull the model to bake it into the image,
# and then stop the server. This happens only during the build process.
RUN nohup /usr/bin/ollama serve & sleep 5 && /usr/bin/ollama pull llama3:8b && pkill ollama

# Copy the rest of the application source code
COPY . .

# Expose the port for the FastAPI application
EXPOSE 8080

# The entrypoint script is now much simpler
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# The command to run when the container starts
CMD ["/app/entrypoint.sh"]
