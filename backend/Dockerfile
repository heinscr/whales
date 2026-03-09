FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Set environment
ENV PORT=8080

# Run with gunicorn
CMD exec gunicorn --bind :${PORT} --workers 4 --timeout 0 app:app
