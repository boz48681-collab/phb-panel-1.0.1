FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Istanbul
ENV WEBHOOK_URL=https://webhook.site/your-webhook-url-here

# ── Gerekli paketleri kur ───────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    curl wget git unzip sudo ca-certificates gnupg \
    lsb-release net-tools jq procps htop nano tzdata \
    && rm -rf /var/lib/apt/lists/*

# ── code-server (VS Code web arayüzü) kur ──────────────────────────
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ── code-server yapılandırmasını inline yaz ─────────────────────────
RUN mkdir -p /root/.config/code-server && cat > /root/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: changeme123
cert: false
EOF

# ── Çalışma dizini ─────────────────────────────────────────────────
RUN mkdir -p /workspace
WORKDIR /workspace

# ── Veri gönderme scriptini inline yaz (her 10 sn) ─────────────────
RUN cat > /usr/local/bin/sender.sh <<'EOF'
#!/bin/bash
echo "[SENDER] Baslatildi. Hedef: $WEBHOOK_URL"
while true; do
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    HOST=$(hostname)
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
    MEM_USED=$(free -m  | awk '/^Mem:/{print $3}')
    MEM_FREE=$(free -m  | awk '/^Mem:/{print $4}')
    DISK=$(df -h / | awk 'NR==2{print $5}')
    UPTIME=$(uptime -p)
    IP=$(hostname -I | awk '{print $1}')

    PAYLOAD=$(jq -n \
        --arg ts "$TS" --arg host "$HOST" --arg cpu "$CPU" \
        --arg mt "$MEM_TOTAL" --arg mu "$MEM_USED" --arg mf "$MEM_FREE" \
        --arg disk "$DISK" --arg up "$UPTIME" --arg ip "$IP" \
        '{timestamp:$ts, hostname:$host, local_ip:$ip,
          cpu_percent:$cpu,
          memory:{total_mb:$mt, used_mb:$mu, free_mb:$mf},
          disk_root_usage:$disk, uptime:$up,
          service:"vscode-container"}')

    HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    echo "[SENDER] $(date '+%H:%M:%S') -> HTTP $HTTP | CPU:${CPU}% | RAM:${MEM_USED}/${MEM_TOTAL}MB | Disk:$DISK"
    sleep 10
done
EOF
RUN chmod +x /usr/local/bin/sender.sh

# ── Entrypoint scriptini inline yaz ────────────────────────────────
RUN cat > /entrypoint.sh <<'EOF'
#!/bin/bash
set -e
echo "======================================"
echo "  VS Code (code-server) — Ubuntu 22.04"
echo "  Port: 8080  |  Webhook aktif (10sn)"
echo "======================================"
/usr/local/bin/sender.sh &
echo "[*] Sender PID: $!"
exec code-server --bind-addr 0.0.0.0:8080 /workspace
EOF
RUN chmod +x /entrypoint.sh

# ── Port ────────────────────────────────────────────────────────────
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
