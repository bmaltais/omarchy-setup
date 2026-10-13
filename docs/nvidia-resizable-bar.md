# Playbook: NVIDIA Resizable BAR (fixes Chromium-family renderer crashes)

Turn on Resizable BAR for an NVIDIA GPU so Chromium, Edge and VS Code stop aborting when they map video buffers. Without it, the GPU exposes only a 256MB VRAM aperture, which fills up and then fails.

## Symptom

A browser renderer dies with `SIGILL` while playing video. The kernel log has, one second earlier:

```
NVRM: dmaAllocMapping_GM107: can't alloc VA space for mapping
NVRM: Out of memory [NV_ERR_NO_MEMORY]
nvidia-drm: Failed to map NvKmsKapiMemory
```

The `SIGILL` is deliberate. Chromium's `client_native_pixmap_dmabuf.cc` gets `ENOMEM` from `mmap` on a GPU dma-buf and executes `ud2`. The machine is not out of RAM.

Confirm the cause:

```bash
./scripts/nvidia-resizable-bar-status.sh
```

`BAR 1: 256M` plus `EnableResizableBar: 0` means this playbook applies.

## Assumptions

- Omarchy (Arch + Hyprland), NVIDIA proprietary driver, UEFI boot via Limine and a UKI
- A GPU that supports Resizable BAR (RTX 30-series or newer; `lspci -vv` shows a `Resizable BAR` capability)
- A CPU/board whose firmware has **Above 4G Decoding** and **Re-Size BAR Support** (tested on an AMD A520 board; BAR 1 went from 256M to 32G on an RTX 3090)

## Live paths this playbook changes

| Path | Role |
|------|------|
| Motherboard BIOS | Above 4G Decoding, Re-Size BAR Support (stored in NVRAM, not on disk) |
| `/etc/modprobe.d/nvidia-resizable-bar.conf` | `NVreg_EnableResizableBar=1` |
| `/boot/EFI/Linux/omarchy_linux.efi` | UKI rebuilt by `limine-update` so the option is in the initramfs |

Template: [`config/nvidia-resizable-bar/`](../config/nvidia-resizable-bar/).

## 1. Detect

```bash
./scripts/nvidia-resizable-bar-status.sh
```

## 2. BIOS (manual, once per board)

Reboot into the BIOS (Del or F2). In Advanced Mode (F7):

- Advanced → PCI Subsystem Settings: **Above 4G Decoding** = Enabled
- **Re-Size BAR Support** = Enabled (hidden until Above 4G Decoding is on)
- Boot → CSM: **Launch CSM** = Disabled (the system must boot UEFI)

If the options are missing, check for a newer BIOS.

Boot, then run the status script. BAR 1 should now be several GiB (32G on a 24GB RTX 3090), not 256M. If it is still 256M, the firmware option did not take. Setting the driver option without this step does nothing.

## 3. Install

```bash
./scripts/nvidia-resizable-bar-install.sh
```

It writes the modprobe drop-in and runs `sudo limine-update`. NVIDIA loads from the initramfs, so editing `/etc/modprobe.d` alone is not enough; the UKI has to be rebuilt. The script skips itself if the option is already set anywhere in `/etc/modprobe.d/`.

Reboot.

## 4. Verify

```bash
./scripts/nvidia-resizable-bar-status.sh
```

Wanted: BAR 1 resized, `EnableResizableBar: 1`, modprobe option present. Play a video in the browser; the NVRM errors should be gone from `journalctl -k`.

## Until it is on (workaround)

Disabling graphics acceleration stops the dma-buf mapping:

- Edge and Chromium: Settings → System → "Use graphics acceleration when available" → off, restart
- VS Code: Command Palette → "Preferences: Configure Runtime Arguments" → `"disable-hardware-acceleration": true`

Hyprland still maps through the 256MB window, so the desktop can still freeze until a reboot.

## Undo

```bash
sudo rm /etc/modprobe.d/nvidia-resizable-bar.conf
sudo limine-update
```

If you added the option to `/etc/modprobe.d/nvidia.conf` by hand, remove that line instead. Reboot. The BIOS settings can stay on.

## After updates / reinstall

- Kernel or driver updates: nothing to redo. The drop-in stays in `/etc/modprobe.d` and gets baked into each rebuilt UKI. `limine-update` rebuilds one per installed kernel, and I confirmed the option lands in the image of the running kernel.
- **Reinstalling Omarchy:** the modprobe drop-in lives on the root filesystem and is wiped. Rerun the install script. As far as I know the Omarchy installer only sets `options nvidia_drm modeset=1`.
- The BIOS settings survive a reinstall. A BIOS reset to defaults or a CMOS clear turns them off; redo step 2.
