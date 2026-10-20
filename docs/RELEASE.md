# 0.2.2 private preview

This release adds a 2.5-second preload before starting or reopening DNBRADIO’s
320K MP3 stream on macOS. The player shows “Buffering live audio…” while waiting.
Pause, failures, quality/station changes, and Quit cancel the pending start.
AAC, recordings, other stations, Linux, and Windows keep their startup behavior.

It includes the previous playback-retry, library controls, and live Pause/Play
fixes. The optional Omarchy plugin remains version 0.4.0.

## Release scope

- Linux x86_64 Flatpak. Linux Mint 22.3 Cinnamon/X11 is the initial tester target.
- Apple Silicon macOS ZIP, targeting macOS 26 or later. Ad hoc signed for private
  testing, without Apple notarization or an automatic updater.
- Windows x86_64 portable ZIP for Windows 10 (1809+) and Windows 11. Unsigned
  private preview, including Qt, FFmpeg, and app-local Visual C++ runtime DLLs.
  No installer or administrator access is required.

The mini player shares the full window's audio session, metadata, station and
quality selection, volume/mute, archive playback, recent mixes, history, and
navigation. Linux and Windows offer Mini player, Open player, and Quit in their tray menus.
Closing the full window keeps playback running when a tray is available.
Without a tray it quits. If the panel disappears, the full window reopens.

## Checks

- Storage, settings, corruption preservation, and shared data normalization tests.
- Native UI navigation, artwork fallback, profiles, schedule, contributors,
  library/resume, history, purchase links, and fixture audio playback/seeking.
- Linux X11 mini-player controls, shared playback, close-to-tray, dropdown contrast,
  keyboard interaction, native tray clicks/context menu, focus dismissal, bottom
  panel positioning, panel-loss recovery, and no-tray quit.
- Linux, Windows, and macOS compilation and platform tests in CI.
- Linux Flatpak packaging and installed-bundle startup in CI.
- Local packaged macOS UI/mini-player tests, real HTTPS playback, bundled dependency
  and minimum-OS audit, production test-loader exclusion, and strict signature checks.
- Windows extracted-ZIP startup, DLL origin checks without Qt on PATH, production
  test-loader exclusion, matching QA/runtime DLLs, UI/audio fixtures, tray controls,
  and live HTTPS MP3/AAC startup and Pause/Play recovery. A desktop screenshot and
  logs are retained in CI.

Linux desktop interaction tests use Xvfb, Openbox, and trayer. Exact Mint/Cinnamon
and Wayland desktop behavior still needs tester feedback. Native macOS focus-loss
validation remains limited; QML controls and native status-item activation were
exercised. The owner tested the updated candidate on an M2 Air with macOS 26.5.2
and reported that it now seems fine. Automated tests on that Air reproduced the live restart
hang before the fix and passed afterward for MP3 and AAC. The owner also confirmed that the 0.2.2 buffering candidate eliminated repeated
10–50 ms cutouts on the M2 Air with a Scarlett 4i4 at 44.1 kHz. The exact
underlying AVFoundation timing fault remains unconfirmed. Automated muted traces
verify progress and control behavior, not audible output. A new local-fixture
regression checks preload cancellation, retries, quality/station switches,
recordings, and shutdown; macOS CI runs it before real MP3/AAC startup/restart.

## Private release procedure

1. Verify the repository is private and the intended source head passed CI and review.
2. Download the Flatpak CI artifact from that head and verify its SHA-256.
3. Build the macOS ZIP from the same source with `BUILD_TESTING=OFF`, arm64, and
   deployment target 26.0. Bundle Qt using `macdeployqt`, audit all dependencies and
   minimum OS versions, sign, and verify the final app. Run packaged tests using a
   separate test-enabled executable with the same bundled frameworks.
4. Download the Windows ZIP from the matching successful CI head and verify
   `SHA256SUMS-windows`. Its `BUILD-INFO.json` records the source commit and runtime
   versions. Require the ZIP source commit to match the release tag. Preserve all
   older tags and published assets.
5. Create a new private GitHub prerelease with the platform packages,
   checksum files, and optional assembled Omarchy plugin. Keep public hosting disabled.
6. Follow the README installation steps and record tester feedback.

## Known limits

- No account synchronization, automatic updater, or launch at login.
- Reminders run only while the application is open.
- Wayland compositors control panel placement; a system tray must be provided by
  the desktop for tray access. Linux without a tray retains the full-window player.
- The standalone player and Omarchy plugin have separate libraries/settings.
- Label catalogue and inferred purchase links remain separate work.
- A private preview is not a claim of verified support on every target distro.
- Windows CI runs on Server 2022. Windows 10/11 desktop behavior and audible output
  still need tester feedback. The portable preview has no Authenticode signature.
