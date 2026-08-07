#!/usr/bin/env bash
set -u

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_FILE="${1:-$BASE_DIR/test-config.env}"

if [[ ! -r "$CONFIG_FILE" ]]; then
    printf 'Missing test configuration: %s\n' "$CONFIG_FILE" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$CONFIG_FILE"
set +a

required_config=(PVE_HOST PVE_NODE PVE_VMID PVE_TOKEN_ID PVE_TOKEN_SECRET)
for name in "${required_config[@]}"; do
    if [[ -z "${!name:-}" ]]; then
        printf 'Missing configuration value: %s\n' "$name" >&2
        exit 1
    fi
done

# shellcheck disable=SC1091
. "$BASE_DIR/api.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/viewer.sh"

printf 'Requesting fresh SPICE session for VM %s...\n' "$PVE_VMID"
if ! session_json=$(api_spice_session); then
    printf 'Could not obtain SPICE session; remote-viewer will not be launched.\n' >&2
    exit 1
fi

printf 'Launching remote-viewer. Close the viewer to finish the test.\n'
viewer_run "$session_json"
