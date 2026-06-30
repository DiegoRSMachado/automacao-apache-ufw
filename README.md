# Lab — Webserver Apache Endurecido + Firewall UFW (Linux Avançado / SOC)

Provisionamento e **hardening** de um servidor Apache, política de borda com **UFW**
(default-deny) e **auditoria read-only** da postura de segurança. Separação clara entre
o que *altera* o sistema e o que apenas *observa* — com mapeamento MITRE ATT&CK/D3FEND.

Lab acadêmico/supervisionado (SENAC-DF). Defensivo — Blue Team / hardening.

## Por que 3 scripts (e não 2 misturados)

O lab original juntava instalar + atualizar + auditar no mesmo script. Auditoria que
altera o sistema não é auditoria. Aqui cada script tem **uma responsabilidade**:

| Script | Papel | Altera o sistema? |
|---|---|---|
| `apache_hardening.sh` | Instala e endurece o Apache | **Sim** |
| `ufw_firewall.sh` | Aplica a política de firewall | **Sim** |
| `apache_audit.sh` | Coleta a postura de segurança | **Não** (read-only) |

## O que foi corrigido do lab original

- **`netstat` → `ss`**: o `net-tools` está deprecado e ausente em sistemas modernos; o
  script antigo falhava no passo de portas. `ss -tulpn` é o substituto correto.
- **UFW: política em vez de teatro**: o controle real é `default deny incoming`. Negar
  21/23/25 explicitamente é redundante quando o default já bloqueia tudo. Removido o ruído,
  aplicado o default-deny.
- **`ufw --force enable`**: o `enable` puro é interativo e travava o script (e podia
  derrubar o SSH). O `--force` resolve, com SSH garantido antes via `limit`/escopo.
- **SSH com `ufw limit`**: throttle nativo contra brute force (T1110), em vez de `allow` cru.
- **Hardening real do Apache**: `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off`,
  e desativação de `autoindex`/`status` — fechando vazamento de versão e recon.

## Mapa de controles

| Vetor | ATT&CK | Controle | D3FEND |
|---|---|---|---|
| Banner/versão expostos | T1592 | ServerTokens Prod, Signature Off | D3-PH |
| Superfície de serviço | T1190 | patch + módulos de risco off | D3-PH |
| Listagem de diretório / server-status | T1083/T1046 | `a2dismod autoindex status` | D3-PH |
| Serviço não-autorizado exposto | T1021 | UFW `default deny incoming` | D3-NTF |
| Brute force SSH | T1110 | `ufw limit` ou escopo `MGMT_NET` | D3-ITF |

## Ordem de execução

```bash
# 1. Endurecer e subir o Apache (valida config antes de aplicar)
sudo bash apache_hardening.sh

# 2. Aplicar a política de firewall
#    (opcional: escopar SSH à rede de gerência)
sudo MGMT_NET="192.168.56.0/24" bash ufw_firewall.sh

# 3. Auditar — read-only, gera relatório datado apache_audit_AAAA-MM-DD_HHMMSS.txt
sudo bash apache_audit.sh
```

> **Anti-lockout (execução remota):** o `ufw_firewall.sh` garante o SSH antes de ativar.
> Ainda assim, ao rodar via SSH numa máquina crítica, agende um resgate:
> `echo "ufw disable" | sudo at now + 5 minutes` (cancele com `sudo atrm <id>` se tudo der certo).

## Validação

```bash
# Versão NÃO deve vazar para o cliente:
curl -sI http://localhost | grep -i '^Server:'      # esperado: apenas "Server: Apache"

# Listagem de diretório deve estar desabilitada:
#   crie um dir sem index e acesse — deve dar 403, não listar arquivos.

# Firewall efetivo:
sudo ufw status verbose                              # web/SSH allow, resto deny

# Brute force barrado (do Kali): repetir conexões SSH dispara o limit do UFW.
```

## [SOC] — transformar o webserver em fonte de detecção

Hardening reduz a superfície; o SOC vê o que ainda bate na porta. Plugue os logs no Wazuh:

```xml
<!-- ossec.conf do agente -->
<localfile><log_format>apache</log_format><location>/var/log/apache2/access.log</location></localfile>
<localfile><log_format>apache</log_format><location>/var/log/apache2/error.log</location></localfile>
<localfile><log_format>syslog</log_format><location>/var/log/ufw.log</location></localfile>
```

Sinais a caçar (regras nativas do Wazuh + correlação):
- **Varredura/enumeração web (T1595):** rajada de 404/403 da mesma origem → recon.
- **Tentativa de path traversal / LFI (T1083):** `../`, `/etc/passwd` na URL.
- **Bloqueios UFW correlacionados:** muitos `[UFW BLOCK]` da mesma origem → scan de portas (T1046).
- **Acesso a `server-status`/`.git`/`.env`:** indica recon de configuração exposta.

## Custo no hardware (i5 2013 / 16GB / HDD)

UFW e Apache hardening: custo desprezível. O `apt upgrade` é o passo pesado (rede + I/O no
HDD) — por isso fica isolado no script de hardening, comentável, e fora da auditoria. A
auditoria é leve e não escreve no sistema, só gera o relatório `.txt`.

## Próximos passos

1. **TLS forte**: `a2enmod ssl`, certificado, e cabeçalhos de segurança (HSTS, X-Content-Type-Options, CSP).
2. **ModSecurity (WAF)** com OWASP CRS — bloqueio de SQLi/XSS na borda da aplicação (T1190).
3. **fail2ban** lendo `error.log`/`access.log` para banir scanners e brute force de login web.
4. **Dashboard Wazuh** com as detecções acima — evidência visual de ataques bloqueados.

---
**Autor:** Diego Machado · Lab SENAC-DF · Blue Team / Hardening / SOC
