#!/bin/bash

set -euo pipefail

INSTALL="/usr/bin/install"
UDEVADM="/usr/bin/udevadm"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
RULES_DIR="${RULES_DIR:-/etc/udev/rules.d}"

require_root() {
    if [ "${EUID}" -ne 0 ]; then
        echo "Please run this installer as root." >&2
        exit 1
    fi
}

main() {
    require_root

    "$INSTALL" -d "$BIN_DIR" "$RULES_DIR"
    "$INSTALL" -m 0755 "$REPO_ROOT/scripts/mount_usb.sh" "$BIN_DIR/mount_usb.sh"
    "$INSTALL" -m 0755 "$REPO_ROOT/scripts/unmount_usb.sh" "$BIN_DIR/unmount_usb.sh"
    "$INSTALL" -m 0755 "$REPO_ROOT/scripts/queue_usb_event.sh" "$BIN_DIR/queue_usb_event.sh"
    "$INSTALL" -m 0644 "$REPO_ROOT/udev/99-omv-usb-automount.rules" "$RULES_DIR/99-omv-usb-automount.rules"

    "$UDEVADM" control --reload-rules

    cat <<EOF
Installed:
  - $BIN_DIR/mount_usb.sh
  - $BIN_DIR/unmount_usb.sh
  - $BIN_DIR/queue_usb_event.sh
  - $RULES_DIR/99-omv-usb-automount.rules

udev rules were reloaded. Replug a USB drive to test the automount flow.
Logs are written to /var/log/usb_mount.log.
EOF
}

main "$@"
