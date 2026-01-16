# UpdateDNS

Dynamic DNS updater for Cloudflare. Automatically updates your DNS records when your public IP changes.

## Quick Start (Docker)

```bash
# 1. Clone and configure
git clone https://github.com/TejGandham/UpdateDNS.git
cd UpdateDNS
cp config/secrets.exs.sample config/secrets.exs

# 2. Edit config/secrets.exs with your Cloudflare credentials
#    (see Configuration section below)

# 3. Build and run
make build
make update
```

## Requirements

- Docker and Docker Compose
- Cloudflare account with API token

## Configuration

Edit `config/secrets.exs`:

```elixir
import Config

config :update_dns, :cloudflare,
  zone_id: "your_zone_id",
  api_token: "your_api_token",
  record_name: "home.example.com"
```

### Getting Cloudflare Credentials

1. **Zone ID**: Cloudflare Dashboard → Select domain → Scroll down → API section
2. **API Token**: [Create token](https://dash.cloudflare.com/profile/api-tokens) → Use "Edit zone DNS" template → Select your zone
3. **Record Name**: The A record to update (must already exist in Cloudflare)

## Usage

| Command | Description |
|---------|-------------|
| `make update` | Update DNS record (skips if IP unchanged) |
| `make force-update` | Update DNS record (bypass cache) |
| `make check-ip` | Show current public IP |
| `make check-dns` | Show IP in Cloudflare DNS |
| `make clear-cache` | Clear cached IP |
| `make dev` | Interactive Elixir shell |
| `make scheduler` | Start auto-updates (every 5 min) |
| `make stop` | Stop scheduler |
| `make logs` | View scheduler logs |

### Scheduled Updates

```bash
# Start background scheduler (default: 5 minutes)
make scheduler

# Custom interval
UPDATE_INTERVAL_MINUTES=10 make scheduler

# View logs
make logs

# Stop
make stop
```

## Features

- **IP Caching**: Only calls Cloudflare API when IP actually changes
- **Fallback Services**: Multiple IP detection services (ipify, ifconfig.co, my-ip.io)
- **PATCH Updates**: Uses Cloudflare's idiomatic partial update endpoint
- **Auto Retry**: Built-in retry for transient network errors
- **Docker-based**: No local Elixir installation required

## Project Structure

```
UpdateDNS/
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── mix.exs
├── config/
│   ├── config.exs
│   ├── secrets.exs          # Your credentials (gitignored)
│   └── secrets.exs.sample
└── lib/
    ├── update_cloudflare_dns.ex
    ├── dns_record_manager.ex
    └── public_ip_fetcher.ex
```

## Native Elixir (without Docker)

Requires Elixir 1.18+:

```bash
mix deps.get
mix run -e "UpdateCloudflareDNS.run()"
```

## License

MIT
