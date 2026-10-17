#!/usr/bin/env bash
# Run inside dbus-run-session -- xvfb-run -a, with openbox, trayer and xdotool installed.
set -euo pipefail
cd "$(dirname "$0")/.."
player="${1:-build/dnbradio}"
export QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software
openbox >/tmp/dnbradio-test-openbox.log 2>&1 &
wm=$!
trayer --edge bottom --align right --widthtype pixel --width 40 --height 32 >/tmp/dnbradio-test-trayer.log 2>&1 &
tray=$!
trap 'kill "$tray" "$wm" 2>/dev/null || true' EXIT
python3 - <<'PY'
import subprocess, time
for _ in range(100):
    if subprocess.run(['xdotool', 'search', '--name', '^panel$'], stdout=subprocess.DEVNULL).returncode == 0:
        break
    time.sleep(0.1)
else:
    raise SystemExit('Tray host did not start')
PY
python3 tests/menu-bar.py "$player"
kill "$tray"
wait "$tray" || true
python3 tests/tray-x11.py "$player"
