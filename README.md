# Proxmox Wyse appliance runtime

This runtime is intended for a Debian/XFCE Wyse appliance with LightDM autologin.
It starts one assigned Proxmox VM, creates a fresh SPICE connection, launches
`remote-viewer`, reconnects after viewer/VM restarts, and powers off the Wyse
when the assigned VM is confirmed stopped.

## Install on a Wyse

Copy this directory to the Wyse and run, as root:

```sh
sudo ./setup.sh <lightdm-autologin-user>
sudo editor /etc/proxmox-launcher/config.env
sudo reboot
```

The installer does not replace an existing `config.env`. Use a different
configuration file on each Wyse; the runtime code is identical.

Required packages are `curl`, `jq`, `remote-viewer`, and `sudo`.

## Test from the Windows computer

Before touching a Wyse, run the read-only Proxmox integration test from
PowerShell. It checks the token, VM status, and SPICE response without starting
or stopping the VM:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose.ps1
```

The defaults match the current test configuration. Override them if needed:

```powershell
.\diagnose.ps1 -PveHost 192.168.2.2 -PveNode wisdom -PveVmid 101 -TokenId 'wyse01@pve!launcher'
```

## Test the viewer from MX Linux

If the school network does not provide DNS for `wisdom.school.local`, add a
temporary local mapping on MX Linux:

```sh
echo '192.168.2.2 wisdom.school.local' | sudo tee -a /etc/hosts
getent hosts wisdom.school.local
nc -vz wisdom.school.local 3128
```

Copy `test-config.env.example` to `test-config.env`, put the temporary test
token secret in it, and run:

```sh
chmod +x test-viewer.sh
./test-viewer.sh
```

The test requests a fresh SPICE session and launches `remote-viewer`. It does
not start or stop the VM.
