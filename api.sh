#!/usr/bin/env bash

api_call() {
    local method="$1" endpoint="$2"
    shift 2
    local api_url="${PVE_API_URL:-https://${PVE_HOST}:8006/api2/json}"
    local -a tls_args=()

    if [[ "${PVE_TLS_VERIFY:-1}" == '0' ]]; then
        tls_args+=(--insecure)
    fi

    curl --silent --show-error --fail \
        "${tls_args[@]}" \
        --connect-timeout "${API_CONNECT_TIMEOUT:-5}" \
        --max-time "${API_TIMEOUT:-15}" \
        --request "$method" \
        --header "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
        "${api_url%/}/${endpoint#/}" \
        "$@"
}

api_vm_status() {
    api_call GET "nodes/${PVE_NODE}/qemu/${PVE_VMID}/status/current" \
        | jq -er '.data.status'
}

api_start_vm() {
    api_call POST "nodes/${PVE_NODE}/qemu/${PVE_VMID}/status/start" >/dev/null
}

api_spice_session() {
    api_call POST "nodes/${PVE_NODE}/qemu/${PVE_VMID}/spiceproxy" \
        | jq -ec '.data'
}
