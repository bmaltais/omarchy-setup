# Playbook: DisplayLink on Omarchy (Hyprland)

Use a DisplayLink USB hub or dock as extra monitors on Omarchy. A DisplayLink device is **not** a normal USB-C / DP-alt-mode dock: it needs the **evdi** kernel module plus the **displaylink** userspace driver. Support on Linux is experimental. Expect more lag and CPU use than a native HDMI, DisplayPort, or Thunderbolt connection.

Prefer native GPU ports when you can. Use this playbook when the extra screens only exist on a DisplayLink hub.

## Assumptions

- Omarchy (Arch + Hyprland / Wayland)
- Matching kernel headers for the running kernel (DKMS)
- Hub vendor ID `17e9` (DisplayLink / Synaptics)
- USB **3 SuperSpeed** for usable video (1080p@60 is a reasonable target)

## Live paths this playbook changes

| Path | Role |
|------|------|
| `~/.config/hypr/monitors.lua` | Output names, mode, position, scale |
| `~/.config/uwsm/env-hyprland` | `AQ_DRM_DEVICES` and NVIDIA/evdi workarounds (must exist before Hyprland starts) |
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

Add `--apply-monitors` to write a left-to-right `monitors.lua` from currently connected outputs (backs up the existing file first). Without that flag, the script still installs udev, modprobe, systemd, and UWSM env, and prints a suggested `monitors.lua`.

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

`AQ_*` changes in `~/.config/uwsm/env-hyprland` need a **new Hyprland session** (log out / reboot), not only `hyprctl reload`.

Lid-closed + externals-only on a laptop is already an Omarchy feature (`Super + Ctrl + Delete`, or close the lid with externals connected). This playbook does not replace that.

### NVIDIA + evdi

Hyprland must render on the real GPU and scan out on evdi. If `AQ_DRM_DEVICES` is unset, an evdi card can become primary after reboot (`/dev/dri/card0` is not stable).

The configure script:

- Writes udev rules so the discrete GPU is `/dev/dri/nvidia-gpu` (or `amd-gpu` / `intel-gpu`) and evdi cards are `/dev/dri/evdi0`, `/dev/dri/evdi1`
- Exports `AQ_DRM_DEVICES` with the GPU first, then evdi
- On NVIDIA, also sets `AQ_NO_MODIFIERS=1` and `AQ_MGPU_NO_EXPLICIT=1`

Without the NVIDIA workarounds, Hyprland logs look like:

```text
ERR from aquamarine ]: drm: drmPrimeFDToHandle failed
ERR from aquamarine ]: drm: Buffer failed to import to KMS
ERR from aquamarine ]: GBM: Allocating with modifiers failed, falling back to implicit
```

Outputs then show up in `hyprctl monitors` at `0x0` and never modeset.

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

If `hyprctl monitors` still only shows the internal / native panel:

- Unplug/replug the hub
- `sudo systemctl restart displaylink.service`
- Reboot **with the hub connected**
- `sudo dmesg | grep -iE 'evdi|displaylink|17e9'`

Some sessions only pick up evdi outputs when the compositor starts with the dock already attached. Hyprland/aquamarine evdi support is unofficial.

## After kernel or Omarchy updates

evdi is DKMS. A new kernel often needs a rebuild:

```bash
./scripts/displaylink-rebuild.sh
```

That runs `dkms autoinstall` and restarts `displaylink.service`. If the module fails to build, wait for a newer `evdi-dkms` or switch to `evdi-dkms-git` if it tracks a newer tree.

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

Remove the `# BEGIN omarchy-setup displaylink` block from `~/.config/uwsm/env-hyprland` if present. Restore `~/.config/hypr/monitors.lua` from the backup the configure script created, or run `omarchy refresh hyprland` only if you intend to reset **all** Hyprland user Lua (ask first).

Packages (optional):

```bash
omarchy pkg drop displaylink evdi-dkms
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
