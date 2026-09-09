# Playbook: Chromium ad blocker (uBlock Origin Lite)

Install **uBlock Origin Lite** on Omarchy’s Chromium so it blocks ads on YouTube and the rest of the web. Chromium 132+ dropped Manifest V2, so classic uBlock Origin from the Arch `ublock-origin` package will not load. Lite is the Manifest V3 replacement from the same author.

The install is one script plus a Chromium restart. Force-install is used so Complete filtering mode gets `<all_urls>` without a permission prompt. Complete mode is what actually strips YouTube player ads, not only banner ads.

## Assumptions

- Omarchy (Arch + Hyprland)
- Chromium is the browser (`command -v chromium`)
- Network access to the Chrome Web Store update service (`clients2.google.com`)
- sudo in a visible terminal (writes under `/etc/chromium` and `/usr/share/chromium`)

## Live paths this playbook changes

| Path | Role |
|------|------|
| `/etc/chromium/policies/managed/ublock-origin-lite.json` | Force-install, pin the toolbar icon, set Complete filtering |
| `/usr/share/chromium/extensions/ddkjiahejlhfcafbddmgiahcphecmpfh.json` | Same Chrome Web Store hook Omarchy uses for the 1Password extension |

Chromium itself unpacks the extension into `~/.config/chromium/Default/Extensions/ddkjiahejlhfcafbddmgiahcphecmpfh/` after restart. This playbook does not write that directory.

Templates: [`config/chromium-adblock/`](../config/chromium-adblock/).

Omarchy already writes `/etc/chromium/policies/managed/color.json` for the theme. Chromium may show “managed by your organization.” That is expected and is not unique to this playbook.

## Quick install

```bash
./scripts/chromium-adblock-status.sh
./scripts/chromium-adblock-install.sh
```

Quit Chromium fully, then open it again. Reload any YouTube tab that was already open (`Ctrl+R`).

```bash
./scripts/chromium-adblock-status.sh
```

Success is `policy: present`, `store hook: present`, and `extension on disk: yes` after the restart.

## 1. Detect

```bash
./scripts/chromium-adblock-status.sh
```

You want:

1. `chromium` on `PATH`
2. After install, both policy files exist
3. After a Chromium restart, the extension directory exists under the Default profile

If Chromium is missing:

```bash
omarchy install browser chromium
```

## 2. Install

```bash
./scripts/chromium-adblock-install.sh
```

What it does:

- Installs the managed policy from [`config/chromium-adblock/ublock-origin-lite.json`](../config/chromium-adblock/ublock-origin-lite.json)
- Installs the Chrome Web Store external-extension JSON (same pattern as `omarchy install service 1password`)
- Does **not** kill a running Chromium (that would drop unsaved tabs)

Extension ID: `ddkjiahejlhfcafbddmgiahcphecmpfh` (uBlock Origin Lite).

### Why not `--load-extension` in `chromium-flags.conf`?

`omarchy refresh chromium` rewrites `~/.config/chromium-flags.conf` from Omarchy defaults. A policy file under `/etc/chromium/policies/managed/` survives that refresh.

### Why Complete mode?

uBlock Origin Lite defaults to Optimal. YouTube ads need cosmetic filters and scriptlets, which require Optimal or Complete plus host permissions. This playbook sets `defaultFiltering` to `complete` and force-installs so Chromium grants `<all_urls>` without a click-through.

If a site breaks, lower that site only: click the uBOL toolbar icon and slide to Optimal or Basic. The default stays Complete.

## 3. Configure

Configuration is in the policy file. There is no extra configure script.

| Policy | Value | Why |
|--------|-------|-----|
| `installation_mode` | `force_installed` | Auto-install, auto-update, grant host permissions |
| `toolbar_pin` | `force_pinned` | Icon stays visible |
| `defaultFiltering` | `complete` | YouTube + leftover cosmetic ads |
| `disableFirstRunPage` | `true` | Skip the first-run tab |
| `showBlockedCount` | `true` | Badge on the icon |
| `strictBlockMode` | `true` | Block known-bad pages |
| `popupBlockMode` | `true` | Block popup ads |

Do not add a `rulesets` policy unless you intend to lock filter lists. Locked lists cannot be toggled from the dashboard.

## 4. Verify

Restart Chromium, then:

```bash
./scripts/chromium-adblock-status.sh
```

In Chromium:

- `chrome://extensions` lists **uBlock Origin Lite** and it is enabled
- `chrome://policy` shows `ExtensionInstallForcelist` and the `3rdparty` uBOL keys
- Open a site that is usually full of ads, or reload YouTube; the icon badge should count blocked requests

YouTube still changes its player scripts. A rare ad can slip through until the next Lite update. Reload the tab after installing; a restored YouTube tab from before the restart is still running the old page.

## After updates

Nothing DKMS-related. The extension updates itself from the Chrome Web Store.

`omarchy refresh chromium` does not remove this playbook. Removing Chromium (`omarchy remove browser` is for other browsers; Chromium is the Omarchy default) would leave the policy files in `/etc` until you run undo.

## Undo

```bash
./scripts/chromium-adblock-remove.sh
```

Then quit and reopen Chromium so it drops the force-installed extension.

That only deletes the two files this playbook added. It does not touch `color.json` or Omarchy’s bundled Copy URL / yt-dlp / WhatsApp Slim extensions.

## Optional: SponsorBlock

uBlock Origin Lite blocks **ad network** requests (pre-roll, banners, overlays). It does not skip in-video “this video is sponsored by…” chapters. For that, add [SponsorBlock](https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnmlneghlbhopmepmneahkbieocophcm) (`mnmlneghlbhopmepmneahkbieocophcm`) from the Chrome Web Store. This playbook does not install it.

## References

- [uBlock Origin Lite (Chrome Web Store)](https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh)
- [uBOL managed settings](https://github.com/uBlockOrigin/uBOL-home/wiki/Managed-settings)
- [Chromium: policy for extensions](https://www.chromium.org/administrators/configuring-policy-for-extensions/)
- Omarchy’s 1Password installer (`omarchy install service 1password`) for the `/usr/share/chromium/extensions/<id>.json` pattern
