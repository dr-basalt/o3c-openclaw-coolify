#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/.openclaw /data/workspace /var/lib/tailscale

: "${TS_AUTHKEY:?TS_AUTHKEY required}"

export OPENCLAW_CONFIG_PATH=/data/.openclaw/openclaw.json
export OPENCLAW_STATE_DIR=/data/.openclaw
export OPENCLAW_WORKSPACE_DIR=/data/workspace

cat >"${OPENCLAW_CONFIG_PATH}" <<JSON
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "tailscale": {
      "mode": "serve"
    },
    "trustedProxies": ["127.0.0.1"],
    "auth": {
      "mode": "token",
      "allowTailscale": true
    },
    "controlUi": {
      "allowedOrigins": [
        "https://${TAILSCALE_HOSTNAME:-openclaw-ts2}.tail0e5c46.ts.net",
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

echo "Using config:"
cat "${OPENCLAW_CONFIG_PATH}"

echo "Starting tailscaled..."
tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking &
sleep 5

echo "Connecting to Tailscale..."
tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TAILSCALE_HOSTNAME:-openclaw-ts2}"

echo "Starting OpenClaw gateway..."
openclaw gateway --tailscale serve &
GATEWAY_PID=$!

echo "Waiting for OpenClaw gateway on 127.0.0.1:18789..."
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:18789/ >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -fsS http://127.0.0.1:18789/ >/dev/null 2>&1; then
  echo "OpenClaw gateway did not start correctly."
  ps ufax || true
  wait "${GATEWAY_PID}" || true
  exit 1
fi

echo "Auto-approving latest pending device if any..."
openclaw devices approve --latest || true

echo "OpenClaw + Tailscale ready."
wait -n
