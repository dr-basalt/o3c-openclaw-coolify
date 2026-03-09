#!/usr/bin/env bash
set -euo pipefail

mkdir -p \
  /data/ui/.openclaw /data/ui/workspace \
  /data/node/.openclaw /data/node/workspace \
  /var/lib/tailscale

: "${TS_AUTHKEY:?TS_AUTHKEY required}"
: "${OPENCLAW_UI_GATEWAY_TOKEN:?OPENCLAW_UI_GATEWAY_TOKEN required}"
: "${OPENCLAW_NODE_GATEWAY_TOKEN:?OPENCLAW_NODE_GATEWAY_TOKEN required}"

# -------------------------
# UI profile (browser)
# loopback + tailscale serve
# -------------------------
cat >/data/ui/.openclaw/openclaw.json <<JSON
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
      "token": "${OPENCLAW_UI_GATEWAY_TOKEN}",
      "allowTailscale": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/ui/workspace",
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

# -------------------------
# Node profile (android)
# tailnet bind + direct WS
# -------------------------
cat >/data/node/.openclaw/openclaw.json <<JSON
{
  "gateway": {
    "mode": "local",
    "bind": "tailnet",
    "port": 19789,
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_NODE_GATEWAY_TOKEN}"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/node/workspace",
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

# -------------------------
# Start tailscale
# -------------------------
tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking &
sleep 5

tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TAILSCALE_HOSTNAME:-openclaw-ts}"

# -------------------------
# Start UI gateway
# -------------------------
export OPENCLAW_CONFIG_PATH=/data/ui/.openclaw/openclaw.json
export OPENCLAW_STATE_DIR=/data/ui/.openclaw
openclaw gateway --profile ui --tailscale serve &
UI_PID=$!

# -------------------------
# Start Node gateway
# -------------------------
OPENCLAW_CONFIG_PATH=/data/node/.openclaw/openclaw.json \
OPENCLAW_STATE_DIR=/data/node/.openclaw \
openclaw gateway --profile node --bind tailnet --port 19789 --token "${OPENCLAW_NODE_GATEWAY_TOKEN}" &
NODE_PID=$!

# -------------------------
# Wait a bit, then approve latest pending device on node profile
# -------------------------
sleep 8

OPENCLAW_CONFIG_PATH=/data/node/.openclaw/openclaw.json \
OPENCLAW_STATE_DIR=/data/node/.openclaw \
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_NODE_GATEWAY_TOKEN}" \
openclaw --profile node devices approve --latest || true

wait -n "$UI_PID" "$NODE_PID"
