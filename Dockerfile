# UpdateDNS Dockerfile
# Elixir 1.18 + Erlang/OTP 27 for Cloudflare Dynamic DNS updates

# Use official Elixir image (more reliably available)
FROM elixir:1.18-slim

LABEL maintainer="UpdateDNS"
LABEL description="Cloudflare Dynamic DNS Updater"

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Copy dependency files first for better layer caching
COPY mix.exs mix.lock ./

# Create config directory and copy config files
COPY config/config.exs config/
COPY config/secrets.exs.sample config/

# Create a placeholder secrets.exs for compilation (will be overwritten at runtime)
RUN cp config/secrets.exs.sample config/secrets.exs

# Fetch and compile dependencies
RUN mix deps.get && mix deps.compile

# Copy application source code
COPY lib lib
COPY update_dns.sh ./

# Create directories
RUN mkdir -p log

# Set environment
ENV MIX_ENV=dev
ENV LANG=C.UTF-8

# Default command: run the DNS update
CMD ["mix", "run", "-e", "UpdateCloudflareDNS.run()"]
