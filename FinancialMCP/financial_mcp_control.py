#!/usr/bin/python3
"""Control the running LedgerForge-owned service; never launch another service."""
import argparse
import json
import os
import stat
import sys
import urllib.error
import urllib.request


def control(state_path, action):
    info = os.stat(state_path)
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
        raise ValueError("The running app's control file is not private to this user.")
    with open(state_path, encoding="utf-8") as handle:
        state = json.load(handle)
    port = state["controlPort"]
    if not isinstance(port, int) or not 1 <= port <= 65535:
        raise ValueError("LedgerForge's control listener is not ready.")
    command = "enable" if action in ("enable", "disable") else action
    payload = {"instance": state["instance"]}
    if command == "enable":
        payload["enabled"] = action == "enable"
    request = urllib.request.Request(
        "http://127.0.0.1:%d/%s" % (port, command),
        data=None if command == "status" else json.dumps(payload).encode(),
        headers={"Authorization": "Bearer " + state["controlToken"], "Content-Type": "application/json"},
        method="GET" if command == "status" else "POST",
    )
    # This control channel is local even when the owner has configured a proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(request, timeout=5) as response:
        result = json.load(response)
    if result.get("instance") != state["instance"]:
        raise ValueError("LedgerForge restarted. Run the command again.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True)
    actions = ("status", "start", "stop", "restart", "settings", "enable", "disable", "revoke")
    parser.add_argument("action", choices=actions, nargs="?")
    args = parser.parse_args()
    action = args.action
    if action is None:
        print("LedgerForge Financial MCP\n" + "\n".join("%d. %s" % (i + 1, x.capitalize()) for i, x in enumerate(actions)) + "\n0. Exit")
        choice = input("Choose an action: ").strip()
        if choice == "0":
            return 0
        if not choice.isdigit() or not 1 <= int(choice) <= len(actions):
            print("Choose one of the listed actions.", file=sys.stderr)
            return 2
        action = actions[int(choice) - 1]
    try:
        result = control(args.state, action)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, urllib.error.URLError):
        print("LedgerForge is unavailable or its control state changed. Open LedgerForge and check Settings > Financial MCP.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
