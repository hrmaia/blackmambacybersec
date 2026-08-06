# M-Files — Access Management (Entra ID Dynamic Groups)

**Category:** Documentation & Procedures
**Application:** M-Files
**Author:** Hebert Maia
**Status:** Active

> ⚠️ Sanitized for portfolio purposes — real client names and domains replaced
> with `ClientOrg A` / `ClientOrg B` and `@blackmambacyber.com`-style
> placeholders. Structure, logic, and commands are unchanged from production use.

---

## What is M-Files?

M-Files is a cloud-based document and information management platform. It allows staff to store, search, and collaborate on documents in a structured and secure way.

Access to M-Files is controlled via Microsoft Single Sign-On (SSO). Users do not have a separate M-Files password — they log in with their Microsoft account. Currently all users are provisioned with **Read-Only** access.

| Feature | Detail |
|---|---|
| Login method | Microsoft SSO (Entra ID) |
| Current access level | Read-Only |
| Available via | Web browser and Desktop application |

---

## How Access Works

Access is controlled by a tag applied to each user's account in Microsoft Entra ID. When the tag is present, the user is automatically added to the M-Files group and granted access. When removed, access is revoked automatically — no manual group changes needed.

| Setting | Value |
|---|---|
| Attribute | `extensionAttribute2` |
| Tag value | `ReadOnly-MFiles` |
| Dynamic Group Rule | `user.extensionAttribute2 -eq "ReadOnly-MFiles"` |

> 💡 Additional access groups (read-write, admin) have been pre-created and are ready to activate when requested.

---

## Environment Architecture

| Organisation | Environment | How the tag is applied |
|---|---|---|
| ClientOrg A | Cloud only | PowerShell (MgGraph) |
| ClientOrg B | Hybrid AD + Cloud | Active Directory (on-premises) |

### Data Flow — ClientOrg B Users

```
ClientOrg B AD (on-premises)
    ↓  Entra Connect — syncs to cloud every 30 minutes
ClientOrg B Entra ID
    ↓  Cross-Tenant Sync (Sync-to-MFiles-OrgA)
ClientOrg A Entra ID
    ↓  Dynamic Group evaluates tag
M-Files Access Granted
```

> ⚠️ **ClientOrg B:** Never set the tag via PowerShell Graph. Changes made in the cloud will be overwritten by Entra Connect within 30 minutes. Always use Active Directory.

---

## M-Files Desktop Application

M-Files is available as both a **web version** and a **desktop application**. The web version covers basic document access, however some users require the desktop version for full functionality including complaints management, non-conformance management, and views.

> ⚠️ Currently only ClientOrg B users require the desktop version. Confirm with the manager before deploying to any user.

### Deployment via NinjaOne

| Setting | Value |
|---|---|
| Application name | `M-Files Desktop` |
| Installation parameter | `M_MFCLIENT_DRIVE_LETTER=K` |
| Silent install flag | `/qn` |

**Full deployment command:**

```cmd
msiexec /i "MFiles_Custom.msi" M_MFCLIENT_DRIVE_LETTER=K /qn
```

> 💡 The `M_MFCLIENT_DRIVE_LETTER=K` parameter forces the M-Files virtual drive to use the letter **K**. This only applies to new installations — upgrades preserve the existing drive letter.

**Steps in NinjaOne:**

1. Go to **NinjaOne → Software → Applications**
2. Find **M-Files Desktop**
3. Select the target device(s)
4. Set the installation parameter to `M_MFCLIENT_DRIVE_LETTER=K`
5. Deploy

---

## Before You Start — PowerShell (Cloud Only)

Connect to Microsoft Graph at the beginning of every session:

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"
```

If you get a module error, run this first:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Import-Module Microsoft.Graph.Authentication
```

Disconnect when finished:

```powershell
Disconnect-MgGraph
```

---

## Apply Tag

### Single User — ClientOrg A (Cloud)

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

Update-MgUser -UserId "user@clientorg-a.blackmambacyber.com" -OnPremisesExtensionAttributes @{
    ExtensionAttribute2 = "ReadOnly-MFiles"
}
```

### Few Users — ClientOrg A (Cloud)

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = @(
    "user1@clientorg-a.blackmambacyber.com",
    "user2@clientorg-a.blackmambacyber.com",
    "user3@clientorg-a.blackmambacyber.com"
)

foreach ($upn in $users) {
    try {
        Update-MgUser -UserId $upn -OnPremisesExtensionAttributes @{ ExtensionAttribute2 = "ReadOnly-MFiles" }
        Write-Host "✅ Updated: $upn"
    }
    catch {
        Write-Host "❌ Failed: $upn — $($_.Exception.Message)"
    }
}
```

### Bulk via CSV — ClientOrg A (Cloud)

CSV file: one email per line, no header required.

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

$csvPath = "C:\temp\users.csv"
$logPath = "C:\temp\users_result.csv"
$users   = Get-Content -Path $csvPath | Where-Object { $_ -ne "" }
$results = [System.Collections.Generic.List[object]]::new()

