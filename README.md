# Geary Mail — a DankMaterialShell plugin

Unread-mail counts for every account configured in [Geary](https://wiki.gnome.org/Apps/Geary),
shown in your [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar.

No IMAP setup, no passwords: the plugin reads the per-account SQLite databases Geary already
keeps in sync, so whatever Geary knows, the bar knows.

```
┌──────────────────────────────────────────────┐
│  Mail                                     ✕  │
│  1151 unread • updated 14:59                 │
├──────────────────────────────────────────────┤
│  ╭────────────────────────────────────────╮  │
│  │ ◉ schneik@industrialmachinearts.com (45)│  │
│  ╰────────────────────────────────────────╯  │
│  ╭────────────────────────────────────────╮  │
│  │ ◉ schneik@fastmail.com          (1106) │  │
│  │    UPS      Your packages arrive today │  │
│  │    Marianne Greetings           13:21  │  │
│  ╰────────────────────────────────────────╯  │
│                        ⟳   [ ↗ Open Geary ]  │
└──────────────────────────────────────────────┘
```

---

## Contents

- [Why](#why)
- [Requirements](#requirements)
- [Install](#install)
- [Troubleshooting](#troubleshooting)
- [Usage](#usage)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [The helper script standalone](#the-helper-script-standalone)
- [Limitations](#limitations)

## Why

GNOME has half a dozen "new mail" indicators; DMS had none. Every existing indicator wants
its own IMAP credentials. If you already run Geary, that's duplicated setup and a second
connection to every server. This plugin piggybacks on Geary instead.

## Requirements

- DankMaterialShell with plugin support
- Geary (Flatpak `org.gnome.Geary` or native) with at least one account
- `python3` (stdlib only — no pip packages)

## Install

The plugin is in the [DMS plugin registry](https://github.com/AvengeMedia/dms-plugin-registry),
so the normal route is the one DMS manages for you:

```sh
dms plugins install dankGearyMail
```

or **DMS Settings → Plugins → Browse**, then **Install** on *Dank Geary Mail*. Enable it, and
add it to a bar section under **Settings → Appearance → DankBar Layout**. Later,
`dms plugins update dankGearyMail` and `dms plugins uninstall dankGearyMail` work as for any
registry plugin.

### Development install

To run the plugin straight from a checkout instead:

```sh
git clone https://github.com/schneik80/dms-geary-mail.git
cd dms-geary-mail
./install.sh          # copy into ~/.config/DankMaterialShell/plugins/dankGearyMail
./install.sh --link   # or symlink, so edits in the checkout are live
```

Then enable it in **DMS Settings → Plugins** (or `dms ipc call plugins enable dankGearyMail`)
and add it to the bar. A development install is not tracked by `dms plugins`; remove it with
`./install.sh --uninstall`. If the plugin is already installed from the registry, `install.sh`
refuses to overwrite it unless you pass `--force`, which uninstalls the registry copy first.

## Troubleshooting

**"Install failed: plugin already installed: Dank Geary Mail"** from the Plugin Browser or
`dms plugins install`, or **"failed to remove symlink: … directory not empty"** from
`dms plugins uninstall`.

DMS installs registry plugins that live in a subdirectory of their repo (this one does) as a
symlink into `plugins/.repos/`, and expects `plugins/dankGearyMail` to be that symlink. Anything
else at that path blocks it: a directory left by an older `install.sh`, a hand-made copy, or a
stale symlink from `install.sh --link` whose target has moved or is on a drive that is not
mounted. Clear it and install again:

```sh
./install.sh --uninstall        # from a checkout, handles every case
# or by hand:
rm -rf ~/.config/DankMaterialShell/plugins/dankGearyMail \
       ~/.config/DankMaterialShell/plugins/dankGearyMail.meta
dms plugins install dankGearyMail
```

**"Dank Geary Mail Startup Failed" toast when enabling** — the startup check (DMS 1.5 and
later) could not find `python3` or a Geary configuration. The toast says which. Fix that, then
enable the plugin again. Older DMS skips the check and the widget shows `!` instead.

**The widget is amber** — Geary is not running, so the counts are whatever it last synced.
**The widget is red / shows `!`** — the helper failed; run `python3 geary-unread.py` from the
plugin directory to see the error.

## Usage

| Action | Result |
|---|---|
| Left click | Popout with each account and its unread badge (configurable to open Geary instead) |
| Click an account row | Expand the five most recent unread INBOX messages |
| Right click | Launch Geary |
| Icon colour | Primary when unread > 0; amber when Geary isn't running (counts may be stale); red on error |

## Configuration

DMS Settings → Plugins → Dank Geary Mail:

| Setting | Default | Notes |
|---|---|---|
| Folders to count | Inbox only | *All folders* sums everything except Junk/Trash/Sent/Drafts/Archive |
| Refresh interval | 2 min | How often the database is re-read |
| Per-account counts in bar | off | Show `3·0·12` instead of the total |
| Hide when nothing is unread | off | |
| Left click | Open popout | Or open Geary |
| Launch command | `flatpak run org.gnome.Geary` | Use `geary` for a native install |

## Architecture

```
plugin/
├── plugin.json                 DMS manifest
├── DankGearyMailWidget.qml     bar pill + popout; runs the helper via Quickshell Process
├── DankGearyMailSettings.qml   settings page
├── DankGearyMailStartupCheck.qml  runs before load (DMS ≥ 1.5); blocks with a toast if python3 or Geary is missing
└── geary-unread.py             reads Geary's DBs, prints JSON
```

`geary-unread.py` looks for Geary in this order:

1. Flatpak: `~/.var/app/org.gnome.Geary/{config,data}/geary`
2. Native: `$XDG_CONFIG_HOME/geary` and `$XDG_DATA_HOME/geary`

For each `<account>/geary.ini` it derives a display name (label → first sender mailbox → login),
opens `<account>/geary.db` read-only, and reads `FolderTable.unread_count` — the unread count the
IMAP server last reported to Geary. Recent messages come from `MessageTable` rows without the
`\Seen` flag. The FTS table is never touched (it uses Geary's private tokenizer).

The widget parses the JSON, updates the pill, and re-runs the helper on a timer and whenever the
popout opens.

## The helper script standalone

```sh
python3 plugin/geary-unread.py                  # inbox counts + 5 recent per account
python3 plugin/geary-unread.py --mode all       # all non-junk folders
python3 plugin/geary-unread.py --recent 0       # counts only
python3 plugin/geary-unread.py --root ~/.var/app/org.gnome.Geary
```

Output:

```json
{"accounts":[{"id":"account_01","name":"me@example.com","unread":45,
              "recent":[{"from":"UPS","subject":"Your packages arrive today","ts":1787335271}],
              "error":null}],
 "total":45,"gearyRunning":true,"error":null}
```

Handy for waybar, polybar, or anything else that can shell out.

## Limitations

- **Geary must be running** (a background or minimized window is fine) for counts to update.
  The bar tells you when it isn't.
- Counts reflect what Geary's sync has fetched; a brand-new account has no database until its
  first sync.
- Direct IMAP polling was deliberately not implemented: Flatpak Geary stores passwords via the
  Secret portal, sealed to the sandbox, and GNOME Online Accounts logins have no password at all.
