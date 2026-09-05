#!/usr/bin/env bash
# Development install of the Geary Mail plugin into DankMaterialShell.
#
# Most people should install from the DMS plugin registry instead:
#     dms plugins install dankGearyMail
# (or DMS Settings -> Plugins -> Browse). That install is managed by
# `dms plugins update/uninstall`; this script is for hacking on a checkout.
#
#   ./install.sh              copy the plugin into place
#   ./install.sh --link       symlink instead, so edits in this repo are live
#   ./install.sh --force      replace a registry-managed install with this checkout
#   ./install.sh --uninstall  remove either kind of install

set -euo pipefail

PLUGIN_ID="dankGearyMail"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plugin"
DMS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell"
PLUGINS_DIR="$DMS_DIR/plugins"
DEST="$PLUGINS_DIR/$PLUGIN_ID"
META="$DEST.meta"
LOCK="$DMS_DIR/plugins.lock.json"

mode="copy"
force=0
for arg in "$@"; do
    case "$arg" in
        --link)      mode="link" ;;
        --uninstall) mode="uninstall" ;;
        --force)     force=1 ;;
        -h|--help)   sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "usage: $(basename "$0") [--link] [--force] [--uninstall]" >&2; exit 2 ;;
    esac
done

# True when the plugin was installed by `dms plugins` (registry). DMS marks such
# installs with a .meta file, a symlink into plugins/.repos, and a lockfile entry.
registry_managed() {
    [ -e "$META" ] && return 0
    if [ -L "$DEST" ]; then
        case "$(readlink "$DEST")" in "$PLUGINS_DIR/.repos/"*) return 0 ;; esac
    fi
    [ -f "$LOCK" ] && python3 - "$LOCK" "$PLUGIN_ID" <<'PY' 2>/dev/null
import json, sys
sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])).get("plugins", {}) else 1)
PY
}

remove_registry_install() {
    if command -v dms >/dev/null && dms plugins uninstall "$PLUGIN_ID"; then
        return 0
    fi
    echo "dms could not uninstall it; cleaning up by hand." >&2
    rm -rf "$DEST" "$META"
    if [ -f "$LOCK" ]; then
        python3 - "$LOCK" "$PLUGIN_ID" <<'PY'
import json, sys
p, pid = sys.argv[1], sys.argv[2]
d = json.load(open(p))
if d.get("plugins", {}).pop(pid, None) is not None:
    json.dump(d, open(p, "w"), indent=2)
PY
    fi
}

remove_dev_install() {
    # rm -rf on a symlink (even a dangling one) removes the link, not the target.
    rm -rf "$DEST"
    rm -f "$META"   # a stale .meta makes DMS treat the directory as a symlink install
}

if [ "$mode" = "uninstall" ]; then
    if registry_managed; then
        remove_registry_install
    elif [ -e "$DEST" ] || [ -L "$DEST" ]; then
        remove_dev_install
        echo "Removed $DEST"
    else
        echo "$PLUGIN_ID is not installed."
    fi
    echo "If it is still in your bar, remove it under DMS Settings -> Appearance -> DankBar Layout."
    exit 0
fi

command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }

if registry_managed; then
    if [ "$force" -eq 0 ]; then
        cat >&2 <<MSG
$PLUGIN_ID is already installed from the DMS plugin registry.
  To update it:                        dms plugins update $PLUGIN_ID
  To replace it with this checkout:    $(basename "$0") --force$([ "$mode" = link ] && echo ' --link')
MSG
        exit 1
    fi
    remove_registry_install
fi

if ! python3 "$SRC/geary-unread.py" --recent 0 >/dev/null 2>&1; then
    echo "Geary configuration not found (looked in ~/.var/app/org.gnome.Geary and ~/.config/geary)." >&2
    echo "Install Geary and add at least one account, then re-run." >&2
    exit 1
fi

mkdir -p "$PLUGINS_DIR"
remove_dev_install

if [ "$mode" = "link" ]; then
    ln -s "$SRC" "$DEST"
    echo "Linked $DEST -> $SRC"
    case "$SRC" in
        /run/media/*|/media/*|/mnt/*)
            echo "Note: this checkout is on a removable or late-mounted drive. The link must resolve" >&2
            echo "when DMS starts, or the plugin will not load and 'dms plugins install' will fail" >&2
            echo "with 'file exists'. Prefer a plain copy (no --link) if that drive is not always mounted." >&2 ;;
    esac
else
    cp -r "$SRC" "$DEST"
    echo "Installed to $DEST"
fi
chmod +x "$DEST/geary-unread.py" 2>/dev/null || true

echo
echo "This is a development install; 'dms plugins update/uninstall' will not manage it."
echo "Use '$(basename "$0") --uninstall' to remove it (also before switching back to the registry install)."
echo
echo "Next steps:"
echo "  1. DMS Settings -> Plugins, enable 'Dank Geary Mail'"
echo "     (or: dms ipc call plugins enable $PLUGIN_ID)"
echo "  2. DMS Settings -> Appearance -> DankBar Layout -> add 'Dank Geary Mail'"
