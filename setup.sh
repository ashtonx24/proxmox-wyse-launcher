#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo 'Run this installer as root.' >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_DIR='/opt/proxmox-launcher'
CONFIG_DIR='/etc/proxmox-launcher'
CONFIG_FILE="$CONFIG_DIR/config.env"
ENABLE_KIOSK=0

if [[ "${1:-}" == '--enable-kiosk' ]]; then
    ENABLE_KIOSK=1
    shift
fi

KIOSK_USER="${1:-}"
if [[ -z "$KIOSK_USER" && -r /etc/lightdm/lightdm.conf ]]; then
    KIOSK_USER=$(sed -n 's/^autologin-user=//p' /etc/lightdm/lightdm.conf | tail -n 1)
fi
if [[ -z "$KIOSK_USER" ]]; then
    echo 'Usage: sudo ./setup.sh <lightdm-autologin-user>' >&2
    exit 1
fi
if ! id "$KIOSK_USER" >/dev/null 2>&1; then
    echo "Unknown user: $KIOSK_USER" >&2
    exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl jq remote-viewer sudo

install -d -m 0755 "$INSTALL_DIR" "$CONFIG_DIR"
install -m 0755 "$SCRIPT_DIR/runtime.sh" "$SCRIPT_DIR/api.sh" \
    "$SCRIPT_DIR/viewer.sh" "$SCRIPT_DIR/system.sh" "$INSTALL_DIR/"
install -m 0644 "$SCRIPT_DIR/config.env.example" "$CONFIG_DIR/config.env.example"

if [[ ! -e "$CONFIG_FILE" ]]; then
    install -m 0640 -o root -g "$KIOSK_USER" \
        "$SCRIPT_DIR/config.env.example" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE; edit it before rebooting."
fi
chown root:"$KIOSK_USER" "$CONFIG_FILE"
chmod 0640 "$CONFIG_FILE"

install -d -m 0755 /etc/sudoers.d
printf '%s ALL=(root) NOPASSWD: /usr/bin/systemctl poweroff\n' "$KIOSK_USER" \
    > /etc/sudoers.d/proxmox-launcher
chmod 0440 /etc/sudoers.d/proxmox-launcher
visudo -cf /etc/sudoers.d/proxmox-launcher

if [[ "$ENABLE_KIOSK" -eq 1 ]]; then
cat > /etc/xdg/autostart/proxmox-launcher.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Proxmox Launcher
Comment=Start the assigned Proxmox VM console
Exec=$INSTALL_DIR/runtime.sh
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
chmod 0644 /etc/xdg/autostart/proxmox-launcher.desktop
fi

echo 'Installation complete.'
echo "Edit $CONFIG_FILE, then reboot or log out and back in."
if [[ "$ENABLE_KIOSK" -eq 0 ]]; then
    echo 'Kiosk autostart is not enabled. Re-run with --enable-kiosk after testing.'
fi
