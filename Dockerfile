# =============================================================================
# OpenAlgo Docker Image
# Optimized for Coolify/Dokploy deployment
# =============================================================================

# ------------------------------ Builder Stage --------------------------------
FROM python:3.12-slim-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency specification first for better layer caching
COPY pyproject.toml .

# Install dependencies using uv (fast Python package manager)
RUN pip install --no-cache-dir uv && \
    uv venv .venv && \
    uv pip install --upgrade pip && \
    uv sync && \
    uv pip install gunicorn eventlet==0.35.2 && \
    rm -rf /root/.cache /root/.uv

# ----------------------------- Production Stage ------------------------------
FROM python:3.12-slim-bookworm AS production

# Labels for container metadata
LABEL org.opencontainers.image.title="OpenAlgo"
LABEL org.opencontainers.image.description="OpenAlgo Trading Platform - Optimized for Coolify/Dokploy"
LABEL org.opencontainers.image.source="https://github.com/marketcalls/openalgo"

# Install minimal runtime dependencies and set timezone
RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata \
        curl \
        tini \
    && ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv

# Copy application source
COPY --chown=appuser:appuser . .

# Copy our custom start script (overrides upstream)
COPY --chown=appuser:appuser start.sh /app/start.sh

# Create required directories and set permissions
RUN mkdir -p /app/log /app/log/strategies /app/db /app/strategies \
             /app/strategies/scripts /app/strategies/examples /app/keys /app/logs && \
    chown -R appuser:appuser /app && \
    chmod -R 755 /app/strategies /app/log /app/logs && \
    chmod 700 /app/keys && \
    touch /app/.env && chown appuser:appuser /app/.env && chmod 644 /app/.env && \
    chmod +x /app/start.sh && \
    # Remove Windows line endings if any
    sed -i 's/\r$//' /app/start.sh

# Runtime environment
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Kolkata \
    APP_MODE=standalone \
    PORT=5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -sf http://localhost:${PORT:-5000}/ || exit 1

# Switch to non-root user
USER appuser

# Expose ports
EXPOSE 5000 8765

# Use tini as init system for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/start.sh"]
