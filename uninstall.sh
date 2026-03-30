#!/bin/bash

set -euo pipefail

RM="/bin/rm"
UDEVADM="/usr/bin/udevadm"

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
RULES_DIR="${RULES_DIR:-/etc/udev/rules.d}"

require_root() {
    if [ "${EUID}" -ne 0 ]; then
        echo "Please run this uninstaller as root." >&2
        exit 1
    fi
}

main() {
    require_root

    "$RM" -f \
        "$BIN_DIR/mount_usb.sh" \
        "$BIN_DIR/unmount_usb.sh" \
        "$BIN_DIR/queue_usb_event.sh" \
        "$RULES_DIR/99-omv-usb-automount.rules"

    "$UDEVADM" control --reload-rules

    cat <<EOF
Removed OMV-USB-Automount files from:
  - $BIN_DIR
  - $RULES_DIR

udev rules were reloaded.
EOF
}

main "$@"
