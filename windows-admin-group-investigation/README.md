# Windows Server Administrators Group Addition – Investigation Guide

> ⚠️ Sanitized for portfolio purposes — real hostname, domain, org name, and IP
> replaced with generic placeholders. SIDs, event IDs, and command sequences
> are unchanged from the real investigation.

**Event Summary**

- **Alert**: User `CLIENTORG-DC01\Riskclear` added a member to the group `Builtin\Administrators`
- **Device**: CLIENTORG-DC01 | 10.10.10.10 | Microsoft Windows Server 2019 Server Standard 64-bit (1809 / Build 17763)
- **Organization**: ClientOrg Data Center
- **Executed By**: `CLIENTORG-DC01\Riskclear`
  - SID: `S-1-5-21-3592196275-2466196025-2418987872-1003`
- **Added Member SID**: `S-1-5-21-3592196275-2466196025-2418987872-1005`
- **Group**: `Builtin\Administrators`
- **Elevated Account**: Not specified

This guide consolidates the full investigation process, commands, and analysis for both **standalone (workgroup)** and **domain-joined** scenarios. The server name contains "DC", and later outputs showed domain group membership (`CLIENTORGDOM\Domain Admins`), indicating the server is domain-joined (or has a trust).

---

## 1. Key Observations from Investigation Outputs

### Commands Run
```powershell
Get-WmiObject win32_useraccount | Select domain,name,sid
Get-LocalGroupMember -Group "Administrators" | Select-Object Name, SID
```

### Notable Output
```
CLIENTORGDOM\Domain Admins    S-1-5-21-2676099817-3428148052-3384824227-512
```

**Analysis**:
- `CLIENTORGDOM\Domain Admins` with RID `-512` is the standard Domain Admins group from the **CLIENTORGDOM** domain.
- On a domain-joined server (especially a Domain Controller), Domain Admins is automatically nested into the local `Administrators` group. This is normal behaviour.
- The SID of this group (`S-1-5-21-2676099817-3428148052-3384824227-512`) does **not** match the SID from the original alert (`S-1-5-21-3592196275-2466196025-2418987872-1005`).
- The original event SID prefix (`3592196275-2466196025-2418987872`) is different from the CLIENTORGDOM domain SID. This may indicate:
  - A different domain / forest
  - A domain trust
  - Or a local account on a non-domain-joined system (less likely given the output)

The RID `-1005` on the added member strongly suggests a **user account** (RIDs ≥ 1000 are typically created users/groups).

---

## 2. Investigation Steps

### Step 1: Resolve the SIDs to Account Names

#### Option A – Domain-Joined / Active Directory Available
```powershell
Import-Module ActiveDirectory

# Resolve the account that performed the action
Get-ADObject -Identity 'S-1-5-21-3592196275-2466196025-2418987872-1003' `
  -Properties SamAccountName, DisplayName, whenCreated, lastLogon, Enabled, MemberOf

# Resolve the added member
Get-ADObject -Identity 'S-1-5-21-3592196275-2466196025-2418987872-1005' `
  -Properties SamAccountName, DisplayName, whenCreated, lastLogon, Enabled, MemberOf
```

#### Option B – Standalone / No AD Module (Local Accounts)
```powershell
# Using Get-LocalUser
Get-LocalUser | Where-Object { $_.SID -eq 'S-1-5-21-3592196275-2466196025-2418987872-1003' } |
  Select Name, SID, Enabled, LastLogon

Get-LocalUser | Where-Object { $_.SID -eq 'S-1-5-21-3592196275-2466196025-2418987872-1005' } |
  Select Name, SID, Enabled, LastLogon

# Using WMIC
wmic useraccount where sid='S-1-5-21-3592196275-2466196025-2418987872-1003' get name,sid,disabled,lastlogon
wmic useraccount where sid='S-1-5-21-3592196275-2466196025-2418987872-1005' get name,sid,disabled,lastlogon

# Using WMI (broader)
Get-WmiObject Win32_UserAccount |
  Where-Object { $_.SID -eq 'S-1-5-21-3592196275-2466196025-2418987872-1005' } |
  Select Domain, Name, SID, Disabled, LastLogon
```

**What to look for**:
- Account name of RID `-1005`
- Creation date (`whenCreated`)
- Last logon timestamp
- Whether the account is enabled
- Group memberships (especially high-privilege groups)

---

### Step 2: Review Current Administrators Group Membership

```powershell
Get-LocalGroupMember -Group 'Administrators' |
  Select-Object Name, SID, PrincipalSource |
  Sort-Object Name
```

Or classic:
```cmd
net localgroup Administrators
```

**Check**:
- Is the SID ending in `-1005` still present?
- `PrincipalSource` values:
  - `Local` → local account
  - `ActiveDirectory` → domain account
- Presence of unexpected domain groups or foreign SIDs (possible trust)

---

### Step 3: Examine Security Event Logs

