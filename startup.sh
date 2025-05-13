#!/bin/bash
set -e
exec > >(tee /var/log/startup-script.log) 2>&1 # Log stdout/stderr

echo "Startup script started at $(date)"

# System update and essential packages
apt-get update -y
apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release redis-server

# Configure Redis to listen on all interfaces (needed if Hyperswitch container doesn't use network_mode: host or for external debugging)
# If using network_mode: host for Hyperswitch, redis listening on 127.0.0.1 (default) is fine.
# For simplicity and robustness with network_mode: host, default Redis config should work.
# sed -i 's/bind 127.0.0.1 -::1/bind 0.0.0.0/' /etc/redis/redis.conf

# Enable and start Redis
systemctl enable redis-server
systemctl start redis-server
echo "Redis installed and started."

# Install Docker
echo "Installing Docker..."
# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
echo "Docker installed and started."

# Create directory for Hyperswitch
mkdir -p /opt/hyperswitch
cd /opt/hyperswitch

# Fetch External IP for APP_BASE_URL
EXTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -s)
if [ -z "$EXTERNAL_IP" ]; then
  echo "WARNING: Could not determine external IP address. APP_BASE_URL will be incomplete."
  APP_BASE_URL="http://YOUR_VM_IP:8080" # Fallback
else
  APP_BASE_URL="http://${EXTERNAL_IP}:8080"
fi
echo "External IP detected: ${EXTERNAL_IP}. APP_BASE_URL set to: ${APP_BASE_URL}"


# Create .env file for Hyperswitch
# IMPORTANT: Review and update these values, especially ADMIN_API_KEY and any other sensitive or specific settings.
echo "Creating .env file..."
cat <<EOF > /opt/hyperswitch/.env
# Hyperswitch Environment Variables
# Ensure these are correctly set for your Hyperswitch instance.

# Database Configuration (points to the PostgreSQL container)
DATABASE_URL=postgresql://hyperswitch_user:hyperswitch_password@localhost:5432/hyperswitch_db

# Redis Configuration (points to Redis on the host, accessible via localhost due to network_mode: host)
REDIS_URL=redis://localhost:6379

# Application URL (auto-detected external IP)
APP_BASE_URL=${APP_BASE_URL}

# API Keys and other settings - REPLACE PLACEHOLDERS
ADMIN_API_KEY=SET_YOUR_STRONG_ADMIN_API_KEY_HERE # <<< IMPORTANT: Change this!
# LOCKER_HOST=http://localhost:8082 # Example: if you have a locker service

# Add other Hyperswitch specific environment variables here as needed
# E.g., LOG_LEVEL=DEBUG
# MASTER_KEY=your_32_byte_master_key_here # Example, if needed

EOF
echo ".env file created."
cat /opt/hyperswitch/.env # Print .env content to log for verification

# Create docker-compose.yml
echo "Creating docker-compose.yml..."
cat <<EOF > /opt/hyperswitch/docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15 # Using PostgreSQL 15
    container_name: hyperswitch_postgres
    environment:
      POSTGRES_USER: hyperswitch_user
      POSTGRES_PASSWORD: hyperswitch_password # Consider managing this more securely for non-dev
      POSTGRES_DB: hyperswitch_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
    # ports: # Port 5432 is accessible on host due to Hyperswitch using network_mode: host
    #   - "127.0.0.1:5432:5432" # If you only want localhost access to Postgres from host
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U hyperswitch_user -d hyperswitch_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  hyperswitch:
    # IMPORTANT: Verify this is the correct/desired Hyperswitch image and tag
    image: hyperswitch/hyperswitch:latest
    container_name: hyperswitch_app
    env_file:
      - .env
    # 'ports' mapping is not used here because of network_mode: "host"
    # Hyperswitch will listen on port 8080 directly on the host's network interface.
    network_mode: "host"
    depends_on:
      postgres:
        condition: service_healthy # Wait for postgres to be healthy
    restart: unless-stopped
    # healthcheck: # Add a suitable healthcheck for Hyperswitch if available
    #   test: ["CMD", "curl", "-f", "http://localhost:8080/health"] # Example
    #   interval: 30s
    #   timeout: 10s
    #   retries: 3

volumes:
  postgres_data: # Persists PostgreSQL data on the VM's disk

EOF
echo "docker-compose.yml created."

# Start Hyperswitch and PostgreSQL
echo "Running docker compose up -d..."
docker compose -f /opt/hyperswitch/docker-compose.yml up -d

echo "Docker containers started:"
docker ps -a

echo "Startup script finished at $(date)"
echo "You should be able to access Hyperswitch at ${APP_BASE_URL} after a few minutes."
echo "Verify Redis: redis-cli ping (should return PONG)"
echo "Verify Docker containers: docker ps"
echo "Check Hyperswitch logs: docker logs hyperswitch_app"
echo "Check Postgres logs: docker logs hyperswitch_postgres" 