# DNBRADIO Pulse for Omarchy 4

Native Quickshell player and library, version 0.4.0. Click **DNB** in the bar.
Right-click to play/pause, or scroll over the widget to adjust volume. The
service and audio player are shared across monitors. Closing a window keeps
audio playing. Playback does not start automatically at login.

## Features

- Six live stations, including Bassdrive, DNBRADIO MP3/AAC quality selection,
  song information, listener counts, volume and mute.
- Home with upcoming shows and recently aired mixes. Recorded mixes use four
  cards per row. Mix covers fall back to DJ artwork when absent or unable to load.
- DJ profiles with public bio, membership date, play/mix counts, social links,
  next show, and paginated mixes. Open profiles from shows or mix cards.
- Song history beside now playing, with artwork, times, albums and explicit
  purchase links when supplied by the station. Purchase URLs are not inferred
  from track names or identifiers. Bassdrive's feed has no song history.
- Full paginated recording archive with title/DJ/description search, exact genre
  filtering, and newest/oldest/most-played sorting.
- Mix artwork, description, tracklist, genre, plays, download, and copy-link
  sharing. The same player handles live radio and recordings with seeking.
- Favorites and the latest 100 listening sessions, including resume positions and larger artwork.
- Library scrolling follows trackpad movement and coasts on release. Mouse wheel
  notches ease into place; clicking or dragging the scrollbar stops momentum.
- Show schedule with larger artwork in the desktop's local timezone. Opt-in per-show notifications
  arrive five minutes before start while the shell is running. Late wakeups
  notify only within two minutes after start. Reminders are deduplicated across
  restarts. A changed show start time requires setting a new reminder.
- Contributors section with cards showing public names, contribution amounts, original
  currency, dates, pagination, profile avatars, and donation links. Exact, unique
  public alias matches link to DJ profiles; unmatched/ambiguous names use initials. Donations open the website's
  checkout in the browser. No payment information is handled by this plugin.
- Browser links for chat, Discord, merchandise, podcasts, and help.

## Install or update

Requires Omarchy 4.0.4 or later with Hyprland Lua dispatchers, Quickshell 0.3.1,
Qt 6 Multimedia, Python 3, and `notify-send`. Run in the unlocked desktop session:

```sh
python3 scripts/package-omarchy.py build/omarchy
python3 build/omarchy/install.py
```

The installer backs up the existing plugin and playback, initializes local
library storage if absent, validates the plugin, restarts the shell, and restores
playback, position, volume, and mute. It leaves backups under
`~/.local/state/dnbradio/backups/`. A brief audio interruption is expected.
It never bypasses a locked session. Over SSH, use the desktop's `OMARCHY_PATH`,
`WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` environment values.

No root access, API key, web server, or extra background service is needed.
Network requests run in the existing shell. Public requests go to DNBRADIO,
its AzuraCast server, JungleTrain, Bassdrive, and artwork hosts published in their feeds.

## Storage and controls

Station, quality, volume and mute are saved in Omarchy's `shell.json` through
its plugin API. Favorites, recent mixes, positions, and reminder state are
written atomically to `$XDG_STATE_HOME/dnbradio/library.json`, defaulting to
`~/.local/state/dnbradio/library.json`. Positions save every 15 seconds and on
pause/switch. A damaged file is preserved and a visible warning disables writes.
This library is local to this desktop, with no account synchronization.

Panel keys: Space play/pause, 1–6 stations, M mute, arrows volume/station, Tab
change tab, R refresh, Esc close. Search and dropdowns handle their own keys.
The library supports Tab navigation and Esc to leave details or close the window.

