#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/.openclaw /data/workspace /var/lib/tailscale

cat >/data/.openclaw/openclaw.json <<'JSON'
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "tailscale": {
      "mode": "serve"
    },
    "auth": {
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

tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking &
sleep 5

tailscale up --authkey="${TS_AUTHKEY}" --hostname="${TAILSCALE_HOSTNAME:-openclaw-ts}"

exec openclaw gateway --tailscale serve
