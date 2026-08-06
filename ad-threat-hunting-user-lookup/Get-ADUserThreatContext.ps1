<#
.SYNOPSIS
    Pulls threat-hunting context for an on-prem AD user: account status,
    direct + nested group memberships, and privileged-group flagging.
    Can also run in reverse to expand a group's full nested membership.

.DESCRIPTION
    Built for incident response / threat hunting scenarios where a suspect
    account or group has been identified and you need to quickly understand
    its actual effective access — including via nested group membership,
    which is easy to miss if you only check direct membership.

.PARAMETER SamAccountName
    The AD account (sAMAccountName) to investigate.

.PARAMETER GroupName
    Reverse-lookup mode: expand this group's full nested membership instead
    of investigating a user.

.PARAMETER ExpandGroup
    Switch. Required alongside -GroupName to confirm reverse-lookup mode.

.PARAMETER PrivilegedGroups
    Optional. Override/extend the default list of high-value groups checked
    for (nested) membership.

.PARAMETER ExportCsv
    Optional path. If supplied, results are also written to CSV.

.EXAMPLE
    .\Get-ADUserThreatContext.ps1 -SamAccountName jsmith

.EXAMPLE
    .\Get-ADUserThreatContext.ps1 -SamAccountName jsmith -ExportCsv .\jsmith_context.csv

.EXAMPLE
    .\Get-ADUserThreatContext.ps1 -GroupName "Domain Admins" -ExpandGroup

.NOTES
    Reconstructed for portfolio purposes — sanitized of any real
    incident/client data. Contact: hebert@blackmambacyber.com
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "User")]
    [string]$SamAccountName,

    [Parameter(ParameterSetName = "Group")]
    [string]$GroupName,

    [Parameter(ParameterSetName = "Group")]
    [switch]$ExpandGroup,

    [string[]]$PrivilegedGroups,

    [string]$ExportCsv
)

Import-Module ActiveDirectory -ErrorAction Stop

$DefaultPrivilegedGroups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Schema Admins",
    "Administrators",
    "Account Operators",
    "Backup Operators",
    "Server Operators",
    "Print Operators",
    "Group Policy Creator Owners"
)

$privGroupList = if ($PrivilegedGroups) { $PrivilegedGroups } else { $DefaultPrivilegedGroups }

function Get-NestedGroupMembership {
    <#
        Returns the full set of groups a user (or group) effectively belongs
        to, walking up the nested membership chain. AD's built-in
        -MemberOf only returns direct membership, so this recurses.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADPrincipal]$Identity
    )

    $visited = New-Object System.Collections.Generic.HashSet[string]
    $queue = New-Object System.Collections.Generic.Queue[string]

    foreach ($dn in (Get-ADPrincipalGroupMembership -Identity $Identity | Select-Object -ExpandProperty DistinguishedName)) {
        $queue.Enqueue($dn)
    }

    while ($queue.Count -gt 0) {
        $currentDn = $queue.Dequeue()
        if ($visited.Contains($currentDn)) { continue }
        [void]$visited.Add($currentDn)

        try {
            $parentGroups = Get-ADPrincipalGroupMembership -Identity $currentDn -ErrorAction Stop
            foreach ($pg in $parentGroups) {
                if (-not $visited.Contains($pg.DistinguishedName)) {
                    $queue.Enqueue($pg.DistinguishedName)
                }
            }
        }
        catch {
            # Some groups (e.g. built-in) may not resolve as principals for nested lookup — skip quietly
        }
    }

    return $visited | ForEach-Object {
        Get-ADGroup -Identity $_ -Properties Name | Select-Object -ExpandProperty Name
    }
}

