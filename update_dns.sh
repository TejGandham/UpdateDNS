#!/bin/bash

# UpdateDNS - Cloudflare Dynamic DNS Updater
# Usage: ./update_dns.sh [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$1" = "--force" ]; then
    mix run -e "UpdateCloudflareDNS.run(force: true)"
else
    mix run -e "UpdateCloudflareDNS.run()"
fi

