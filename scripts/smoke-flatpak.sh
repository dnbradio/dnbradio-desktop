#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
(cd dist && sha256sum --check SHA256SUMS)
flatpak install --user --noninteractive --assumeyes dist/dnbradio-0.2.0-linux-x86_64.flatpak
status=0
dbus-run-session -- xvfb-run -a timeout 15s flatpak run \
  --env=QT_QPA_PLATFORM=xcb --env=QT_QUICK_BACKEND=software \
  com.dnbradio.Player > build/flatpak-startup.log 2>&1 || status=$?
cat build/flatpak-startup.log
if [ "$status" -ne 124 ]; then
  echo "Packaged application exited before the startup check completed (status $status)." >&2
  exit 1
fi
if grep -E 'QQmlApplicationEngine failed|TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign' build/flatpak-startup.log; then
  exit 1
fi
echo "PASS: installed Flatpak remained running on X11 without QML errors"
