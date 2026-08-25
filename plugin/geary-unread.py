#!/usr/bin/env python3
"""Print unread-mail counts for every account Geary has configured.

Reads Geary's own SQLite databases (no IMAP, no credentials). Counts are the
server-reported unread counts Geary stores in FolderTable, so they are fresh
whenever Geary is running.

Output (JSON on stdout):
  {"accounts":[{"id","name","unread","recent":[{"from","subject","ts"}],"error"}],
   "total":N, "gearyRunning":bool, "error":null|str}
"""
import argparse
import configparser
import json
import os
import sqlite3
import subprocess
import sys

HOME = os.path.expanduser("~")
FLATPAK = os.path.join(HOME, ".var/app/org.gnome.Geary")
XDG_CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
XDG_DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))

EXCLUDED_ATTRS = ("\\Junk", "\\Trash", "\\Drafts", "\\Sent", "\\Archive", "\\All")


def find_roots(override):
    """Return (config_dir, data_dir) for the first Geary install found."""
    candidates = []
    if override:
        candidates.append((os.path.join(override, "config/geary"), os.path.join(override, "data/geary")))
    candidates.append((os.path.join(FLATPAK, "config/geary"), os.path.join(FLATPAK, "data/geary")))
    candidates.append((os.path.join(XDG_CONFIG, "geary"), os.path.join(XDG_DATA, "geary")))
    for cfg, data in candidates:
        if os.path.isdir(cfg) and os.path.isdir(data):
            return cfg, data
    return None, None


def account_name(ini):
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(ini)
    label = cp.get("Account", "label", fallback="").strip()
    if label:
        return label, cp
    mailboxes = cp.get("Account", "sender_mailboxes", fallback="")
    first = mailboxes.split(";")[0].strip()
    if first:
        if "<" in first and ">" in first:
            first = first[first.index("<") + 1:first.index(">")]
        return first, cp
    return cp.get("Incoming", "login", fallback=os.path.basename(os.path.dirname(ini))), cp


def open_ro(path):
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=2)
    conn.execute("PRAGMA query_only = 1")
    return conn


def unread_for(conn, mode, cp):
    if mode == "inbox":
        row = conn.execute(
            "SELECT unread_count FROM FolderTable WHERE name = 'INBOX' COLLATE NOCASE AND parent_id IS NULL"
        ).fetchone()
        return int(row[0] or 0) if row else 0

    skip_names = {
        cp.get("Folders", k, fallback="").strip()
        for k in ("junk_folder", "trash_folder", "drafts_folder", "sent_folder", "archive_folder")
    }
    skip_names.discard("")
    total = 0
    for name, attrs, unread in conn.execute("SELECT name, attributes, unread_count FROM FolderTable"):
        attrs = attrs or ""
        if name in skip_names or any(a in attrs for a in EXCLUDED_ATTRS):
            continue
        total += int(unread or 0)
    return total


def recent_for(conn, limit):
    rows = conn.execute(
        """
        SELECT m.from_field, m.subject, COALESCE(m.internaldate_time_t, m.date_time_t)
        FROM MessageLocationTable l
        JOIN MessageTable m ON m.id = l.message_id
        JOIN FolderTable f ON f.id = l.folder_id
        WHERE f.name = 'INBOX' COLLATE NOCASE AND f.parent_id IS NULL
          AND l.remove_marker = 0
          AND (m.flags IS NULL OR m.flags NOT LIKE '%\\Seen%')
        ORDER BY l.ordering DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    out = []
    for frm, subj, ts in rows:
        frm = (frm or "").strip()
        if "<" in frm and frm.index("<") > 0:
            frm = frm[: frm.index("<")].strip().strip('"')
        out.append({"from": frm, "subject": (subj or "(no subject)").strip(), "ts": ts})
    return out


def geary_running():
    try:
        r = subprocess.run(
            ["pgrep", "-f", r"(org\.gnome\.Geary|/app/bin/geary|(^|/)geary($| ))"],
            capture_output=True, text=True, timeout=2,
        )
        return r.returncode == 0
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=("inbox", "all"), default="inbox")
    ap.add_argument("--recent", type=int, default=5)
    ap.add_argument("--root", help="Geary app root containing config/geary and data/geary")
    args = ap.parse_args()

    result = {"accounts": [], "total": 0, "gearyRunning": geary_running(), "error": None}
    cfg, data = find_roots(args.root)
    if not cfg:
        result["error"] = "Geary configuration not found"
        print(json.dumps(result))
        return 1

    for acct in sorted(os.listdir(cfg)):
        ini = os.path.join(cfg, acct, "geary.ini")
        if not os.path.isfile(ini):
            continue
        name, cp = account_name(ini)
        entry = {"id": acct, "name": name, "unread": None, "recent": [], "error": None}
        db = os.path.join(data, acct, "geary.db")
        try:
            if not os.path.isfile(db):
                raise FileNotFoundError("no geary.db (account never synced)")
            conn = open_ro(db)
            try:
                entry["unread"] = unread_for(conn, args.mode, cp)
                if args.recent > 0:
                    entry["recent"] = recent_for(conn, args.recent)
            finally:
                conn.close()
        except Exception as e:  # locked db, schema mismatch, ...
            entry["error"] = str(e)
        result["accounts"].append(entry)
        result["total"] += entry["unread"] or 0

    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
