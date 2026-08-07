#!/usr/bin/env bash
set -u

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_FILE="${PROXMOX_LAUNCHER_CONFIG:-/etc/proxmox-launcher/config.env}"

if [[ ! -r "$CONFIG_FILE" ]]; then
    printf 'Missing configuration: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

# config.env is administrator-controlled shell-style configuration.
set -a
# shellcheck disable=SC1090
. "$CONFIG_FILE"
set +a

if [[ -z "${PVE_TOKEN_SECRET:-}" && -n "${api_token:-}" ]]; then
    PVE_TOKEN_SECRET="$api_token"
fi

# shellcheck disable=SC1091
. "$BASE_DIR/system.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/api.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/viewer.sh"

required_config=(PVE_HOST PVE_NODE PVE_VMID PVE_TOKEN_ID PVE_TOKEN_SECRET)
for name in "${required_config[@]}"; do
    if [[ -z "${!name:-}" ]]; then
        log "Missing configuration value: $name"
        exit 1
    fi
done

wait_for_api() {
    while true; do
        if status=$(api_vm_status 2>/dev/null); then
            printf '%s\n' "$status"
            return 0
        fi
        log 'Waiting for Proxmox API.'
        sleep_retry
    done
}

ensure_vm_running() {
    local status
    status=$(wait_for_api)

    if [[ "$status" == 'stopped' ]]; then
        log 'VM is stopped; requesting start.'
        if ! api_start_vm >/dev/null 2>&1; then
            log 'VM start request failed; retrying.'
            return 1
        fi
        log 'Waiting for VM to become running.'
        while true; do
            status=$(wait_for_api)
            [[ "$status" == 'running' ]] && return 0
            [[ "$status" == 'stopped' ]] || log "VM status: $status"
        done
    fi

    [[ "$status" == 'running' ]]
}

while true; do
    if ! ensure_vm_running; then
        log 'VM is not currently running; retrying.'
        sleep_retry
        continue
    fi

    log 'Requesting fresh SPICE session.'
    if ! session_json=$(api_spice_session 2>/dev/null); then
        log 'SPICE session is not ready; retrying.'
        sleep_retry
        continue
    fi

    log 'Launching remote-viewer.'
    viewer_run "$session_json" >/dev/null 2>&1 || true
    sleep_retry

    if ! status=$(api_vm_status 2>/dev/null); then
        log 'Viewer exited; API unavailable, retrying.'
        continue
    fi

    if [[ "$status" == 'stopped' ]]; then
        poweroff_appliance
        exit 0
    fi

    log "Viewer exited while VM status is $status; reconnecting."
done
