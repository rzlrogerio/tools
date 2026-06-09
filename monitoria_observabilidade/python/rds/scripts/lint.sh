#!/usr/bin/env bash
set -euo pipefail

# Script para criar um venv, instalar ferramentas de lint/format e rodar
# Usage: ./scripts/lint.sh

PYTHON=${PYTHON:-/usr/bin/python3}
VENV_DIR=".venv-lint"

echo "Criando venv em ${VENV_DIR}..."
${PYTHON} -m venv "${VENV_DIR}"
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "Atualizando pip e instalando ferramentas: black, flake8, isort, autoflake"
python -m pip install --upgrade pip
python -m pip install black flake8 isort autoflake

# Encontrar arquivos .py do projeto, ignorando venvs
PY_FILES=$(find . -name '*.py' -not -path './.venv*' -not -path './.venv-lint*' -not -path './.venv/*' -print)

if [ -n "$PY_FILES" ]; then
	echo "Rodando autoflake (remove imports/vars não usados)..."
	printf '%s\0' $PY_FILES | xargs -0 -n 50 autoflake --in-place --remove-unused-variables --remove-all-unused-imports

	echo "Rodando isort (ordenar imports)..."
	printf '%s\0' $PY_FILES | xargs -0 -n 50 isort

	echo "Rodando black..."
	python -m black --line-length 88 $PY_FILES

	echo "Rodando flake8..."
	python -m flake8 --max-line-length=88 $PY_FILES
else
	echo "Nenhum arquivo .py encontrado para lintar."
fi

echo "Lint/format concluído. Saia do venv com: deactivate"
