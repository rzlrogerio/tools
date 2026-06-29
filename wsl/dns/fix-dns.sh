#!/bin/bash

# Script para corrigir problemas de DNS no WSL, especialmente ao usar VPNs.
# Ele desativa a geração automática do resolv.conf do WSL e configura servidores DNS estáticos e o host Windows.

RESOLV_CONF="/etc/resolv.conf"
WSL_CONF="/etc/wsl.conf"

echo "=== WSL DNS Fixer ==="

# 1. Verificar se rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "Erro: Por favor, execute este script como root (sudo)."
  exit 1
fi

# 2. Configurar /etc/wsl.conf para não gerar resolv.conf automaticamente
if [ -f "$WSL_CONF" ]; then
  if ! grep -q "[network]" "$WSL_CONF"; then
    echo -e "\n[network]\ngenerateResolvConf = false" >> "$WSL_CONF"
    echo "✓ Geração automática de resolv.conf desativada em $WSL_CONF"
  elif ! grep -q "generateResolvConf" "$WSL_CONF"; then
    # Se [network] existe mas não generateResolvConf
    sed -i '/\[network\]/a generateResolvConf = false' "$WSL_CONF"
    echo "✓ Geração automática de resolv.conf desativada em $WSL_CONF"
  else
    echo "✓ Configuração generateResolvConf já existe em $WSL_CONF"
  fi
else
  echo -e "[network]\ngenerateResolvConf = false" > "$WSL_CONF"
  echo "✓ Arquivo $WSL_CONF criado com a geração automática desativada."
fi

# 3. Remover link simbólico antigo se existir
if [ -L "$RESOLV_CONF" ]; then
  rm -f "$RESOLV_CONF"
  echo "✓ Link simbólico antigo $RESOLV_CONF removido."
elif [ -f "$RESOLV_CONF" ]; then
  mv "$RESOLV_CONF" "${RESOLV_CONF}.bak"
  echo "✓ Backup do $RESOLV_CONF atual criado como ${RESOLV_CONF}.bak"
fi

# 4. Obter o IP do Host Windows (Gateway do WSL)
NAMESERVER_HOST=$(ip route show | grep default | awk '{print $3}')

if [ -z "$NAMESERVER_HOST" ]; then
  # Fallback caso não encontre rota padrão
  NAMESERVER_HOST="172.17.0.1"
fi

# 5. Escrever novo resolv.conf
cat <<EOF > "$RESOLV_CONF"
# Gerado por fix-dns.sh
# DNS público confiável + Gateway do Windows Host
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver $NAMESERVER_HOST
search localdomain
EOF

echo "✓ Novo arquivo $RESOLV_CONF gerado com sucesso:"
cat "$RESOLV_CONF"
echo "====================="
echo "Pronto! Se o DNS ainda não funcionar, tente reiniciar o WSL no PowerShell do Windows:"
echo "wsl --shutdown"