1. Open **Event Viewer** (`eventvwr.msc`)
2. Navigate to **Windows Logs → Security**
3. Filter for:
   - **Event ID 4732** – A member was added to a security-enabled local group
   - **Event ID 4733** – A member was removed from a security-enabled local group
   - **Event ID 4624 / 4634** – Logon / Logoff
   - **Event ID 4672** – Special privileges assigned to new logon

Export recent events for analysis:
```powershell
Get-WinEvent -FilterHashtable @{
  LogName = 'Security'
  ID      = 4732,4733,4624,4672
} -MaxEvents 200 |
  Export-Csv -Path C:\Logs\AdminGroupChanges.csv -NoTypeInformation
```

In the event details, verify:
- SubjectUserName = `Riskclear`
- MemberSid = the `-1005` SID
- TargetUserName = `Administrators`
- Source IP / Logon Type (if remote)

---

### Step 4: Verify the Actor Account (`Riskclear`)

#### Domain environment
```powershell
Get-ADUser -Identity 'S-1-5-21-3592196275-2466196025-2418987872-1003' `
  -Properties DisplayName, whenCreated, lastLogon, PasswordLastSet, MemberOf, Enabled
```

#### Local environment
```powershell
Get-LocalUser -Name 'Riskclear' | Select Name, SID, Enabled, PasswordLastSet, LastLogon
net user Riskclear
```

Confirm whether `Riskclear` is expected to have rights to modify the Administrators group.

---

### Step 5: Additional Domain Checks (if applicable)

```powershell
# Confirm domain SID
Get-ADDomain | Select Name, DomainSID

# List recent user accounts
Get-ADUser -Filter * -Properties whenCreated |
  Where-Object { $_.whenCreated -gt (Get-Date).AddDays(-30) } |
  Select SamAccountName, SID, whenCreated |
  Sort-Object whenCreated

# Check domain trusts
Get-ADTrust -Filter * | Select Name, Direction, TrustType, TrustAttributes
```

---

### Step 6: Quick Health & Anomaly Checks

```powershell
# Antivirus scan
Start-MpScan -ScanType FullScan

# Running processes
Get-Process | Select Name, Path, StartTime | Sort-Object StartTime -Descending

# Local users sorted by creation (if available)
Get-LocalUser | Select Name, SID, Enabled, LastLogon | Sort-Object Name
```

Recommended external tools (Sysinternals):
- Autoruns
- Process Explorer
- Process Monitor

---

## 3. Remediation (if the addition is unauthorized)

```powershell
# Remove the member from Administrators
Remove-LocalGroupMember -Group 'Administrators' `
  -Member 'S-1-5-21-3592196275-2466196025-2418987872-1005'

# Disable the account (domain)
Disable-ADAccount -Identity 'S-1-5-21-3592196275-2466196025-2418987872-1005'

# Or disable local account
Disable-LocalUser -SID 'S-1-5-21-3592196275-2466196025-2418987872-1005'

# Reset password of the actor (example)
# net user Riskclear "NewStrongPasswordHere!"
```

Also recommended:
- Rotate credentials for all privileged accounts
- Review and tighten Group Policy auditing
- Enable advanced audit policy for Account Management and Logon events

---

## 4. Enabling Better Future Auditing

In **Local Security Policy** (`secpol.msc`) or Group Policy:

- Computer Configuration → Windows Settings → Security Settings → Advanced Audit Policy Configuration
  - Account Management → Audit User Account Management → Success and Failure
  - Account Management → Audit Security Group Management → Success and Failure
  - Logon/Logoff → Audit Logon → Success and Failure

---

## 5. Quick Reference Command Cheat-Sheet

| Goal                              | Command |
|-----------------------------------|---------|
| Resolve local SID                 | `Get-LocalUser \| Where SID -eq '...'` |
| Resolve domain SID                | `Get-ADObject -Identity '...'` |
| List Administrators               | `Get-LocalGroupMember -Group Administrators` |
| Classic list                      | `net localgroup Administrators` |
| Security events                   | `Get-WinEvent -FilterHashtable @{LogName='Security';ID=4732}` |
| Recent domain users               | `Get-ADUser -Filter * -Properties whenCreated` |
| Domain trusts                     | `Get-ADTrust -Filter *` |
| Remove admin member               | `Remove-LocalGroupMember -Group Administrators -Member 'SID'` |

---

## Notes & Recommendations

1. The presence of `CLIENTORGDOM\Domain Admins` confirms domain involvement. Treat the server as domain-joined going forward.
2. The original added SID (`...-1005`) does not match the Domain Admins SID. Resolve it fully – it is the primary lead.
3. Always correlate Event ID 4732 with surrounding logon events (4624) to determine whether the action was interactive, remote, or service-based.
4. If this server is a Domain Controller, any unauthorized addition to Administrators is a high-severity incident.
5. Document findings, timestamps, and actions taken for your incident response records.

---

**Author:** Hebert Maia
Investigation of privilege escalation / unauthorized local admin addition on a Windows Server 2019 domain controller.
Feel free to fork, adapt, or extend this guide for your environment.
