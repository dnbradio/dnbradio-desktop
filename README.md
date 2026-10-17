# DNBRADIO OS Player

A native desktop radio player for [DNBRADIO](https://dnbradio.com), built for Omarchy.

This repository is the dedicated home for standalone player development. The existing implementation is in [dnbradio-laravel/integrations/omarchy/dnbradio](https://github.com/dnbradio/dnbradio-laravel/tree/main/integrations/omarchy/dnbradio).

## Player features

- Live radio stations, including DNBRADIO and Bassdrive.
- Recorded mixes, artwork, mix details, and DJ profiles.
- Show schedules and reminders.
- Favorites, recently played mixes, and playback resume.
- Contributor acknowledgments and donation links.
- Song history and available purchase links.
- Native desktop controls and smooth scrolling.

## Technology

The player uses Qt Quick/QML and Quickshell within Omarchy. It consumes DNBRADIO and station APIs for radio, archive, schedule, and profile data.

Label catalogue and purchase-link enrichment is tracked as separate follow-up work.
