param(
    [string]$PveHost = '192.168.2.2',
    [string]$PveNode = 'wisdom',
    [string]$PveVmid = '101',
    [string]$TokenId = 'wyse01@pve!launcher',
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'
$secret = $null
if (Test-Path -LiteralPath $EnvFile) {
    $envLine = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match '^\s*api_token\s*=' } |
        Select-Object -First 1
    if ($envLine -match '^\s*api_token\s*=\s*(.*)\s*$') {
        $secret = $Matches[1].Trim()
        if (($secret.StartsWith("'") -and $secret.EndsWith("'")) -or
            ($secret.StartsWith('"') -and $secret.EndsWith('"'))) {
            $secret = $secret.Substring(1, $secret.Length - 2)
        }
    }
}

if ([string]::IsNullOrWhiteSpace($secret)) {
    $secretSecure = Read-Host 'Proxmox API token secret' -AsSecureString
    $secretPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretSecure)
    try {
        $secret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPtr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPtr)
    }
}

$baseUrl = "https://$PveHost`:8006/api2/json"
function Invoke-PveApi([string]$Method, [string]$Path) {
    $uri = "$baseUrl/$Path"
    try {
        # curl.exe is used because Windows PowerShell validates the custom
        # PVEAPIToken Authorization value as a standard auth header.
        $raw = & curl.exe --silent --show-error --fail --insecure `
            --request $Method `
            --header "Authorization: PVEAPIToken=$TokenId=$secret" `
            $uri 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw (($raw -join "`n").Trim())
        }
        ($raw -join "`n") | ConvertFrom-Json
    }
    catch {
        throw "API request failed: $Method $uri`n$($_.Exception.Message)"
    }
}

Write-Host "Testing Proxmox API: $baseUrl"
$statusResponse = Invoke-PveApi 'GET' "nodes/$PveNode/qemu/$PveVmid/status/current"
$status = $statusResponse.data.status
Write-Host "Authentication: OK"
Write-Host "VM status: $status"

if ($status -ne 'running') {
    Write-Host 'VM is not running; SPICE test skipped. No VM changes were made.'
    exit 0
}

$spiceResponse = Invoke-PveApi 'POST' "nodes/$PveNode/qemu/$PveVmid/spiceproxy"
$spice = $spiceResponse.data
Write-Host "SPICE response fields: $(@($spice.psobject.Properties.Name) -join ', ')"
foreach ($field in @('type', 'host', 'proxy', 'tls-port', 'host-subject')) {
    $value = $spice.$field
    if ([string]::IsNullOrWhiteSpace([string]$value)) {
        throw "SPICE response is missing field: $field"
    }
    Write-Host "SPICE $field`: $value"
}
if ([string]::IsNullOrWhiteSpace([string]$spice.ca)) {
    throw 'SPICE response is missing field: ca'
}
if ([string]::IsNullOrWhiteSpace([string]$spice.ticket) -and
    [string]::IsNullOrWhiteSpace([string]$spice.password)) {
    throw 'SPICE response is missing credential field: ticket or password'
}
Write-Host 'SPICE metadata: OK (ticket and CA received; values not printed)'
