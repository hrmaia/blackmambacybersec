# AD Threat Hunting — User & Group Membership Lookup

## What it does
A PowerShell script used during threat-hunting/incident-response work to
quickly pull the **full blast radius context** for a suspect on-prem Active
Directory account:

- Account details (enabled/disabled, last logon, password last set, lockout
  status, whether it's privileged)
- Direct and **nested/effective** group memberships (not just direct — a user
  can be in a privileged group via nested membership, which matters a lot when
  you're trying to figure out what an attacker could actually touch)
- Flags if the account is (directly or nested) a member of any high-value
  groups (Domain Admins, Enterprise Admins, Schema Admins, Account Operators,
  Backup Operators, or any custom list you supply)
- Optionally, the reverse lookup: given a group, list every member (nested,
  expanded) — useful when the pivot goes the other way ("who's in this
  compromised group?")

Output goes to console (color-coded for quick triage) and can optionally be
exported to CSV for the incident timeline/report.

## Where/how it was used
Built for use during active investigations — the scenario is usually "we've
found a suspicious login/process/account, what does this account actually have
access to, and is it privileged (directly or via nesting)?" Speed matters in
that moment, so this is meant to be run interactively against a single
username with minimal setup.

## Usage
```powershell
# Basic lookup — direct + nested group membership, privileged-group flagging
.\Get-ADUserThreatContext.ps1 -SamAccountName jsmith

# Export to CSV for the investigation report
.\Get-ADUserThreatContext.ps1 -SamAccountName jsmith -ExportCsv .\jsmith_context.csv

# Reverse lookup — expand a group's full nested membership
.\Get-ADUserThreatContext.ps1 -GroupName "Domain Admins" -ExpandGroup
```

## Requirements
- `ActiveDirectory` PowerShell module (RSAT or run from a DC)
- Read access to the domain (no elevated rights required for standard lookups)

## Notes
- Reconstructed for portfolio purposes — sanitized of any real
  incident/client data. The privileged-group list is a sensible default set;
  extend `$DefaultPrivilegedGroups` for environment-specific groups (e.g.
  tiering-model admin groups).
