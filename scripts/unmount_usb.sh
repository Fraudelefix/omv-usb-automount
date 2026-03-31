#!/bin/bash

set -euo pipefail
PATH="/usr/sbin:/usr/bin:/sbin:/bin"

CAT="/bin/cat"
DATE="/bin/date"
FINDMNT="/usr/bin/findmnt"
RMDIR="/bin/rmdir"
RM="/bin/rm"
SLEEP="/bin/sleep"
SYSTEMD_UMOUNT="/usr/bin/systemd-umount"
UMOUNT="/bin/umount"
LOG_FILE="/var/log/usb_mount.log"
STATE_DIR="/run/omv-usb-automount"
MOUNT_ROOT="/media/usbdevices"

log_message() {
    printf '%s %s\n' "$("$DATE" '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

state_file_for() {
    local devname="$1"
    printf '%s/%s.mountpoint' "$STATE_DIR" "$(basename "$devname")"
}

read_mount_point() {
    local devname="$1"
    local state_file
    local mount_point

    state_file="$(state_file_for "$devname")"
    if [ -f "$state_file" ]; then
        "$CAT" "$state_file"
        return 0
    fi

    mount_point="$("$FINDMNT" -rn -S "$devname" -o TARGET 2>/dev/null || true)"
    case "$mount_point" in
        "$MOUNT_ROOT"/*)
            printf '%s\n' "$mount_point"
            ;;
    esac
}

wait_for_unmount() {
    local mount_point="$1"
    local attempt

    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        if ! "$FINDMNT" -rn -T "$mount_point" > /dev/null 2>&1; then
            return 0
        fi
        "$SLEEP" 1
    done

    return 1
}

main() {
    local devname="${1:-}"
    local mount_point
    local state_file

    if [ -z "$devname" ]; then
        log_message "Error: no device path provided for unmount"
        exit 1
    fi

    state_file="$(state_file_for "$devname")"
    mount_point="$(read_mount_point "$devname")"

    if [ -z "$mount_point" ]; then
        "$RM" -f "$state_file" 2>/dev/null || true
        exit 0
    fi

    case "$mount_point" in
        "$MOUNT_ROOT"/*)
            ;;
        *)
            log_message "Refusing to manage unexpected mount path $mount_point for $devname"
            exit 1
            ;;
    esac

    log_message "Attempting to unmount $devname from $mount_point"

    if "$FINDMNT" -rn -T "$mount_point" > /dev/null 2>&1; then
        if ! "$SYSTEMD_UMOUNT" "$mount_point" >> "$LOG_FILE" 2>&1; then
            log_message "systemd-umount failed for $mount_point, falling back to umount"
            "$UMOUNT" "$mount_point" >> "$LOG_FILE" 2>&1
        fi
    fi

    if ! wait_for_unmount "$mount_point"; then
        log_message "Error: mount point $mount_point is still active"
        exit 1
    fi

    "$RMDIR" "$mount_point" 2>/dev/null || log_message "Mount directory $mount_point was not empty, leaving it in place"

    "$RM" -f "$state_file" 2>/dev/null || true
    log_message "Unmounted $devname from $mount_point"
}

main "$@"
