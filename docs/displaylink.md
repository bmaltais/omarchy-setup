# Playbook: DisplayLink on Omarchy (Hyprland)

Use a DisplayLink USB hub or dock as extra monitors on Omarchy. A DisplayLink device is **not** a normal USB-C / DP-alt-mode dock: it needs the **evdi** kernel module plus the **displaylink** userspace driver. Support on Linux is experimental. Expect more lag and CPU use than a native HDMI, DisplayPort, or Thunderbolt connection.

Prefer native GPU ports when you can. Use this playbook when the extra screens only exist on a DisplayLink hub.

**Status:** works on NVIDIA with a patched Aquamarine (see [NVIDIA + evdi](#nvidia--evdi)); verified with a Plugable UD-3900PDZ on an RTX 3090, Hyprland 0.56, Aquamarine 0.15.1, evdi 1.15.1, `displaylink` 6.4. AMD and Intel are expected to work with stock Aquamarine but are untested here.

## Assumptions

- Omarchy (Arch + Hyprland / Wayland)
- Matching kernel headers for the running kernel (DKMS)
- Hub vendor ID `17e9` (DisplayLink / Synaptics)
- USB **3 SuperSpeed** for usable video (1080p@60 is a reasonable target)

## Live paths this playbook changes

| Path | Role |
|------|------|
| `~/.config/hypr/monitors.lua` | Only with `--apply-monitors`: appends lines for evdi outputs it does not mention yet (backup first, rolled back on config errors) |
| `~/.config/uwsm/env-hyprland` | A marked block that resolves `AQ_DRM_DEVICES` at login, plus NVIDIA multi-GPU workarounds (must exist before Hyprland starts). The previous file is backed up before the block is replaced |
| `/etc/modprobe.d/evdi.conf` | `initial_device_count` so evdi cards exist at login |
| `/etc/modules-load.d/evdi.conf` | Load `evdi` at boot |
| `/etc/udev/rules.d/99-drm-stable-names.rules` | Stable `/dev/dri/nvidia-gpu`, `/dev/dri/evdi0`, … (generated; not committed) |
| `/etc/systemd/system/displaylink.service.d/early.conf` | Start DisplayLink after modules load |
| `displaylink.service` | Enabled |

Templates for the generic files are in [`config/displaylink/`](../config/displaylink/).

## 1. Detect

Confirm it is DisplayLink, not a driverless USB-C dock:

```bash
./scripts/displaylink-detect.sh
```

You want:

1. `lsusb` shows vendor `17e9`
2. `uname -r` matches an installed `*-headers` package
3. After install: `evdi` loaded and `displaylink.service` active
4. Extra DRM nodes `platform-evdi.*` under `/dev/dri/by-path/`
5. `hyprctl monitors` lists extra outputs (`DVI-I-1`, `DVI-I-2`, or extra `DP-*` / `HDMI-*`)

USB speed matters for *smoothness*, not for whether a picture can exist at all. DisplayLink compresses frames. One 1080p@60 screen can run on USB 2 (`480M`); two screens will feel laggy. Plug the hub into a USB 3 / USB-C SuperSpeed port with a SuperSpeed cable when you can:

```bash
lsusb -t | grep -A2 -i displaylink
```

You want `5000M` or `10000M`. Keyboard and Ethernet on the hub can work on USB 2 while the SuperSpeed video function never enumerates.

If `hyprctl monitors` lists DisplayLink outputs at `0x0` with `enabled=disabled` in sysfs, that is a **modeset / buffer-import failure**, not a bandwidth failure. USB 2 is not why the screen stays black.

To paste detect output into a public issue, run `./scripts/displaylink-detect.sh --sanitize`.

## 2. Install

```bash
./scripts/displaylink-install.sh
```

What it does:

- Installs `dkms`, `usbutils`, and headers for the **running** kernel
- Builds `evdi-dkms` and `displaylink` from the AUR via `omarchy pkg aur add`
- Enables and starts `displaylink.service`

On a very new kernel, `evdi-dkms` may fail to compile. Then try `evdi-dkms-git` (check that it is actually newer than `evdi-dkms` first; it is not always).

Xorg snippets from the Arch wiki are **not** required on Wayland. Hyprland talks to evdi DRM nodes directly.

## 3. Configure

```bash
./scripts/displaylink-configure.sh
```

Options:

- `--apply-monitors` appends `hl.monitor` lines for evdi outputs that `monitors.lua` does not mention yet, placed to the right of the existing layout at `1920x1080@60`, scale 1. Existing lines are never rewritten, so your scales, rotations, comments and `disabled = true` lines stay. It backs the file up first, runs `hyprctl reload`, and **restores the backup and exits 1** if `hyprctl configerrors` reports anything.
- `--no-modifiers` also exports `AQ_NO_MODIFIERS=1`. Off by default and not needed with the patched Aquamarine; kept only for experiments.

Without `--apply-monitors`, the script still installs udev, modprobe, systemd and the UWSM env block, and prints the lines it would add.

### Hyprland layout

List names:

```bash
hyprctl monitors
```

DisplayLink outputs are often `DVI-I-1` / `DVI-I-2`. Native GPU outputs keep their usual `DP-*` / `HDMI-*` / `eDP-*` names.

Positions use **scaled** resolution. Keep DisplayLink at **1080p or 1440p @ 60 Hz**. evdi frequently rejects high pixel clocks (120 Hz 1080p, 4K@60 on two screens).

Example (one native panel + two DisplayLink screens), also in [`config/displaylink/monitors.lua.example`](../config/displaylink/monitors.lua.example):

```lua
hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "DVI-I-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })
hl.monitor({ output = "DVI-I-2", mode = "1920x1080@60", position = "3840x0", scale = 1 })
```

Replace output names with whatever `hyprctl monitors` shows. After saving:

```bash
hyprctl reload
hyprctl configerrors
```

`AQ_*` changes in `~/.config/uwsm/env-hyprland` and the evdi udev symlinks need a **new Hyprland session** (log out / reboot), not only `hyprctl reload`.

Lid-closed + externals-only on a laptop is already an Omarchy feature (`Super + Ctrl + Delete`, or close the lid with externals connected). This playbook does not replace that.

### Multi-GPU: `AQ_DRM_DEVICES`

Hyprland must render on the real GPU and scan out on evdi. If `AQ_DRM_DEVICES` is unset, an evdi card can become primary after reboot (`/dev/dri/card0` is not stable).

The configure script:

- Writes udev rules so the discrete GPU is `/dev/dri/nvidia-gpu` (or `amd-gpu` / `intel-gpu`) and evdi cards are `/dev/dri/evdi0`, `/dev/dri/evdi1`. If no GPU can be detected it skips the GPU rule instead of guessing.
- Installs the block from [`config/displaylink/env-hyprland.example`](../config/displaylink/env-hyprland.example). It picks the GPU **at login**: the udev symlink if present, else the first PCI card whose driver is not `evdi`. It lists `evdi0`/`evdi1` only if they exist, and leaves `AQ_DRM_DEVICES` unset if no GPU is found. A fixed list pointing at devices that are not there (hub unplugged, module not loaded) must never be what Hyprland starts with.
- On NVIDIA also sets `AQ_FORCE_LINEAR_BLIT=0` and `AQ_MGPU_NO_EXPLICIT=1`.

### NVIDIA + evdi

On NVIDIA, stock Aquamarine cannot drive evdi outputs. Symptoms: the output is listed by `hyprctl monitors` with the mode you asked for, `/sys/class/drm/card*-DVI-I-*/enabled` stays `disabled`, the screen shows no signal, and the log has:

```text
ERR from aquamarine ]: drm: drmPrimeFDToHandle failed
ERR from aquamarine ]: drm: Buffer failed to import to KMS
```

**Cause.** evdi has no render device, and NVIDIA's dmabuf exporter refuses `dma_buf_attach` from foreign drivers, so the primary GPU's buffer cannot be imported into evdi. `AQ_NO_MODIFIERS=1` does not fix this and can grey out the native outputs, so it is **not** set by default.

**Fix.** [hyprwm/aquamarine#279](https://github.com/hyprwm/aquamarine/pull/279) adds a last-resort CPU-copy path (the same approach KWin and Mutter use): when the direct import fails on evdi, the frame is read back and written into a dumb buffer. It is not merged upstream yet. This repo carries it, adapted to Aquamarine 0.15.1, as [`config/displaylink/aquamarine-evdi-nvidia.patch`](../config/displaylink/aquamarine-evdi-nvidia.patch) (three changes on top of the PR: write the blit fence into the commit snapshot, the `OPTIONS.length == 0` swapchain guard, and no queued/timed commits for evdi).

```bash
./scripts/displaylink-aquamarine-patch.sh
```

It builds Arch's `aquamarine` package with the patch (version `<ver>-1.1`, so it sorts above the stock `<ver>-1`) and installs it with `pacman -U`. `--build-only` builds without installing. Log out and back in afterwards. A working session logs `direct KMS import of primary buffer failed … switching to dumb-buffer CPU copy`.

Things to know:

- **It does not survive an Aquamarine update by itself.** A newer package from Arch/Omarchy replaces it and the heads go back to no signal. Install the update hook once:

  ```bash
  ./scripts/displaylink-aquamarine-patch.sh --install-hook
  ```

  After every `omarchy update`, the hook runs `--ensure`. That does nothing unless `displaylink` is installed, NVIDIA is in use and the installed `libaquamarine` lacks the fix (`--status` prints `patched` or `stock`). If it lacks the fix, it rebuilds against the new Arch version, checks that the built package really carries the fix, installs it, and sends a notification asking you to log out. If the patch no longer applies, or the build fails, you get a notification instead, and the system package is left alone (screens stay at no signal until the patch is updated). Use `--remove-hook` to uninstall the hook. The hook file is generated per machine with this repo's path; it is not committed.
- **When upstream merges #279**, the stock library will carry the fix and `--ensure` becomes a no-op on its own. If the merged code logs a different message than the marker the script greps for, `--ensure` will try to rebuild, find the patch no longer applies, and say upstream's state in the notification. At that point run `--remove-hook` and stop using this patch.
- **Do not `IgnorePkg` it.** Hyprland and Aquamarine are versioned together; holding Aquamarine back breaks Hyprland updates.
- **It costs CPU.** Every frame for the evdi screen is read back and copied. A tester measured about 16–20% of one core while content changes, on a small panel; a 1080p screen costs more. Measure it on your hardware.
- `Cannot commit when a page-flip is awaiting` lines in the Hyprland log are common and have not caused visible problems.
- **Undo:** `sudo pacman -S aquamarine` reinstalls the stock package.

AMD and Intel primaries do not need the patch.

Do **not** put PCI `by-path` names in `AQ_DRM_DEVICES` (they contain colons, and Aquamarine splits the variable on `:`). Use the udev symlinks instead.

## 4. Verify

Reboot with the hub already plugged in, then:

```bash
./scripts/displaylink-detect.sh
hyprctl monitors
```

Success looks like:

- `displaylink.service` is `active`
- `lsmod` contains `evdi`
- Extra outputs are **not** `0x0` — they show a real mode such as `1920x1080@60`
- `/sys/class/drm/card*-DVI-I-*/enabled` is `enabled` for connected DisplayLink connectors

If an output looks healthy (real mode in `hyprctl monitors`, `enabled` in `/sys/class/drm/card*-*/enabled`, a `Modesetting … with 1920x1080@60` line in the Hyprland log) but the screen says "no signal", **check the monitor's input source and the cabling first**. A monitor that is also wired to another machine or GPU, or daisy-chained from another monitor, stays on its other input. This looks identical to a driver failure. Pressing the monitor's input button, or unplugging one cable at a time while watching `/sys/class/drm/card*-*/status`, tells you which dock port feeds which output.

Docks like the Plugable UD-3900PDZ have three HDMI ports: the first is USB-C DisplayPort alt mode (needs a USB-C port that carries DisplayPort; it never works behind a USB-A link), the other two are DisplayLink and appear as `DVI-I-1` / `DVI-I-2`. Two outputs with byte-identical EDIDs usually mean two identical monitors, not a fault.

If `hyprctl monitors` still only shows the internal / native panel:

- Unplug/replug the hub
- `sudo systemctl restart displaylink.service`
- Reboot **with the hub connected**
- `sudo dmesg | grep -iE 'evdi|displaylink|17e9'`

Without the udev symlinks (the configure step) `AQ_DRM_DEVICES` lists only the GPU and Aquamarine ignores evdi entirely, so run configure and start a new session. Some sessions only pick up evdi outputs when the compositor starts with the dock already attached. Hyprland/aquamarine evdi support is unofficial.

## Test it safely

Before running configure for real, on any machine:

1. **Dry run.** Runs the configure script against throwaway copies of your `monitors.lua` and `env-hyprland`, with `sudo` and `hyprctl reload` stubbed, and prints the diff. Nothing is installed or reloaded.

   ```bash
   ./scripts/displaylink-dryrun.sh --apply-monitors
   ./scripts/displaylink-dryrun.sh --fake-evdi --apply-monitors   # pretend DVI-I-1/2 exist
   DRYRUN_CONFIGERRORS="oops" ./scripts/displaylink-dryrun.sh --fake-evdi --apply-monitors   # exercise the rollback
   ```

2. **Check that evdi builds for your kernel**, without installing it. Download the release the AUR package points at, then:

   ```bash
   make -C /usr/lib/modules/$(uname -r)/build M=$PWD/module modules
   ```

3. **Snapshot first.** `omarchy snapshot create` (snapper) before the real run.
4. **Test without the hub.** `initial_device_count=2` creates virtual evdi cards even with nothing plugged in, so after the real install you can check the udev symlinks, the `AQ_DRM_DEVICES` value (`echo $AQ_DRM_DEVICES` in a new session) and that Hyprland still starts, from a second TTY with the snapshot ready.
5. Only real hardware proves the buffer import. A VM with a virtual GPU can test everything except that.

`Hyprland --verify-config` is not a reliable check here (it can crash even on a valid config); use `hyprctl reload` and `hyprctl configerrors` instead.

## After kernel or Omarchy updates

evdi is DKMS. A new kernel often needs a rebuild:

```bash
./scripts/displaylink-rebuild.sh
```

That runs `dkms autoinstall` and restarts `displaylink.service`. On NVIDIA also rerun `./scripts/displaylink-aquamarine-patch.sh` whenever `aquamarine` was updated. If the module fails to build, wait for a newer `evdi-dkms` or switch to `evdi-dkms-git` if it tracks a newer tree.

## Undo

```bash
sudo systemctl disable --now displaylink.service
sudo rm -f /etc/modprobe.d/evdi.conf \
           /etc/modules-load.d/evdi.conf \
           /etc/udev/rules.d/99-drm-stable-names.rules
sudo rm -rf /etc/systemd/system/displaylink.service.d
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=drm
```

Remove the `# BEGIN omarchy-setup displaylink` … `# END` block from `~/.config/uwsm/env-hyprland` if present (or restore the `env-hyprland.bak.*` the script made). Remove the lines under `-- Added by omarchy-setup displaylink-configure.sh` from `~/.config/hypr/monitors.lua`, or restore the `monitors.lua.bak.*` backup, or run `omarchy refresh hyprland` only if you intend to reset **all** Hyprland user Lua (ask first).

Packages (optional):

```bash
omarchy pkg drop displaylink evdi-dkms
sudo pacman -S aquamarine   # only if the patched build was installed
```

## Why the same hub can work on Windows and fail on Omarchy

This is expected. It is not proof that the cable is fine on Linux, and it is not proof that Linux “should just work.”

- Plugable and Synaptics ship a **first-party Windows driver**. Linux uses the community `evdi` kernel module plus a userspace binary. Many docks (including the Plugable UD-3900PDZ) list Windows / macOS / ChromeOS and **not Linux**.
- Windows does not go through Hyprland, Aquamarine, or NVIDIA GBM buffer import. On NVIDIA + Wayland the usual Linux failure is `drmPrimeFDToHandle failed` / outputs stuck at `0x0`, even when `displaylink.service` is healthy.
- DisplayLink **can** draw a picture over USB 2. Windows will do that. USB 2 only makes the desktop laggy; it does not by itself keep the screen black.
- Hybrid USB-C docks often have **one native DP-alt-mode** HDMI and **two DisplayLink** HDMIs. Alt-mode needs a USB-C port that carries DisplayPort. A USB-A desktop port never provides that, on any OS. Those extra screens are DisplayLink-only.

`AQ_*` workarounds in `~/.config/uwsm/env-hyprland` apply only after a new Hyprland session (log out or reboot), not after `hyprctl reload`.

## Practical limits

- DisplayLink compresses frames over USB. Two 4K@60 screens will tax the CPU and often feel laggy.
- Start at 1080p or 1440p @ 60 Hz. USB 2 (`480M`) can still show one 1080p screen; prefer SuperSpeed.
- Hybrid GPU laptops: keep `AQ_DRM_DEVICES` pointed at the GPU Hyprland should render on, and still include the evdi cards so those outputs exist.
- A catch-all `hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })` can pick a useless last EDID mode (for example `720x400`) on evdi. Prefer explicit names and modes.

## References

- [ArchWiki: DisplayLink](https://wiki.archlinux.org/title/DisplayLink)
- [Hyprland: Multi-GPU / `AQ_DRM_DEVICES`](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Multi-GPU/)
- [Hyprland: monitors](https://wiki.hypr.land/Configuring/Basics/Monitors/)
- AUR: [evdi-dkms](https://aur.archlinux.org/packages/evdi-dkms), [displaylink](https://aur.archlinux.org/packages/displaylink)
