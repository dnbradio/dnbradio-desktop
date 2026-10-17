# 0.2.0 private preview

This release adds the shared tray mini player on Linux and macOS, readable dark
dropdowns, and the supplied DNBRADIO logo for desktop and menu-bar icons.
The optional Omarchy plugin remains version 0.4.0.

## Release scope

- Linux x86_64 Flatpak. Linux Mint 22.3 Cinnamon/X11 is the initial tester target.
- Apple Silicon macOS ZIP, targeting macOS 26 or later. Ad hoc signed for private
  testing, without Apple notarization or an automatic updater.
- Windows remains a compilation/test target; no Windows installer is included.

The mini player shares the full window's audio session, metadata, station and
quality selection, volume/mute, archive playback, recent mixes, history, and
navigation. Linux offers Mini player, Open player, and Quit in its tray menu.
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

Linux desktop interaction tests use Xvfb, Openbox, and trayer. Exact Mint/Cinnamon
and Wayland desktop behavior still needs tester feedback. The macOS build host's
locked desktop prevents native focus-loss validation; its QML controls and native
status-item activation are exercised. The earlier macOS build was also tested by
the owner on Apple Silicon.

## Private release procedure

1. Verify the repository is private and the intended source head passed CI and review.
2. Download the Flatpak CI artifact from that head and verify its SHA-256.
3. Build the macOS ZIP from the same source with `BUILD_TESTING=OFF`, arm64, and
   deployment target 26.0. Bundle Qt using `macdeployqt`, audit all dependencies and
   minimum OS versions, sign, and verify the final app. Run packaged tests using a
   separate test-enabled executable with the same bundled frameworks.
4. Create a private GitHub prerelease with the Flatpak, macOS ZIP, checksum file,
   and optional assembled Omarchy plugin. Keep Flathub and public hosting disabled.
5. Follow the README installation steps and record tester feedback.

## Known limits

- No account synchronization, automatic updater, or launch at login.
- Reminders run only while the application is open.
- Wayland compositors control panel placement; a system tray must be provided by
  the desktop for tray access. Linux without a tray retains the full-window player.
- The standalone player and Omarchy plugin have separate libraries/settings.
- Label catalogue and inferred purchase links remain separate work.
- A private preview is not a claim of verified support on every target distro.
