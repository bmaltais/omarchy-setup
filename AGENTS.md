# Agent instructions for omarchy-setup

This repository is the **source of truth** for reusable Omarchy customizations.
Live files under `~/.config/` and `/etc/` are applied copies. Playbooks, templates,
and scripts live here so a setup can be repeated, shared, and reviewed.

This repo is intended to be **public**. Treat every file as if a stranger will clone it.

## When to use this repo

Use it whenever you:

- Configure Omarchy beyond a one-line `omarchy` command (DisplayLink, monitors, GPU, docks, udev, systemd drop-ins, Hyprland env)
- Need to repeat a setup on another machine
- Are about to edit `~/.config/hypr/`, `~/.config/uwsm/`, or `/etc/` for a customization that should survive reinstalls

Also follow the local **omarchy** skill for live-system rules (never edit `/usr/share/omarchy/`, prefer `omarchy pkg`, backup before Hyprland edits, validate with `hyprctl reload` and `hyprctl configerrors`).

## Privacy — never commit personal data

Do not put any of the following in this repo:

- Names, emails, usernames, hostnames, machine IDs
- Home directory paths (`/home/<user>/...`)
- MAC addresses, disk UUIDs, IP addresses, Wi-Fi SSIDs
- Monitor serials, EDID dumps, `hyprctl` output with serials
- PCI / USB IDs that are unique to one machine **as committed config** (generate them at apply-time)
- SSH keys, tokens, passwords, YubiKey / FIDO identifiers
- Photos or screenshots that show a desktop with personal windows

Safe to commit:

- Product names (for example “DisplayLink”, “Plugable UD-3900PDZ”) as examples
- Vendor IDs that identify a *device class* (`17e9` = DisplayLink)
- Placeholders (`DP-3`, `DVI-I-1`, `0000:XX:XX.X`)
- Scripts that *detect* machine-specific values and write them to the live system

Sanitize before committing command output. Prefer `scripts/displaylink-detect.sh --sanitize`.

## How a playbook is structured

Each customization is a playbook:

```
docs/<topic>.md                 # human + agent guide (the source of truth)
config/<topic>/                 # generic templates only
scripts/<topic>-*.sh            # detect / install / configure / rebuild
```

`docs/<topic>.md` must include:

1. What problem it solves
2. Hardware / software assumptions
3. Detect → install → configure → verify
4. Live paths that will be changed
5. How to undo
6. After kernel / Omarchy update notes

Start from [`docs/playbook-template.md`](docs/playbook-template.md).

## How to apply a playbook

1. Read `docs/<topic>.md` end to end.
2. Run the detect script. Confirm the machine matches the playbook.
3. Run install, then configure. Do not skip detect on an unfamiliar machine.
4. Leave machine-specific output on the live system, not in git.
5. If the user asked to document a *new* customization, add or update the playbook in the same change. Do not only edit `~/.config`.

## After changing the live system

If you applied or learned something that is not already in the playbook:

- Update `docs/<topic>.md` with the generic version of the fix
- Put new templates under `config/<topic>/`
- Extend scripts instead of hardcoding one machine’s names
- Mention the playbook in the root [`README.md`](README.md) index

Do not copy the user’s current `monitors.lua` or udev rules into git unless you have replaced identifiers with placeholders.

## Playbook index

| Playbook | Doc | Scripts |
|----------|-----|---------|
| DisplayLink USB graphics on Hyprland | [`docs/displaylink.md`](docs/displaylink.md) | `scripts/displaylink-*.sh` |
| Chromium ad blocker (uBlock Origin Lite) | [`docs/chromium-adblock.md`](docs/chromium-adblock.md) | `scripts/chromium-adblock-*.sh` |
| NVIDIA Resizable BAR | [`docs/nvidia-resizable-bar.md`](docs/nvidia-resizable-bar.md) | `scripts/nvidia-resizable-bar-*.sh` |

## Conventions

- Target **Omarchy** (Arch + Hyprland). Prefer `omarchy pkg add` and `omarchy pkg aur add` over raw `pacman` / `yay`.
- Templates are generic. Scripts bind them to the current machine.
- Hyprland env that must exist *before* the compositor starts (`AQ_*`) goes in `~/.config/uwsm/env-hyprland`, not only `hl.env()` in Lua.
- System files (`/etc/modprobe.d`, `/etc/udev/rules.d`, systemd drop-ins) are installed by scripts with `sudo` in a visible terminal.
- Comments in committed files explain non-obvious constraints, not the author’s machine.

## Out of scope

- Omarchy source development (`/usr/share/omarchy/`, `omarchy dev ...`)
- Secrets, private dotfiles, or a full home-directory dump
- One-off tweaks the user does not want reused (ask if unclear; default to documenting)
