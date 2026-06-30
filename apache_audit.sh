#!/bin/bash
# ==============================================================================
# apache_audit.sh — Auditoria READ-ONLY do Apache (NÃO altera o sistema)
# Projeto Linux Avançado / SOC · Autor: Diego Machado
#
# Coleta postura de segurança, não só "status do serviço". Usa `ss` (netstat
# está deprecado e some em sistemas modernos). Saída em tela e relatório datado.
# ==============================================================================
set -uo pipefail   # sem -e: a auditoria continua mesmo se um item falhar

TS="$(date +%F_%H%M%S)"
OUT="apache_audit_${TS}.txt"
exec > >(tee "$OUT") 2>&1

line(){ echo "----------------------------------------------------------------"; }

echo "================ AUDITORIA APACHE — ${TS} ================"

line; echo "[1] Versão do Apache (deve estar mascarada para o público):"
apache2 -v 2>/dev/null || echo ">> Apache não instalado."

line; echo "[2] Sintaxe da configuração:"
apache2ctl -t 2>&1 || true

line; echo "[3] Módulos de risco carregados (autoindex/status/userdir/cgi):"
if apache2ctl -M 2>/dev/null | grep -Ei 'autoindex|status|userdir|cgi'; then
  echo ">> ATENÇÃO: módulo(s) de risco acima ativo(s). Avalie desabilitar."
else
  echo ">> OK: nenhum módulo de risco óbvio carregado."
fi

line; echo "[4] Information disclosure (security.conf):"
grep -Ei 'ServerTokens|ServerSignature|TraceEnable' \
  /etc/apache2/conf-available/security.conf 2>/dev/null \
  || echo ">> Diretivas de hardening NÃO encontradas (rode o apache_hardening.sh)."

line; echo "[5] Header 'Server' exposto na resposta HTTP:"
if curl -sI http://localhost 2>/dev/null | grep -i '^Server:'; then
  echo ">> Se aparecer versão/SO acima, há vazamento (ServerTokens != Prod)."
else
  echo ">> Host não respondeu em :80 ou curl ausente."
fi

line; echo "[6] Sockets em escuta (ss — substitui o netstat):"
ss -tulpn 2>/dev/null | grep -i apache2 || echo ">> Apache não está escutando."

line; echo "[7] Estado do serviço:"
echo -n "ativo: "; systemctl is-active apache2 2>/dev/null || true
echo -n "habilitado no boot: "; systemctl is-enabled apache2 2>/dev/null || true

line; echo "[8] Política de firewall (UFW):"
ufw status verbose 2>/dev/null || echo ">> UFW não configurado/instalado."

line; echo "================ FIM — relatório salvo em ${OUT} ================"