foreach ($upn in $users) {
    try {
        Update-MgUser -UserId $upn -OnPremisesExtensionAttributes @{ ExtensionAttribute2 = "ReadOnly-MFiles" }
        Write-Host "✅ Updated: $upn"
        $results.Add([PSCustomObject]@{ Email = $upn; Status = "Success"; Error = "" })
    }
    catch {
        Write-Host "❌ Failed: $upn"
        $results.Add([PSCustomObject]@{ Email = $upn; Status = "Failed"; Error = $_.Exception.Message })
    }
}

$results | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Success: $(($results | Where-Object Status -eq 'Success').Count)"
Write-Host "❌ Failed:  $(($results | Where-Object Status -eq 'Failed').Count)"
```

### Single User — ClientOrg B (Active Directory UI)

> 💡 Use this method if you are not comfortable with PowerShell. Safest option for L1 technicians.

1. Open **Active Directory Users and Computers (ADUC)**
2. Click **View** in the top menu → make sure **Advanced Features** is ticked
3. Find the user — use `Ctrl + F` to search by name
4. Right-click the user → **Properties**
5. Click the **Attribute Editor** tab
6. Scroll down and find `extensionAttribute2`
7. Double-click it → type `ReadOnly-MFiles` exactly as shown → click **OK**
8. Click **OK** to close

> ⚠️ The value must be typed exactly as: `ReadOnly-MFiles` — it is case sensitive.
> Once done, notify your senior engineer to force a sync to the cloud.

### Single User — ClientOrg B (Active Directory PowerShell)

```powershell
Import-Module ActiveDirectory

$adUser = Get-ADUser -Filter {EmailAddress -eq "user@clientorg-b.blackmambacyber.com"}
Set-ADUser -Identity $adUser.SamAccountName -Replace @{extensionAttribute2 = "ReadOnly-MFiles"}

# Force sync to cloud immediately — run on Entra Connect server
Start-ADSyncSyncCycle -PolicyType Delta
```

> 💡 If the user's EmailAddress field is empty in AD, use SamAccountName directly:
> `Set-ADUser -Identity "username" -Replace @{extensionAttribute2 = "ReadOnly-MFiles"}`

### Bulk via CSV — ClientOrg B (Active Directory)

```powershell
Import-Module ActiveDirectory

$csvPath = "C:\temp\users_source.csv"
$logPath = "C:\temp\users_source_result.csv"
$users   = Get-Content -Path $csvPath | Where-Object { $_ -ne "" } | ForEach-Object { $_.Trim() }
$results = [System.Collections.Generic.List[object]]::new()

foreach ($email in $users) {
    try {
        $adUser = Get-ADUser -Filter {EmailAddress -eq $email} -ErrorAction Stop
        if (-not $adUser) { throw "User not found by EmailAddress" }
        Set-ADUser -Identity $adUser.SamAccountName -Replace @{extensionAttribute2 = "ReadOnly-MFiles"}
        Write-Host "✅ Updated: $email ($($adUser.SamAccountName))"
        $results.Add([PSCustomObject]@{ Email = $email; SamAccountName = $adUser.SamAccountName; Status = "Success"; Error = "" })
    }
    catch {
        Write-Host "❌ Failed: $email — $($_.Exception.Message)"
        $results.Add([PSCustomObject]@{ Email = $email; SamAccountName = ""; Status = "Failed"; Error = $_.Exception.Message })
    }
}

$results | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Success: $(($results | Where-Object Status -eq 'Success').Count)"
Write-Host "❌ Failed:  $(($results | Where-Object Status -eq 'Failed').Count)"
```

After running, force a delta sync:

```powershell
Start-ADSyncSyncCycle -PolicyType Delta
```

---

## Remove Tag

> ⚠️ Removing the tag immediately revokes M-Files access for that user.

### Single User (Cloud)

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

Update-MgUser -UserId "user@clientorg-a.blackmambacyber.com" -OnPremisesExtensionAttributes @{
    ExtensionAttribute2 = $null
}
```

### Few Users (Cloud)

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = @("user1@clientorg-a.blackmambacyber.com", "user2@clientorg-a.blackmambacyber.com")

foreach ($upn in $users) {
    Update-MgUser -UserId $upn -OnPremisesExtensionAttributes @{ ExtensionAttribute2 = $null }
    Write-Host "✅ Removed: $upn"
}
```

### Bulk via CSV (Cloud)

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = Get-Content "C:\temp\users.csv" | Where-Object { $_ -ne "" }

foreach ($upn in $users) {
    Update-MgUser -UserId $upn -OnPremisesExtensionAttributes @{ ExtensionAttribute2 = $null }
    Write-Host "✅ Removed: $upn"
}
```

### Single User — ClientOrg B (Active Directory UI)

> 💡 Safest option for L1 technicians.

1. Open **Active Directory Users and Computers (ADUC)**
2. Click **View** → make sure **Advanced Features** is ticked
3. Find the user — use `Ctrl + F` to search by name
4. Right-click the user → **Properties**
5. Click the **Attribute Editor** tab
6. Scroll down and find `extensionAttribute2`
7. Double-click it → **select the value** → **delete it** → click **OK**
8. Click **OK** to close

