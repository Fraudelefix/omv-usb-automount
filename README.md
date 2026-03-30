# OMV-USB-Automount

Automount USB storage devices on an OpenMediaVault host without adding them to the OMV Web UI.

This repository started as a short how-to. It now ships the scripts and udev rules directly so the setup is versioned, reviewable, and easier to maintain.

## What it does

- Mounts USB partitions under `/media/usbdevices/<label-or-uuid>` when they are plugged in
- Unmounts them automatically when they are removed
- Logs mount activity to `/var/log/usb_mount.log`
- Avoids deleting unexpected paths during cleanup
- Handles duplicate labels by creating unique mount directories

Mounted drives remain outside OMV's managed filesystems, so they will not appear in the OMV storage UI.

## Repository layout

```text
.
|-- install.sh
|-- uninstall.sh
|-- scripts/
|   |-- mount_usb.sh
|   |-- queue_usb_event.sh
|   `-- unmount_usb.sh
`-- udev/
    `-- 99-omv-usb-automount.rules
```

## Installation

Clone the repository on your OMV host, then run:

```bash
sudo ./install.sh
```

The installer copies:

- `scripts/mount_usb.sh` to `/usr/local/bin/mount_usb.sh`
- `scripts/unmount_usb.sh` to `/usr/local/bin/unmount_usb.sh`
- `scripts/queue_usb_event.sh` to `/usr/local/bin/queue_usb_event.sh`
- `udev/99-omv-usb-automount.rules` to `/etc/udev/rules.d/99-omv-usb-automount.rules`

It also reloads udev rules.

After installation, unplug and reconnect a USB drive to trigger the new flow.

## How it works

`udev` detects USB partition add and remove events.

On add:

- `queue_usb_event.sh` hands the job off to `systemd-run`
- `mount_usb.sh` waits for the block device to become ready
- the script derives a mount directory name from the filesystem label, partition label, UUID, or device name
- `systemd-mount` mounts the device under `/media/usbdevices`
- the chosen mount point is recorded under `/run/omv-usb-automount`

On remove:

- `queue_usb_event.sh` launches the unmount helper
- `unmount_usb.sh` reads the recorded mount point
- the device is unmounted
- the mount directory is removed only if it is inside `/media/usbdevices`

## Manual verification

After plugging in a USB drive:

```bash
findmnt /media/usbdevices
tail -f /var/log/usb_mount.log
```

To inspect the installed udev rule:

```bash
sudo udevadm test /sys/class/block/sdX/sdX1
```

Replace `sdX1` with the real block device path from your system.

## Uninstall

```bash
sudo ./uninstall.sh
```

This removes the installed scripts and udev rule, then reloads udev rules.

## Notes

- The udev rule targets USB partitions that look like `/dev/sdX1`, `/dev/sdb2`, and so on.
- If two devices share the same label, the second one gets a suffixed mount directory such as `backup-2`.
- This project does not create OMV shared folders automatically.
- A future OMV plugin could provide deeper integration, but this repo is intentionally lightweight.
