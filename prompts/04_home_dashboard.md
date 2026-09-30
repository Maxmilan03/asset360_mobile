# PROMPT 04 — Home Dashboard (design/02_home_dashboard.jpg)

Follow `CLAUDE.md`. The image shows **one long scrolling Home screen** split across 3 phones: left = top, middle = middle, right = bottom. Build it as a single scrollable page.

## Header (HomeHeader)
- Logo + "Purple IQ", bell with badge (unread notifications), avatar + "Rex Kumar / DCS ▾".
  - Bell → Notifications.
  - Tapping the name opens a small menu: Profile, Settings, Switch Site, Logout.
- Big "Asset360" and "Asset Lifecycle, Maintenance & Operations" over a dark purple industrial background. Build a gradient with a subtle factory skyline silhouette drawn with CustomPaint.

## Top section (left phone)
- "Good Morning, Rex!": greeting based on DemoClock (Morning / Afternoon / Evening).
- "Here's what's happening today."
- Date **"Fri, 25 Sep 2026"** (the design's "Thu" is wrong).
- "All Sites ▾" dropdown: choosing a site filters the counts that belong to a site (at minimum, update the label and show a filtered-state chip).
- 4 KPI tiles, all computed from data, each opening a filtered list:
  - Work Orders (My Assigned) → Maintenance, My Work Orders tab
  - Inspections (Due Today) → Inspection, Due tab
  - Approvals (Pending) → My Approvals screen
  - Critical Alert (Requires Action) → Alerts, Critical tab
- Quick Actions grid of 8, with "Customize" in the header:
  - Scan Asset → Scan
  - Report Issue → Report Issue form
  - Move Asset → Transfer Asset step 1
  - Create Work Order → new WO form (build a simple one: asset picker, title, priority, type, due date, assignee; saving adds it to the Maintenance list)
  - Start Inspection → Inspection list
  - Asset Audit → Audit list
  - Inventory Issue → Inventory
  - More Actions → sheet with the rest of the modules
  - **Customize** opens a sheet where the user can reorder and toggle quick actions; this works in-memory.
- My Tasks: tabs All / Work Orders / Inspections / Approvals, with counts computed so **All = sum of the others**. Rows show priority chip, title, asset and location, and due time (red "Due in 1h 20m" / "Overdue" from DemoClock). Tapping a row opens its detail. "View All" → a My Tasks full screen.

## My Approvals screen (new, same style)
- A list of movement requests awaiting Rex's approval.
- Each has Approve / Reject. Reject asks for a reason.
- Approving updates the movement status and the Home counter.

## Middle section (middle phone)
- **Asset Overview:** donut (fl_chart) with 12,458 in the centre and a legend with counts and computed %. "View All →" opens the Assets list. Tapping a legend row opens Assets filtered by that status.
- **Maintenance Performance:** 4 tiles (PM Compliance 92%, MTTR 1.8 hrs, WO Closure Rate 98%, Avg. Downtime 12 hrs). Tapping a tile opens a sheet explaining the metric with a small 6-month trend chart. "View All" → Maintenance.
- **Upcoming Activities:** date badge, icon, title, subtitle, time, location. Tap → detail. "View Calendar →" → Maintenance Calendar: a month view with dots on days that have WOs/inspections/audits; tapping a day lists them.
- **Recent Alerts:** 3 latest alerts, with an icon coloured by severity. Tap → Alert Details. "View All →" → Alerts.

## Bottom section (right phone)
- **Asset Location (Live):** mini floor plan (CustomPaint) with coloured pins. Legend: Vehicles 12, People 24, Equipment 142, Alerts 6 (from the tracking summary). Expand icon / "View Map →" → Tracking & IoT.
- **Asset Health:** 87% "Good" ring and 5 bars with percentages; "View Details →" opens a breakdown sheet.
- **Cost Summary (AED):** donut with 1.25M "Total Cost", 6 legend rows with computed %; "View Details →" opens a cost breakdown sheet.
- **Recent Assets:** CNC-00123 and GEN-00045 rows → Asset detail. "View All →" → Assets.

## Behaviour
- Pull-to-refresh shows a shimmer for 1 second, then data.
- All numbers react to state changes from other modules. For example, closing WO-2026-0045 lowers the Work Orders count.

## Done when
The page matches the design top to bottom, and every tile, chip, row, link and legend item works as listed.
