#!/usr/bin/env python3
"""Install/update in the current user's unlocked Omarchy 4 session."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

PLUGIN_ID = "com.dnbradio.radio"
FILES = ["Stations.js", "Data.js", "Artwork.qml", "SmoothScrollView.qml", "MixCard.qml", "RadioService.qml", "LibraryState.qml",
         "LibraryWindow.qml", "BarWidget.qml", "Panel.qml", "README.md", "manifest.json"]


def command(*args, required=True):
    result = subprocess.run(args, capture_output=True, text=True, timeout=40)
    if required and result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr or result.stdout}")
    return result.stdout.strip() if result.returncode == 0 else ""


def install():
    source = Path(__file__).resolve().parent
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    state = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "dnbradio"
    target = config / "omarchy/plugins" / PLUGIN_ID
    if target.is_symlink() or source == target.resolve():
        raise RuntimeError("Run from a separate source folder. The installed plugin must not be a symlink.")
    for file in FILES:
        if not (source / file).is_file():
            raise RuntimeError("Missing source file: " + file)
    for executable in ["omarchy", "omarchy-shell", "notify-send"]:
        if not shutil.which(executable):
            raise RuntimeError("Required command is unavailable: " + executable)
    if command("omarchy-shell", "lock", "isLocked") != "false":
        raise RuntimeError("Unlock Omarchy before installing. The shell cannot safely restart while locked.")
    command("omarchy", "plugin", "validate", str(source))

    state.mkdir(parents=True, exist_ok=True)
    backup = state / "backups" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup.mkdir(parents=True, mode=0o700)
    if target.exists():
        shutil.copytree(target, backup / "plugin")
    shell_config = config / "omarchy/shell.json"
    if shell_config.is_file():
        shutil.copy2(shell_config, backup / "shell.json")
    initial = command("omarchy-shell", "dnbradio", "status", required=False)
    playback = json.loads(initial) if initial else None
    if playback:
        (backup / "playback.json").write_text(json.dumps(playback))
        command("omarchy-shell", "dnbradio", "saveLibrary", required=False)
    library_file = state / "library.json"
    if library_file.exists():
        shutil.copy2(library_file, backup / "library.json")
    else:
        library_file.write_text(json.dumps(dict(version=1, favorites=[], recent=[], reminders=[], notified=[])))
        library_file.chmod(0o600)

    print("Backup:", backup, flush=True)
    if target.exists():
        command("omarchy", "plugin", "disable", PLUGIN_ID)
    target.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        shutil.copy2(source / name, target / name)
    command("omarchy", "plugin", "validate", str(target))
    # Clear Qt's component cache. Never kill a lock client directly.
    command("omarchy", "restart", "shell")
    command("omarchy-shell", "shell", "rescanPlugins")
    command("omarchy", "plugin", "enable", PLUGIN_ID)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if command("omarchy-shell", "dnbradio", "status", required=False):
            break
        time.sleep(0.5)
    else:
        raise RuntimeError("Plugin did not start. Backup and playback snapshot: " + str(backup))
    if playback:
        command("omarchy-shell", "dnbradio", "restore", json.dumps(playback))
        if playback.get("playing") or playback.get("connecting"):
            deadline = time.monotonic() + 35
            while time.monotonic() < deadline:
                current = json.loads(command("omarchy-shell", "dnbradio", "status"))
                expected_position = max(0, playback.get("position", 0) - 2000)
                resumed = current.get("mode") != "archive" or current.get("position", 0) >= expected_position
                if current.get("playing") and resumed:
                    break
                if current.get("error"):
                    raise RuntimeError("Plugin installed, but playback could not resume: " + current["error"])
                time.sleep(0.5)
            else:
                raise RuntimeError("Plugin installed, but resume is unverified. Playback snapshot: " + str(backup / "playback.json"))
    for name in FILES:
        assert hashlib.sha256((source / name).read_bytes()).digest() == hashlib.sha256((target / name).read_bytes()).digest(), name
    print("Installed DNBRADIO 0.4.0. Playback restored." if playback else "Installed DNBRADIO 0.4.0.")


if __name__ == "__main__":
    install()
