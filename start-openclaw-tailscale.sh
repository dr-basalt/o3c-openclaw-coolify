#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/.openclaw /data/workspace /var/lib/tailscale

: "${OPENCLAW_GATEWAY_TOKEN:?OPENCLAW_GATEWAY_TOKEN required}"
: "${TS_AUTHKEY:?TS_AUTHKEY required}"

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
    },
    "controlUi": {
      "allowedOrigins": [
        "https://${TAILSCALE_HOSTNAME:-openclaw-ts}.tail0e5c46.ts.net",
        "https://openclaw-ts.tail0e5c46.ts.net",
        "https://openclaw-ts2.tail0e5c46.ts.net",
        "https://openclaw-ts-2.tail0e5c46.ts.net",
        "https://appassets.androidplatform.net",
        "app://android",
        "null"
      ]
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

echo "Starting tailscaled..."
tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking &
sleep 5

echo "Connecting to Tailscale..."
tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TAILSCALE_HOSTNAME:-openclaw-ts2}"

echo "Starting OpenClaw gateway..."
openclaw gateway --tailscale serve &

echo "Waiting for OpenClaw gateway..."
until curl -fsS http://127.0.0.1:18789/health >/dev/null 2>&1 || \
      curl -fsS http://127.0.0.1:18789 >/dev/null 2>&1; do
  sleep 2
done

export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN}"

echo "Auto-approving latest pending device if any..."
openclaw devices approve --latest || true

echo "OpenClaw + Tailscale ready."
wait -n
