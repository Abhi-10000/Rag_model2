# Start with the standard, clean python:3.10 image
FROM python:3.10

# Set working directory
WORKDIR /app

# The only system dependency we might need is for python-docx, but it's
# usually handled by the Python package itself. This is a clean base.

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
