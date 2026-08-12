# Syntax=docker/dockerfile:1
# Optimized Multi-stage Dockerfile for OpenAlgo (marketcalls/openalgo)
# Built according to Astral uv & Node best practices for Coolify/Dokploy

# ==============================================================================
# Stage 1: Python Builder
# ==============================================================================
FROM python:3.12-slim-bookworm AS python-builder

# Build arguments for upstream source code fetching
ARG UPSTREAM_REPO="marketcalls/openalgo"
ARG UPSTREAM_REF="main"

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv from official Astral image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set uv environment variables for optimization
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Clone upstream OpenAlgo source if not building from local context
RUN git clone --depth 1 --branch ${UPSTREAM_REF} https://github.com/${UPSTREAM_REPO}.git /app/src \
    && cp -rn /app/src/* /app/ \
    && rm -rf /app/src /app/.git

# Create virtual environment and install dependencies
RUN uv venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

RUN if [ -f "pyproject.toml" ]; then \
        uv pip install --no-cache -e . gunicorn eventlet; \
    elif [ -f "requirements.txt" ]; then \
        uv pip install --no-cache -r requirements.txt gunicorn eventlet; \
    else \
        uv pip install --no-cache gunicorn eventlet; \
    fi

# ==============================================================================
# Stage 2: Frontend Builder (React 19 / Vite)
# ==============================================================================
FROM node:22-slim AS frontend-builder

WORKDIR /app

# Copy python-builder source to access frontend directory
COPY --from=python-builder /app/frontend ./frontend

# Install dependencies and build static assets
RUN cd frontend \
    && if [ -f "package-lock.json" ]; then npm ci; else npm install; fi \
    && npm run build

# ==============================================================================
# Stage 3: Production Runtime
# ==============================================================================
FROM python:3.12-slim-bookworm AS production

# Set timezone to Asia/Kolkata (IST) & install runtime packages
# Note: chromium and fonts-liberation are required by Plotly/Kaleido 1.x static chart generation
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    fonts-liberation \
    tzdata \
    ca-certificates \
    curl \
    procps \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata

# Create dedicated non-root user and group pinned to UID/GID 1000
RUN groupadd --gid 1000 appuser && \
    useradd --create-home --uid 1000 --gid 1000 appuser

WORKDIR /app

# Copy virtual environment and backend source code from python-builder
COPY --from=python-builder --chown=appuser:appuser /app/.venv /app/.venv
COPY --from=python-builder --chown=appuser:appuser /app /app

# Copy compiled frontend static assets from frontend-builder
COPY --from=frontend-builder --chown=appuser:appuser /app/frontend/dist /app/frontend/dist

# Copy container entrypoint script
COPY --chown=appuser:appuser entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Ensure persistent directories exist with correct ownership
RUN mkdir -p /app/db /app/log /app/logs /app/strategies /app/keys /tmp/gunicorn_workers && \
    chown -R appuser:appuser /app /tmp/gunicorn_workers

# Environment variables
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED=1 \
    PORT=5000 \
    WEBSOCKET_PORT=8765 \
    BROWSER_PATH=/usr/bin/chromium \
    CHROME_BIN=/usr/bin/chromium \
    NUMBA_NUM_THREADS=2

# Switch to non-root user
USER appuser

# Expose ports: 5000 (Flask Web UI / REST API) and 8765 (WebSocket Proxy)
EXPOSE 5000 8765

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:5000/auth/check-setup || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
