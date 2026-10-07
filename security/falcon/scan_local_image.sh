#!/bin/sh
# scan_local_image.sh - Portable shell wrapper for scan_local_image.py
# Works on Linux, macOS, and other Unix-like systems
# Usage: ./scan_local_image.sh <image_id> [options]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/scan_local_image.py"

# Check if Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "[ERROR] Python script not found: $PYTHON_SCRIPT" >&2
    exit 1
fi

# Check if python3 is available (try both python3 and python)
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "[ERROR] Python not found. Please install python3." >&2
    exit 1
fi

# Execute Python script with all arguments
exec "$PYTHON_CMD" "$PYTHON_SCRIPT" "$@"
