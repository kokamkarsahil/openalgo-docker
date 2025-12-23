# ------------------------------ Builder Stage ------------------------------ #
FROM python:3.12-bullseye AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml .

# Create isolated virtual-env with uv, then add gunicorn and eventlet
RUN pip install --no-cache-dir uv && \
    uv venv .venv && \
    uv pip install --upgrade pip && \
    uv sync && \
    uv pip install gunicorn eventlet==0.35.2 && \
    rm -rf /root/.cache

# ----------------------------- Production Stage ---------------------------- #
FROM python:3.12-slim-bullseye AS production

# Set timezone to IST (Asia/Kolkata) and install minimal runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata \
        curl && \
    ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home appuser

WORKDIR /app

# Copy the ready-made venv and source with correct ownership
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv
COPY --chown=appuser:appuser . .

# Create required directories with proper permissions
RUN mkdir -p /app/log /app/log/strategies /app/db /app/strategies \
             /app/strategies/scripts /app/strategies/examples /app/keys /app/logs && \
    chown -R appuser:appuser /app && \
    chmod -R 755 /app/strategies /app/log && \
    chmod 700 /app/keys && \
    touch /app/.env && chown appuser:appuser /app/.env && chmod 666 /app/.env

# Copy and fix entrypoint script
COPY --chown=appuser:appuser start.sh /app/start.sh
RUN sed -i 's/\r$//' /app/start.sh && chmod +x /app/start.sh

# ---- Runtime Environment -------------------------------------------------- #
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Kolkata \
    APP_MODE=standalone \
    # Default port for PaaS platforms (Coolify/Dokploy use PORT env var)
    PORT=5000

# Healthcheck for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-5000}/ || exit 1

USER appuser

# Expose main app port and websocket port
EXPOSE 5000
EXPOSE 8765

CMD ["/app/start.sh"]
