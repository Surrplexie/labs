#!/usr/bin/env bash
# build_linux.sh -- Build workflow_gui binary for Linux using pinned PyInstaller.
#
# Outputs:
#   dist/workflow_gui        -- standalone executable
#   dist/SHA256SUMS.txt      -- SHA-256 checksum for verification
#
# Verify after build:
#   sha256sum dist/workflow_gui
#   cat dist/SHA256SUMS.txt
#
# Usage:
#   bash ./30_scripts/build_linux.sh
#   bash ./30_scripts/build_linux.sh --python python3.12
#   bash ./30_scripts/build_linux.sh --skip-pip-install
#
# Requirements:
#   - Python 3.10+ with tkinter support
#     Debian/Ubuntu: sudo apt install python3-tk
#     Fedora:        sudo dnf install python3-tkinter
#     Arch:          sudo pacman -S tk
#   - pip (usually bundled with Python)

set -e

PYTHON="python3"
SKIP_PIP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --python)           PYTHON="$2"; shift 2 ;;
        --skip-pip-install) SKIP_PIP=true; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$SCRIPT_DIR/workflow_gui.py"
REQ_FILE="$SCRIPT_DIR/build_requirements.txt"
DIST_DIR="$ROOT/dist"
BUILD_TMP="$DIST_DIR/_build_tmp"
SPEC_DIR="$DIST_DIR/_spec"
OUTPUT="$DIST_DIR/workflow_gui"
SUMS_FILE="$DIST_DIR/SHA256SUMS.txt"

# Single source of truth for PyInstaller pin
if [ ! -f "$REQ_FILE" ]; then
    echo "build_requirements.txt not found: $REQ_FILE" >&2
    exit 1
fi
PYINSTALLER_VERSION=$(
    grep -E '^[[:space:]]*pyinstaller==' "$REQ_FILE" | head -n 1 | cut -d= -f3 | tr -d '[:space:]'
)
if [ -z "$PYINSTALLER_VERSION" ]; then
    echo "No pyinstaller== pin in $REQ_FILE" >&2
    exit 1
fi

echo ""
echo "=== Workflow GUI -- Linux Build ==="
echo "  Script      : $SCRIPT"
echo "  PyInstaller : $PYINSTALLER_VERSION (pinned)"
echo "  Output      : $OUTPUT"
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

# -- Install pinned PyInstaller
if [ "$SKIP_PIP" = false ]; then
    echo "Installing pinned PyInstaller $PYINSTALLER_VERSION (from build_requirements.txt)..."
    "$PYTHON" -m pip install -r "$REQ_FILE" --quiet

    # Confirm installed version
    INSTALLED_VER=$("$PYTHON" -m pip show pyinstaller 2>/dev/null | grep "^Version:" | awk '{print $2}')
    if [ "$INSTALLED_VER" != "$PYINSTALLER_VERSION" ]; then
        echo "  WARNING: installed PyInstaller $INSTALLED_VER != pinned $PYINSTALLER_VERSION"
        echo "  Continuing -- update build_requirements.txt if intentional."
    else
        echo "  PyInstaller $PYINSTALLER_VERSION confirmed."
    fi
fi

# -- Capture source hash before build
SRC_HASH=$(sha256sum "$SCRIPT" | awk '{print $1}' | tr 'a-f' 'A-F')
echo "  Source hash (workflow_gui.py): $SRC_HASH"

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

# -- Compute SHA256 and write checksum file
if [ -f "$OUTPUT" ]; then
    EXE_HASH=$(sha256sum "$OUTPUT" | awk '{print $1}' | tr 'a-f' 'A-F')
    SIZE=$(du -sh "$OUTPUT" | cut -f1)
    BUILD_TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat > "$SUMS_FILE" << EOF
# SHA256SUMS -- workflow_gui Linux build
# Generated  : $BUILD_TS
# Python     : $PY_VER
# PyInstaller: $PYINSTALLER_VERSION
# Source hash: $SRC_HASH  workflow_gui.py

$EXE_HASH  workflow_gui
EOF

    echo ""
    echo "Build SUCCEEDED"
    echo "  $OUTPUT  ($SIZE)"
    echo "  SHA-256: $EXE_HASH"
    echo "  Checksum file: $SUMS_FILE"
    echo ""
    echo "Verification:"
    echo "  sha256sum dist/workflow_gui"
    echo "  Compare to: $EXE_HASH"
    echo ""
    echo "Usage:"
    echo "  ./dist/workflow_gui"
    echo "  ./dist/workflow_gui --repo /path/to/labs"
    chmod +x "$OUTPUT"
else
    echo "Output file not found after build -- check PyInstaller output above."
    exit 1
fi
