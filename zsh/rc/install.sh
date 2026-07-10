#!/usr/bin/env bash
# ============================================================================
# Universal Zsh Configuration Installer
# ============================================================================
# This script installs the modular Zsh configuration with automatic backup
# Compatible with macOS, Linux, and WSL
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================================"
    echo "  $1"
    echo "============================================================================"
    echo ""
}

# Check if script is being run from the correct directory
check_directory() {
    if [[ ! -f "zshrc-universal" ]] || [[ ! -d "zsh" ]]; then
        print_error "Este script deve ser executado do diretório que contém 'zshrc-universal' e 'zsh/'"
        print_info "Por favor, navegue até o diretório correto e execute novamente."
        exit 1
    fi
}

# Create backup of existing .zshrc
backup_zshrc() {
    if [[ -f "$HOME/.zshrc" ]]; then
        local backup_file="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Criando backup do .zshrc atual..."
        cp "$HOME/.zshrc" "$backup_file"
        print_success "Backup criado: $backup_file"
        return 0
    else
        print_warning "Nenhum .zshrc existente encontrado (primeira instalação)"
        return 1
    fi
}

# Check if Oh-My-Zsh is installed
check_ohmyzsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_warning "Oh-My-Zsh não está instalado!"
        echo ""
        echo "Esta configuração requer Oh-My-Zsh. Você pode instalá-lo com:"
        echo "  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        echo ""
        read -p "Deseja instalar Oh-My-Zsh agora? (s/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            print_info "Instalando Oh-My-Zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            print_success "Oh-My-Zsh instalado com sucesso"
        else
            print_error "Instalação cancelada. Por favor, instale Oh-My-Zsh primeiro."
            exit 1
        fi
    else
        print_success "Oh-My-Zsh já está instalado"
    fi
}

# Install required Oh-My-Zsh plugins
install_plugins() {
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

    print_info "Verificando plugins necessários..."

    # zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        print_info "Instalando zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
        print_success "zsh-autosuggestions instalado"
    else
        print_success "zsh-autosuggestions já está instalado"
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        print_info "Instalando zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        print_success "zsh-syntax-highlighting instalado"
    else
        print_success "zsh-syntax-highlighting já está instalado"
    fi

    # zsh-history-substring-search
    if [[ ! -d "$plugins_dir/zsh-history-substring-search" ]]; then
        print_info "Instalando zsh-history-substring-search..."
        git clone https://github.com/zsh-users/zsh-history-substring-search "$plugins_dir/zsh-history-substring-search"
        print_success "zsh-history-substring-search instalado"
    else
        print_success "zsh-history-substring-search já está instalado"
    fi
}

