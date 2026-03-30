#!/bin/bash

set -euo pipefail
PATH="/usr/sbin:/usr/bin:/sbin:/bin"

BASH="/bin/bash"
SYSTEMD_RUN="/usr/bin/systemd-run"
MOUNT_SCRIPT="/usr/local/bin/mount_usb.sh"
UNMOUNT_SCRIPT="/usr/local/bin/unmount_usb.sh"

usage() {
    echo "Usage: $0 {add|remove} /dev/sdXN" >&2
    exit 1
}

main() {
    local action="${1:-}"
    local devname="${2:-}"
    local unit_name

    if [ -z "$action" ] || [ -z "$devname" ]; then
        usage
    fi

    unit_name="omv-usb-automount-${action}-$(basename "$devname")"

    case "$action" in
        add)
            exec "$SYSTEMD_RUN" --quiet --property=Type=oneshot --unit "$unit_name" \
                "$BASH" -lc 'sleep 2; exec "$1" "$2"' _ "$MOUNT_SCRIPT" "$devname"
            ;;
        remove)
            exec "$SYSTEMD_RUN" --quiet --property=Type=oneshot --unit "$unit_name" \
                "$UNMOUNT_SCRIPT" "$devname"
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
