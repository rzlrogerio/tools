# ============================================================================
# asdf Version Manager Configuration
# ============================================================================
# This module intelligently detects and configures asdf based on how it was
# installed: Git clone, Homebrew, or package manager (apt/dnf/pacman)
# Supports both legacy Bash version (< 0.16) and new Go version (>= 0.16)
# ============================================================================

# Helper function to source asdf if found
init_asdf() {
    local asdf_script="$1"
    if [[ -f "$asdf_script" ]]; then
        source "$asdf_script"
        return 0
    fi
    return 1
}

# ============================================================================
# Detection and initialization
# ============================================================================

# Priority 1: Check if asdf is already in PATH (any installation method)
if command -v asdf &> /dev/null; then
    # asdf is already available, initialize completions
    if [[ -n "$ASDF_DIR" ]]; then
        # Append completions to fpath
        fpath=(${ASDF_DIR}/completions $fpath)
    fi

    # For asdf 0.16+ (Go version), ensure proper initialization
    if [[ -z "$ASDF_DIR" ]] && [[ -d "$HOME/.asdf" ]]; then
        export ASDF_DIR="$HOME/.asdf"
    fi

# Priority 2: Homebrew installation (macOS and Linux)
elif [[ "$HAS_BREW" == true ]]; then
    # Try Homebrew installation paths
    if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -f "$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh" ]]; then
        # Found in Homebrew prefix
        export ASDF_DIR="$HOMEBREW_PREFIX/opt/asdf/libexec"
        init_asdf "$ASDF_DIR/asdf.sh"

    elif init_asdf "$(brew --prefix asdf 2>/dev/null)/libexec/asdf.sh"; then
        # Found using brew --prefix
        export ASDF_DIR="$(brew --prefix asdf)/libexec"

    elif init_asdf "/opt/homebrew/opt/asdf/libexec/asdf.sh"; then
        # Apple Silicon default path
        export ASDF_DIR="/opt/homebrew/opt/asdf/libexec"

    elif init_asdf "/usr/local/opt/asdf/libexec/asdf.sh"; then
        # Intel Mac default path
        export ASDF_DIR="/usr/local/opt/asdf/libexec"

    elif init_asdf "/home/linuxbrew/.linuxbrew/opt/asdf/libexec/asdf.sh"; then
        # Linuxbrew default path
        export ASDF_DIR="/home/linuxbrew/.linuxbrew/opt/asdf/libexec"
    fi

# Priority 3: Git clone installation (traditional method)
elif init_asdf "$HOME/.asdf/asdf.sh"; then
    export ASDF_DIR="$HOME/.asdf"

# Priority 3b: asdf 0.18+ (Go version) - no asdf.sh needed, just bin in PATH
elif [[ -d "$HOME/.asdf/bin" ]] && [[ -x "$HOME/.asdf/bin/asdf" ]]; then
    export ASDF_DIR="$HOME/.asdf"
    add_to_path "$ASDF_DIR/bin"
    add_to_path "$ASDF_DIR/shims"
    # Add completions to fpath for Go version
    [[ -d "$ASDF_DIR/completions" ]] && fpath=(${ASDF_DIR}/completions $fpath)

# Priority 4: Package manager installations
elif [[ "$IS_LINUX" == true ]]; then
    # apt/dpkg (Debian/Ubuntu)
    if init_asdf "/opt/asdf-vm/asdf.sh"; then
        export ASDF_DIR="/opt/asdf-vm"

    # pacman (Arch Linux)
    elif init_asdf "/opt/asdf/asdf.sh"; then
        export ASDF_DIR="/opt/asdf"

    # dnf/yum (Fedora/RHEL/CentOS)
    elif init_asdf "/usr/share/asdf/asdf.sh"; then
        export ASDF_DIR="/usr/share/asdf"
    fi
fi

# ============================================================================
# Add asdf shims to PATH if found
# ============================================================================
if [[ -n "$ASDF_DIR" ]]; then
    # Add asdf binary and shims to PATH
    if [[ -d "$ASDF_DIR/bin" ]]; then
        add_to_path "$ASDF_DIR/bin"
    fi

    if [[ -d "$ASDF_DIR/shims" ]]; then
        add_to_path "$ASDF_DIR/shims"
    fi

    # Add completions to fpath
    if [[ -d "$ASDF_DIR/completions" ]]; then
        fpath=(${ASDF_DIR}/completions $fpath)
    fi
fi

# ============================================================================
# Alternative: asdf-vm installed globally
# ============================================================================
# Some installations might use /usr/local/bin/asdf or similar
if [[ -z "$ASDF_DIR" ]] && command -v asdf &> /dev/null; then
    export ASDF_DIR="$(dirname $(dirname $(command -v asdf)))"
fi

# ============================================================================
# Troubleshooting function
# ============================================================================
# Uncomment to debug asdf detection
# asdf_debug() {
#     echo "=== asdf Detection Debug ==="
#     echo "ASDF_DIR: ${ASDF_DIR:-not set}"
#     echo "asdf command available: $(command -v asdf &> /dev/null && echo "yes" || echo "no")"
#     if command -v asdf &> /dev/null; then
#         echo "asdf location: $(command -v asdf)"
#         echo "asdf version: $(asdf version 2>/dev/null || echo "unable to determine")"
#     fi
#     echo "=========================="
# }
# asdf_debug

# ============================================================================
# Installation hints (if asdf not found)
# ============================================================================
if ! command -v asdf &> /dev/null; then
    # Create a function to show installation instructions
    install_asdf() {
        echo "=== asdf is not installed ==="
        echo ""
        if [[ "$IS_MAC" == true ]]; then
            echo "For macOS, install with Homebrew:"
            echo "  brew install asdf"
            echo ""
        elif [[ "$IS_LINUX" == true ]]; then
            echo "For Linux, choose one of the following methods:"
            echo ""
            if [[ "$HAS_BREW" == true ]]; then
                echo "1. Using Homebrew (recommended if you use Homebrew):"
                echo "   brew install asdf"
                echo ""
            fi
            if [[ "$HAS_APT" == true ]]; then
                echo "2. Using apt (Ubuntu/Debian):"
                echo "   sudo apt install asdf"
                echo ""
            fi
            if [[ "$HAS_DNF" == true ]]; then
                echo "3. Using dnf (Fedora):"
                echo "   sudo dnf install asdf"
                echo ""
            fi
            if [[ "$HAS_PACMAN" == true ]]; then
                echo "4. Using pacman (Arch):"
                echo "   yay -S asdf-vm"
                echo ""
            fi
            echo "5. Using Git (latest version, works everywhere):"
            echo "   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.18.0"
            echo ""
            echo "   Or for the absolute latest:"
            echo "   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch latest"
            echo ""
        fi
        echo "After installation, restart your terminal or run: source ~/.zshrc"
        echo ""
        echo "Note: asdf 0.16+ is a complete rewrite in Go. See migration guide:"
        echo "https://asdf-vm.com/guide/upgrading-to-v0-16"
        echo "=============================="
    }

    # Note: Function is available but won't auto-execute
    # Users can run 'install_asdf' to see instructions
fi
