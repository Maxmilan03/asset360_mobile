# PROMPT 15 — WIP / Operations (design/13_wip_operations.jpg)

Follow `CLAUDE.md`. Build the 3 screens. Production orders use the **MO-** prefix (e.g. MO-2026-0018) so they never clash with maintenance WO numbers. Wherever the design says "WO-2026-0018", show "MO-2026-0018", and call the screen "Production Order".

## Screen 1 (left): WIP / Operations hub
- 4 KPI tiles: WIP in Process, Completed Today, Delayed, On Hold (from data). Tapping a tile selects the matching tab.
- 4 action tiles:
  - **Scan to Move:** scan a unit/serial, which shows its current station and a "Move to next station" confirm. This adds a location entry.
  - **Start Operation:** pick an MO and its next pending operation → Start.
  - **End Operation:** pick a running operation → enter good qty / scrap qty → End.
  - **Report Issue:** issue form with the MO/unit attached; type defaults to "Production".
- Tabs: All WIP / In Process / Completed / Delayed, with counts from the summary rule.
- Search (MO, product, serial, location) and filter.
- Rows: photo, MO number, status chip, product, serial, current station, and a **mini station progress bar** (circles joined by lines: done = filled violet ✓, current = ring, failed = red !, pending = grey). **The current station in the row must equal the one on the detail screen** (the design contradicts itself: SMT Line 1 vs AOI Line 1).

## Screen 2 (middle): WIP Tracking (unit PCB-A-4587)
- Unit card: photo, serial, In Process chip, Production Order, Product, Batch No., Current Station.
- Tabs: **Overview** | Process Flow | Location History | Documents.
- Horizontal flow: SMT ✓ (time) → AOI (current, time) → Assembly → Testing → Packing.
- **Current Operation** with Edit:
  - Operation, Start Time, Operator (link), Status, Expected Duration, Actual Duration.
  - Actual duration ticks live from the start time (capped to demo values).
  - A photo with a 🔍 zoom button.
- **Location Details:** path chip with a scan button (scanning a station tag updates the location), Last Scanned, Scanned By, Scan Device, "View on Map" → Tracking.
- Photos (n) + Add Photo.
- **Move to Next Operation:**
  - Confirms and completes the current operation, then starts the next.
  - Updates the flow, the list row and the MO progress.
  - If a quality check fails (ask "Passed quality check?" Yes/No), mark the step red and create a finding.
- **Report Issue:** issue form prefilled.
- **Process Flow tab:** a vertical routing view with each step's standard time vs actual. **Location History:** a scan timeline. **Documents:** work instructions (open the sample PDF).

## Screen 3 (right): Production Order (MO-2026-0018)
- Header card: photo, MO number, product, In Process chip, Customer, Planned Qty, Completed Qty, Due Date, and a **Progress ring = completed / planned** (64%).
- Tabs: **Operations** | Components | Resources | Quality | Notes.
- Operations list: number circle or ✓, name, status chip, time, duration.
  - The completed step shows "View".
  - The running step shows **Pause** / **End** (not "Start": the design wrongly shows Start on a step that's already in progress).
  - Pending steps show **Start**, enabled only for the next step in sequence.
- **Components:** bill of materials with required / issued quantities; "Issue from Inventory" reduces inventory stock.
- **Resources:** machines/stations and operators assigned.
- **Quality:** check results and first-pass yield.
- **Notes:** add notes with a timestamp.
- **Pause WO** (reason sheet) → status On Hold, button becomes Resume. **Complete Work Order** is enabled only when all operations are done; it marks the MO Completed and moves it to the Completed tab.

## Done when
A production order can be run from the first to the last operation, unit movement is recorded, and the hub KPIs, list rows and details stay in sync.
