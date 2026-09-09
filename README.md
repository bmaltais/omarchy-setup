# omarchy-setup

Playbooks for customizing [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland) in a way that can be repeated and shared.

Live config stays on the machine (`~/.config/`, `/etc/`). This repo stores **generic** docs, templates, and scripts so you can rebuild a setup without copying personal files.

## Playbooks

| Topic | Guide | Apply |
|-------|-------|--------|
| DisplayLink USB hub / dock on Hyprland | [docs/displaylink.md](docs/displaylink.md) | `scripts/displaylink-detect.sh`, `displaylink-install.sh`, `displaylink-configure.sh` |

## Quick start (DisplayLink)

```bash
git clone https://github.com/<you>/omarchy-setup.git
cd omarchy-setup

./scripts/displaylink-detect.sh
./scripts/displaylink-install.sh
./scripts/displaylink-configure.sh --apply-monitors
```

Plug the hub into a **USB 3 / SuperSpeed** port, then reboot with it attached. Full notes, limits, and undo steps are in the DisplayLink guide.

After a kernel or Omarchy update:

```bash
./scripts/displaylink-rebuild.sh
```

## Adding another customization

1. Copy [docs/playbook-template.md](docs/playbook-template.md) to `docs/<topic>.md`
2. Add generic templates under `config/<topic>/` and scripts under `scripts/`
3. Link it from this README and from [AGENTS.md](AGENTS.md)

Agents working in this repo should read [AGENTS.md](AGENTS.md) first. That file is the rulebook for keeping playbooks public-safe.

## Publish to GitHub

```bash
gh auth login
cd omarchy-setup
gh repo create omarchy-setup --public --source=. --remote=origin --push
```

Then replace `<you>` in clone URLs with your GitHub user or org.

## License

MIT. See [LICENSE](LICENSE).
