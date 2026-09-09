---
name: omarchy-setup
description: >
  Apply and document reusable Omarchy customizations from this playbook repo
  (DisplayLink/evdi, Hyprland monitors, udev, UWSM AQ_DRM_DEVICES).
  Use when configuring DisplayLink, docks, extra monitors on Hyprland, or when
  the user wants a customization recorded for later. /omarchy-setup
---

# Omarchy setup playbooks

This repository is the source of truth for **repeatable** Omarchy customizations.

1. Read [`AGENTS.md`](../../../AGENTS.md) before editing the repo or the live system.
2. Follow the matching playbook instead of inventing a one-off:

   - DisplayLink USB graphics: [`docs/displaylink.md`](../../../docs/displaylink.md)

3. Prefer the scripts in `scripts/` over copying machine-specific `/etc` files.
4. After a successful live change, update the playbook if the docs were missing a step. Keep committed files generic (no hostnames, serials, emails, home paths, PCI addresses).

Do not dump `~/.config` into git. Templates live under `config/<topic>/`; scripts bind them to the current machine.
