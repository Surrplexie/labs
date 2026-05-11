#!/usr/bin/env bash
# install-hooks.sh -- Install .github/hooks/pre-push into .git/hooks/
#
# Usage:
#   bash ./30_scripts/install-hooks.sh
#   bash ./30_scripts/install-hooks.sh --uninstall

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE="$ROOT/.github/hooks/pre-push"
GIT_HOOKS="$ROOT/.git/hooks"
DEST="$GIT_HOOKS/pre-push"

UNINSTALL=false
if [ "${1:-}" = "--uninstall" ]; then UNINSTALL=true; fi

if [ "$UNINSTALL" = true ]; then
    if [ -f "$DEST" ]; then
        rm "$DEST"
        echo "Uninstalled: $DEST"
    else
        echo "Hook not installed (nothing to remove)."
    fi
    exit 0
fi

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: source hook not found at: $SOURCE"
    exit 1
fi

if [ ! -d "$GIT_HOOKS" ]; then
    echo "ERROR: .git/hooks/ not found. Run from inside the git repository."
    exit 1
fi

if [ -f "$DEST" ]; then
    cp "$DEST" "$DEST.bak"
    echo "Backed up existing hook to: $DEST.bak"
fi

cp "$SOURCE" "$DEST"
chmod +x "$DEST"

echo ""
echo "Hook installed successfully."
echo "  Source : $SOURCE"
echo "  Dest   : $DEST"
echo ""
echo "The hook will run validate.ps1 and redact-check.ps1 before every push."
echo "To skip in an emergency: git push --no-verify"
