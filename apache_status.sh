#!/bin/bash
# Script de Auditoria e Status do Webserver Apache
# Baseado no laboratorio pratico de Linux Avancado

STATUS_FILE="apache_status.txt"

echo "--- [1] Atualizando repositorios..."
sudo apt update

echo "--- [2] Verificando upgrades pendentes..."
sudo apt upgrade -y

echo "--- [3] Verificando instalacao do Apache2..."
sudo apt install apache2 -y

echo "--- [4] Coletando status do servico..."
# Salva o status no arquivo de log conforme solicitado
sudo systemctl status apache2 --no-pager > $STATUS_FILE

echo "--- [5] Verificando portas abertas (Netstat)..."
sudo netstat -tulpn | grep apache2 >> $STATUS_FILE

echo "Auditoria concluida. Verifique o arquivo $STATUS_FILE"
