#!/usr/bin/env python3
"""Rebuild the i3 ws1.json layout on sway, which has no append_layout.

    ws1_layout.py [--adopt] [workspace]     (default: 1)

Opens Brave, a second Brave window, Discord and kitty, waits for their
windows, then arranges them:

    +--------------+-----------------+
    |              | [Brave|Discord] |  tabbed, 61%
    | Brave        |                 |
    | (tabbed)     +-----------------+
    |  66%         | [kitty]         |  tabbed, 39%
    +--------------+-----------------+

Discord is single-instance, so an already open Discord window is reused.
With --adopt, matching windows already on the workspace are used too, and
only the missing ones are opened. Use it to re-apply the layout.
"""
import json
import subprocess
import sys
import time

# mark, app_id, command, reuse an existing window, titles to ignore
SLOTS = [
    ("main", "brave-browser", ["brave", "--new-window"], False, ()),
    ("side", "brave-browser", ["brave", "--new-window"], False, ()),
    ("discord", "discord", ["discord"], True, ("Discord Updater",)),
    ("term", "kitty", ["kitty"], False, ()),
]
TIMEOUT = 60
MARK_PREFIX = "ws1_"


def sway(cmd):
    subprocess.run(["swaymsg", "-q", cmd], check=False)


def tree():
    return json.loads(subprocess.check_output(["swaymsg", "-t", "get_tree"]))


def windows(node=None):
    node = node or tree()
    if node.get("pid") and node["type"] in ("con", "floating_con"):
        yield node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from windows(child)


def find(node, pred, parent=None):
    """Return (node, parent) of the first node matching pred."""
    if pred(node):
        return node, parent
    for child in node.get("nodes", []):
        hit = find(child, pred, node)
        if hit:
            return hit
    return None


def notify(msg):
    subprocess.run(["notify-send", "-u", "critical", "ws1 layout", msg], check=False)


def matches(win, app_id, ignore):
    return win.get("app_id") == app_id and (win.get("name") or "") not in ignore and win.get("name")


def acquire(ws, adopt):
    """Open (or reuse) one window per slot. Returns {mark: con_id}."""
    t = tree()
    before = {w["id"] for w in windows(t)}
    hit = find(t, lambda n: n["type"] == "workspace" and n.get("num") == int(ws))
    on_ws = list(windows(hit[0])) if hit else []
    got = {}
    for mark, app_id, cmd, reuse, ignore in SLOTS:
        pool = list(windows(t)) if reuse else on_ws if adopt else []
        if pool:
            for w in pool:
                if matches(w, app_id, ignore) and w["id"] not in got.values():
                    got[mark] = w["id"]
                    break
        if mark not in got:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)

    deadline = time.monotonic() + TIMEOUT
    while len(got) < len(SLOTS) and time.monotonic() < deadline:
        time.sleep(0.25)
        current = list(windows())
        for mark, app_id, _cmd, _reuse, ignore in SLOTS:
            if mark in got:
                continue
            for w in current:
                if w["id"] not in before and w["id"] not in got.values() and matches(w, app_id, ignore):
                    got[mark] = w["id"]
                    break
    return got


def arrange(ws, got):
    m = {k: MARK_PREFIX + k for k in got}
    # Park the windows elsewhere first so any containers they were in on the
    # target workspace disappear, and they come back as plain siblings.
    for mark, con_id in got.items():
        sway(f'[con_id={con_id}] mark --add {m[mark]}, floating disable, move container to workspace {MARK_PREFIX}tmp')
    for mark in got:
        sway(f'[con_mark={m[mark]}] move container to workspace number {ws}')

    # Right column: splitv holding a tabbed [side, discord] over a tabbed [term].
    # Sway only wraps a window in a new container when it has siblings,
    # so the order of these steps matters.
    sway(f'[con_mark={m["term"]}] split v')
    sway(f'[con_mark={m["side"]}] move container to mark {m["term"]}')
    sway(f'[con_mark={m["side"]}] swap container with mark {m["term"]}')
    sway(f'[con_mark={m["side"]}] split h, layout tabbed')
    sway(f'[con_mark={m["discord"]}] move container to mark {m["side"]}')
    sway(f'[con_mark={m["term"]}] split h, layout tabbed')
    # Left column: tabbed [main]
    sway(f'[con_mark={m["main"]}] split v, layout tabbed')

    t = tree()
    workspace =find(t, lambda n: n["type"] == "workspace" and n.get("num") == int(ws))[0]
    left = find(t, lambda n: m["main"] in n.get("marks", []))[1]
    top = find(t, lambda n: m["side"] in n.get("marks", []))[1]
    right = find(t, lambda n: n["id"] == top["id"])[1]

    ids = [c["id"] for c in workspace["nodes"]]
    if ids.index(right["id"]) < ids.index(left["id"]):
        sway(f'[con_id={left["id"]}] swap container with con_id {right["id"]}')

    sway(f'[con_id={left["id"]}] resize set width 66 ppt')
    sway(f'[con_id={top["id"]}] resize set height 61 ppt')

    for mark in m.values():
        sway(f'[con_mark={mark}] unmark {mark}')


def main(*args):
    adopt = "--adopt" in args
    rest = [a for a in args if a != "--adopt"]
    ws = rest[0] if rest else "1"
    got = acquire(ws, adopt)
    missing = [s[0] for s in SLOTS if s[0] not in got]
    if missing:
        notify(f"Timed out waiting for: {', '.join(missing)}. Layout not applied.")
        return 1
    arrange(ws, got)
    sway(f'[con_id={got["main"]}] focus')
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
