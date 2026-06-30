#!/bin/bash
# ==============================================================================
# apache_hardening.sh — Instala e ENDURECE o Apache2 (script de mudança)
# Projeto Linux Avançado / SOC · Autor: Diego Machado
#
# Separado da auditoria de propósito: este script ALTERA o sistema (instala,
# corrige config). Auditoria é read-only (apache_audit.sh).
#
# MITRE: reduz T1592/T1190 (info disclosure + superfície de ataque)
# D3FEND: D3-PH (Platform Hardening)
# ==============================================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "[ERRO] Rode como root."; exit 1; }
SEC="/etc/apache2/conf-available/security.conf"

# Define (ou substitui) uma diretiva de config de forma idempotente
set_directive() {
  local key="$1" val="$2" file="$3"
  if grep -qiE "^\s*${key}\b" "$file"; then
    sed -i -E "s|^\s*${key}\b.*|${key} ${val}|I" "$file"
  else
    echo "${key} ${val}" >> "$file"
  fi
}

echo "[*] Atualizando índices de pacote..."
apt-get update -y

echo "[*] Aplicando patches de segurança (reduz superfície T1190)..."
# Comente a linha abaixo se NÃO quiser upgrade completo neste momento.
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "[*] Instalando Apache2 e curl..."
apt-get install -y apache2 curl

echo "[*] Hardening contra information disclosure..."
set_directive "ServerTokens"    "Prod" "$SEC"   # esconde versão/SO no banner
set_directive "ServerSignature" "Off"  "$SEC"   # remove assinatura nas páginas de erro
set_directive "TraceEnable"     "Off"  "$SEC"   # desabilita HTTP TRACE (XST)

echo "[*] Desabilitando módulos de risco (autoindex/status)..."
a2dismod -q -f autoindex 2>/dev/null || true     # evita listagem de diretório
a2dismod -q -f status    2>/dev/null || true     # server-status exposto = recon

echo "[*] Testando a configuração ANTES de aplicar..."
if apache2ctl configtest 2>&1; then
  systemctl reload apache2
  systemctl enable apache2
  echo "[OK] Apache endurecido, validado e recarregado."
else
  echo "[ERRO] configtest falhou — NÃO recarreguei o Apache. Revise a config."; exit 1
fi
