# OpenAlgo Docker

Pre-built, production-ready Docker images for the [OpenAlgo](https://github.com/marketcalls/openalgo) trading platform, optimized for **Coolify**, **Dokploy**, **Railway**, and self-hosted cloud deployments.

---

## Features

- ⚡ **Ultra-fast Multi-Stage Build**: Uses `uv` (fast Python package manager) and Node 22 for pre-compiled Vite/React frontend assets.
- 📊 **Headless Chart Export**: Pre-installed `chromium` and `fonts-liberation` for Plotly static image rendering (Kaleido 1.x) in Telegram bot charts.
- 🔒 **Secure Non-Root User**: Runs as non-root `appuser` pinned to UID/GID `1000` for seamless host volume permission compatibility.
- 🔧 **Auto-Configured Environment**: Generates `.env` dynamically from environment variables on cloud platforms.
- 🛠️ **Automated Migrations**: Automatically runs database schema migrations (`upgrade/migrate_all.py`) on container startup.
- 🛡️ **Pre-flight Key Security**: Protects against default or leaked secret key usage on startup.
- 🚀 **Multi-Architecture**: Multi-arch builds for `linux/amd64` and `linux/arm64`.

---

## Supported Brokers

OpenAlgo supports 34+ brokers out of the box:

`aliceblue`, `angel`, `arrow`, `compositedge`, `definedge`, `deltaexchange`, `dhan`, `dhan_sandbox`, `firstock`, `fivepaisa`, `fivepaisaxts`, `flattrade`, `fyers`, `groww`, `hdfcsky`, `ibulls`, `iifl`, `iiflcapital`, `indmoney`, `jainamxts`, `kotak`, `motilal`, `mstock`, `nubra`, `paytm`, `pocketful`, `rmoney`, `samco`, `shoonya`, `tradejini`, `tradesmart`, `upstox`, `wisdom`, `zebu`, `zerodha`.

---

## Quick Start

### Using Docker Compose

```bash
# Clone this repository
git clone https://github.com/kokamkarsahil/openalgo-docker.git
cd openalgo-docker

# Create environment file
cp .env.example .env
# Edit .env with your configuration

# Start the container
docker compose up -d
```

### Using Standalone Docker

```bash
docker run -d \
  --name openalgo \
  -p 5000:5000 \
  -p 8765:8765 \
  -e HOST_SERVER=https://your-domain.com \
  -e REDIRECT_URL=https://your-domain.com/broker/callback \
  -e BROKER_API_KEY=your_api_key \
  -e BROKER_API_SECRET=your_api_secret \
  -e APP_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))") \
  -e API_KEY_PEPPER=$(python3 -c "import secrets; print(secrets.token_hex(32))") \
  -v openalgo_db:/app/db \
  -v openalgo_keys:/app/keys \
  ghcr.io/kokamkarsahil/openalgo:latest
```

---

## Required Environment Variables

| Variable | Description |
|---|---|
| `HOST_SERVER` | Your application base URL (e.g., `https://openalgo.example.com`) |
| `REDIRECT_URL` | OAuth callback URL for your broker |
| `BROKER_API_KEY` | Your broker's API key |
| `BROKER_API_SECRET` | Your broker's API secret |
| `APP_KEY` | 64-char hex application secret key (`python3 -c "import secrets; print(secrets.token_hex(32))"`) |
| `API_KEY_PEPPER` | 64-char hex API key pepper for hashing (`python3 -c "import secrets; print(secrets.token_hex(32))"`) |

---

## Optional Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `5000` | Application HTTP web port |
| `FLASK_ENV` | `production` | Flask environment |
| `LOG_LEVEL` | `INFO` | Logging verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`) |
| `WEBSOCKET_PORT` | `8765` | WebSocket proxy server port |
| `WEBSOCKET_URL` | Auto-detected | External WebSocket URL (auto-generated from `HOST_SERVER`) |
| `DATABASE_URL` | `sqlite:///db/openalgo.db` | Main database connection URL |
| `BROKER_API_KEY_MARKET` | Optional | Market data API key (required for XTS brokers) |
| `BROKER_API_SECRET_MARKET` | Optional | Market data API secret (required for XTS brokers) |

---

## Deployment Guides

### Coolify

1. Create a new **Docker Compose** service in Coolify.
2. Paste the contents of [`docker-compose.yml`](file:///home/ubuntu/Projects/openalgo-docker/docker-compose.yml).
3. Set your environment variables in the Coolify Dashboard (`HOST_SERVER`, `REDIRECT_URL`, `BROKER_API_KEY`, `BROKER_API_SECRET`, `APP_KEY`, `API_KEY_PEPPER`).
4. Click **Deploy**.

### Dokploy

1. Create a new **Docker Compose** application in Dokploy.
2. Use this repository URL or paste [`docker-compose.yml`](file:///home/ubuntu/Projects/openalgo-docker/docker-compose.yml).
3. Configure the required environment variables.
4. Click **Deploy**.

### Self-Hosted Nginx Reverse Proxy

```nginx
server {
    listen 443 ssl http2;
    server_name openalgo.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
```

---

## Storage & Volume Mounts

| Volume | Internal Container Path | Description |
|---|---|---|
| `openalgo_db` | `/app/db` | Persistent SQLite databases |
| `openalgo_logs` | `/app/logs` | Main application log files |
| `openalgo_log` | `/app/log` | Strategy log files |
| `openalgo_strategies` | `/app/strategies` | Custom user strategies and scripts |
| `openalgo_keys` | `/app/keys` | Encrypted API key storage |

---

## Building Locally

```bash
# Clone helper repository
git clone https://github.com/kokamkarsahil/openalgo-docker.git
cd openalgo-docker

# Build image using Docker Compose
docker compose build

# Or build directly with docker build
docker build -t openalgo:local .
```

---

## Ports & Protocols

| Port | Protocol | Usage |
|---|---|---|
| `5000` | HTTP | Flask Web UI & REST API |
| `8765` | WebSocket | Real-time market feed & strategy notifications |

---

## Automatic Image Updates

This repository automatically checks for new OpenAlgo releases daily at midnight UTC via GitHub Actions and builds multi-arch Docker images published to GitHub Container Registry (`ghcr.io/kokamkarsahil/openalgo`).

---

## Support & Resources

- [OpenAlgo Documentation](https://docs.openalgo.in/)
- [OpenAlgo GitHub Repository](https://github.com/marketcalls/openalgo)
- [OpenAlgo Discord Community](https://discord.com/invite/UPh7QPsNhP)

---

## License

This Docker configuration repository is provided under the MIT License. OpenAlgo is subject to its own license terms; see the [upstream repository](https://github.com/marketcalls/openalgo) for details.
