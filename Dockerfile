#FROM coollabsio/openclaw:2026.2.6
FROM coollabsio/openclaw-base:2026.3.8

USER root

RUN apt-get update && apt-get install -y curl ca-certificates gnupg && \
    mkdir -p /usr/share/keyrings && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
      | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
      | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale jq && \
    rm -rf /var/lib/apt/lists/*

COPY start-openclaw-tailscale.sh /usr/local/bin/start-openclaw-tailscale.sh
RUN chmod +x /usr/local/bin/start-openclaw-tailscale.sh

ENTRYPOINT ["/usr/local/bin/start-openclaw-tailscale.sh"]
