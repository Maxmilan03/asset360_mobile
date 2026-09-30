# PROMPT 10 — Maintenance and Work Orders (design/08_maintenance.jpg)

Follow `CLAUDE.md`. Build the 3 screens plus the hub's other tiles. The Work tab in the bottom bar is active on these screens.

## Screen 1 (left): Maintenance hub
- 6 tiles:
  - **My Work Orders** (badge = count) → My Work Orders tab
  - **Preventive Maintenance:** PM schedules list (asset, frequency, next due, last done), with "Generate WO now" per schedule
  - **Breakdown Requests:** WOs of type Breakdown
  - **Service History:** completed WOs with filters
  - **Spare Parts** → Inventory
  - **Maintenance Calendar:** month view (reuse the one from Home)
- Tabs: **My Work Orders (8)** / **PM Due (12)** / **Overdue (3)** / **All**, with computed counts.
- Search (WO no., asset, location) and filter sheet (priority, status, type, date).
- Rows: photo, priority chip (Critical red / High orange / Medium amber / Low blue), WO number, asset + problem, location, status chip, date. Tap → WO detail.
- "+" FAB → Create Work Order form.

## Screen 2 (middle): WO detail, Overview
- Header: WO number, priority chip, subtitle.
  - The status dropdown (Open / Assigned / In Progress / On Hold / Completed / Closed) changes the status. Changing to On Hold asks for a reason.
- Asset card → Asset detail. Show the asset's real status ("Under Maintenance" for GEN-00045, not "Active").
- Open Date / Priority / Due Date with a live red countdown chip ("1h 20m remaining", ticking every minute from DemoClock). After the due time it turns into "Overdue by …".
- Assigned To (avatar, name, role; tap → reassign sheet with a people picker), Reported By, Category, Work Type, SLA, Status.
- Issue Description with Edit (inline edit, Save / Cancel).
- Photos (n) + Add Photo (image_picker). Tap a photo → full-screen viewer.
- Buttons: **Update Status ▾** (sheet with statuses + comment) and **Close Work Order**.
  - **Close Work Order is disabled until all tasks are completed.** The design shows it active too early. Tapping the disabled button shows "Complete all tasks first (2 of 6 done)".
  - Closing asks for resolution notes, labour hours, parts used, and a signature pad (draw with a finger, CustomPaint). It then sets the WO to Closed, sets the asset status back to Active, and updates counts everywhere.

## Screen 3 (right): Tasks tab
- Task Progress "n / 6" with a green bar, **computed from completed tasks** (the design's "3/6" was wrong; it starts at 1/6).
- An accordion list of the 6 tasks. Each has a number circle or green ✓, a title, and a status chip or completion time.
- The open task (Inspection & Diagnosis) shows:
  - Checklist "4 / 6 completed" with checkboxes (tapping toggles and updates the count).
  - Number inputs with units for vibration (mm/s) and temperature (°C).
  - Notes field with a mic button. The mic opens a "Recording…" sheet with a running timer and a Stop button. Stopping attaches a "Voice note 0:12" chip to the task. This is simulated; no real audio is recorded.
  - "Add Photos / Video" with camera, gallery and video buttons.
  - **Complete Task**, enabled only when all checklist items are ticked. It marks the task done, opens the next one, and updates progress.
- Pending tasks expand to show their own checklists (make short realistic ones).
- **Other tabs:**
  - **Parts:** reserved/used parts. "+ Add Part" picks from Inventory with quantity; this reduces available stock in Inventory.
  - **History:** status change log.
  - **Documents:** linked docs → Document details.

## Done when
A work order can be driven from Open to Closed entirely in the app, the task checklist works, and the countdown, parts reservation, signature and every count stay consistent.
