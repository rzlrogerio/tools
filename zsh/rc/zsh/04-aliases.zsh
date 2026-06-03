# ============================================================================
# Aliases Configuration
# ============================================================================
# This module defines aliases with intelligent detection of available commands
# Aliases are only created if the underlying command is available
# ============================================================================

# ============================================================================
# General Aliases
# ============================================================================

# Less - case insensitive search
alias less="less -i"

# Grep - case insensitive by default
alias grep="grep -i"

# Python - ensure python3 is used
if command -v python3 &> /dev/null; then
    alias python="python3"
fi

if command -v pip3 &> /dev/null; then
    alias pip="pip3"
fi

# ============================================================================
# Better alternatives (if available)
# ============================================================================

# bat/batcat - better cat with syntax highlighting
if command -v batcat &> /dev/null; then
    alias bat="batcat"
    alias cat="batcat --paging=never"
elif command -v bat &> /dev/null; then
    alias cat="bat --paging=never"
fi

# exa - better ls (if available)
if command -v exa &> /dev/null; then
    alias ls="exa --icons"
    alias ll="exa -l --icons --git"
    alias la="exa -la --icons --git"
    alias lt="exa --tree --icons --level=2"
elif command -v eza &> /dev/null; then
    # eza is the new maintained fork of exa
    alias ls="eza --icons"
    alias ll="eza -l --icons --git"
    alias la="eza -la --icons --git"
    alias lt="eza --tree --icons --level=2"
else
    # Fallback to standard ls with colors
    if [[ "$IS_MAC" == true ]]; then
        alias ls="ls -G"
        alias ll="ls -lhG"
        alias la="ls -lahG"
    else
        alias ls="ls --color=auto"
        alias ll="ls -lh --color=auto"
        alias la="ls -lah --color=auto"
    fi
fi

# fd - better find (if available)
if command -v fd &> /dev/null; then
    alias find="fd"
fi

# ripgrep - better grep (if available)
if command -v rg &> /dev/null; then
    alias rgrep="rg"
fi

# htop - better top (if available)
if command -v htop &> /dev/null; then
    alias top="htop"
elif command -v btop &> /dev/null; then
    alias top="btop"
fi

# ============================================================================
# Directory Navigation
# ============================================================================
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# Quick directory listing after cd
function cd() {
    builtin cd "$@" && ls
}

# ============================================================================
# Git Aliases
# ============================================================================
if command -v git &> /dev/null; then
    alias g="git"
    alias gs="git status"
    alias ga="git add"
    alias gc="git commit"
    alias gp="git push"
    alias gl="git pull"
    alias gd="git diff"
    alias gco="git checkout"
    alias gb="git branch"
    alias glog="git log --oneline --graph --decorate"
    alias gclean="git clean -fd"
fi

# ============================================================================
# Docker Aliases
# ============================================================================
if command -v docker &> /dev/null; then
    alias d="docker"
    alias dc="docker-compose"
    alias dps="docker ps"
    alias dpsa="docker ps -a"
    alias di="docker images"
    alias dex="docker exec -it"
    alias dlog="docker logs -f"
    alias dstop="docker stop"
    alias drm="docker rm"
    alias drmi="docker rmi"
    alias dprune="docker system prune -af"
fi

# ============================================================================
# Kubernetes Aliases
# ============================================================================
if command -v kubectl &> /dev/null; then
    alias k="kubectl"
    alias kgp="kubectl get pods"
    alias kgs="kubectl get svc"
    alias kgd="kubectl get deployments"
    alias kgn="kubectl get nodes"
    alias kdp="kubectl describe pod"
    alias kds="kubectl describe service"
    alias kdd="kubectl describe deployment"
    alias kl="kubectl logs -f"
    alias kex="kubectl exec -it"
    alias kctx="kubectx"
    alias kns="kubens"
fi

