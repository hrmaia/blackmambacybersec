<#
.SYNOPSIS
    Bulk-sets extensionAttribute2 on user accounts, used by an Entra ID Dynamic
    Group membership rule to drive M-Files SSO vault/role assignment.

.DESCRIPTION
    Reads a CSV of UserPrincipalName + VaultRole pairs and writes the VaultRole
    value into extensionAttribute2 for each matching user.

    Supports two modes:
      - Cloud-only tenant: writes directly to Entra ID via Microsoft Graph.
      - Hybrid tenant (Entra Connect): writes to on-prem Active Directory instead,
        since extensionAttribute2 is a synced attribute owned by AD for synced
        objects — writing it directly in Entra ID gets clobbered on the next
        Entra Connect sync cycle.

.PARAMETER CsvPath
    Path to a CSV with columns: UserPrincipalName, VaultRole

.PARAMETER Hybrid
    Switch. If set, writes to on-prem AD via the ActiveDirectory module instead
    of Microsoft Graph. Requires the account running this to have attribute
    write permissions in AD and the ActiveDirectory module installed.

.EXAMPLE
    .\Set-ExtensionAttributeForVaultAccess.ps1 -CsvPath .\users.csv
    Cloud-only tenant — writes via Microsoft Graph.

.EXAMPLE
    .\Set-ExtensionAttributeForVaultAccess.ps1 -CsvPath .\users.csv -Hybrid
    Hybrid tenant — writes via on-prem AD, to be picked up by the next
    Entra Connect delta sync.

.NOTES
    Reconstructed for portfolio purposes — sanitized of real tenant/client data.
    Contact: hebert@blackmambacyber.com
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [switch]$Hybrid
)

function Connect-GraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "User.ReadWrite.All"
    }
}

function Set-AttributeCloud {
    param([string]$Upn, [string]$VaultRole)

    try {
        Update-MgUser -UserId $Upn -OnPremisesExtensionAttributes @{
            ExtensionAttribute2 = $VaultRole
        }
        Write-Host "[Cloud] $Upn -> extensionAttribute2 = $VaultRole" -ForegroundColor Green
    }
    catch {
        Write-Warning "[Cloud] Failed to update $Upn : $($_.Exception.Message)"
    }
}

function Set-AttributeOnPrem {
    param([string]$Upn, [string]$VaultRole)

    try {
        $user = Get-ADUser -Filter "UserPrincipalName -eq '$Upn'" -Properties extensionAttribute2
        if (-not $user) {
            Write-Warning "[OnPrem] No AD user found for $Upn"
            return
        }
        Set-ADUser -Identity $user.DistinguishedName -Replace @{ extensionAttribute2 = $VaultRole }
        Write-Host "[OnPrem] $Upn -> extensionAttribute2 = $VaultRole (pending sync)" -ForegroundColor Green
    }
    catch {
        Write-Warning "[OnPrem] Failed to update $Upn : $($_.Exception.Message)"
    }
}

# --- Main ---------------------------------------------------------------

if (-not (Test-Path $CsvPath)) {
    throw "CSV not found at path: $CsvPath"
}

$rows = Import-Csv -Path $CsvPath
if (-not ($rows | Get-Member -Name UserPrincipalName) -or -not ($rows | Get-Member -Name VaultRole)) {
    throw "CSV must contain 'UserPrincipalName' and 'VaultRole' columns."
}

if ($Hybrid) {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Running in HYBRID mode — writing to on-prem AD. Remember: a sync cycle is required before Entra ID / M-Files reflects this." -ForegroundColor Yellow
}
else {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Connect-GraphIfNeeded
    Write-Host "Running in CLOUD-ONLY mode — writing directly to Entra ID via Graph." -ForegroundColor Yellow
}

$results = foreach ($row in $rows) {
    $upn = $row.UserPrincipalName.Trim()
    $role = $row.VaultRole.Trim()

    if ($Hybrid) {
        Set-AttributeOnPrem -Upn $upn -VaultRole $role
    }
    else {
        Set-AttributeCloud -Upn $upn -VaultRole $role
    }

    [PSCustomObject]@{
        UserPrincipalName = $upn
        VaultRole         = $role
        Mode              = if ($Hybrid) { "OnPrem" } else { "Cloud" }
    }
}

Write-Host "`nProcessed $($results.Count) user(s)." -ForegroundColor Cyan
