#!/usr/bin/env bash
# Install the Geary Mail plugin into DankMaterialShell.
#
#   ./install.sh            copy the plugin into place
#   ./install.sh --link     symlink instead, so edits in this repo are live
#   ./install.sh --uninstall

set -euo pipefail

PLUGIN_ID="dankGearyMail"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plugin"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/$PLUGIN_ID"

mode="copy"
case "${1:-}" in
    --link)      mode="link" ;;
    --uninstall) mode="uninstall" ;;
    "")          ;;
    *) echo "usage: $(basename "$0") [--link|--uninstall]" >&2; exit 2 ;;
esac

if [ "$mode" = "uninstall" ]; then
    rm -rf "$DEST"
    echo "Removed $DEST"
    echo "Now disable it in DMS Settings -> Plugins, and remove it from your bar layout."
    exit 0
fi

command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }

if ! python3 "$SRC/geary-unread.py" --recent 0 >/dev/null 2>&1; then
    echo "Geary configuration not found (looked in ~/.var/app/org.gnome.Geary and ~/.config/geary)." >&2
    echo "Install Geary and add at least one account, then re-run." >&2
    exit 1
fi

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"

if [ "$mode" = "link" ]; then
    ln -s "$SRC" "$DEST"
    echo "Linked $DEST -> $SRC"
else
    cp -r "$SRC" "$DEST"
    echo "Installed to $DEST"
fi
chmod +x "$DEST/geary-unread.py" 2>/dev/null || true

echo
echo "Next steps:"
echo "  1. DMS Settings -> Plugins -> Scan for Plugins, then enable 'Dank Geary Mail'"
echo "     (or: dms ipc call plugins enable $PLUGIN_ID)"
echo "  2. DMS Settings -> Appearance -> DankBar Layout -> add 'Dank Geary Mail'"
