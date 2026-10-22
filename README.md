# omarchy-setup

Playbooks for customizing [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland) in a way that can be repeated and shared.

Live config stays on the machine (`~/.config/`, `/etc/`). This repo stores **generic** docs, templates, and scripts so you can rebuild a setup without copying personal files.

## Playbooks

| Topic | Guide | Apply |
|-------|-------|--------|
| DisplayLink USB hub / dock on Hyprland | [docs/displaylink.md](docs/displaylink.md) | `scripts/displaylink-detect.sh`, `displaylink-install.sh`, `displaylink-configure.sh` |
| Chromium ad blocker (uBlock Origin Lite) | [docs/chromium-adblock.md](docs/chromium-adblock.md) | `scripts/chromium-adblock-install.sh` |
| NVIDIA Resizable BAR (browser crashes on video) | [docs/nvidia-resizable-bar.md](docs/nvidia-resizable-bar.md) | `scripts/nvidia-resizable-bar-install.sh` |
| Shared Cargo build cache (mr-boxington via mise) | [docs/mr-boxington.md](docs/mr-boxington.md) | `scripts/mr-boxington-install.sh` |
| Start apps (StartBar, StartAppImage, StartFS, StartFSGUI), Oma Cast and ArtCraft Launcher | [docs/start-apps.md](docs/start-apps.md) | `scripts/start-apps-*.sh` |

## Quick start (Chromium ad blocker)

```bash
git clone https://github.com/bmaltais/omarchy-setup.git
cd omarchy-setup

./scripts/chromium-adblock-install.sh
```

Quit Chromium fully and open it again. Reload YouTube if a tab was already open. Details, Complete-mode notes, and undo: [docs/chromium-adblock.md](docs/chromium-adblock.md).

```bash
./scripts/chromium-adblock-status.sh
```

## Quick start (DisplayLink)

```bash
git clone https://github.com/bmaltais/omarchy-setup.git
cd omarchy-setup

./scripts/displaylink-detect.sh
./scripts/displaylink-install.sh
./scripts/displaylink-dryrun.sh --apply-monitors   # optional: preview what configure would change
./scripts/displaylink-configure.sh --apply-monitors
./scripts/displaylink-aquamarine-patch.sh   # NVIDIA only: stock Aquamarine cannot drive evdi outputs
```

Plug the hub into a **USB 3 / SuperSpeed** port, then reboot with it attached. Full notes, limits, and undo steps are in the DisplayLink guide.

After a kernel or Omarchy update:

```bash
./scripts/displaylink-rebuild.sh
```

## Quick start (NVIDIA Resizable BAR)

Enable **Above 4G Decoding** and **Re-Size BAR Support** in the BIOS first, then:

```bash
./scripts/nvidia-resizable-bar-status.sh
./scripts/nvidia-resizable-bar-install.sh
```

Reboot. Re-run the install script after any Omarchy reinstall. Details: [docs/nvidia-resizable-bar.md](docs/nvidia-resizable-bar.md).

## Adding another customization

1. Copy [docs/playbook-template.md](docs/playbook-template.md) to `docs/<topic>.md`
2. Add generic templates under `config/<topic>/` and scripts under `scripts/`
3. Link it from this README and from [AGENTS.md](AGENTS.md)

Agents working in this repo should read [AGENTS.md](AGENTS.md) first. That file is the rulebook for keeping playbooks public-safe.

## Publish your own fork

```bash
gh repo fork bmaltais/omarchy-setup --clone
```

Or copy the tree into a new repo and point the clone URL at your account.

## License

MIT. See [LICENSE](LICENSE).
