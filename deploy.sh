#!/usr/bin/env bash
# deploy.sh — Push & run chat_go on your VPS
# Usage: bash deploy.sh

set -euo pipefail

VPS_IP="107.175.91.211"
VPS_USER="root"
VPS_PORT="22"
REMOTE_DIR="/opt/chat_go"
APP_NAME="chat_go"

echo "📦 Syncing project to VPS..."
rsync -avz --exclude='.git' \
  --exclude='backend/server' \
  --exclude='backend/server_bin' \
  --exclude='backend/media_cache' \
  --exclude='frontend/.dart_tool' \
  --exclude='frontend/build' \
  -e "ssh -p ${VPS_PORT}" \
  "$(dirname "$0")/" \
  "${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/"

echo "🚀 Running on VPS..."
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_IP}" bash <<EOF
  set -e
  cd ${REMOTE_DIR}

  # Install Docker if not present
  if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
  fi

  # Install Docker Compose plugin if not present
  if ! docker compose version &>/dev/null; then
    echo "Installing Docker Compose plugin..."
    apt-get update -qq && apt-get install -y docker-compose-plugin
  fi

  echo "🔨 Building and starting containers..."
  docker compose down --remove-orphans || true
  docker compose build --no-cache
  docker compose up -d

  echo "✅ Done! App running at http://${VPS_IP}:8088"
  docker compose ps
EOF

