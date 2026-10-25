# Source provenance

The player and the Omarchy plugin started in DNBRADIO's website repository,
`dnbradio/dnbradio-laravel`, which isn't public. The plugin came from
`integrations/omarchy/dnbradio` at commit
`bb250e49752b5f0dc66fc08d7bcc231e32c43684` (plugin 0.4.0). Plugin 0.5.0 adds the
label and release links from commit `5f6431d3b82d7729010ec33bf4f0dfe6b3d6e7be`
of the same path.

The standalone application replaces Omarchy UI controls, shell IPC, storage,
notifications and window management with Qt facilities. The Omarchy plugin
remains in `integrations/omarchy`.

Both are licensed under the GNU General Public License, version 3 or later.
Third-party runtime components keep their own licenses. See
[THIRD-PARTY-NOTICES.md](../packaging/THIRD-PARTY-NOTICES.md).
