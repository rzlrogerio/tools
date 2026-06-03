# ============================================================================
# Common Shell Configuration
# ============================================================================
# This module contains settings that are common across all operating systems
# History, completions initialization, and performance optimizations
# ============================================================================

# ============================================================================
# History Configuration
# ============================================================================
HISTFILE=~/.zsh_history
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# ============================================================================
# Completion System
# ============================================================================
# Initialize completions
autoload -Uz compinit

# Optimize compinit - only regenerate once per day
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# ============================================================================
# Git Performance Optimizations
# ============================================================================
# Disable tracking of untracked files in large repositories
export DISABLE_UNTRACKED_FILES_DIRTY="true"

# Configure git to hide status in oh-my-zsh (speeds up prompt)
if command -v git &> /dev/null; then
    git config --global --add oh-my-zsh.hide-status 1 2>/dev/null
    git config --global --add oh-my-zsh.hide-dirty 1 2>/dev/null
fi

# ============================================================================
# Azure CLI Optimizations
# ============================================================================
# Load Azure CLI completion asynchronously to prevent blocking
# Note: Azure CLI uses bash completion, which needs bashcompinit in zsh
if [[ -f /etc/bash_completion.d/azure-cli ]]; then
    {
        # Load bashcompinit for bash completion compatibility
        autoload -U bashcompinit &> /dev/null && bashcompinit &> /dev/null
        source /etc/bash_completion.d/azure-cli 2>/dev/null
    } &!
fi

# Function to update Azure CLI cache
update_az_cache() {
    echo "Atualizando cache do Azure CLI..."
    local cache_dir="$HOME/.zsh/cache/az"
    mkdir -p "$cache_dir"

    # Cache common commands
    echo "login logout account configure group vm webapp storage network keyvault acr aks cosmosdb sql functionapp monitor backup deployment resource provider extension version help" > "$cache_dir/commands"

    # Cache resource groups and subscriptions if logged in
    if az account show &>/dev/null; then
        az group list --query "[].name" -o tsv 2>/dev/null > "$cache_dir/resource-groups" || true
        az account list --query "[].name" -o tsv 2>/dev/null > "$cache_dir/subscriptions" || true
    fi

    echo "Cache do Azure CLI atualizado!"
}

# ============================================================================
# FZF History Search Configuration
# ============================================================================
# Enhanced history search with FZF
fzf-history-widget() {
    local selected num
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null

    # Use fc with chronological order, most recent at bottom
    selected=( $(fc -l 1 | awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $1 "\t" cmd }' |
        fzf --height=40% --layout=reverse --border --ansi --header='Histórico: mais recentes embaixo' +m --query="$LBUFFER" --nth=2.. --tac) )
    local ret=$?

    if [ -n "$selected" ]; then
        num=$selected[1]
        if [ -n "$num" ]; then
            zle vi-fetch-history -n $num
        fi
    fi
    zle reset-prompt
    return $ret
}

# Only create widget if FZF is available
if command -v fzf &> /dev/null; then
    zle -N fzf-history-widget
    bindkey '^R' fzf-history-widget
    bindkey '^X^R' history-incremental-search-backward
fi

# ============================================================================
# Keybindings
# ============================================================================
# History substring search (from plugin)
# These are configured after plugins are loaded
if [[ -n "${key[Up]}" ]]; then
    bindkey "${key[Up]}" history-substring-search-up
fi
if [[ -n "${key[Down]}" ]]; then
    bindkey "${key[Down]}" history-substring-search-down
fi

# Tab completion navigation
bindkey '^[[Z' reverse-menu-complete  # Shift+Tab to go back
bindkey '^I' menu-complete            # Tab to advance

# ============================================================================
# Additional Configuration Files
# ============================================================================
# Load user's custom autocomplete configuration if it exists
[[ -f ~/.zsh_autocomplete_config ]] && source ~/.zsh_autocomplete_config
