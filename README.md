# DNBRADIO OS Player

A standalone Qt desktop player for [DNBRADIO](https://dnbradio.com), with an optional Omarchy plugin.

**Private preview, version 0.1.0.** Linux is the first release target. Windows and macOS builds are checked in CI as development targets; installers for those platforms come later. The repository and releases remain private until the owner explicitly authorizes public distribution.

## Install on Linux Mint 22.3 (Cinnamon / X11)

Download `dnbradio-0.1.0-linux-x86_64.flatpak` from this private repository's Releases page, then run:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./dnbradio-0.1.0-linux-x86_64.flatpak
flatpak run com.dnbradio.Player
```

The bundle includes the application and uses the KDE Qt runtime from Flathub. Your desktop stays Cinnamon. The app does not require Omarchy, Hyprland, or Quickshell. Linux builds support both X11 and Wayland through Qt. Mint 22.3 Cinnamon/X11 is the initial tester target; Ubuntu LTS, Fedora, and Arch are further validation targets.

No playback starts automatically. Choose a station and press Play, or open a recorded mix. Minimize the window to keep listening. Closing the window quits the standalone player and saves playback positions. A tray icon is offered where the desktop supports one. Reminders are checked while the application is running and also appear inside the window.

## Features

- Six live stations, including DNBRADIO and Bassdrive, with quality selection, volume, and mute.
- Home with upcoming shows and recently aired mixes.
- Searchable recorded mixes, artwork fallback, mix details, tracklists, download/share links, and DJ profiles.
- Local-time show schedules and opt-in reminders.
- Favorites, recent mixes, and playback resume.
- Contributor cards, public contribution amounts, profile avatars where matched, and donation links.
- Song history and explicit purchase links supplied by station metadata.
- Keyboard navigation and smooth scrolling.

Label catalogue enrichment remains separate work. No purchase destinations are guessed from song titles or identifiers.

## Build

Requires CMake 3.21+, C++17, Qt 6.8+ (Quick, Quick Controls 2, Multimedia, Widgets, Network, and Test for tests), plus the Qt SVG/image plugins. A Qt 6.10 runtime is used for Linux bundles.

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
ctest --test-dir build -C Release --output-on-failure
node --test tests/data.test.cjs
# Linux executable; macOS uses build/dnbradio.app/Contents/MacOS/dnbradio:
python3 tests/smoke.py build/dnbradio
```

To build the Linux bundle on an x86_64 Linux machine with Flatpak Builder:

```sh
bash scripts/build-flatpak.sh
```

## Architecture and data

`qml/` contains the portable player, library, UI, station catalogue, and API normalization. `src/` provides the Qt application entry point, atomic library persistence, settings, notifications, and tray integration. There are no Omarchy imports or shell commands in the standalone application.

Library data is stored under Qt's per-user application data directory. Flatpak isolates it under `~/.var/app/com.dnbradio.Player/`. A separate `player.ini` stores station, volume, quality, and mute. Only one instance may use a data directory at a time. An unreadable library is preserved and saving is disabled until it is repaired. The existing Omarchy library stays separate.

The application uses public DNBRADIO, AzuraCast, JungleTrain, Bassdrive, and artwork endpoints. Donation and purchase links open in the system browser. No authentication or payment details are stored in the player.

## Optional Omarchy integration

The Omarchy 0.4.0 plugin is retained from the tested original implementation. Assemble it with the shared data and scrolling files:

```sh
python3 scripts/package-omarchy.py build/omarchy
python3 build/omarchy/install.py
```

Run the installer in your unlocked Omarchy desktop session. It backs up the installed plugin and restores playback. See [the integration README](integrations/omarchy/README.md) for controls and its native test tools.

## Validation and releases

CI builds on Linux, Windows, and macOS, runs storage and data tests, exercises the native Linux UI with local API/audio fixtures on X11, and creates a private Flatpak artifact. Tests use isolated data directories and do not control installed players. The test-QML loader is compiled only when `BUILD_TESTING` is enabled; release bundles disable it.

Platform validation, private release steps, and known limitations are recorded in [release notes](docs/RELEASE.md). Source provenance is in [PROVENANCE.md](docs/PROVENANCE.md).