# ============================================================================
# Terraform Aliases
# ============================================================================
if command -v terraform &> /dev/null; then
    alias tf="terraform"
    alias tfi="terraform init"
    alias tfp="terraform plan"
    alias tfa="terraform apply"
    alias tfd="terraform destroy"
    alias tfv="terraform validate"
    alias tff="terraform fmt"
    alias tfw="terraform workspace"
fi

# ============================================================================
# Azure CLI Aliases
# ============================================================================
if command -v az &> /dev/null; then
    alias azl="az account list -o table"
    alias azs="az account show"
    alias azset="az account set --subscription"
    alias azg="az group list -o table"
    alias azvm="az vm list -o table"
fi

# ============================================================================
# System-specific Aliases
# ============================================================================

if [[ "$IS_MAC" == true ]]; then
    # macOS specific aliases
    alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES; killall Finder"
    alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO; killall Finder"
    alias brewup="brew update && brew upgrade && brew cleanup"

elif [[ "$IS_LINUX" == true ]] && [[ "$IS_WSL" == false ]]; then
    # Linux specific aliases (not WSL)
    if [[ "$HAS_APT" == true ]]; then
        alias update="sudo apt update && sudo apt upgrade -y"
        alias install="sudo apt install"
        alias remove="sudo apt remove"
        alias search="apt search"
    elif [[ "$HAS_DNF" == true ]]; then
        alias update="sudo dnf update -y"
        alias install="sudo dnf install"
        alias remove="sudo dnf remove"
        alias search="dnf search"
    elif [[ "$HAS_PACMAN" == true ]]; then
        alias update="sudo pacman -Syu"
        alias install="sudo pacman -S"
        alias remove="sudo pacman -R"
        alias search="pacman -Ss"
    fi

elif [[ "$IS_WSL" == true ]]; then
    # WSL specific aliases
    alias open="wslview"
    alias explorer="explorer.exe"

    # VSCode: prefer VSCode Server (remote) over code.exe
    # Only alias to code.exe if VSCode Server is not available
    if ! command -v code &> /dev/null && command -v code.exe &> /dev/null; then
        alias code="code.exe"
    fi

    # Windows clipboard integration
    alias pbcopy="clip.exe"
    if command -v powershell.exe &> /dev/null; then
        alias pbpaste="powershell.exe Get-Clipboard"
    fi
fi

# ============================================================================
# Utility Functions
# ============================================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"    ;;
            *.tar.gz)    tar xzf "$1"    ;;
            *.tar.xz)    tar xJf "$1"    ;;
            *.bz2)       bunzip2 "$1"    ;;
            *.rar)       unrar x "$1"    ;;
            *.gz)        gunzip "$1"     ;;
            *.tar)       tar xf "$1"     ;;
            *.tbz2)      tar xjf "$1"    ;;
            *.tgz)       tar xzf "$1"    ;;
            *.zip)       unzip "$1"      ;;
            *.Z)         uncompress "$1" ;;
            *.7z)        7z x "$1"       ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Get IP addresses
myip() {
    if [[ "$IS_WSL" == true ]]; then
        echo "WSL IP: $(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
        echo "Windows IP: $HOST_IP"
    elif [[ "$IS_MAC" == true ]]; then
        echo "Local IP: $(ipconfig getifaddr en0)"
    else
        echo "Local IP: $(hostname -I | awk '{print $1}')"
    fi

    if command -v curl &> /dev/null; then
        echo "Public IP: $(curl -s ifconfig.me)"
    fi
}

# Quick web server
serve() {
    local port="${1:-8000}"
    if command -v python3 &> /dev/null; then
        python3 -m http.server "$port"
    elif command -v python &> /dev/null; then
        python -m SimpleHTTPServer "$port"
    else
        echo "Python not found"
    fi
}

# ============================================================================
# Custom Aliases (add your own here or in ~/.zshrc.local)
# ============================================================================
# This section is intentionally empty
# Add your custom aliases to ~/.zshrc.local to keep them separate
