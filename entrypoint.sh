#!/usr/bin/env bash
set -e

echo "================================================================="
echo "🚀 OpenAlgo Container Starting..."
echo "================================================================="

# Set working directory
CDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CDIR"

ENV_FILE="/app/.env"
APP_PORT="${PORT:-5000}"
WS_PORT="${WEBSOCKET_PORT:-8765}"

# Ensure directories exist before file operations or migrations
mkdir -p /tmp/gunicorn_workers /app/db /app/log /app/log/strategies /app/logs /app/strategies /app/strategies/scripts /app/keys /app/tmp

# 1. Environment Variable / .env Generation
if [ ! -f "$ENV_FILE" ]; then
    echo "[OpenAlgo] Generating dynamic .env file..."
    
    # Auto-generate APP_KEY if not supplied
    if [ -z "$APP_KEY" ]; then
        echo "[OpenAlgo] APP_KEY not provided. Auto-generating secure secret key..."
        APP_KEY="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(32))')"
    fi

    # Auto-generate API_KEY_PEPPER if not supplied
    if [ -z "$API_KEY_PEPPER" ]; then
        echo "[OpenAlgo] API_KEY_PEPPER not provided. Auto-generating secure pepper..."
        API_KEY_PEPPER="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(32))')"
    fi

    # Auto-generate FERNET_SALT if not supplied
    if [ -z "$FERNET_SALT" ]; then
        FERNET_SALT="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(16))')"
    fi

    cat > "$ENV_FILE" << EOF
# OpenAlgo Auto-Generated Environment Configuration
ENV_CONFIG_VERSION = '1.0.7'

# Server & Host Settings
HOST_SERVER = '${HOST_SERVER:-http://localhost:5000}'
REDIRECT_URL = '${REDIRECT_URL:-http://localhost:5000/broker/callback}'

# Secret Keys
APP_KEY = '${APP_KEY}'
API_KEY_PEPPER = '${API_KEY_PEPPER}'
FERNET_SALT = '${FERNET_SALT}'

# Broker Authentication
BROKER_API_KEY = '${BROKER_API_KEY:-}'
BROKER_API_SECRET = '${BROKER_API_SECRET:-}'
BROKER_API_KEY_MARKET = '${BROKER_API_KEY_MARKET:-}'
BROKER_API_SECRET_MARKET = '${BROKER_API_SECRET_MARKET:-}'

# Valid Brokers
VALID_BROKERS = '${VALID_BROKERS:-fivepaisa,fivepaisaxts,aliceblue,angel,arrow,compositedge,definedge,deltaexchange,dhan,dhan_sandbox,firstock,flattrade,fyers,groww,hdfcsecurities,hdfcsky,ibulls,iifl,iiflcapital,indmoney,jainamxts,kotak,motilal,mstock,nubra,paytm,pocketful,rmoney,samco,shoonya,tradejini,tradesmart,upstox,wisdom,zebu,zerodha}'

# Ports & Application Settings
FLASK_HOST_IP = '0.0.0.0'
FLASK_PORT = '${APP_PORT}'
FLASK_DEBUG = '${FLASK_DEBUG:-False}'
FLASK_ENV = '${FLASK_ENV:-production}'
LOG_LEVEL = '${LOG_LEVEL:-INFO}'

# WebSocket Proxy Settings
WEBSOCKET_HOST = '0.0.0.0'
WEBSOCKET_PORT = '${WS_PORT}'

# Persistent Database Paths
DATABASE_URL = '${DATABASE_URL:-sqlite:///db/openalgo.db}'
LOGS_DATABASE_URL = '${LOGS_DATABASE_URL:-sqlite:///db/logs.db}'
SANDBOX_DATABASE_URL = '${SANDBOX_DATABASE_URL:-sqlite:///db/sandbox.db}'
LATENCY_DATABASE_URL = '${LATENCY_DATABASE_URL:-sqlite:///db/latency.db}'
HEALTH_DATABASE_URL = '${HEALTH_DATABASE_URL:-sqlite:///db/health.db}'
HISTORIFY_DATABASE_URL = '${HISTORIFY_DATABASE_URL:-db/historify.duckdb}'
EOF
    echo "[OpenAlgo] .env file successfully created."
fi

# 2. Pre-flight Security Verification
if grep -q "CHANGE_THIS" "$ENV_FILE" 2>/dev/null; then
    echo "⚠️ [WARNING] Placeholder keys detected in .env file! Updating with random secure keys..."
    NEW_KEY="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(32))')"
    sed -i "s/CHANGE_THIS.*/${NEW_KEY}/g" "$ENV_FILE"
fi

# 3. Database Schema Migrations
if [ -f "/app/upgrade/migrate_all.py" ]; then
    echo "[OpenAlgo] Running database schema migrations..."
    /app/.venv/bin/python /app/upgrade/migrate_all.py || echo "⚠️ [OpenAlgo] Migrations finished with warnings."
else
    echo "[OpenAlgo] Migration script upgrade/migrate_all.py not found. Skipping migrations."
fi

# 4. Start Background WebSocket Proxy
echo "[OpenAlgo] Starting WebSocket proxy server on port ${WS_PORT}..."
/app/.venv/bin/python -m websocket_proxy.server &
WEBSOCKET_PID=$!
echo "[OpenAlgo] WebSocket proxy server started with PID $WEBSOCKET_PID"

# Signal handling and cleanup
cleanup() {
    echo "[OpenAlgo] Shutting down gracefully..."
    if [ -n "$WEBSOCKET_PID" ]; then
        kill "$WEBSOCKET_PID" 2>/dev/null || true
    fi
    exit 0
}
trap cleanup SIGTERM SIGINT

# 5. Launch Main Application
echo "[OpenAlgo] Starting Gunicorn server with eventlet worker on port ${APP_PORT}..."
exec /app/.venv/bin/gunicorn \
    --worker-class eventlet \
    --workers 1 \
    --bind "0.0.0.0:${APP_PORT}" \
    --timeout 300 \
    --graceful-timeout 30 \
    --worker-tmp-dir /tmp/gunicorn_workers \
    --no-control-socket \
    --access-logfile - \
    --error-logfile - \
    app:app
