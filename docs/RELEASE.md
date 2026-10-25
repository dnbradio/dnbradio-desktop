# Releases

`CMakeLists.txt` sets the app version and `integrations/omarchy/manifest.json`
sets the plugin version. Release notes live on the GitHub release.

## Packages

- Linux x86_64 Flatpak, built by the `flatpak` CI job.
- Windows x86_64 portable ZIP for Windows 10 (1809+) and Windows 11, built by the
  `native (windows-2022)` CI job. It includes Qt, FFmpeg and app-local Visual C++
  runtime DLLs. `BUILD-INFO.json` records the source commit and runtime versions.
- Apple Silicon macOS ZIP for macOS 26 or later, packaged by a maintainer from the
  tagged commit with `BUILD_TESTING=OFF`. `Contents/Resources/BUILD-INFO.json`
  records the source commit and the Qt and OpenSSL versions.
- Omarchy plugin archive, assembled by `scripts/package-omarchy.py` and packed as
  `omarchy/` inside `dnbradio-omarchy-<version>.tar.gz`.

## Procedure

1. Bump the version in `CMakeLists.txt`, add a `<release>` entry to
   `packaging/com.dnbradio.Player.metainfo.xml`, and merge once CI passes.
2. Download the Flatpak and Windows artifacts from the CI run for that merge
   commit and verify their SHA-256 files. The Windows ZIP's `BUILD-INFO.json`
   must name the same commit.
3. Build the macOS ZIP from the same commit. Bundle Qt with `macdeployqt` and
   leave out Qt modules the app never loads. Check the architecture, minimum
   macOS version and dependencies of every Mach-O file, sign the app, and verify
   the signature after extracting the ZIP. Run the packaged tests with a
   test-enabled executable that uses the same bundled frameworks.
4. Tag the commit `v<version>` and publish a GitHub release with the packages,
   `SHA256SUMS` and `RELEASE-PROVENANCE.json`, which names the source commit,
   the CI run and the package hashes. Keep earlier tags and assets.
5. Update the version shown on https://dnbradio.com/apps.

## Checks

- Storage, settings, corruption preservation and shared data normalization tests.
- Native UI navigation, artwork fallback, profiles, schedule, contributors,
  library and resume, history, purchase links, and fixture audio playback and
  seeking.
- Linux X11 mini player controls, close to tray, tray clicks and context menu,
  panel-loss recovery and no-tray quit, using Xvfb, Openbox and trayer.
- Linux Flatpak packaging and installed-bundle startup.
- Windows extracted-ZIP startup with Qt removed from `PATH`, DLL origin checks,
  test-loader exclusion, tray controls, and live HTTPS MP3/AAC startup and
  Pause/Play recovery.
- macOS live MP3 prebuffering, startup and restart with AVFoundation.

Automated playback checks verify progress and control behavior, not audible
output.

## Known limits

- No account sync, automatic updater or launch at login.
- Reminders run only while the app is open.
- Wayland compositors control panel placement. Tray access needs a tray provided
  by the desktop. Without one, Linux keeps the full-window player.
- The app and the Omarchy plugin keep separate libraries and settings.
- macOS packages are Apple Silicon only, need macOS 26 or later and are not
  notarized yet. Windows packages are not Authenticode-signed yet.
- Windows CI runs on Windows Server 2022 without an audio device, so audible
  output on Windows 10 and 11 depends on listener reports.
