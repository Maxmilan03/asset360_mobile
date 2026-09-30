# PROMPT 11 — Inspection (design/09_inspection.jpg)

Follow `CLAUDE.md`. Build the 3 screens plus the hub tiles. Build one **reusable checklist engine** (`lib/core/checklist/`) that supports these item types: choice (radio chips like Good / Minor Issue / Major Issue), yes/no, number with unit and normal range, text, photo, and signature. Maintenance tasks should reuse it too.

## Screen 1 (left): Inspection hub
- 6 tiles:
  - **My Inspections** (badge)
  - **Due Today** (badge)
  - **Overdue** (red badge)
  - **Completed**
  - **Findings** (badge): all findings, each with severity, asset and status (Open / Action Taken / Closed); tap → finding detail with "Create Work Order" / "Close Finding"
  - **Inspection Calendar**
- Tabs: My Inspections / Due / Overdue / All. **Counts are computed, and badge and tab counts must match** (the design shows Overdue 2 on the tile but 3 on the tab).
- Search and filter. Rows: photo, INS number, asset + type, location, status chip (Overdue red, Due Today amber, In Progress blue, Scheduled green), date. Tap → inspection.
- "+" FAB → Create Inspection: asset, template (Fire Pump Routine, HVAC, Generator Safety, Forklift Safety, Fire Extinguisher Monthly), due date and time, inspector.

## Screen 2 (middle): Inspection, Checklist tab
- Header: INS number, Overdue chip (computed from DemoClock), status dropdown, subtitle.
- Tabs: Details | **Checklist** | Findings (n) | Documents.
- Checklist Progress "8 / 12" with a bar, computed live.
- Sections as accordions with "answered / total" and a number circle. Section 1 is expanded and shows 4 items, each with radio chips and a green ✓ once answered.
- Selecting a negative answer ("Minor Issue", "Major Issue", "Yes" for leakage, "Loose", "Damaged", "Needs Cleaning", "Not Acceptable") automatically opens a **"Add Finding"** sheet: description, severity, photo. Saving adds it to Findings (n).
- Buttons: **Save as Draft** (SnackBar "Draft saved", keeps answers) / **Next →** (goes to the next section).

## Screen 3 (right): Checklist, section 2 "Performance Check"
- The "2 / 4" header must be computed: with 3 items answered it shows **3 / 4**.
- Number fields with a unit suffix and a **normal range chip**. Typing a value outside the range turns the chip red and shows "Out of range", then offers "Add Finding".
- The flow rate field is empty; an ⓘ icon shows its expected range.
- Vibration uses radio chips Normal / High / Excessive.
- Notes field and Photos (n): thumbnails with an ✕ to remove, and Add Photo (image_picker).
- Buttons: **Previous** / **Save & Next**.
- After the last section: a **Summary & Submit** step showing score (items passed / total), findings list, inspector signature pad, and Submit.
  - Submit marks the inspection Completed and moves it to the Completed tab.
  - For each open finding it offers "Create Work Order" (prefilled).
  - Home and badge counts update.
- **Details tab:** asset, template, scheduled date and time, inspector, location, last inspection result.
- **Documents tab:** linked docs, and upload via file_picker.

## Done when
An inspection can be completed end to end with findings, the range validation and auto-finding work, every count is computed, and the checklist engine is reusable.
