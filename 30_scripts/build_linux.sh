#!/usr/bin/env bash
# build_linux.sh -- Build workflow_gui binary for Linux using PyInstaller.
#
# Output: dist/workflow_gui  (single-file, no Python install needed on target)
#
# Usage:
#   bash ./30_scripts/build_linux.sh
#   bash ./30_scripts/build_linux.sh --python python3.12
#   bash ./30_scripts/build_linux.sh --skip-pip-upgrade
#
# Requirements:
#   - Python 3.10+ with tkinter support
#     Debian/Ubuntu: sudo apt install python3-tk
#     Fedora:        sudo dnf install python3-tkinter
#   - pip (usually bundled with Python)

set -e

PYTHON="python3"
SKIP_PIP=false

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --python)         PYTHON="$2"; shift 2 ;;
        --skip-pip-upgrade) SKIP_PIP=true; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$SCRIPT_DIR/workflow_gui.py"
DIST_DIR="$ROOT/dist"
BUILD_TMP="$DIST_DIR/_build_tmp"
SPEC_DIR="$DIST_DIR/_spec"
OUTPUT="$DIST_DIR/workflow_gui"

echo ""
echo "=== Workflow GUI -- Linux Build ==="
echo "  Script : $SCRIPT"
echo "  Output : $OUTPUT"
echo ""

# -- Check Python
echo -n "Checking Python... "
PY_VER=$("$PYTHON" --version 2>&1) || {
    echo "NOT FOUND"
    echo "Install Python 3.10+ and ensure '$PYTHON' is on PATH."
    exit 1
}
echo "$PY_VER"

# -- Check tkinter
echo -n "Checking tkinter... "
"$PYTHON" -c "import tkinter" 2>/dev/null && echo "OK" || {
    echo "NOT FOUND"
    echo "Install tkinter for your distro:"
    echo "  Debian/Ubuntu:  sudo apt install python3-tk"
    echo "  Fedora:         sudo dnf install python3-tkinter"
    echo "  Arch:           sudo pacman -S tk"
    exit 1
}

# -- Upgrade PyInstaller
if [ "$SKIP_PIP" = false ]; then
    echo "Installing / upgrading PyInstaller..."
    "$PYTHON" -m pip install --upgrade pyinstaller --quiet
    echo "  PyInstaller ready."
fi

# -- Create output dirs
mkdir -p "$DIST_DIR" "$BUILD_TMP" "$SPEC_DIR"

# -- Build
echo ""
echo "Building..."

"$PYTHON" -m PyInstaller \
    --onefile \
    --windowed \
    --name "workflow_gui" \
    --distpath "$DIST_DIR" \
    --workpath "$BUILD_TMP" \
    --specpath "$SPEC_DIR" \
    --noconfirm \
    "$SCRIPT"

# -- Report
if [ -f "$OUTPUT" ]; then
    SIZE=$(du -sh "$OUTPUT" | cut -f1)
    echo ""
    echo "Build SUCCEEDED"
    echo "  $OUTPUT  ($SIZE)"
    echo ""
    echo "Usage:"
    echo "  ./dist/workflow_gui"
    echo "  ./dist/workflow_gui --repo /path/to/labs"
    chmod +x "$OUTPUT"
else
    echo "Output file not found after build -- check PyInstaller output above."
    exit 1
fi
