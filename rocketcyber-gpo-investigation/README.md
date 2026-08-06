# RocketCyber Privilege Escalation Alert – GPO False Positive Investigation

**Incident Response / Threat Hunting Case Study**
**Author:** Hebert Maia
**Date:** August 2026
**Environment:** Domain-joined Windows 11 Pro workstation

> ⚠️ Sanitized for portfolio purposes — the domain name has been replaced
> with a generic placeholder (`CLIENTORGDOM`), consistent with the
> [`windows-admin-group-investigation`](../windows-admin-group-investigation)
> write-up which covers a related domain environment.

---

## Overview

A RocketCyber alert flagged a potential privilege escalation on a Windows 11 endpoint (`Computer01`). The alert indicated that an account was added to the local `Administrators` group (Event ID 4732), with a possible new account creation (Event ID 4720) and `net.exe` activity (T1136).

After investigation, the activity was confirmed as **legitimate** and caused by a Group Policy Object that adds the domain group `CLIENTORGDOM\Domain Admins` to the local Administrators group.

This case study documents the full investigation process, the tools and commands used, how the SID mismatch was resolved, and the final remediation / tuning recommendations.

---

## Alert Summary

| Field                  | Value                                                                 |
|-------------------------|-------------------------------------------------------------------------|
| Device                 | Computer01                                                            |
| OS                     | Microsoft Windows 11 Pro 64-bit (Build 26100)                         |
| Executed By            | Computer01\User01                                                     |
| Executed By SID        | S-1-5-21-533097763-311161407-1355160548-1007                         |
| Elevated Account SID   | S-1-5-21-2676099817-3428148052-3384824227-512                        |
| Group                  | Builtin\Administrators                                                |
| Suggested Check        | `Get-WmiObject win32_useraccount \| Select domain,name,sid`          |

**Problem:** The Elevated Account SID did **not** appear in the output of the suggested PowerShell command.

---

## Investigation Timeline

### 1. Initial SID Check

Ran the recommended command:

```powershell
Get-WmiObject win32_useraccount | Select domain,name,sid
```

**Result:** No match for either SID.
**Reason:** The command only returns **local user accounts**. It does not return domain groups.

### 2. Translate SIDs

```powershell
$sid1 = "S-1-5-21-533097763-311161407-1355160548-1007"
$sid2 = "S-1-5-21-2676099817-3428148052-3384824227-512"

$objSID1 = New-Object System.Security.Principal.SecurityIdentifier($sid1)
$objSID2 = New-Object System.Security.Principal.SecurityIdentifier($sid2)

$objSID1.Translate([System.Security.Principal.NTAccount])
$objSID2.Translate([System.Security.Principal.NTAccount])
```

### 3. Check Local Administrators Group Membership

```powershell
Get-LocalGroupMember -Group "Administrators" | Select-Object Name, SID
```

**Key Finding:**

```
Name                          SID
----                          ---
CLIENTORGDOM\Domain Admins    S-1-5-21-2676099817-3428148052-3384824227-512
```

This SID matched the "Elevated Account" SID in the RocketCyber alert exactly.

### 4. Confirm Source of the Change

- Checked applied GPOs: `gpresult /r /scope computer`
- Reviewed Group Policy Management Console on the domain controller
- Confirmed a GPO was configured to add `CLIENTORGDOM\Domain Admins` to the local `Administrators` group (Restricted Groups / Local Users and Groups preference)

### 5. Rule Out Malicious Activity

- No Event ID 4720 (new account creation) linked to this SID
- No suspicious `net.exe` process creation (Event ID 4688) matching the timeframe
- Change was performed by `NT AUTHORITY\SYSTEM` (typical for GPO application)

---

## Root Cause

A domain Group Policy Object intentionally adds the `CLIENTORGDOM\Domain Admins` group to the local Administrators group on domain-joined workstations.

RocketCyber correctly detected the group membership change (Event ID 4732) but presented the **group SID** as an "Elevated Account", which caused confusion during initial triage.

---

## Resolution & Recommendations

### Immediate Actions

- Confirmed the GPO is approved and expected
- Documented the GPO as a known legitimate source of Event ID 4732
- Created a suppression / exception rule in RocketCyber for:
  - Event ID 4732
  - Member: `CLIENTORGDOM\Domain Admins`
  - SID: `S-1-5-21-2676099817-3428148052-3384824227-512`
  - Actor: `NT AUTHORITY\SYSTEM`

### Long-term Recommendations

1. Prefer least-privilege custom AD groups instead of `Domain Admins` where possible
2. Enable auditing for GPO changes
3. Create a baseline of expected local group membership changes driven by GPO
4. Tune EDR / XDR alerts to differentiate between user accounts and domain groups when reporting elevated SIDs

---

## Commands Used (Quick Reference)

| Purpose                              | Command |
|----------------------------------------|---------|
| List local Administrators members    | `Get-LocalGroupMember -Group "Administrators" \| Select Name, SID` |
| List local user accounts + SIDs      | `Get-WmiObject win32_useraccount \| Select domain,name,sid` |
| Translate SID to account name        | See PowerShell SID translation above |
| Check applied GPOs                   | `gpresult /r /scope computer` |
| Query Event ID 4732                  | `Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=4732]]"` |
| Check for net.exe process creation   | `Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=4688]]" \| Where { $_.Message -like "*net.exe*" }` |

---

## Lessons Learned

- Always check **group** membership, not just user accounts, when investigating privilege escalation alerts.
- Domain group SIDs will never appear in `win32_useraccount`.
- RocketCyber (and similar tools) sometimes label a group SID as an "account". Always verify the SID type.
- GPO-driven changes are a common source of false positives for Event ID 4732.

---

## Skills Demonstrated

- Windows Security Event Log analysis (4720, 4732, 4688)
- SID investigation and translation
- Distinguishing local vs domain principals
- GPO troubleshooting
- EDR alert triage and false-positive tuning
- PowerShell & CMD investigation techniques
