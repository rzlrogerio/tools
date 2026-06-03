# ============================================================================
# Environment Detection Module
# ============================================================================
# This module detects the operating system and environment type
# Sets variables that can be used by other configuration modules
# ============================================================================

# Detect Operating System
export OS_TYPE="unknown"
export IS_MAC=false
export IS_LINUX=false
export IS_WSL=false

case "$(uname -s)" in
    Darwin*)
        export OS_TYPE="macos"
        export IS_MAC=true
        ;;
    Linux*)
        export OS_TYPE="linux"
        export IS_LINUX=true

        # Check if running in WSL
        if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null || \
           grep -qi microsoft /proc/sys/kernel/osrelease &> /dev/null; then
            export IS_WSL=true
            export OS_TYPE="wsl"
        fi
        ;;
    *)
        export OS_TYPE="unknown"
        ;;
esac

# Detect Linux Distribution (if on Linux/WSL)
export LINUX_DISTRO="unknown"
if [[ "$IS_LINUX" == true ]] || [[ "$IS_WSL" == true ]]; then
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        export LINUX_DISTRO="$ID"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        export LINUX_DISTRO="$DISTRIB_ID"
    fi
fi

# Detect package managers
export HAS_BREW=false
export HAS_APT=false
export HAS_DNF=false
export HAS_YUM=false
export HAS_PACMAN=false

command -v brew &> /dev/null && export HAS_BREW=true
command -v apt &> /dev/null && export HAS_APT=true
command -v dnf &> /dev/null && export HAS_DNF=true
command -v yum &> /dev/null && export HAS_YUM=true
command -v pacman &> /dev/null && export HAS_PACMAN=true

# Architecture detection
export ARCH="$(uname -m)"
export IS_ARM=false
[[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]] && export IS_ARM=true

# Debug function (uncomment to see detected values)
# print_env_info() {
#     echo "OS Type: $OS_TYPE"
#     echo "Is Mac: $IS_MAC"
#     echo "Is Linux: $IS_LINUX"
#     echo "Is WSL: $IS_WSL"
#     echo "Linux Distro: $LINUX_DISTRO"
#     echo "Has Homebrew: $HAS_BREW"
#     echo "Has APT: $HAS_APT"
#     echo "Architecture: $ARCH"
#     echo "Is ARM: $IS_ARM"
# }
# print_env_info
