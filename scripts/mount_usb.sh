#!/bin/bash

set -euo pipefail
PATH="/usr/sbin:/usr/bin:/sbin:/bin"

DATE="/bin/date"
BLKID="/usr/sbin/blkid"
FINDMNT="/usr/bin/findmnt"
MKDIR="/bin/mkdir"
SED="/bin/sed"
SLEEP="/bin/sleep"
SYSTEMD_MOUNT="/usr/bin/systemd-mount"
TR="/usr/bin/tr"
LOG_FILE="/var/log/usb_mount.log"
STATE_DIR="/run/omv-usb-automount"
MOUNT_ROOT="/media/usbdevices"

log_message() {
    printf '%s %s\n' "$("$DATE" '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

sanitize_name() {
    local raw="$1"
    local sanitized

    sanitized="$(
        printf '%s' "$raw" |
            "$TR" -cs '[:alnum:]._- ' '_' |
            "$SED" 's/^_//; s/_$//'
    )"

    if [ -z "$sanitized" ]; then
        sanitized="usb-device"
    fi

    printf '%s' "$sanitized"
}

resolve_mount_name() {
    local devname="$1"
    local base_name="$2"
    local candidate="$base_name"
    local index=2

    while [ -e "$MOUNT_ROOT/$candidate" ] && ! "$FINDMNT" -rn -S "$devname" -T "$MOUNT_ROOT/$candidate" > /dev/null 2>&1; do
        candidate="${base_name}-${index}"
        index=$((index + 1))
    done

    printf '%s' "$candidate"
}

device_label() {
    local devname="$1"
    local label

    label="$("$BLKID" -o value -s LABEL "$devname" 2>/dev/null || true)"
    if [ -z "$label" ]; then
        label="$("$BLKID" -o value -s PARTLABEL "$devname" 2>/dev/null || true)"
    fi
    if [ -z "$label" ]; then
        label="$("$BLKID" -o value -s UUID "$devname" 2>/dev/null || true)"
    fi
    if [ -z "$label" ]; then
        label="$(basename "$devname")"
    fi

    printf '%s' "$label"
}

ensure_device_ready() {
    local devname="$1"
    local attempt

    for attempt in 1 2 3 4 5; do
        if [ -b "$devname" ] && "$BLKID" "$devname" > /dev/null 2>&1; then
            return 0
        fi
        "$SLEEP" 1
    done

    return 1
}

wait_for_mount() {
    local devname="$1"
    local mount_point="$2"
    local attempt

    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        if "$FINDMNT" -rn -S "$devname" -T "$mount_point" > /dev/null 2>&1; then
            return 0
        fi
        "$SLEEP" 1
    done

    return 1
}

main() {
    local devname="${1:-}"
    local mount_name
    local mount_point
    local state_file

    if [ -z "$devname" ]; then
        log_message "Error: no device path provided"
        exit 1
    fi

    if ! ensure_device_ready "$devname"; then
        log_message "Error: device $devname is not ready for mounting"
        exit 1
    fi

    if "$FINDMNT" -rn -S "$devname" > /dev/null 2>&1; then
        log_message "Device $devname is already mounted"
        exit 0
    fi

    "$MKDIR" -p "$MOUNT_ROOT" "$STATE_DIR"

    mount_name="$(sanitize_name "$(device_label "$devname")")"
    mount_name="$(resolve_mount_name "$devname" "$mount_name")"
    mount_point="$MOUNT_ROOT/$mount_name"
    state_file="$STATE_DIR/$(basename "$devname").mountpoint"

    "$MKDIR" -p "$mount_point"
    log_message "Attempting to mount $devname at $mount_point"

    if ! "$SYSTEMD_MOUNT" --no-block --options=rw,noatime "$devname" "$mount_point" >> "$LOG_FILE" 2>&1; then
        log_message "Error: systemd-mount failed for $devname"
        rmdir "$mount_point" 2>/dev/null || true
        exit 1
    fi

    if ! wait_for_mount "$devname" "$mount_point"; then
        log_message "Error: mount did not appear for $devname at $mount_point"
        exit 1
    fi

    printf '%s\n' "$mount_point" > "$state_file"
    log_message "Mounted $devname at $mount_point"
}

main "$@"
