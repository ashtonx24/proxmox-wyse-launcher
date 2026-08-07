#!/usr/bin/env bash

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

sleep_retry() {
    sleep "${RETRY_SECONDS:-5}"
}

poweroff_appliance() {
    log 'Assigned VM is stopped; powering off appliance.'
    sudo -n /usr/bin/systemctl poweroff
}
