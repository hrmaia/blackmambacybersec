# NinjaOne ↔ DattoRMM Deployment Tracker

## What it does
Cross-references an in-progress **NinjaOne RMM** agent rollout against a legacy
**DattoRMM** install base, so an MSP can see at a glance which endpoints across
each client org are:

- ✅ Migrated (present in both NinjaOne and Datto)
- 🟡 NinjaOne only (deployed, old agent not yet removed)
- 🔴 Datto only (not yet migrated)
- ⚠️ Name mismatch / needs manual review

Results are written to a formatted Excel workbook — one summary sheet plus one
sheet per client org — with conditional formatting and a rolling history of
previous snapshots so you can see week-over-week migration progress.

## Where/how it was used
Built during an active NinjaOne rollout across roughly 22 MSP client
organizations, replacing legacy DattoRMM. Hostname naming conventions varied
significantly between orgs (some prefixed by site code, some by asset tag, some
free-text), so a single exact-match rule wasn't enough — the matcher supports
multiple rule types per org, applied in priority order.

Config is external (`config.json`), so client orgs and their matching rules can
be added/adjusted without touching code — useful since new orgs were onboarded
throughout the project.

## Usage
```bash
pip install pandas openpyxl
python deployment_tracker.py --config config.json --ninja ninja_export.csv --datto datto_export.csv --out report.xlsx
```

Both `ninja_export.csv` and `datto_export.csv` are the raw device-list exports
from each RMM platform (Organization/Site, Hostname, Last Seen columns at
minimum).

## Notes
- Snapshots are appended to `history.json` on each run, so trend charts can be
  built later without re-processing old exports.
- Placeholder org names (`ClientOrg A`, `ClientOrg B`, ...) are used in
  `config.json` — swap in real org names/domains for actual use.
