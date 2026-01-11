# OpenAlgo Docker

Pre-built Docker images for [OpenAlgo](https://github.com/marketcalls/openalgo) trading platform, optimized for **Coolify**, **Dokploy**, and self-hosted deployments.

## Features

- 🚀 **Multi-architecture**: Supports AMD64 and ARM64
- 🔒 **Secure**: Runs as non-root user with proper permissions
- ⚡ **Optimized**: Uses `tini` for proper signal handling, slim base image
- 🔧 **Auto-configured**: Generates `.env` from environment variables
- 📦 **Pre-built**: Ready-to-use images on GitHub Container Registry

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

### Using Docker directly

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

## Required Environment Variables

| Variable | Description |
|----------|-------------|
| `HOST_SERVER` | Your application URL (e.g., `https://openalgo.example.com`) |
| `REDIRECT_URL` | OAuth callback URL for your broker |
| `BROKER_API_KEY` | Your broker's API key |
| `BROKER_API_SECRET` | Your broker's API secret |
| `APP_KEY` | Application secret key (generate with `python -c "import secrets; print(secrets.token_hex(32))"`) |
| `API_KEY_PEPPER` | API key pepper for hashing (generate another hex token) |

## Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `5000` | Application port |
| `FLASK_ENV` | `production` | Flask environment |
| `LOG_LEVEL` | `INFO` | Logging level |
| `WEBSOCKET_PORT` | `8765` | WebSocket server port |
| `WEBSOCKET_URL` | Auto-detected | WebSocket URL (auto-generated from HOST_SERVER) |
| `DATABASE_URL` | `sqlite:///db/openalgo.db` | Database connection URL |

### XTS Broker Credentials (Optional)

| Variable | Description |
|----------|-------------|
| `BROKER_API_KEY_MARKET` | Market data API key for XTS brokers |
| `BROKER_API_SECRET_MARKET` | Market data API secret for XTS brokers |

## Deployment

### Coolify

1. Create a new Docker Compose service
2. Paste the contents of `docker-compose.yml`
3. Add environment variables in the Coolify dashboard
4. Deploy

### Dokploy

1. Create a new Docker Compose application
2. Use this repository URL or paste `docker-compose.yml`
3. Configure environment variables
4. Deploy

### Self-hosted with Nginx

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

## Volumes

| Volume | Path | Description |
|--------|------|-------------|
| `openalgo_db` | `/app/db` | SQLite databases |
| `openalgo_logs` | `/app/logs` | Application logs |
| `openalgo_log` | `/app/log` | Strategy logs |
| `openalgo_strategies` | `/app/strategies` | Custom strategies |
| `openalgo_keys` | `/app/keys` | API keys storage |

## Building Locally

```bash
# Build the image
docker compose build

# Or build with specific tag
docker build -t openalgo:local .
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 5000 | HTTP | Web application |
| 8765 | WebSocket | Real-time updates |

## Automatic Updates

This repository automatically checks for new OpenAlgo releases daily and builds updated Docker images.

## Support

- [OpenAlgo Documentation](https://docs.openalgo.in/)
- [OpenAlgo Discord](https://discord.com/invite/UPh7QPsNhP)
- [GitHub Issues](https://github.com/kokamkarsahil/openalgo-docker/issues)

## License

This Docker configuration is provided as-is. OpenAlgo is licensed under its own terms - see the [OpenAlgo repository](https://github.com/marketcalls/openalgo) for details.
