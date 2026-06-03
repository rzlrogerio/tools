# ============================================================================
# PATH Configuration Module
# ============================================================================
# This module configures PATH based on the detected operating system
# It intelligently adds paths only if they exist
# ============================================================================

# Helper function to add to PATH only if directory exists
add_to_path() {
    if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$1:$PATH"
    fi
}

add_to_path_end() {
    if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$PATH:$1"
    fi
}

# ============================================================================
# Common paths (all systems)
# ============================================================================
# Note: We add to PATH without removing existing entries to preserve
# VSCode Server, devcontainers, and other tool paths

add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"
add_to_path "$HOME/.cargo/bin"  # Rust
add_to_path "$HOME/go/bin"      # Go

# Krew (kubectl plugin manager)
add_to_path "${KREW_ROOT:-$HOME/.krew}/bin"

# ============================================================================
# macOS specific paths
# ============================================================================
if [[ "$IS_MAC" == true ]]; then
    # Homebrew paths - different locations for Intel vs Apple Silicon
    if [[ "$IS_ARM" == true ]]; then
        # Apple Silicon (M1/M2/M3)
        add_to_path "/opt/homebrew/bin"
        add_to_path "/opt/homebrew/sbin"

        # Set HOMEBREW_PREFIX for Apple Silicon
        [[ -d "/opt/homebrew" ]] && export HOMEBREW_PREFIX="/opt/homebrew"
    else
        # Intel Mac
        add_to_path "/usr/local/bin"
        add_to_path "/usr/local/sbin"

        # Set HOMEBREW_PREFIX for Intel
        [[ -d "/usr/local/Cellar" ]] && export HOMEBREW_PREFIX="/usr/local"
    fi

    # User-local homebrew installation
    add_to_path "$HOME/homebrew/bin"
    add_to_path "$HOME/homebrew/sbin"

    # macOS system paths
    add_to_path_end "/usr/bin"
    add_to_path_end "/bin"
    add_to_path_end "/usr/sbin"
    add_to_path_end "/sbin"
fi

# ============================================================================
# Linux specific paths
# ============================================================================
if [[ "$IS_LINUX" == true ]]; then
    # Linuxbrew (Homebrew on Linux)
    add_to_path "/home/linuxbrew/.linuxbrew/bin"
    add_to_path "/home/linuxbrew/.linuxbrew/sbin"

    # User-local homebrew on Linux
    add_to_path "$HOME/.linuxbrew/bin"
    add_to_path "$HOME/.linuxbrew/sbin"

    # Standard Linux paths
    add_to_path "/usr/local/bin"
    add_to_path "/usr/local/sbin"
fi

# ============================================================================
# WSL specific paths
# ============================================================================
if [[ "$IS_WSL" == true ]]; then
    # WSL-specific configurations

    # Get Windows IP for X11 forwarding
    if command -v host &> /dev/null; then
        export HOST_IP=$(host `hostname` | grep -oP '(\s)\d+(\.\d+){3}' | tail -1 | awk '{ print $NF }' | tr -d '\r')
        export DISPLAY="${HOST_IP}:0.0"
    else
        export DISPLAY=:0
    fi

    # WSL graphics support
    export LIBGL_ALWAYS_INDIRECT=1
    export NO_AT_BRIDGE=1
    # export PULSE_SERVER=tcp:$HOST_IP  # Uncomment if you need audio

    # Windows browser integration
    if [[ -f "$HOME/bin/chrome-wrapper.sh" ]]; then
        export BROWSER="$HOME/bin/chrome-wrapper.sh"
    fi
fi

# ============================================================================
# Go configuration
# ============================================================================
if command -v go &> /dev/null; then
    export GO111MODULE=on
    export GOPATH="$HOME/go"
    add_to_path "$GOPATH/bin"
fi

# ============================================================================
# Display configuration
# ============================================================================
# Set display to :0 if not already set (useful for WSL and remote sessions)
[[ -z "$DISPLAY" ]] && export DISPLAY=:0

# ============================================================================
# Locale settings
# ============================================================================
# Use English date/time format
export LC_TIME=en_US.utf8

# Editor
export EDITOR=vim
export VISUAL=vim

# Pager
export PAGER=less
export LESS="-R -i"  # -R: show colors, -i: ignore case in searches
