# Playbook: Start apps and Oma Cast

Install a set of Omarchy shell plugins and the StartFS daemon so a fresh machine gets a Windows-style taskbar, an AppImage manager, the StartFS cluster filesystem with its GUI, and the Oma Cast launcher, plus the ArtCraft Launcher installed through StartAppImage.

| Piece | What it is | Source |
|-------|------------|--------|
| StartBar | Taskbar and Start menu plugin | `github.com/bmaltais/StartBar` |
| StartAppImage | Installs and manages AppImages (double-click install card) | `github.com/bmaltais/StartAppImage` |
| StartFS | Tailscale-based filesystem daemon, mounted at `~/StartFS` | `github.com/bmaltais/StartFS` (release installer) |
| StartFSGUI | Plugin for StartFS: node list, health, upgrades | `github.com/bmaltais/StartFSGUI` |
| Oma Cast | Command launcher plugin (third party) | `github.com/typecraft-dev/oma-cast` |
| ArtCraft Launcher | Third-party AppImage, installed through StartAppImage | `github.com/storytold/craft-launcher` (GitHub release) |

## Assumptions

- Omarchy 4 (Arch + Hyprland, `omarchy-shell`) with `omarchy plugin`
- Network access to GitHub; a Tailscale account for StartFS
- sudo in a visible terminal (package installs)

## Live paths this playbook changes

| Path | Role |
|------|------|
| `~/.config/omarchy/plugins/`, `shell.json` | Plugins added and enabled by `omarchy plugin add` |
| `~/.local/bin/startfs` | StartFS binary (installer) |
| `~/.config/systemd/user/startfs.service` | Daemon that mounts `~/StartFS` |
| `~/.local/share/oma-cast` | Oma Cast clone (the plugin is linked from here; keep it) |
| `~/.local/bin/oma-cast` | Oma Cast CLI link |
| `~/.config/hypr/` | Only with `--bind-oma-cast` (keybinding) |

Packages: `squashfs-tools` (StartAppImage cannot read AppImages without `unsquashfs`), `fuse3` and `tailscale` (StartFS). Installed with `omarchy pkg add`.

## Quick install

```bash
./scripts/start-apps-status.sh
./scripts/start-apps-install.sh
```

## 1. Detect

```bash
./scripts/start-apps-status.sh
```

Each plugin shows `enabled`, `disabled` or `missing`.

## 2. Install

```bash
./scripts/start-apps-install.sh
```

The script is safe to rerun: plugins already present are skipped, `startfs` is only fetched if missing, and the Oma Cast clone is fast-forwarded.

The StartFS step pipes the project's `install.sh` from its `main` branch into `sh`. Read it first if you want to; it checks the release checksum itself. Pin a release with `STARTFS_VERSION=vX.Y.Z`, or use `STARTFS_NO_SERVICE=1` to install without starting the service.

ArtCraft Launcher is installed last with `startappimage add github:storytold/craft-launcher`. The AppImage lives in the repo `craft-launcher`; the main `storytold/artcraft` repo only releases macOS and Windows installers, so `github:storytold/artcraft` does not resolve. `github:` sources are what StartAppImage's `update` follows, so the launcher updates with the rest. The step needs the `startappimage` command, which StartAppImage's **Command line** setting links into `~/.local/bin`; if it is off the script skips the launcher and says so.

Oma Cast's Hyprland keybinding is opt-in because it edits `~/.config/hypr/`. Back that up, then:

```bash
./scripts/start-apps-install.sh --bind-oma-cast
```

## 3. Configure

Left manual on purpose because they are per-machine or per-account:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
systemctl --user status startfs
```

Joining another machine to the StartFS cluster is done from StartFSGUI ("Invite a node...").

StartAppImage opens its settings window once after the shell loads and offers to enable its launcher entry, `.AppImage` file association and CLI. Choose there.

## 4. Verify

```bash
./scripts/start-apps-status.sh
```

Expect the four plugins `enabled`, `startfs` with a version, and `startfs service: active` once Tailscale is up. The taskbar appears on every monitor after the shell reloads.

## After updates

- `startappimage update` updates ArtCraft Launcher (and any other GitHub-sourced AppImage).
- `omarchy plugin update` updates the git-managed plugins (StartBar, StartAppImage, StartFSGUI). Oma Cast is updated by rerunning the install script.
- `startfs update` upgrades the daemon on every node, or use the StartFS window in StartFSGUI.
- StartFSGUI follows StartFS 1.10 or later; an older daemon only shows basic status.
- A kernel update does not affect any of this.

## Undo

```bash
omarchy plugin remove io.github.bmaltais.startbar
omarchy plugin remove io.github.bmaltais.startappimage
omarchy plugin remove io.github.bmaltais.startfsgui
systemctl --user disable --now startfs
rm -f ~/.local/bin/startfs ~/.config/systemd/user/startfs.service
oma-cast uninstall
rm -rf ~/.local/share/oma-cast
startappimage remove artcraft-launcher
```

Removing the packages is separate (`omarchy pkg remove`); `fuse3` and `tailscale` may be used by other things. Data in `~/StartFS` is not deleted by any of this.

## References

- [StartBar](https://github.com/bmaltais/StartBar), [StartAppImage](https://github.com/bmaltais/StartAppImage), [StartFS](https://github.com/bmaltais/StartFS), [StartFSGUI](https://github.com/bmaltais/StartFSGUI)
- [Oma Cast](https://github.com/typecraft-dev/oma-cast)
