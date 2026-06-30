#!/bin/bash
# ==============================================================================
# ufw_firewall.sh — Política de borda com UFW
# Projeto Linux Avançado / SOC · Autor: Diego Machado
#
# Base correta: DEFAULT DENY incoming + ALLOW outgoing. Libera só web e SSH,
# com rate limit anti brute force. Sem "deny" cosmético — o default-deny já
# bloqueia tudo que não for liberado explicitamente.
#
# MITRE: mitiga T1021 (serviço não-autorizado), T1110 (brute force SSH)
# D3FEND: D3-NTF (Network Traffic Filtering), D3-ITF (Inbound Traffic Filtering)
# ==============================================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "[ERRO] Rode como root."; exit 1; }
command -v ufw >/dev/null || { echo "[*] Instalando ufw..."; apt-get install -y ufw; }

# Vazio = SSH liberado de qualquer origem (com limit). Defina a rede de gerência
# para escopar o SSH (recomendado): ex. MGMT_NET="192.168.56.0/24"
MGMT_NET="${MGMT_NET:-}"

echo "[*] Resetando e aplicando política base (default deny incoming)..."
ufw --force reset
ufw default deny incoming      # <- ESTE é o controle real. Bloqueia 21/23/25/etc.
ufw default allow outgoing
ufw logging on                 # registra bloqueios (alimenta o SIEM)

echo "[*] SSH com proteção contra brute force..."
if [ -n "$MGMT_NET" ]; then
  ufw allow from "$MGMT_NET" to any port 22 proto tcp   # escopo de rede
else
  ufw limit 22/tcp                                       # throttle nativo do UFW
fi

echo "[*] Liberando serviço web (HTTP/HTTPS)..."
ufw allow 80/tcp
ufw allow 443/tcp

echo "[*] Ativando firewall..."
ufw --force enable             # --force evita o prompt interativo que travava o script
ufw status verbose

echo "[OK] UFW ativo. Tudo que não foi liberado acima está bloqueado por padrão."
