# Proxmox Wyse Appliance Runtime

A small, stateless runtime for turning a thin client and one assigned Proxmox
VM into a single-purpose computer.

The client boots into its local Linux installation only as appliance firmware.
The user is presented with the assigned virtual machine through `remote-viewer`.

## Runtime behavior

The runtime:

- waits for the Proxmox API to become reachable;
- starts the assigned VM when it is stopped;
- waits for a usable SPICE session;
- launches `remote-viewer` in fullscreen mode;
- reconnects after a viewer crash or VM reboot;
- powers off the client after the assigned VM is confirmed stopped.

It does not implement SPICE, rendering, window management, or desktop UI. It
uses Proxmox's API and `remote-viewer` directly.

Runtime state is not persisted. Every boot reconstructs its situation from the
external configuration file and current Proxmox API responses.

## Project structure

```text
api.sh                 Proxmox API operations
viewer.sh              Temporary SPICE file and remote-viewer handling
system.sh              Logging, retry delays, and appliance poweroff
runtime.sh             Main orchestration loop
setup.sh               Appliance installer
diagnose.ps1           Read-only Windows API/SPICE diagnostic
test-viewer.sh         Linux viewer integration test
```

## Requirements

The appliance requires:

- Debian 13 or a compatible Debian-based installation;
- LightDM or another display manager with automatic login configured;
- `curl`, `jq`, `virt-viewer`, and `sudo`;
- network access to the Proxmox API and SPICE proxy;
- one permanently assigned Proxmox VM.

The integration test was performed using:

- Dell Wyse 5070 thin clients running Debian 13;
- MX Linux as a Linux test environment;
- Libretto hardware as an additional test/development environment;
- Proxmox VE with SPICE console access.

## Configuration

Copy `config.env.example` to the external configuration path created by the
installer:

```sh
/etc/proxmox-launcher/config.env
```

Example:

```sh
PVE_HOST='proxmox.example.local'
PVE_NODE='node-name'
PVE_VMID='123'
PVE_TOKEN_ID='launcher@pve!client-token'
PVE_TOKEN_SECRET='token-secret'
PVE_TLS_VERIFY='1'
```

Use a separate configuration file and API token for each appliance. Never
commit real configuration files or token secrets to a public repository.

Set `PVE_TLS_VERIFY='0'` only when the client does not trust the Proxmox API
certificate. Installing the appropriate CA certificate is preferable.

## Installation

Clone the repository on the appliance and install the runtime:

```sh
git clone https://github.com/your-account/proxmox-wyse-launcher.git
cd proxmox-wyse-launcher
sudo bash setup.sh <lightdm-autologin-user>
```

The first installation leaves kiosk autostart disabled. Configure the appliance:

```sh
sudo nano /etc/proxmox-launcher/config.env
```

## Hostname resolution

The SPICE response may contain a proxy hostname such as:

```text
proxy=http://proxmox-node.example.local:3128
```

That hostname must resolve from the appliance. If local DNS does not provide
it, add a local mapping using the Proxmox node's reachable IP address:

```sh
echo '192.0.2.10 proxmox-node.example.local' | sudo tee -a /etc/hosts
```

Use the actual hostname and IP for the deployment. This preserves the hostname
used by the SPICE certificate while routing the connection correctly.

## Manual test

Before enabling kiosk mode, run the runtime manually as the autologged-in user:

```sh
sudo -u <lightdm-autologin-user> /opt/proxmox-launcher/runtime.sh
```

Confirm that the assigned VM opens successfully. Stop the VM from Proxmox and
confirm that the appliance powers off as expected.

## Enable kiosk mode

After the manual test succeeds:

```sh
sudo bash setup.sh --enable-kiosk <lightdm-autologin-user>
sudo reboot
```

The same source code can be installed on multiple appliances. Only the
external configuration differs.

## Development and testing

The Windows diagnostic checks API authentication, VM status, and SPICE metadata
without starting or stopping a VM:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose.ps1 -PveHost <host> -PveNode <node> -PveVmid <vmid> -TokenId '<token-id>'
```

The Linux viewer test requests a fresh SPICE session and launches
`remote-viewer`:

```sh
cp test-config.env.example test-config.env
nano test-config.env
chmod +x test-viewer.sh
./test-viewer.sh
```

`test-config.env` is ignored by Git and must never be committed.
