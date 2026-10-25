# DNBRADIO desktop player

The [DNBRADIO](https://dnbradio.com) player for macOS, Windows and Linux, plus a bar plugin for [Omarchy](https://omarchy.org). Listen to the live stations, dig through recorded mixes and DJ profiles, follow the show schedule and keep your favorites close.

It's a native Qt app. It isn't a website in a wrapper, and it doesn't need an account.

## Download

Get the latest version from the [releases page](https://github.com/dnbradio/dnbradio-desktop/releases/latest) or from [dnbradio.com/apps](https://dnbradio.com/apps).

| Platform | File | Requirements |
|---|---|---|
| macOS | `dnbradio-<version>-macos-arm64.zip` | Apple Silicon Mac with macOS 26 or later |
| Windows | `dnbradio-<version>-windows-x86_64.zip` | 64-bit Windows 10 (1809 or newer) or Windows 11 |
| Linux | `dnbradio-<version>-linux-x86_64.flatpak` | x86_64 with Flatpak and the Flathub remote |
| Omarchy | `dnbradio-omarchy-<version>.tar.gz` | Omarchy 4.0.4 or later |

Every release lists SHA-256 checksums in `SHA256SUMS`.

### macOS

Unzip the download, move `DNBRADIO.app` to Applications and open it. Unzip it outside iCloud Drive or other synced folders. The app isn't notarized by Apple yet, so macOS blocks the first launch. Open System Settings, go to Privacy & Security and click Open Anyway next to the DNBRADIO message. You only need to do this once per version.

### Windows

Extract the whole ZIP and run `DNBRADIO\dnbradio.exe`. Nothing gets installed and you don't need administrator rights. Keep the EXE together with its DLLs and folders. The build isn't code-signed yet, so SmartScreen may say "Windows protected your PC". Click More info, then Run anyway.

Your library and settings live in `%LOCALAPPDATA%\DNBRADIO\DNBRADIO`, so you can delete or replace the extracted folder when you update. Quit the old version first.

### Linux

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./dnbradio-<version>-linux-x86_64.flatpak
flatpak run com.dnbradio.Player
```

The bundle uses the KDE runtime from Flathub and runs on X11 and Wayland. Your desktop doesn't need to be KDE. Linux Mint 22.3 (Cinnamon, X11) is the main test target, and reports from other distributions are welcome.

### Omarchy

The plugin adds a DNB button to the Omarchy bar with the same stations, library and schedule. Extract the archive and run the installer from your unlocked desktop session:

```sh
tar -xzf dnbradio-omarchy-<version>.tar.gz
python3 omarchy/install.py
```

The installer backs up any existing copy, restarts the shell and restores what was playing. Expect a short audio gap. See the [plugin README](integrations/omarchy/README.md) for requirements, controls and the `omarchy-shell dnbradio` commands. To turn it off, run `omarchy plugin disable com.dnbradio.radio`.

## Using the player

Nothing plays until you pick a station and press Play, or open a recorded mix. Click the DNBRADIO icon in the menu bar, notification area or system tray to open the mini player. It shares playback, volume and recent mixes with the main window. Closing the main window keeps the music going. Use Quit to stop and save. If your desktop has no tray, closing the window quits.

Show reminders only fire while the app is running.

## Features

- Six live stations: DNBRADIO in 320K MP3 or 128K AAC, Atmospheric, JungleTrain, Section 8, Darkstep and Bassdrive.
- The full mix archive, with search, genre filters, tracklists, downloads and share links.
- DJ profiles with bios, links, upcoming shows and their mixes.
- The show schedule in your local time, with optional reminders.
- Favorites, recently played mixes and resume where you left off.
- Song history, with purchase links when the station supplies them.
- The contributor wall and donation links.
- Keyboard navigation and smooth scrolling.

## Privacy

There's no account, analytics or tracking. The app talks to public endpoints only: dnbradio.com, DNBRADIO's AzuraCast server, the JungleTrain and Bassdrive streams, and artwork hosts named in their feeds. Favorites and settings stay on your computer. Donation and purchase links open in your browser, and the app never handles payment details.

## Report a problem

Open an [issue](https://github.com/dnbradio/dnbradio-desktop/issues) with your platform, the version you downloaded and what you were playing. For anything else, use the [contact page](https://dnbradio.com/contact).

## Build from source

Requires CMake 3.21+, a C++17 compiler and Qt 6.8+ with Quick, Quick Controls 2, Multimedia, Widgets and Network, plus the Qt SVG and image format plugins. The tests also need Qt Test, Python 3 and Node.js.

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
ctest --test-dir build -C Release --output-on-failure
node --test tests/data.test.cjs
# Linux executable. On macOS use build/dnbradio.app/Contents/MacOS/dnbradio:
python3 tests/smoke.py build/dnbradio
python3 tests/playback-retry.py build/dnbradio
python3 tests/library-controls.py build/dnbradio
# Linux tray tests need Xvfb, openbox, trayer, xdotool, x11-utils and wmctrl:
dbus-run-session -- xvfb-run -a -s "-screen 0 1280x900x24" bash tests/tray-x11.sh build/dnbradio
```

Build the Flatpak bundle on an x86_64 Linux machine with Flatpak Builder:

```sh
bash scripts/build-flatpak.sh
```

On Windows with MSVC 2022 and the Qt tools on `PATH`, build the release executable and the portable ZIP after the test build above:

```powershell
cmake -S . -B build-release -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build-release --config Release --parallel
python scripts/package-windows.py build-release/Release/dnbradio.exe build/Release/dnbradio.exe
python tests/windows-package.py (Get-ChildItem dist/dnbradio-*-windows-x86_64.zip).FullName build-windows-package/QA --live
```

Packaging uses fresh `build-windows-package/DNBRADIO` and `QA` directories and refuses to overwrite an existing bundle. The QA executable stays out of the release ZIP. Leave out `--live` to run only the local fixture tests.

Assemble the Omarchy plugin with the shared data and scrolling files:

```sh
python3 scripts/package-omarchy.py build/omarchy
```

The DNBRADIO logo lives in `packaging/menu-bar.svg`. With ImageMagick installed, `python3 scripts/generate-icons.py` regenerates the launcher SVG, the Windows `.ico` and, on macOS, the `.icns`. Normal builds use the generated files.

## How it's put together

`qml/` holds the player, library, UI, station list and API normalization. `src/` provides the Qt entry point, atomic library storage, settings, notifications and tray integration. The standalone app has no Omarchy imports or shell commands. `integrations/omarchy/` holds the plugin, which shares `qml/Data.js`, `qml/Stations.js` and `qml/SmoothScrollView.qml` with the app.

The library is stored in Qt's per-user application data directory. Flatpak keeps it under `~/.var/app/com.dnbradio.Player/`. A separate `player.ini` stores the station, volume, quality and mute. Only one copy of the app can use a data directory at a time. If the library file can't be read, the app keeps it untouched and turns saving off until it's fixed. The Omarchy plugin keeps its own library.

CI builds and tests on Linux, Windows and macOS, runs the native Linux UI against local API and audio fixtures on X11, and produces the Flatpak bundle and Windows ZIP. The Windows job checks the extracted ZIP with Qt removed from `PATH` and exercises live HTTPS playback. The macOS job checks live startup and recovery with AVFoundation. [docs/RELEASE.md](docs/RELEASE.md) covers releases and known limits. [docs/PROVENANCE.md](docs/PROVENANCE.md) records where the code came from.

## License

The DNBRADIO desktop player and the Omarchy plugin are free software under the [GNU General Public License, version 3](LICENSE) or (at your option) any later version.

Release packages bundle Qt, FFmpeg (Windows), OpenSSL (macOS) and the Microsoft Visual C++ runtime (Windows) under their own licenses. The macOS and Windows packages include those notices, and [packaging/THIRD-PARTY-NOTICES.md](packaging/THIRD-PARTY-NOTICES.md) lists the Windows components.

The DNBRADIO name and logo identify the official station and app. The GPL covers this code but doesn't grant rights to the name or logo. If you share a modified version, give it a different name and icon.
