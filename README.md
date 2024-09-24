
# UpdateDNS

An Elixir application that dynamically updates DNS records when your public IP address changes.

## Overview

UpdateDNS is a lightweight, configurable Elixir application designed to keep your DNS records synchronized with your current public IP address. It's ideal for users with dynamic IP addresses who need their domain to always point to the correct location, such as for hosting services from home.

## Features

- **Cloudflare Support**: Compatible with Cloudflare DNS provider.
- **IPv4 and IPv6 Support**: Updates both A (IPv4) and AAAA (IPv6) records.
- **Easy Configuration**: Simple configuration using Elixir's configuration files.
- **Automated Execution**: Can run as a daemon or be scheduled via cron jobs.
- **Logging**: Detailed logging for monitoring and troubleshooting.
- **Extensible**: Easily extendable to support additional DNS providers.

## Table of Contents

- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Steps](#steps)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Run Manually](#run-manually)
  - [Run as a Daemon](#run-as-a-daemon)
  - [Automate with Cron](#automate-with-cron)
- [Development Workflow](#development-workflow)
  - [Setting Up the Development Environment](#setting-up-the-development-environment)
  - [Running the App in Development Mode](#running-the-app-in-development-mode)
  - [Running Tests](#running-tests)
  - [Creating a Release](#creating-a-release)
- [Deployment](#deployment)
  - [Docker Deployment](#docker-deployment)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Installation

### Prerequisites

- **Elixir**: Version 1.11 or higher
- **Erlang/OTP**: Version 23 or higher
- **Git**: For cloning the repository
- **(Optional) Docker**: If you prefer containerized deployment

### Steps

1. **Clone the Repository**

   ```bash
   git clone https://github.com/TejGandham/UpdateDNS.git
   cd UpdateDNS
   ```

2. **Install Dependencies**

   Fetch and compile the dependencies:

   ```bash
   mix deps.get
   mix deps.compile
   ```

## Configuration

1. **Create Configuration File**

   Copy the sample secrets configuration file:

   ```bash
   cp config/secrets.exs.sample config/secrets.exs
   ```

2. **Edit `config/secrets.exs`**

   Update the configuration with your DNS provider details:

   ```elixir
   use Mix.Config

   config :update_dns,
     provider: :cloudflare,
     api_token: "your_api_token",
     zone_id: "your_zone_id",
     record_name: "subdomain.example.com",
     record_type: "A", # "A" for IPv4 or "AAAA" for IPv6
     ttl: 120
   ```

   - **provider**: DNS provider (e.g., `:cloudflare`, `:google_domains`).
   - **api_token**: API token or key for authentication.
   - **zone_id**: DNS zone ID.
   - **record_name**: DNS record to update.
   - **record_type**: `"A"` for IPv4 or `"AAAA"` for IPv6.
   - **ttl**: Time-to-live for the DNS record.

3. **Ensure Secrets Config is Loaded**

   In your `config/config.exs`, make sure to import the `secrets.exs` file at the end:

   ```elixir
   import_config "secrets.exs"
   ```

## Usage

### Run Manually

You can manually run the application to update your DNS record:

```bash
mix run -e 'UpdateDNS.update()'
```

### Run as a Daemon

To run the application continuously and monitor for IP changes:

```bash
mix run --no-halt
```

### Automate with Cron

Schedule the application to run periodically using cron:

1. **Open the Cron Tab**

   ```bash
   crontab -e
   ```

2. **Add the Following Line**

   Run the script every 5 minutes:

   ```cron
   */5 * * * * cd /path/to/UpdateDNS && mix run -e 'UpdateDNS.update()' >> /var/log/updatedns.log 2>&1
   ```

## Development Workflow

### Setting Up the Development Environment

1. **Fork the Repository**

   Click the "Fork" button on GitHub to create your own copy.

2. **Clone Your Fork**

   ```bash
   git clone https://github.com/yourusername/UpdateDNS.git
   cd UpdateDNS
   ```

3. **Create a Branch**

   Create a new branch for your feature or bugfix:

   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Install Dependencies**

   ```bash
   mix deps.get
   ```

### Running the App in Development Mode

1. **Modify Configuration for Development**

   Create a development configuration file if needed:

   ```bash
   cp config/secrets.exs config/dev.secrets.exs
   ```

   Update `config/dev.secrets.exs` with your development settings.

2. **Ensure Development Config is Loaded**

   In your `config/dev.exs`, add:

   ```elixir
   import_config "dev.secrets.exs"
   ```

3. **Start the Application**

   Run the application in interactive mode:

   ```bash
   iex -S mix
   ```

   In the Elixir shell, you can invoke the update function:

   ```elixir
   iex> UpdateDNS.update()
   ```

### Running Tests

Ensure your changes don't break existing functionality:

```bash
mix test
```

### Creating a Release

1. **Update Version**

   Update the version number in `mix.exs` and in `CHANGELOG.md`.

2. **Commit Changes**

   ```bash
   git add .
   git commit -m "Release version x.y.z"
   ```

3. **Tag the Release**

   ```bash
   git tag -a vX.Y.Z -m "Version X.Y.Z"
   git push origin vX.Y.Z
   ```

4. **Create GitHub Release**

   - Go to the "Releases" section in GitHub.
   - Click "Draft a new release."
   - Choose the tag and publish the release.

## Deployment

### Docker Deployment

A `Dockerfile` is included for easy containerization.

1. **Build the Docker Image**

   ```bash
   docker build -t updatedns:latest .
   ```

2. **Run the Docker Container**

   ```bash
   docker run -d \
     -v /path/to/config:/app/config \
     --name updatedns \
     updatedns:latest
   ```

   - **Note**: Mount your configuration directory into the container.

3. **Using Docker Compose**

   You can use `docker-compose` for deployment:

   ```yaml
   version: '3'
   services:
     updatedns:
       build: .
       volumes:
         - ./config:/app/config
       restart: unless-stopped
   ```

   Start the application:

   ```bash
   docker-compose up -d
   ```

## Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the Project**

2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/AmazingFeature
   ```

3. **Commit Your Changes**

   ```bash
   git commit -m 'Add some AmazingFeature'
   ```

4. **Push to the Branch**

   ```bash
   git push origin feature/AmazingFeature
   ```

5. **Open a Pull Request**

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
