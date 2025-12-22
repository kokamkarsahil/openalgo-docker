# syntax=docker/dockerfile:1

# Base image
FROM python:3.10-slim-bullseye as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_ENV=production \
    APP_MODE=standalone \
    FLASK_HOST_IP=0.0.0.0 \
    WEBSOCKET_HOST=0.0.0.0

WORKDIR /app

# Install system dependencies (curl and supervisor)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    supervisor \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
# We copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories for persistence
RUN mkdir -p /app/log /app/logs /app/keys /app/db /app/strategies \
    && chmod -R 755 /app/log /app/logs /app/strategies

# Configuration for Supervisor (runs both Flask and Websockets)
RUN echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "[program:flask]" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "command=python3 app.py" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "[program:websocket]" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "command=python3 websocket_server.py" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf

# Expose ports (Flask: 5000, WebSocket: 8765)
EXPOSE 5000 8765

# Volume definitions for persistence
VOLUME ["/app/db", "/app/keys", "/app/strategies", "/app/logs"]

# Start Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