# Install configuration files
install_config() {
    print_info "Instalando arquivos de configuração..."

    # Create config directory
    mkdir -p "$HOME/.config/zsh"
    print_success "Diretório de configuração criado: ~/.config/zsh"

    # Copy main zshrc file
    cp zshrc-universal "$HOME/.zshrc"
    print_success "Arquivo principal copiado: ~/.zshrc"

    # Copy module files
    cp -r zsh/* "$HOME/.config/zsh/"
    print_success "Módulos copiados para: ~/.config/zsh/"

    # Create cache directory
    mkdir -p "$HOME/.zsh/cache"
    print_success "Diretório de cache criado: ~/.zsh/cache"

    # Copy get-context.sh to user's ~/bin
    mkdir -p "$HOME/bin"
    if [[ -f "../bin/get-context.sh" ]]; then
        cp "../bin/get-context.sh" "$HOME/bin/"
        chmod +x "$HOME/bin/get-context.sh"
        print_success "Script get-context.sh copiado para: ~/bin/"
    else
        print_warning "Arquivo ../bin/get-context.sh não encontrado para copiar para ~/bin"
    fi

    # Copy rogerio.zsh-theme to ~/.oh-my-zsh/themes/
    if [[ -d "$HOME/.oh-my-zsh/themes" ]]; then
        if [[ -f "../theme/rogerio.zsh-theme" ]]; then
            cp "../theme/rogerio.zsh-theme" "$HOME/.oh-my-zsh/themes/"
            print_success "Tema rogerio.zsh-theme copiado para: ~/.oh-my-zsh/themes/"
        else
            print_warning "Arquivo de tema ../theme/rogerio.zsh-theme não encontrado"
        fi
    else
        print_warning "Diretório de temas do Oh-My-Zsh (~/.oh-my-zsh/themes) não encontrado"
    fi
}

# Show post-installation information
show_postinstall_info() {
    print_header "Instalação Concluída com Sucesso!"

    echo "Próximos passos:"
    echo ""
    echo "1. Reinicie seu terminal ou execute:"
    echo "   ${GREEN}source ~/.zshrc${NC}"
    echo ""
    echo "2. (Opcional) Instale ferramentas recomendadas:"
    echo "   - fzf: busca fuzzy no histórico"
    echo "   - asdf: gerenciador de versões"
    echo "   - exa/eza: melhor 'ls'"
    echo "   - bat: melhor 'cat'"
    echo "   - fd: melhor 'find'"
    echo ""
    echo "3. Para personalizar, crie o arquivo: ${BLUE}~/.zshrc.local${NC}"
    echo ""
    echo "4. Para ver informações do ambiente detectado:"
    echo "   Edite ${BLUE}~/.config/zsh/00-detect-env.zsh${NC} e descomente a função print_env_info"
    echo ""
    echo "5. Se precisar instalar o asdf, execute no terminal:"
    echo "   ${GREEN}install_asdf${NC}"
    echo ""

    if [[ -n "$BACKUP_FILE" ]]; then
        echo "Seu .zshrc anterior foi salvo em:"
        echo "   ${YELLOW}$BACKUP_FILE${NC}"
        echo ""
    fi

    print_success "Configuração instalada com sucesso!"
    echo ""
}

# Check for optional tools
check_optional_tools() {
    print_header "Verificando Ferramentas Opcionais"

    local tools=("fzf" "asdf" "exa" "eza" "bat" "batcat" "fd" "rg" "htop")
    local installed=()
    local missing=()

    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            installed+=("$tool")
        else
            missing+=("$tool")
        fi
    done

    if [[ ${#installed[@]} -gt 0 ]]; then
        print_success "Ferramentas instaladas: ${installed[*]}"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Ferramentas opcionais não instaladas: ${missing[*]}"
        echo ""
        echo "Estas ferramentas melhoram a experiência, mas não são obrigatórias."
        echo "Veja o README.md para instruções de instalação."
    fi

    echo ""
}

# Verify installation
verify_installation() {
    print_info "Verificando instalação..."

    local errors=0

    if [[ ! -f "$HOME/.zshrc" ]]; then
        print_error "~/.zshrc não encontrado"
        ((errors++))
    fi

    if [[ ! -d "$HOME/.config/zsh" ]]; then
        print_error "~/.config/zsh não encontrado"
        ((errors++))
    fi

    local modules=("00-detect-env.zsh" "01-path.zsh" "02-asdf.zsh" "03-common.zsh" "04-aliases.zsh" "05-completions.zsh")
    for module in "${modules[@]}"; do
        if [[ ! -f "$HOME/.config/zsh/$module" ]]; then
            print_error "Módulo não encontrado: $module"
            ((errors++))
        fi
    done

    if [[ ! -f "$HOME/bin/get-context.sh" ]]; then
        print_error "~/bin/get-context.sh não encontrado"
        ((errors++))
    fi

    if [[ ! -f "$HOME/.oh-my-zsh/themes/rogerio.zsh-theme" ]]; then
        print_error "Tema rogerio.zsh-theme não encontrado em ~/.oh-my-zsh/themes/"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        print_success "Todos os arquivos foram instalados corretamente"
        return 0
    else
        print_error "Encontrados $errors erro(s) durante a verificação"
        return 1
    fi
}

# Main installation function
main() {
    print_header "Instalador de Configuração Universal do Zsh"

    echo "Este script irá:"
    echo "  • Fazer backup do seu .zshrc atual (se existir)"
    echo "  • Verificar/instalar Oh-My-Zsh"
    echo "  • Instalar plugins necessários"
    echo "  • Copiar a configuração modular para ~/.config/zsh"
    echo "  • Configurar o novo ~/.zshrc"
    echo ""

    read -p "Deseja continuar? (s/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
        print_error "Instalação cancelada pelo usuário"
        exit 0
    fi

    # Run installation steps
    check_directory

    print_header "Etapa 1: Backup"
    backup_zshrc || true  # Don't exit if no backup needed
    BACKUP_FILE=$(ls -t "$HOME"/.zshrc.backup.* 2>/dev/null | head -1)

    print_header "Etapa 2: Verificando Oh-My-Zsh"
    check_ohmyzsh

    print_header "Etapa 3: Instalando Plugins"
    install_plugins

    print_header "Etapa 4: Instalando Configuração"
    install_config

    print_header "Etapa 5: Verificando Instalação"
    if ! verify_installation; then
        print_error "Instalação completada com erros. Verifique as mensagens acima."
        exit 1
    fi

    check_optional_tools
    show_postinstall_info
}

# Run main function
main "$@"