function Get-ExpandedGroupMembers {
    <#
        Returns every user that is a member of the given group, including via
        nested group membership (i.e. flattens the tree down to users).
    #>
    param([string]$GroupName)

    $group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
    $visitedGroups = New-Object System.Collections.Generic.HashSet[string]
    $members = New-Object System.Collections.Generic.List[object]

    function Expand-Group($groupDn) {
        if ($visitedGroups.Contains($groupDn)) { return }
        [void]$visitedGroups.Add($groupDn)

        $groupMembers = Get-ADGroupMember -Identity $groupDn -ErrorAction SilentlyContinue
        foreach ($m in $groupMembers) {
            if ($m.objectClass -eq "group") {
                Expand-Group $m.DistinguishedName
            }
            elseif ($m.objectClass -eq "user") {
                $members.Add($m)
            }
        }
    }

    Expand-Group $group.DistinguishedName
    return $members | Sort-Object -Property SamAccountName -Unique
}

# --- Reverse lookup mode: expand a group ------------------------------------
if ($PSCmdlet.ParameterSetName -eq "Group") {
    if (-not $ExpandGroup) {
        throw "Use -ExpandGroup alongside -GroupName to confirm reverse-lookup mode."
    }

    Write-Host "Expanding nested membership for group: $GroupName" -ForegroundColor Cyan
    $expanded = Get-ExpandedGroupMembers -GroupName $GroupName

    $expanded | ForEach-Object {
        [PSCustomObject]@{
            SamAccountName = $_.SamAccountName
            Name           = $_.Name
            Enabled        = (Get-ADUser -Identity $_.SamAccountName -Properties Enabled).Enabled
        }
    } | Format-Table -AutoSize

    if ($ExportCsv) {
        $expanded | Select-Object SamAccountName, Name | Export-Csv -Path $ExportCsv -NoTypeInformation
        Write-Host "Exported to $ExportCsv" -ForegroundColor Green
    }
    return
}

# --- User investigation mode -------------------------------------------------
if (-not $SamAccountName) {
    throw "Provide -SamAccountName, or use -GroupName with -ExpandGroup for reverse lookup."
}

$user = Get-ADUser -Identity $SamAccountName -Properties `
    Enabled, LastLogonDate, PasswordLastSet, LockedOut, AdminCount, `
    DisplayName, DistinguishedName, whenCreated -ErrorAction Stop

Write-Host "`n=== Account: $($user.SamAccountName) ($($user.DisplayName)) ===" -ForegroundColor Cyan
Write-Host ("Enabled:          {0}" -f $user.Enabled)
Write-Host ("Locked Out:       {0}" -f $user.LockedOut)
Write-Host ("Last Logon:       {0}" -f $user.LastLogonDate)
Write-Host ("Password Set:     {0}" -f $user.PasswordLastSet)
Write-Host ("Created:          {0}" -f $user.whenCreated)
Write-Host ("AdminCount Flag:  {0}  (1 = currently or previously in a protected/privileged group)" -f $user.AdminCount)

Write-Host "`n--- Resolving nested group membership (this may take a moment) ---" -ForegroundColor Yellow
$allGroups = Get-NestedGroupMembership -Identity $user

Write-Host "`n=== Effective Group Membership (direct + nested) ===" -ForegroundColor Cyan
$flaggedGroups = @()
foreach ($g in ($allGroups | Sort-Object)) {
    if ($privGroupList -contains $g) {
        Write-Host " [PRIVILEGED] $g" -ForegroundColor Red
        $flaggedGroups += $g
    }
    else {
        Write-Host "  $g"
    }
}

if ($flaggedGroups.Count -gt 0) {
    Write-Host "`n⚠ This account has privileged access via: $($flaggedGroups -join ', ')" -ForegroundColor Red
}
else {
    Write-Host "`nNo privileged group membership detected (direct or nested)." -ForegroundColor Green
}

if ($ExportCsv) {
    $allGroups | Sort-Object | ForEach-Object {
        [PSCustomObject]@{
            SamAccountName = $user.SamAccountName
            GroupName      = $_
            Privileged     = $privGroupList -contains $_
        }
    } | Export-Csv -Path $ExportCsv -NoTypeInformation
    Write-Host "`nExported to $ExportCsv" -ForegroundColor Green
}
