#!/bin/bash
#===============================================================================
#          FILE: setup_venv.sh
#   DESCRIPTION: Prepara o ambiente virtual Python (venv) e instala as dependências
#        AUTHOR: Rogério de Araújo Rodrigues
#===============================================================================

set -euo pipefail

VENV_DIR=".venv"

echo "Criando o ambiente virtual Python em '$VENV_DIR'..."
python3 -m venv "$VENV_DIR"

echo "Ativando o ambiente virtual e instalando as dependências..."
# Executa a instalação de dependências diretamente usando o pip do venv
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install boto3

echo "--------------------------------------------------------"
echo "Ambiente preparado com sucesso!"
echo "Para ativar o ambiente virtual no seu terminal, execute:"
echo "  source $VENV_DIR/bin/activate"
echo "--------------------------------------------------------"
