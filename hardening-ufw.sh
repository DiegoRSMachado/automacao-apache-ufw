#!/bin/bash
# Script de Configuracao de Firewall UFW
# Politica: Bloquear servicos inseguros e liberar apenas Web/SSH

# 1. Habilitar o UFW
sudo ufw enable

# 2. Regras de Permissao (Allow) - Pagina 4 do Relatorio
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# 3. Regras de Bloqueio Explicito (Deny) - Pagina 7 do Relatorio
# Bloqueando protocolos inseguros ou legados
sudo ufw deny 21/tcp    # FTP (Inseguro)
sudo ufw deny 23/tcp    # Telnet
sudo ufw deny 25/tcp    # SMTP (Envio de Spam)
sudo ufw deny 53/udp    # DNS (Evitar amplificacao)

# 4. Recarregar
sudo ufw reload
sudo ufw status verbose