> Once done, notify your senior engineer to force a sync to the cloud.

### Single User — ClientOrg B (Active Directory PowerShell)

```powershell
Import-Module ActiveDirectory

Set-ADUser -Identity "username" -Clear extensionAttribute2

# Force sync immediately — run on Entra Connect server
Start-ADSyncSyncCycle -PolicyType Delta
```

### Bulk via CSV — ClientOrg B (Active Directory)

```powershell
Import-Module ActiveDirectory

$users = Get-Content "C:\temp\users_source.csv" | Where-Object { $_ -ne "" }

foreach ($user in $users) {
    try {
        $adUser = Get-ADUser -Filter {EmailAddress -eq $user} -ErrorAction Stop
        Set-ADUser -Identity $adUser.SamAccountName -Clear extensionAttribute2
        Write-Host "✅ Removed: $user"
    }
    catch {
        Write-Host "❌ Failed: $user — $($_.Exception.Message)"
    }
}

# Force sync after bulk removal
Start-ADSyncSyncCycle -PolicyType Delta
```

---

## Check Tag Status

### Single User

```powershell
Connect-MgGraph -Scopes "User.Read.All"

Get-MgUser -UserId "user@clientorg-a.blackmambacyber.com" -Property OnPremisesExtensionAttributes |
    Select-Object -ExpandProperty OnPremisesExtensionAttributes |
    Select-Object ExtensionAttribute2
```

### Multiple Specific Users

```powershell
Connect-MgGraph -Scopes "User.Read.All"

$users = @(
    "user1@clientorg-a.blackmambacyber.com",
    "user2@clientorg-a.blackmambacyber.com",
    "user3@clientorg-a.blackmambacyber.com"
)

foreach ($upn in $users) {
    $attr = Get-MgUser -UserId $upn -Property OnPremisesExtensionAttributes |
        Select-Object -ExpandProperty OnPremisesExtensionAttributes
    $tag = if ($attr.ExtensionAttribute2) { $attr.ExtensionAttribute2 } else { "NOT SET" }
    Write-Host "$upn → $tag"
}
```

### Who HAS the tag

```powershell
Connect-MgGraph -Scopes "User.Read.All"

Get-MgUser -All -Property DisplayName, UserPrincipalName, OnPremisesExtensionAttributes |
    Where-Object { $_.OnPremisesExtensionAttributes.ExtensionAttribute2 -eq "ReadOnly-MFiles" } |
    Select-Object DisplayName, UserPrincipalName |
    Sort-Object DisplayName
```

### Who DOESN'T have the tag (licensed users only)

Filters out shared mailboxes, service accounts, guests, and disabled accounts automatically.

```powershell
Connect-MgGraph -Scopes "User.Read.All"

Get-MgUser -All -Property DisplayName, UserPrincipalName, OnPremisesExtensionAttributes, AssignedLicenses, AccountEnabled, UserType |
    Where-Object {
        $_.OnPremisesExtensionAttributes.ExtensionAttribute2 -ne "ReadOnly-MFiles" -and
        $_.AccountEnabled -eq $true -and
        $_.AssignedLicenses.Count -gt 0 -and
        $_.UserType -eq "Member"
    } |
    Select-Object DisplayName, UserPrincipalName |
    Sort-Object DisplayName
```

### Full status report — all licensed users (export to CSV)

Shows every licensed user with a column — either `ReadOnly-MFiles` or `NOT SET`.

```powershell
Connect-MgGraph -Scopes "User.Read.All"

$logPath = "C:\temp\users_tag_status.csv"

Get-MgUser -All -Property DisplayName, UserPrincipalName, OnPremisesExtensionAttributes, AccountEnabled, AssignedLicenses |
    Where-Object { $_.AccountEnabled -eq $true -and $_.AssignedLicenses.Count -gt 0 } |
    Select-Object DisplayName, UserPrincipalName,
        @{Name="ExtensionAttribute2"; Expression={
            if ($_.OnPremisesExtensionAttributes.ExtensionAttribute2) {
                $_.OnPremisesExtensionAttributes.ExtensionAttribute2
            } else {
                "NOT SET"
            }
        }} |
    Sort-Object DisplayName |
    Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8

Write-Host "Done — check $logPath"
```

---

## Quick Reference

| Task | Environment |
|---|---|
| Apply — single user | Cloud |
| Apply — few users | Cloud |
| Apply — bulk CSV | Cloud |
| Apply — single user (UI) | AD — ClientOrg B |
| Apply — single user (PowerShell) | AD — ClientOrg B |
| Apply — bulk CSV | AD — ClientOrg B |
| Remove — single user | Cloud |
| Remove — few users | Cloud |
| Remove — bulk CSV | Cloud |
| Remove — single user (UI) | AD — ClientOrg B |
| Remove — single user (PowerShell) | AD — ClientOrg B |
| Remove — bulk CSV | AD — ClientOrg B |
| Check who HAS tag | Cloud |
| Check who DOESN'T have tag | Cloud |
| Full status report CSV | Cloud |
| Force sync to cloud | AD — ClientOrg B |
