#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/.openclaw /data/workspace /var/lib/tailscale

: "${OPENCLAW_GATEWAY_TOKEN:?OPENCLAW_GATEWAY_TOKEN required}"
: "${TS_AUTHKEY:?TS_AUTHKEY required}"

############################################
# Generate OpenClaw config
############################################

cat >/data/.openclaw/openclaw.json <<JSON
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "tailscale": {
      "mode": "serve"
    },
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}",
      "allowTailscale": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/workspace",
      "model": {
        "primary": "openrouter/auto"
      }
    }
  },
  "browser": {
    "cdpUrl": "http://browser:9222",
    "defaultProfile": "openclaw",
    "evaluateEnabled": true,
    "snapshotDefaults": {
      "mode": "efficient"
    },
    "remoteCdpTimeoutMs": 1500,
    "remoteCdpHandshakeTimeoutMs": 3000
  }
}
JSON

############################################
# Start tailscale
############################################

tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking &
sleep 5

tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TAILSCALE_HOSTNAME:-openclaw-ts}"

############################################
# Start OpenClaw Gateway
############################################

openclaw gateway --tailscale serve &

############################################
# Wait for gateway to start
############################################

echo "Waiting for OpenClaw gateway..."

until curl -s http://127.0.0.1:18789 >/dev/null; do
  sleep 2
done

############################################
# Auto approve device pairing
############################################

export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN}"

echo "Auto approving device if pending..."

sleep 3

openclaw devices list || true
openclaw devices approve --latest || true

############################################
# Keep container alive
############################################

wait -n
