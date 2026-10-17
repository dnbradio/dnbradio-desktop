# 0.1.0 private preview

The first standalone release carries the existing DNBRADIO radio, archive,
profiles, schedule, contributors, and local library into an ordinary Qt desktop
application. The optional Omarchy plugin remains version 0.4.0.

## Release scope

The first downloadable application is an x86_64 Linux Flatpak. The initial tester
uses Linux Mint 22.3, Cinnamon, and X11. Windows and macOS are build/test targets
for portability, with signed installers deferred. Other Linux desktops remain
validation targets until their actual desktop behavior has been checked.

## Checks

- Shared data normalization, URL validation, monetary display, reminder timing,
  and artwork fallback serialization.
- Native storage round-trip, settings persistence, and preservation of a corrupt library.
- Native UI navigation, mix details, artwork fallback, library/schedule artwork,
  contributor click/Return/Space activation, profiles and pagination, song history,
  purchase links, notifications, local audio playback/seeking, saved positions,
  and narrow layout.
- Linux, Windows, and macOS compilation and storage tests in CI.
- Linux X11 UI/audio smoke and Flatpak packaging in CI.

Native macOS audio testing uses the Cocoa platform: the AVFoundation backend
needs its native event loop. The headless platform remains suitable for storage
tests. Linux UI tests run with Xvfb/X11.

## Private release procedure

1. Verify the repository is private and the intended source head passed CI and review.
2. Download the Flatpak CI artifact from that same head and verify its SHA-256.
3. Create a private GitHub prerelease with the Flatpak, checksum file, and optional
   assembled Omarchy plugin. Keep Flathub submission and public hosting disabled.
4. Follow the README installation steps on Mint 22.3 Cinnamon/X11 and record tester feedback.

## Known limits

- No account synchronization, automatic app updater, or automatic launch at login.
- Reminders run only while the application is open. A desktop notification is
  offered where the system tray supports it, with an in-app reminder as fallback.
- Closing the standalone window quits playback. Minimizing keeps playback running.
- The standalone player and Omarchy plugin have separate local libraries/settings.
- Label catalogue and inferred release/track links remain separate work.
- A private preview is not a claim of verified support on every target distro.
