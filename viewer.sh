#!/usr/bin/env bash

viewer_create_vv() {
    local session_json="$1" vv_file="$2"
    local ticket proxy host tls_port ca host_subject

    ticket=$(jq -er '.ticket // .password' <<<"$session_json") || return 1
    proxy=$(jq -er '.proxy' <<<"$session_json") || return 1
    host=$(jq -er '.host' <<<"$session_json") || return 1
    tls_port=$(jq -er '."tls-port"' <<<"$session_json") || return 1
    ca=$(jq -er '.ca' <<<"$session_json") || return 1
    ca=${ca//$'\n'/\\n}
    host_subject=$(jq -er '."host-subject"' <<<"$session_json") || return 1

    {
        printf '%s\n' '[virt-viewer]'
        printf 'type=spice\n'
        printf 'fullscreen=1\n'
        printf 'password=%s\n' "$ticket"
        printf 'host=%s\n' "$host"
        printf 'proxy=%s\n' "$proxy"
        printf 'tls-port=%s\n' "$tls_port"
        printf 'host-subject=%s\n' "$host_subject"
        printf 'ca=%s\n' "$ca"
        printf 'delete-this-file=1\n'
    } >"$vv_file"
}

viewer_run() {
    local session_json="$1"
    local vv_file
    vv_file=$(mktemp --tmpdir "proxmox-launcher.XXXXXX.vv") || return 1

    if ! viewer_create_vv "$session_json" "$vv_file"; then
        rm -f -- "$vv_file"
        return 1
    fi

    remote-viewer "$vv_file"
    local result=$?
    rm -f -- "$vv_file"
    return "$result"
}
