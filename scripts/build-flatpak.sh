#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/^project(Dnbradio VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt)
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak-builder --user --disable-rofiles-fuse --install-deps-from=flathub --force-clean --repo=build/flatpak-repo build/flatpak packaging/com.dnbradio.Player.json
mkdir -p dist
flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo build/flatpak-repo dist/dnbradio-$version-linux-x86_64.flatpak com.dnbradio.Player
(cd dist && sha256sum "dnbradio-$version-linux-x86_64.flatpak" > SHA256SUMS)
