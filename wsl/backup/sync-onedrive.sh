#!/bin/bash - 
#===============================================================================
#
#          FILE: sync-onedrive.sh
# 
#         USAGE: ./sync-onedrive.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Rogerio de Araujo Rodrigues (), 
#  ORGANIZATION: 
#       CREATED: 06/29/2024 10:50
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Lista de arquivos e diretórios de origem a sincronizar.
# Pode incluir tanto caminhos absolutos quanto relativos à $HOME.
SOURCES=(
    "$HOME/1-work/"                              # diretório principal de trabalho
    "$HOME/bin/"                                 # script e tools
    "$HOME/.oh-my-zsh"                           # tema personalizado oh-my-zsh
    "$HOME/.zshrc"                               # configuração zsh
    "$HOME/.vimrc"                               # configuração vim
    "$HOME/.vim/"                                # diretório .vim
    "$HOME/.config/Code/User/settings.json"      # configurações do VSCode
    "$HOME/.zsh_history"                         # history
    "$HOME/.aws/config"                          # config aws
    "$HOME/.ssh/id_rsa.pub"                      # chave do ssh
)

# Diretório base de destino onde tudo será replicado
DESTINO_BASE="$HOME/1-work-windows"  # sem barra final para facilitar concatenação

# Caminho do lock file
LOCKFILE="/tmp/rsync_work_sync.lock"

# Verifica se o lock file já existe
if [ -e "$LOCKFILE" ]; then
        echo "O script já está em execução. Abortando." >&2
        exit 1
fi

# Cria o lock file
touch "$LOCKFILE"

# Função para remover o lock file ao sair
cleanup() {
        rm -f "$LOCKFILE"
}
trap cleanup EXIT

# Garante que diretório base de destino existe
mkdir -p "$DESTINO_BASE"

# Opções comuns do rsync
RSYNC_OPTS=(
    -avh
    --delete
    --progress
    --exclude='.git'
    --exclude='.terraform'
    --exclude='.terraform.lock.hcl'
    --exclude='node_modules'
    --exclude='__pycache__'
    --exclude='*.pyc'
    --exclude='*.pyo'
    --exclude='*.tmp'
    --exclude='*.swp'
    --exclude='*.swo'
    --exclude='.DS_Store'
    --exclude='Thumbs.db'
    --exclude='*.log'
    --exclude='.cache'
    --exclude='.vscode'
    --exclude='.idea'
    --exclude='target'
    --exclude='build'
    --exclude='dist'
    --exclude='.next'
)

echo "Iniciando sincronização de ${#SOURCES[@]} itens..."

for SRC in "${SOURCES[@]}"; do
    # Expande ~ se usado e remove dupla barra eventual
    EXPANDED_SRC="${SRC/#\~/$HOME}"
    if [ ! -e "$EXPANDED_SRC" ]; then
        echo "Aviso: origem '$EXPANDED_SRC' não existe, pulando." >&2
        continue
    fi

    # Determina subcaminho relativo para armazenar no destino
    # Se estiver dentro de $HOME usa caminho relativo
    RELATIVE_PATH="${EXPANDED_SRC#$HOME/}" # remove prefixo $HOME

    # Se for arquivo, precisamos só garantir diretório pai
    if [ -f "$EXPANDED_SRC" ]; then
        DEST_PATH="$DESTINO_BASE/$RELATIVE_PATH"
        mkdir -p "$(dirname "$DEST_PATH")"
        echo "Sincronizando arquivo: $EXPANDED_SRC -> $DEST_PATH"
        rsync "${RSYNC_OPTS[@]}" "$EXPANDED_SRC" "$DEST_PATH"
    else
        # Diretório: garantir destino
        DEST_DIR="$DESTINO_BASE/$RELATIVE_PATH"
        mkdir -p "$DEST_DIR"
        echo "Sincronizando diretório: $EXPANDED_SRC -> $DEST_DIR/"
        rsync "${RSYNC_OPTS[@]}" "$EXPANDED_SRC" "$DEST_DIR/"
    fi
done

echo "Sincronização concluída."
