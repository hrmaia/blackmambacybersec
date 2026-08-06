<#
.SYNOPSIS
    Creates an Entra ID Dynamic Security Group used to drive M-Files SSO
    vault/role assignment based on extensionAttribute2.

.DESCRIPTION
    Once user accounts are tagged with extensionAttribute2 (see
    Set-ExtensionAttributeForVaultAccess.ps1), this script creates a Dynamic
    Group whose membership rule matches on that attribute value. M-Files is
    then configured (server-side) to map group membership to vault access,
    so membership self-maintains without manual add/remove as staff change
    roles or leave.

.PARAMETER GroupName
    Display name for the new Dynamic Group, e.g. "MFiles-VaultA-Users"

.PARAMETER AttributeValue
    The extensionAttribute2 value this group's membership rule should match,
    e.g. "VaultA-ReadWrite"

.PARAMETER MailNickname
    Optional mail nickname override. Defaults to a slugified GroupName.

.EXAMPLE
    .\New-MFilesDynamicSecurityGroup.ps1 -GroupName "MFiles-VaultA-Users" -AttributeValue "VaultA-ReadWrite"

.NOTES
    Reconstructed for portfolio purposes — sanitized of real tenant/client data.
    Requires Microsoft.Graph PowerShell SDK and Group.ReadWrite.All scope.
    Dynamic Groups require Entra ID P1 or higher licensing.
    Contact: hebert@blackmambacyber.com
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupName,

    [Parameter(Mandatory = $true)]
    [string]$AttributeValue,

    [string]$MailNickname
)

Import-Module Microsoft.Graph.Groups -ErrorAction Stop

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "Group.ReadWrite.All"
}

if (-not $MailNickname) {
    $MailNickname = ($GroupName -replace '[^a-zA-Z0-9]', '').ToLower()
}

# Membership rule: match users whose extensionAttribute2 equals the given value.
# Scoped to user objects only (not devices/groups).
$membershipRule = "(user.extensionAttribute2 -eq `"$AttributeValue`")"

$existing = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Warning "A group named '$GroupName' already exists (Id: $($existing.Id)). Skipping creation."
    return
}

$params = @{
    DisplayName                  = $GroupName
    MailEnabled                  = $false
    MailNickname                 = $MailNickname
    SecurityEnabled               = $true
    GroupTypes                   = @("DynamicMembership")
    MembershipRule               = $membershipRule
    MembershipRuleProcessingState = "On"
    Description                   = "Auto-managed via extensionAttribute2='$AttributeValue' for M-Files SSO vault access. Do not manually manage membership."
}

try {
    $group = New-MgGroup @params
    Write-Host "Created Dynamic Group '$GroupName' (Id: $($group.Id))" -ForegroundColor Green
    Write-Host "Membership rule: $membershipRule" -ForegroundColor Cyan
    Write-Host "Note: initial membership evaluation can take a few minutes to populate." -ForegroundColor Yellow
}
catch {
    throw "Failed to create Dynamic Group: $($_.Exception.Message)"
}
