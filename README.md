# DNBRADIO OS Player

A standalone Qt desktop player for [DNBRADIO](https://dnbradio.com), with an optional Omarchy plugin.

**Private preview, version 0.2.1.** Linux x86_64 Flatpak, Apple Silicon macOS ZIP, and Windows x86_64 portable ZIP packages are available. The repository and releases remain private until the owner explicitly authorizes public distribution.

## Install on Linux Mint 22.3 (Cinnamon / X11)

Download `dnbradio-0.2.1-linux-x86_64.flatpak` from this private repository's Releases page, then run:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./dnbradio-0.2.1-linux-x86_64.flatpak
flatpak run com.dnbradio.Player
```

The bundle includes the application and uses the KDE Qt runtime from Flathub. Your desktop stays Cinnamon. The app does not require Omarchy, Hyprland, or Quickshell. Linux builds support both X11 and Wayland through Qt. Mint 22.3 Cinnamon/X11 is the initial tester target; Ubuntu LTS, Fedora, and Arch are further validation targets.

No playback starts automatically. Choose a station and press Play, or open a recorded mix. On Linux, Windows, and macOS, click the tray/menu-bar icon to open the mini player. It shares playback, stations, quality, volume, recent mixes, and navigation with the full window. On Linux and Windows, right-click also offers Mini player, Open player, and Quit. Closing the full window keeps playback running when a tray is available; use Quit to exit and save. Without a tray, closing the window quits. If the desktop panel disappears, the full window reopens. Panel placement on Wayland is controlled by the compositor. Reminders are checked while the application is running and also appear inside the window.

## Install on Apple Silicon macOS

Download `dnbradio-0.2.1-macos-arm64.zip`, extract it outside cloud-sync folders, and move `DNBRADIO.app` to Applications. This private preview targets macOS 26 or later and is ad hoc signed, not notarized. If macOS blocks the first launch, use System Settings → Privacy & Security → Open Anyway for this downloaded app.

Click the menu-bar logo for the mini player. Closing the full window keeps playback running; choose Quit to exit. No playback starts automatically.

## Install on Windows

Download `dnbradio-0.2.1-windows-x86_64.zip`, extract the entire ZIP, and run
`DNBRADIO/dnbradio.exe`. Requires 64-bit Windows 10 (1809+) or Windows 11.
Qt, audio codecs, and the Visual C++ runtime are included. Keep the executable
with its DLLs and folders. No installation or administrator access is required.
This private preview is unsigned, so Windows may show an unknown publisher warning.

Click the notification-area logo for the mini player, or right-click for
Mini player, Open player, and Quit. Look in Windows' hidden-icons menu if needed.
Closing the full window keeps playback running. Use Quit to exit before updating.
Your library and settings live in `%LOCALAPPDATA%/DNBRADIO/DNBRADIO`, outside the
extracted folder. Native Windows ARM64 and 32-bit packages are not included.

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
python3 tests/playback-retry.py build/dnbradio
python3 tests/library-controls.py build/dnbradio
# Linux tray tests require Xvfb, openbox, trayer, xdotool, x11-utils, and wmctrl:
dbus-run-session -- xvfb-run -a -s "-screen 0 1280x900x24" bash tests/tray-x11.sh build/dnbradio
```

To build the Linux bundle on an x86_64 Linux machine with Flatpak Builder:

```sh
bash scripts/build-flatpak.sh
```

On Windows with MSVC 2022 and Qt tools on PATH, create the production executable
and portable ZIP after the test build above:

```powershell
cmake -S . -B build-release -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build-release --config Release --parallel
python scripts/package-windows.py build-release/Release/dnbradio.exe build/Release/dnbradio.exe
python tests/windows-package.py dist/dnbradio-0.2.1-windows-x86_64.zip build-windows-package/QA --live
```

Packaging uses fresh `build-windows-package/DNBRADIO` and `QA` directories and
refuses to overwrite an existing bundle. The QA executable is kept outside the
release ZIP. Omit `--live` to run only deterministic local-fixture tests.

The supplied DNBRADIO logo lives in `packaging/menu-bar.svg`. Run `python3 scripts/generate-icons.py` with ImageMagick installed to regenerate the launcher SVG, Windows `.ico`, and, on macOS, the Dock/Finder `.icns`. Normal builds use the generated assets and do not require ImageMagick.

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

CI builds on Linux, Windows, and macOS, runs storage and data tests, exercises the native Linux UI with local API/audio fixtures on X11, and creates private Flatpak and Windows ZIP artifacts. The Windows job checks an extracted ZIP with Qt removed from PATH, verifies bundled DLLs, and exercises the UI, audio, tray mini player, and live HTTPS MP3/AAC startup and Pause/Play recovery. The macOS job also checks live startup and recovery with AVFoundation. Tests use isolated data directories and do not control installed players. The test-QML loader is compiled only when `BUILD_TESTING` is enabled; release bundles disable it.

Platform validation, private release steps, and known limitations are recorded in [release notes](docs/RELEASE.md). Source provenance is in [PROVENANCE.md](docs/PROVENANCE.md).