```sh
omarchy-shell dnbradio open home
omarchy-shell dnbradio open mixes
omarchy-shell dnbradio open schedule
omarchy-shell dnbradio open library
omarchy-shell dnbradio open contributors
omarchy-shell dnbradio open history
omarchy-shell dnbradio profile djfk
omarchy-shell dnbradio profilePage 2
omarchy-shell dnbradio status
omarchy-shell dnbradio libraryStatus
omarchy-shell dnbradio tune dnbradio
omarchy-shell dnbradio pause
omarchy-shell dnbradio volume 45
omarchy-shell dnbradio recording 0
omarchy-shell dnbradio seek 60
omarchy plugin disable com.dnbradio.radio
```

## API contract

All routes are public GETs. They follow the existing API rate limits.

| Route | Parameters / response |
|---|---|
| `/api/podcast` | `search` (max 150), exact `artist` (150), profile slug `dj` (150), exact `genre` (100), `sort=newest\|oldest\|popular`, `page`, `items_per_page` (1–100). Existing `data`/`pagination` fields preserved. Adds `pagination.total` and `capabilities`. |
| `/api/podcast/{id}` | `{data: {...}}` with the same public recording fields as the list. Unpublished, empty, or missing recordings return 404. |
| `/api/schedule` | Existing array of show occurrences with `start`/`end` timestamps, host, title, description, images and public `profile: {slug,name,url}` references. |
| `/api/profiles/{slug}` | `{data: {slug,name,location,bio,image,banner,url,member_since,stats:{mixes,plays},links,next_show}}`. Explicit public profile fields only. Missing profiles return 404. |
| `/api/support` | `page`, `items_per_page` (1–100, default 30). `{data: [{id,alias,amount,currency,date,image,profile}], pagination: {page,total_pages,total}, donate_url}`. Completed positive contributions only. Amount is a decimal string. No emails, legal names, transaction IDs, or payment metadata. |
| `/api/donations` | Compatibility fallback for older servers. Only completed positive donations and public display fields enter the UI. |

Recording objects include title, artist, description, tracklist, image, genre,
mood, plays, timestamp, size, download URL, playback URL, permalink, and a
`profile_image` fallback and a public profile reference when available. The
plugin constructs audio/download/share URLs from numeric mix IDs on dnbradio.com.

Without the new backend deployment, recent mixes, pagination, details from the
list, schedule, local library, and supporters still work. Search/filter/sort
display a server-update message until `/api/podcast` advertises capabilities.
Contributors fall back to the existing 100-entry public list. Profile details
need `/api/profiles/{slug}` and profile mixes require the `dj` capability. Older
servers show a website fallback instead of an unfiltered archive. The old
`open support` IPC command remains an alias for `open contributors`.

Metadata refreshes every 30 seconds, schedule every five minutes, and the
unfiltered archive every 15 minutes. API errors never stop existing playback.

## Validation

On a Linux Omarchy desktop, run the isolated native integration test:

```sh
python3 build/omarchy/tests/native-smoke.py
node --test build/omarchy/tests/data.test.cjs
# Qt input regression (requires g++, pkg-config and Qt6Quick/Qt6Test headers):
python3 build/omarchy/tests/native-scroll.py
```

It briefly opens isolated test windows in the current Wayland session.
It uses a separate Quickshell config, fixture API, local state,
intercepted notification/compositor commands, and muted real archive/Bassdrive playback.
It never controls the installed desktop plugin. Checks cover the bar widget,
compact popup and every library screen, loaded artwork, four-column cards, DJ
profiles, full song history, purchase links, QML errors, failed-page retries,
queries, pagination, details, contributors,
favorites, real seeking/resume, restart persistence, notification deduplication,
legacy API compatibility, and protection of a damaged saved file.

Backend coverage remains in the Laravel repository: `tests/Feature/RadioLibraryApiTest.php`.
Test-only overrides: `DNBRADIO_API_BASE`, `DNBRADIO_STATE_FILE`,
`DNBRADIO_NOWPLAYING_URL`, and `DNBRADIO_BASSDRIVE_URL`.

References: [Omarchy plugins](https://plugins.omarchy.org/develop.html),
[Quickshell windows](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/),
[AzuraCast metadata](https://azura.drmnbss.org/api/nowplaying).
