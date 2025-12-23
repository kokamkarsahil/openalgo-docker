# OpenAlgo Docker - Coolify/Dokploy Ready

Docker build configuration for [OpenAlgo](https://github.com/marketcalls/openalgo) trading platform, optimized for PaaS platforms like **Coolify** and **Dokploy**.

## Features

- 🐳 **Multi-arch builds** (amd64/arm64)
- 🔒 **No SSL complexity** - your platform handles it
- 📦 **Pre-built images** on GitHub Container Registry
- ⚡ **Optimized Dockerfile** with minimal runtime deps
- 🔄 **Automated builds** when upstream releases new versions

## Quick Deploy

### Using Pre-built Image

```bash
docker pull ghcr.io/kokamkarsahil/openalgo:latest
```

### Deploy on Coolify

1. Create a new **Docker Compose** service
2. Use this repository URL or paste the `docker-compose.yml`
3. Set the required environment variables (see below)
4. Deploy!

### Deploy on Dokploy

1. Create a new **Compose** application
2. Connect this repository or use the image directly
3. Configure environment variables
4. Deploy!

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `HOST_SERVER` | Your app's public URL | `https://trading.example.com` |
| `REDIRECT_URL` | Broker callback URL | `https://trading.example.com/zerodha/callback` |
| `BROKER_API_KEY` | Your broker API key | `your_api_key` |
| `BROKER_API_SECRET` | Your broker API secret | `your_api_secret` |
| `APP_KEY` | App security key (32-byte hex) | Generate with: `python -c "import secrets; print(secrets.token_hex(32))"` |
| `API_KEY_PEPPER` | API key pepper (32-byte hex) | Generate another one |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `5000` | HTTP port |
| `WEBSOCKET_PORT` | `8765` | WebSocket port |
| `LOG_LEVEL` | `INFO` | Logging level |
| `FLASK_ENV` | `production` | Flask environment |
| `DATABASE_URL` | SQLite | Database connection URL |

## Supported Brokers

fivepaisa, fivepaisaxts, aliceblue, angel, compositedge, definedge, dhan, dhan_sandbox, firstock, flattrade, fyers, groww, ibulls, iifl, indmoney, jainamxts, kotak, motilal, mstock, paytm, pocketful, samco, shoonya, tradejini, upstox, wisdom, zebu, zerodha

## Building Locally

```bash
# Clone this repo
git clone https://github.com/kokamkarsahil/openalgo-docker.git
cd openalgo-docker

# Clone upstream and copy Dockerfile
git clone https://github.com/marketcalls/openalgo.git build-context
cp Dockerfile build-context/
cd build-context

# Build
docker buildx bake
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Coolify / Dokploy / Traefik            │
│           (SSL Termination & Reverse Proxy)         │
└─────────────────────┬───────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
    ┌───────────┐           ┌───────────┐
    │ Port 5000 │           │ Port 8765 │
    │   Flask   │           │ WebSocket │
    │    App    │           │   Proxy   │
    └───────────┘           └───────────┘
          │                       │
          └───────────┬───────────┘
                      ▼
            ┌───────────────────┐
            │   SQLite / DB     │
            │   (Volumes)       │
            └───────────────────┘
```

## Volumes

The following volumes are created for data persistence:

- `openalgo_db` - Database files
- `openalgo_logs` - Application logs
- `openalgo_strategies` - Trading strategies
- `openalgo_keys` - API keys

## License

This Docker configuration is MIT licensed. OpenAlgo itself is licensed under its own terms - see [upstream repo](https://github.com/marketcalls/openalgo).

## Support

- OpenAlgo Discord: https://discord.com/invite/UPh7QPsNhP
- Upstream Repo: https://github.com/marketcalls/openalgo
