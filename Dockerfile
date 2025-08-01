# Start with a slightly more feature-complete base image than 'slim'
FROM python:3.10

# Set working directory
WORKDIR /app

# Install all necessary system dependencies for Unstructured and its sub-dependencies
# This includes libraries for handling images, PDFs, and various text encodings.
RUN apt-get update && apt-get install -y --no-install-recommends \
    # For Unstructured PDF parsing
    poppler-utils \
    # For Tesseract OCR (images inside PDFs)
    tesseract-ocr \
    # For the libgthread error and other common library needs
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application source code
COPY . .

# Set environment variable and expose port for the cloud environment
ENV PORT=8080
EXPOSE 8080

# The command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
