# =============================================================================
# OpenAlgo Docker Image
# Optimized for Coolify, Dokploy, and Self-Hosted Cloud Deployments
# Multi-stage build: Python dependencies + Node frontend + Slim production
# =============================================================================

# ------------------------------ Python Builder Stage -----------------------
FROM python:3.12-slim-bookworm AS python-builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency specification first for caching
COPY pyproject.toml .

# Install dependencies using uv (fast Python package manager)
RUN pip install --no-cache-dir uv && \
    uv venv .venv && \
    uv pip install --upgrade pip && \
    uv sync && \
    uv pip install "gunicorn>=25.0,<26" eventlet==0.35.2 && \
    rm -rf /root/.cache /root/.uv

# ------------------------------ Frontend Builder Stage ---------------------
FROM node:22-bookworm-slim AS frontend-builder

WORKDIR /app

# Copy frontend package definitions and install dependencies
COPY frontend/package*.json ./frontend/
RUN cd frontend && npm ci

# Copy frontend source and build static bundle
COPY frontend/ ./frontend/
RUN cd frontend && npm run build

# ----------------------------- Production Stage ------------------------------
FROM python:3.12-slim-bookworm AS production

# Container metadata
LABEL org.opencontainers.image.title="OpenAlgo"
LABEL org.opencontainers.image.description="OpenAlgo Trading Platform - Optimized for Coolify/Dokploy/Docker"
LABEL org.opencontainers.image.source="https://github.com/marketcalls/openalgo"

# Install minimal runtime dependencies (including headless Chromium for Plotly export/Kaleido)
RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata \
        curl \
        tini \
        libopenblas0 \
        libgomp1 \
        libgfortran5 \
        chromium \
        fonts-liberation \
    && ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

# Pin non-root user appuser to UID/GID 1000 explicitly for volume permission compatibility
RUN groupadd --gid 1000 appuser && \
    useradd --create-home --uid 1000 --gid 1000 appuser

WORKDIR /app

# Copy virtual environment from python-builder
COPY --from=python-builder --chown=appuser:appuser /app/.venv /app/.venv

# Copy application source code
COPY --chown=appuser:appuser . .

# Copy built frontend assets from frontend-builder
COPY --from=frontend-builder --chown=appuser:appuser /app/frontend/dist /app/frontend/dist

# Copy startup script
COPY --chown=appuser:appuser start.sh /app/start.sh

# Create required runtime directories and configure permissions
RUN mkdir -p /app/log /app/log/strategies /app/db /app/tmp /app/tmp/numba_cache /app/tmp/matplotlib \
             /app/strategies /app/strategies/scripts /app/strategies/examples /app/keys /app/logs && \
    chown appuser:appuser /app && \
    chown -R appuser:appuser /app/log /app/db /app/tmp /app/strategies /app/keys /app/logs && \
    chmod -R 755 /app/strategies /app/log /app/tmp /app/logs && \
    chmod 700 /app/keys && \
    touch /app/.env && chown appuser:appuser /app/.env && chmod 666 /app/.env && \
    chmod +x /app/start.sh && \
    sed -i 's/\r$//' /app/start.sh

# Runtime environment settings
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Kolkata \
    APP_MODE=standalone \
    PORT=5000 \
    TMPDIR=/app/tmp \
    NUMBA_CACHE_DIR=/app/tmp/numba_cache \
    LLVMLITE_TMPDIR=/app/tmp \
    MPLCONFIGDIR=/app/tmp/matplotlib \
    OPENBLAS_NUM_THREADS=2 \
    OMP_NUM_THREADS=2 \
    MKL_NUM_THREADS=2 \
    NUMEXPR_NUM_THREADS=2 \
    NUMBA_NUM_THREADS=2 \
    BROWSER_PATH=/usr/bin/chromium \
    CHROME_BIN=/usr/bin/chromium

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -sf http://localhost:${PORT:-5000}/ || exit 1

# Switch to non-root user
USER appuser

# Expose HTTP app port and WebSocket proxy port
EXPOSE 5000 8765

# Use tini as init process for signal forwarding and process reaping
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/start.sh"]
