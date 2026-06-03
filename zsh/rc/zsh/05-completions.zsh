# ============================================================================
# Completion System Configuration
# ============================================================================
# This module configures the zsh completion system for better performance
# and user experience across different commands and tools
# ============================================================================

# ============================================================================
# General Completion Settings
# ============================================================================

# Use cache for completions
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Create cache directory if it doesn't exist
[[ -d ~/.zsh/cache ]] || mkdir -p ~/.zsh/cache

# Enable menu selection
zstyle ':completion:*' menu select

# Use colors in completion menu
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Group completions by type
zstyle ':completion:*' group-name ''

# Verbose completion descriptions
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'

# ============================================================================
# Matching and Sorting
# ============================================================================

# Case-insensitive and fuzzy matching
zstyle ':completion:*' matcher-list '' \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'

# Sort files by modification time instead of alphabetically
zstyle ':completion:*' file-sort modification

# Show special directories (., ..)
zstyle ':completion:*' special-dirs true

# Don't sort git checkout completions (use frecency)
zstyle ':completion:*:git-checkout:*' sort false

# List directories first
zstyle ':completion:*' list-dirs-first true

# ============================================================================
# Command-specific Completions
# ============================================================================

# CD completion - prioritize local directories
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# Kill command - colorized process list
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# ============================================================================
# Performance Optimizations for Slow CLIs
# ============================================================================

# Azure CLI - very slow, aggressive caching
zstyle ':completion:*:az:*' timeout 1
zstyle ':completion:*:az:*' max-errors 0
zstyle ':completion:*:az:*' use-cache yes
zstyle ':completion:*:az:*' cache-path ~/.zsh/cache/az
zstyle ':completion:*:az:*' accept-exact '*(N)'

# kubectl - can be slow in large clusters
zstyle ':completion:*:kubectl:*' timeout 2
zstyle ':completion:*:kubectl:*' use-cache yes
zstyle ':completion:*:kubectl:*' cache-path ~/.zsh/cache/kubectl

# docker - can be slow with many containers
zstyle ':completion:*:docker:*' timeout 2

# terraform - can be slow in large projects
zstyle ':completion:*:terraform:*' timeout 2

# ============================================================================
# Advanced Completion Features
# ============================================================================

# Use approximate matching when exact match fails
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Ignore completion functions for commands we don't have
zstyle ':completion:*:functions' ignored-patterns '_*'

# Don't complete uninteresting users
zstyle ':completion:*:*:*:users' ignored-patterns \
        adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
        dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
        hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
        mailman mailnull mldonkey mysql nagios \
        named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
        operator pcap postfix postgres privoxy pulse pvm quagga radvd \
        rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs '_*'

# ============================================================================
# kubectl Completion (if available)
# ============================================================================
if command -v kubectl &> /dev/null; then
    # Load kubectl completion in background to avoid blocking startup
    {
        source <(kubectl completion zsh)
    } &!
fi

# ============================================================================
# Helm Completion (if available)
# ============================================================================
if command -v helm &> /dev/null; then
    # Load helm completion in background
    {
        source <(helm completion zsh)
    } &!
fi

# ============================================================================
# AWS CLI Completion (if available)
# ============================================================================
if command -v aws_completer &> /dev/null; then
    autoload -U bashcompinit && bashcompinit
    complete -C aws_completer aws
fi

# ============================================================================
# Terraform Completion (if available)
# ============================================================================
if command -v terraform &> /dev/null; then
    # Load terraform completion in background
    {
        autoload -U bashcompinit && bashcompinit
        complete -o nospace -C $(which terraform) terraform
        complete -o nospace -C $(which terraform) tf
    } &!
fi

# ============================================================================
# Docker Completion (if available and not already loaded)
# ============================================================================
if command -v docker &> /dev/null && [[ ! -f ~/.zsh/completions/_docker ]]; then
    # Docker completion is usually handled by Oh-My-Zsh plugin
    # This is a fallback if needed
    :
fi

# ============================================================================
# Git Completion Enhancements
# ============================================================================
# These settings improve git completion performance
zstyle ':completion:*:git:*' verbose no
zstyle ':completion:*:git-checkout:*' group-order heads-local heads-remote
zstyle ':completion:*:git-checkout:*' group-name ''

# ============================================================================
# History-based Completion
# ============================================================================
# Suggest commands from history
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# ============================================================================
# SSH/SCP/RSYNC Hostname Completion
# ============================================================================
# Read hostnames from various files
if [[ -f ~/.ssh/config ]]; then
    zstyle ':completion:*:(ssh|scp|rsync):*' hosts \
        $(awk '/^Host/ {print $2}' ~/.ssh/config | grep -v '[*?]')
fi

if [[ -f ~/.ssh/known_hosts ]]; then
    zstyle ':completion:*:(ssh|scp|rsync):*' hosts \
        $(awk '{print $1}' ~/.ssh/known_hosts | cut -d, -f1)
fi

# ============================================================================
# Man Pages Completion
# ============================================================================
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# ============================================================================
# Path Completion Optimization
# ============================================================================
# Expand partial paths
zstyle ':completion:*' path-completion true

# Expand glob patterns
zstyle ':completion:*' glob true

# Don't complete directories from PATH when completing files
zstyle ':completion:*' ignore-parents parent pwd

# ============================================================================
# Custom Completion Cache Cleanup
# ============================================================================
# Function to clean completion cache
clean_completion_cache() {
    echo "Cleaning completion cache..."
    rm -rf ~/.zsh/cache/*
    rm -f ~/.zcompdump*
    echo "Cache cleaned. Run 'compinit' to rebuild."
}

# ============================================================================
# Completion debugging function
# ============================================================================
# Uncomment to enable debugging
# debug_completion() {
#     zstyle ':completion:*' verbose yes
#     setopt WARN_CREATE_GLOBAL
#     autoload -U +X compinit && compinit
#     autoload -U +X bashcompinit && bashcompinit
# }
