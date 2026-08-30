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

# 1. Environment Variable / .env Generation & Reconciliation
HOST_SERVER_VAL="${HOST_SERVER:-http://localhost:5000}"
HOST_DOMAIN="${HOST_SERVER_VAL#https://}"
HOST_DOMAIN="${HOST_DOMAIN#http://}"

if [ -z "$WEBSOCKET_URL" ]; then
    if [[ "$HOST_SERVER_VAL" == https://* ]]; then
        WS_URL_VAL="wss://${HOST_DOMAIN}/ws"
    else
        WS_URL_VAL="ws://${HOST_DOMAIN%:*}:${WS_PORT}"
    fi
else
    WS_URL_VAL="$WEBSOCKET_URL"
fi

# Auto-generate keys if not supplied
if [ -z "$APP_KEY" ]; then
    APP_KEY="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(32))')"
fi

if [ -z "$API_KEY_PEPPER" ]; then
    API_KEY_PEPPER="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(32))')"
fi

if [ -z "$FERNET_SALT" ]; then
    FERNET_SALT="$(/app/.venv/bin/python -c 'import secrets; print(secrets.token_hex(16))')"
fi

# Helper function to ensure variable exists in .env
ensure_env_var() {
    local key="$1"
    local value="$2"
    if ! grep -q "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null; then
        echo "${key} = '${value}'" >> "$ENV_FILE"
    fi
}

if [ ! -f "$ENV_FILE" ]; then
    echo "[OpenAlgo] Generating dynamic .env file..."
    cat > "$ENV_FILE" << EOF
# OpenAlgo Auto-Generated Environment Configuration
ENV_CONFIG_VERSION = '1.0.7'

# Server & Host Settings
HOST_SERVER = '${HOST_SERVER_VAL}'
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

# Rate Limit Settings
LOGIN_RATE_LIMIT_MIN = '${LOGIN_RATE_LIMIT_MIN:-5 per minute}'
LOGIN_RATE_LIMIT_HOUR = '${LOGIN_RATE_LIMIT_HOUR:-25 per hour}'
RESET_RATE_LIMIT = '${RESET_RATE_LIMIT:-15 per hour}'
API_RATE_LIMIT = '${API_RATE_LIMIT:-50 per second}'
ORDER_RATE_LIMIT = '${ORDER_RATE_LIMIT:-10 per second}'
SMART_ORDER_RATE_LIMIT = '${SMART_ORDER_RATE_LIMIT:-10 per second}'
WEBHOOK_RATE_LIMIT = '${WEBHOOK_RATE_LIMIT:-100 per minute}'
STRATEGY_RATE_LIMIT = '${STRATEGY_RATE_LIMIT:-200 per minute}'
SESSION_EXPIRY_TIME = '${SESSION_EXPIRY_TIME:-03:00}'

# WebSocket Proxy Settings
WEBSOCKET_HOST = '0.0.0.0'
WEBSOCKET_PORT = '${WS_PORT}'
WEBSOCKET_URL = '${WS_URL_VAL}'

# Logging Configuration
LOG_TO_FILE = '${LOG_TO_FILE:-True}'
LOG_DIR = '${LOG_DIR:-log}'
LOG_FORMAT = '${LOG_FORMAT:-[%(asctime)s] %(levelname)s in %(module)s: %(message)s}'
LOG_RETENTION = '${LOG_RETENTION:-14}'
LOG_COLORS = 'True'
FORCE_COLOR = '1'

# Network & Security
NGROK_ALLOW = '${NGROK_ALLOW:-FALSE}'
CORS_ENABLED = 'TRUE'
CORS_ALLOWED_ORIGINS = '${HOST_SERVER_VAL}'
CORS_ALLOWED_METHODS = 'GET,POST,DELETE,PUT,PATCH'
CORS_ALLOWED_HEADERS = 'Content-Type,Authorization,X-Requested-With'
CORS_EXPOSED_HEADERS = ''
CORS_ALLOW_CREDENTIALS = 'FALSE'
CORS_MAX_AGE = '86400'
CSP_ENABLED = 'TRUE'
CSP_REPORT_ONLY = 'FALSE'
SESSION_COOKIE_NAME = 'session'
CSRF_COOKIE_NAME = 'csrf_token'
CSRF_ENABLED = 'TRUE'

# Persistent Database Paths
DATABASE_URL = '${DATABASE_URL:-sqlite:///db/openalgo.db}'
LOGS_DATABASE_URL = '${LOGS_DATABASE_URL:-sqlite:///db/logs.db}'
SANDBOX_DATABASE_URL = '${SANDBOX_DATABASE_URL:-sqlite:///db/sandbox.db}'
LATENCY_DATABASE_URL = '${LATENCY_DATABASE_URL:-sqlite:///db/latency.db}'
HEALTH_DATABASE_URL = '${HEALTH_DATABASE_URL:-sqlite:///db/health.db}'
HISTORIFY_DATABASE_URL = '${HISTORIFY_DATABASE_URL:-db/historify.duckdb}'
EOF
    echo "[OpenAlgo] .env file successfully created."
else
    echo "[OpenAlgo] Existing .env file found. Checking for missing required configuration..."
    ensure_env_var "ENV_CONFIG_VERSION" "1.0.7"
    ensure_env_var "HOST_SERVER" "${HOST_SERVER_VAL}"
    ensure_env_var "REDIRECT_URL" "${REDIRECT_URL:-http://localhost:5000/broker/callback}"
    ensure_env_var "BROKER_API_KEY" "${BROKER_API_KEY:-}"
    ensure_env_var "BROKER_API_SECRET" "${BROKER_API_SECRET:-}"
    ensure_env_var "BROKER_API_KEY_MARKET" "${BROKER_API_KEY_MARKET:-}"
    ensure_env_var "BROKER_API_SECRET_MARKET" "${BROKER_API_SECRET_MARKET:-}"
    ensure_env_var "VALID_BROKERS" "${VALID_BROKERS:-fivepaisa,fivepaisaxts,aliceblue,angel,arrow,compositedge,definedge,deltaexchange,dhan,dhan_sandbox,firstock,flattrade,fyers,groww,hdfcsecurities,hdfcsky,ibulls,iifl,iiflcapital,indmoney,jainamxts,kotak,motilal,mstock,nubra,paytm,pocketful,rmoney,samco,shoonya,tradejini,tradesmart,upstox,wisdom,zebu,zerodha}"
    ensure_env_var "APP_KEY" "${APP_KEY}"
    ensure_env_var "API_KEY_PEPPER" "${API_KEY_PEPPER}"
    ensure_env_var "FERNET_SALT" "${FERNET_SALT}"
    ensure_env_var "DATABASE_URL" "${DATABASE_URL:-sqlite:///db/openalgo.db}"
    ensure_env_var "LATENCY_DATABASE_URL" "${LATENCY_DATABASE_URL:-sqlite:///db/latency.db}"
    ensure_env_var "LOGS_DATABASE_URL" "${LOGS_DATABASE_URL:-sqlite:///db/logs.db}"
    ensure_env_var "HEALTH_DATABASE_URL" "${HEALTH_DATABASE_URL:-sqlite:///db/health.db}"
    ensure_env_var "SANDBOX_DATABASE_URL" "${SANDBOX_DATABASE_URL:-sqlite:///db/sandbox.db}"
    ensure_env_var "HISTORIFY_DATABASE_URL" "${HISTORIFY_DATABASE_URL:-db/historify.duckdb}"
    ensure_env_var "NGROK_ALLOW" "${NGROK_ALLOW:-FALSE}"
    ensure_env_var "FLASK_HOST_IP" "0.0.0.0"
    ensure_env_var "FLASK_PORT" "${APP_PORT}"
    ensure_env_var "FLASK_DEBUG" "${FLASK_DEBUG:-False}"
    ensure_env_var "FLASK_ENV" "${FLASK_ENV:-production}"
    ensure_env_var "LOGIN_RATE_LIMIT_MIN" "${LOGIN_RATE_LIMIT_MIN:-5 per minute}"
    ensure_env_var "LOGIN_RATE_LIMIT_HOUR" "${LOGIN_RATE_LIMIT_HOUR:-25 per hour}"
    ensure_env_var "RESET_RATE_LIMIT" "${RESET_RATE_LIMIT:-15 per hour}"
    ensure_env_var "API_RATE_LIMIT" "${API_RATE_LIMIT:-50 per second}"
    ensure_env_var "ORDER_RATE_LIMIT" "${ORDER_RATE_LIMIT:-10 per second}"
    ensure_env_var "SMART_ORDER_RATE_LIMIT" "${SMART_ORDER_RATE_LIMIT:-10 per second}"
    ensure_env_var "WEBHOOK_RATE_LIMIT" "${WEBHOOK_RATE_LIMIT:-100 per minute}"
    ensure_env_var "STRATEGY_RATE_LIMIT" "${STRATEGY_RATE_LIMIT:-200 per minute}"
    ensure_env_var "SESSION_EXPIRY_TIME" "${SESSION_EXPIRY_TIME:-03:00}"
    ensure_env_var "WEBSOCKET_HOST" "0.0.0.0"
    ensure_env_var "WEBSOCKET_PORT" "${WS_PORT}"
    ensure_env_var "WEBSOCKET_URL" "${WS_URL_VAL}"
    ensure_env_var "LOG_TO_FILE" "${LOG_TO_FILE:-True}"
    ensure_env_var "LOG_LEVEL" "${LOG_LEVEL:-INFO}"
    ensure_env_var "LOG_DIR" "${LOG_DIR:-log}"
    ensure_env_var "LOG_FORMAT" "${LOG_FORMAT:-[%(asctime)s] %(levelname)s in %(module)s: %(message)s}"
    ensure_env_var "LOG_RETENTION" "${LOG_RETENTION:-14}"
    ensure_env_var "LOG_COLORS" "True"
    ensure_env_var "FORCE_COLOR" "1"
    ensure_env_var "CORS_ENABLED" "TRUE"
    ensure_env_var "CORS_ALLOWED_ORIGINS" "${HOST_SERVER_VAL}"
    ensure_env_var "CORS_ALLOWED_METHODS" "GET,POST,DELETE,PUT,PATCH"
    ensure_env_var "CORS_ALLOWED_HEADERS" "Content-Type,Authorization,X-Requested-With"
    ensure_env_var "CORS_EXPOSED_HEADERS" ""
    ensure_env_var "CORS_ALLOW_CREDENTIALS" "FALSE"
    ensure_env_var "CORS_MAX_AGE" "86400"
    ensure_env_var "CSP_ENABLED" "TRUE"
    ensure_env_var "CSP_REPORT_ONLY" "FALSE"
    ensure_env_var "SESSION_COOKIE_NAME" "session"
    ensure_env_var "CSRF_COOKIE_NAME" "csrf_token"
    ensure_env_var "CSRF_ENABLED" "TRUE"
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
