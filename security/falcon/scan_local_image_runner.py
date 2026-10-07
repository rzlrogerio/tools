#!/usr/bin/env python3
"""Portable wrapper script for scan_local_image.py - works on all platforms.

Usage:
    python scan_local_image_runner.py <image_id> [options]

This wrapper works on Windows, macOS, and Linux without requiring shell scripts.
"""

import sys
import subprocess
from pathlib import Path

def main() -> int:
    """Execute scan_local_image.py with proper argument passing."""
    script_dir = Path(__file__).resolve().parent
    python_script = script_dir / "scan_local_image.py"

    if not python_script.exists():
        print(f"[ERROR] Python script not found: {python_script}", file=sys.stderr)
        return 1

    # Execute the main script with all arguments
    try:
        result = subprocess.run(
            [sys.executable, str(python_script), *sys.argv[1:]],
            check=False,
        )
        return result.returncode
    except FileNotFoundError:
        print("[ERROR] Python executable not found", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
