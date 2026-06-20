#!/bin/bash
#===============================================================================
#
#          FILE: md-2-pdf.sh
# 
#         USAGE: ./md-2-pdf.sh <markdown_file>
# 
#   DESCRIPTION: Converte arquivos Markdown (.md) em PDF usando Pandoc e XeLaTeX.
# 
#  REQUIREMENTS: pandoc, xelatex (TeX Live / MacTeX), DejaVu Sans font
#         NOTES: Funciona em Linux e macOS.
#        AUTHOR: 
#       CREATED: 11/14/2024 10:45
#      REVISION: 1.1
#===============================================================================

# Define exit on error, treat unset variables as errors, and catch pipeline failures
set -euo pipefail

# --- Funções de Ajuda e Detecção ---

detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

print_install_instructions() {
    local os
    os=$(detect_os)
    
    echo "========================================================================"
    echo "ERRO: Dependências ausentes para a execução do script."
    echo "========================================================================"
    echo
    echo "Por favor, instale as seguintes ferramentas:"
    echo
    
    if [ "$os" = "macos" ]; then
        if ! check_command pandoc; then
            echo "  - pandoc:"
            echo "    brew install pandoc"
            echo
        fi
        if ! check_command xelatex; then
            echo "  - xelatex (MacTeX/BasicTeX):"
            echo "    brew install --cask mactex-no-gui"
            echo "    (Após instalar, pode ser necessário reiniciar o terminal para atualizar o PATH)"
            echo
        fi
    elif [ "$os" = "linux" ]; then
        if [ -f /etc/debian_version ]; then
            # Ubuntu, Debian, Mint, etc.
            if ! check_command pandoc; then
                echo "  - pandoc:"
                echo "    sudo apt-get update && sudo apt-get install -y pandoc"
                echo
            fi
            if ! check_command xelatex; then
                echo "  - xelatex (TeX Live XeTeX):"
                echo "    sudo apt-get update && sudo apt-get install -y texlive-xetex texlive-fonts-recommended"
                echo
            fi
        elif [ -f /etc/arch-release ]; then
            # Arch Linux
            if ! check_command pandoc; then
                echo "  - pandoc:"
                echo "    sudo pacman -S --needed pandoc-cli"
                echo
            fi
            if ! check_command xelatex; then
                echo "  - xelatex:"
                echo "    sudo pacman -S --needed texlive-bin texlive-fontsrecommended"
                echo
            fi
        elif [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then
            # Fedora, RHEL, CentOS
            if ! check_command pandoc; then
                echo "  - pandoc:"
                echo "    sudo dnf install -y pandoc"
                echo
            fi
            if ! check_command xelatex; then
                echo "  - xelatex (TeX Live):"
                echo "    sudo dnf install -y texlive-xetex texlive-collection-fontsrecommended"
                echo
            fi
        else
            # Outras distribuições Linux genéricas
            if ! check_command pandoc; then
                echo "  - pandoc (instale através do gerenciador de pacotes da sua distribuição)"
            fi
            if ! check_command xelatex; then
                echo "  - xelatex/texlive (instale através do gerenciador de pacotes da sua distribuição)"
            fi
            echo
        fi
    else
        echo "  - pandoc e xelatex (TeX Live)"
        echo
    fi
}

check_font() {
    local font_name="$1"
    if check_command fc-list; then
        if fc-list : family | grep -qi "$font_name"; then
            return 0
        fi
    elif [ "$(detect_os)" = "macos" ]; then
        # No macOS, se fc-list não estiver instalado, podemos verificar nos diretórios padrão de fontes
        local font_no_spaces="${font_name// /}"
        if [ -d "$HOME/Library/Fonts" ] && find "$HOME/Library/Fonts" -iname "*${font_no_spaces}*" -maxdepth 2 2>/dev/null | grep -q .; then
            return 0
        fi
        if [ -d "/Library/Fonts" ] && find "/Library/Fonts" -iname "*${font_no_spaces}*" -maxdepth 2 2>/dev/null | grep -q .; then
            return 0
        fi
        if [ -d "/System/Library/Fonts" ] && find "/System/Library/Fonts" -iname "*${font_no_spaces}*" -maxdepth 2 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    return 1
}

# --- Validação de Argumentos ---

if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <arquivo_markdown.md>"
    exit 1
fi

fileName="$1"

if [ ! -f "$fileName" ]; then
    echo "Erro: O arquivo '$fileName' não existe."
    exit 1
fi

# --- Verificação de Dependências ---

if ! check_command pandoc || ! check_command xelatex; then
    print_install_instructions
    exit 1
fi

# --- Verificação de Fonte ---
FONT_FAMILY="DejaVu Sans"
if ! check_font "$FONT_FAMILY"; then
    echo "Aviso: A fonte '$FONT_FAMILY' não foi detectada no sistema."
    echo "O PDF pode falhar ao ser gerado ou usar uma fonte padrão do sistema."
    os=$(detect_os)
    if [ "$os" = "linux" ]; then
        if [ -f /etc/debian_version ]; then
            echo "Dica para instalar no Ubuntu/Debian: sudo apt-get install -y fonts-dejavu"
        elif [ -f /etc/arch-release ]; then
            echo "Dica para instalar no Arch: sudo pacman -S ttf-dejavu"
        elif [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then
            echo "Dica para instalar no Fedora: sudo dnf install -y dejavu-sans-fonts"
        fi
    elif [ "$os" = "macos" ]; then
        echo "Dica para instalar no macOS:"
        echo "  brew install --cask font-dejavu"
    fi
    echo
fi

# --- Execução ---

# Remove a extensão do arquivo original de forma segura e adiciona .pdf
outPDF="${fileName%.*}.pdf"

echo "Convertendo '$fileName' para '$outPDF'..."
if pandoc "$fileName" -s -o "$outPDF" --pdf-engine=xelatex -V mainfont="$FONT_FAMILY"; then
    echo "Sucesso! Arquivo '$outPDF' gerado com êxito."
else
    echo "Erro: Falha na geração do PDF através do Pandoc."
    exit 1
fi
