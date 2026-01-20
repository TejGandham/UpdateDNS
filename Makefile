# UpdateDNS Makefile
# Convenient commands for Docker-based development

.PHONY: help build dev update force-update check-ip check-dns clear-cache \
        scheduler stop logs clean deps compile test shell

# Default target
help:
	@echo ""
	@echo "UpdateDNS - Cloudflare Dynamic DNS Updater"
	@echo "==========================================="
	@echo ""
	@echo "Development:"
	@echo "  make build        - Build Docker image"
	@echo "  make dev          - Start interactive Elixir shell (iex)"
	@echo "  make shell        - Start bash shell in container"
	@echo "  make deps         - Fetch dependencies"
	@echo "  make compile      - Compile the project"
	@echo ""
	@echo "DNS Operations:"
	@echo "  make update       - Run DNS update (respects cache)"
	@echo "  make force-update - Force DNS update (bypass cache)"
	@echo "  make check-ip     - Show current public IP"
	@echo "  make check-dns    - Show IP in Cloudflare DNS record"
	@echo "  make clear-cache  - Clear IP cache"
	@echo ""
	@echo "Scheduler:"
	@echo "  make scheduler    - Start background scheduler (default: 5 min)"
	@echo "  make stop         - Stop scheduler"
	@echo "  make logs         - View scheduler logs (follow mode)"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean        - Remove containers and volumes"
	@echo ""
	@echo "Configuration:"
	@echo "  UPDATE_INTERVAL_MINUTES=10 make scheduler  - Custom interval"
	@echo ""

# Build Docker image
build:
	@echo "Building Docker image..."
	docker compose build

# Interactive Elixir shell
dev:
	@echo "Starting interactive Elixir shell..."
	@echo "Type 'UpdateCloudflareDNS.run()' to test"
	@echo ""
	docker compose run --rm dev

# Bash shell in container
shell:
	docker compose run --rm dev bash

# Fetch dependencies
deps:
	docker compose run --rm dev mix deps.get

# Compile project
compile:
	docker compose run --rm dev mix compile

# Run DNS update (cache-aware)
update:
	@echo "Running DNS update..."
	docker compose run --rm update

# Force DNS update (bypass cache)
force-update:
	@echo "Forcing DNS update (bypassing cache)..."
	docker compose run --rm update mix run -e "UpdateCloudflareDNS.run(force: true)"

# Check current public IP
check-ip:
	@echo "Fetching current public IP..."
	@docker compose run --rm update mix run -e 'case PublicIPFetcher.get_public_ip() do {:ok, ip} -> IO.puts("Public IP: #{ip}"); {:error, e} -> IO.puts("Error: #{e}") end'

# Check IP in DNS record
check-dns:
	@echo "Fetching IP from Cloudflare DNS..."
	@docker compose run --rm update mix run -e 'case UpdateCloudflareDNS.check_dns_ip() do {:ok, ip} -> IO.puts("DNS IP: #{ip}"); {:error, e} -> IO.puts("Error: #{e}") end'

# Clear IP cache
clear-cache:
	@echo "Clearing IP cache..."
	docker compose run --rm update mix run -e "UpdateCloudflareDNS.clear_cache(); IO.puts(\"Cache cleared\")"

# Start background scheduler
# Usage: UPDATE_INTERVAL_MINUTES=10 make scheduler
scheduler:
	@echo "Starting scheduler (interval: $${UPDATE_INTERVAL_MINUTES:-5} minutes)..."
	@echo "Use 'make logs' to view output, 'make stop' to stop"
	docker compose --profile scheduled up -d scheduler

# Stop scheduler
stop:
	@echo "Stopping scheduler..."
	docker compose --profile scheduled down

# View scheduler logs
logs:
	docker compose --profile scheduled logs -f scheduler

# Clean up everything
clean:
	@echo "Removing containers and volumes..."
	docker compose down -v --remove-orphans
	docker compose --profile scheduled down -v --remove-orphans
	@echo "Cleanup complete"

# Run tests (if any)
test:
	docker compose run --rm -e MIX_ENV=test dev mix test
