#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak-builder --user --disable-rofiles-fuse --install-deps-from=flathub --force-clean --repo=build/flatpak-repo build/flatpak packaging/com.dnbradio.Player.json
mkdir -p dist
flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo build/flatpak-repo dist/dnbradio-0.1.0-linux-x86_64.flatpak com.dnbradio.Player
sha256sum dist/dnbradio-0.1.0-linux-x86_64.flatpak > dist/SHA256SUMS
