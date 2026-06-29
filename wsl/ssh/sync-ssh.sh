#!/bin/bash

# Script para sincronizar e configurar as chaves SSH do Windows para o WSL.
# Garante que as chaves sejam copiadas com as permissões corretas exigidas pelo SSH (permissões 600).

SSH_DIR_WSL="$HOME/.ssh"

echo "=== WSL SSH Key Sync ==="

# 1. Obter o nome do usuário do Windows
echo "Buscando usuário do Windows..."
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' | tr -d ' ')

if [ -z "$WIN_USER" ]; then
  # Fallback: tentar obter a partir da pasta /mnt/c/Users/ excluindo padrões
  echo "Aviso: Não foi possível obter o usuário via cmd.exe. Tentando via sistema de arquivos..."
  WIN_USER=$(ls -1 /mnt/c/Users/ | grep -vE 'Public|Default|All Users|desktop.ini' | head -n 1)
fi

if [ -z "$WIN_USER" ]; then
  echo "Erro: Não foi possível encontrar o usuário do Windows em /mnt/c/Users/"
  exit 1
fi

echo "✓ Usuário do Windows identificado: $WIN_USER"
SSH_DIR_WIN="/mnt/c/Users/$WIN_USER/.ssh"

# 2. Verificar se o diretório .ssh do Windows existe
if [ ! -d "$SSH_DIR_WIN" ]; then
  echo "Erro: O diretório SSH do Windows não foi encontrado em: $SSH_DIR_WIN"
  exit 1
fi

# 3. Criar o diretório .ssh no WSL se não existir
if [ ! -d "$SSH_DIR_WSL" ]; then
  mkdir -p "$SSH_DIR_WSL"
  chmod 700 "$SSH_DIR_WSL"
  echo "✓ Diretório $SSH_DIR_WSL criado com permissões corretas (700)."
else
  chmod 700 "$SSH_DIR_WSL"
  echo "✓ Diretório $SSH_DIR_WSL já existe. Permissões ajustadas para 700."
fi

# 4. Copiar as chaves e configurar as permissões
echo "Copiando chaves SSH do Windows para o WSL..."

# Lista de chaves comuns para copiar
KEYS_TO_COPY=(
  "id_rsa"
  "id_rsa.pub"
  "id_ed25519"
  "id_ed25519.pub"
  "id_ecdsa"
  "id_ecdsa.pub"
  "config"
  "authorized_keys"
)

COPIED_COUNT=0

for key in "${KEYS_TO_COPY[@]}"; do
  WIN_KEY_PATH="$SSH_DIR_WIN/$key"
  WSL_KEY_PATH="$SSH_DIR_WSL/$key"

  if [ -f "$WIN_KEY_PATH" ]; then
    cp "$WIN_KEY_PATH" "$WSL_KEY_PATH"
    
    # Ajustar permissões dependendo se é chave privada ou pública/config
    if [[ "$key" == *.pub || "$key" == "config" || "$key" == "authorized_keys" ]]; then
      chmod 644 "$WSL_KEY_PATH"
      echo "  → Copiado: $key (permissões 644)"
    else
      chmod 600 "$WSL_KEY_PATH"
      echo "  → Copiado: $key (permissões 600 - Privada)"
    fi
    COPIED_COUNT=$((COPIED_COUNT + 1))
  fi
done

echo "====================="
if [ "$COPIED_COUNT" -eq 0 ]; then
  echo "Nenhuma chave SSH encontrada em $SSH_DIR_WIN."
else
  echo "Sincronização concluída! $COPIED_COUNT arquivo(s) copiado(s) e configurado(s)."
  echo "Chaves disponíveis no WSL:"
  ls -la "$SSH_DIR_WSL"
fi
