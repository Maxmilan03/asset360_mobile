# PROMPT 02 — Mock data layer (single source of truth)

Follow `CLAUDE.md`. Build `lib/data/` so that every later screen reads from the same consistent data. The design images contain some contradictions (the same generator appears as GEN-01 and GEN-00045, the same forklift as FL-012 and FLT-012, stock balances that don't add up, and so on). The data below fixes them. **Use exactly these values.**

## Structure
- `lib/data/models/`: plain Dart classes with `copyWith`, `fromMap`/`toMap` not needed.
- `lib/data/mock/`: the seed data (one file per module).
- `lib/data/repositories/`: one Riverpod `Notifier` per module holding a list in memory, with methods that change it (add, update status, complete task, and so on).
- `lib/core/demo_clock.dart`: `DemoClock.now = DateTime(2026, 9, 25, 10, 30)`, plus helpers `timeAgo()`, `timeLeft()`, `isOverdue()` and `formatDate()` (formats like "25 Sep 2026", "10:24 AM", "25 Sep 2026 10:24 AM").
- Images: map each asset/part to a file in `assets/images/` (the names there match: cnc_vmc, generator, ahu, forklift, fire_pump, laptop, electric_motor, motor_small, pump_unit, camera, drill, projector, pcb, control_panel, air_filter, v_belt, bearing, spark_plug, fire_extinguisher, cold_room, tool_box, cabinet, aoi_machine, building_factory, building_office, building_campus). Use an icon in a soft colored square when no photo exists.

## Current user
Rex Kumar, role "DCS", initials RK, username `rex.kumar`, email `rex.kumar@purpleiq.ae`, password `Asset@360`, authenticator code `123456`, site "All Sites" (options: All Sites, Dubai Factory, Dubai Office, Education City).

## People
Rex Kumar (DCS), Ahmed Ali (Operations), Mohammed Rafi (Maintenance Technician), Ramesh Kumar (Production), Rakesh Kumar (Warehouse Operator), Alex Mathew (AOI Operator), John Smith (Production Supervisor), Suresh Kumar (Warehouse), Fatima Noor (IT), Sara Khan (Finance).

## Assets (detailed records)
| ID | Name | Type / Category | Make / Model | Location | Custodian | Status |
|---|---|---|---|---|---|---|
| CNC-00123 | CNC Vertical Machining Center (VMC) | CNC Machine / Production Equipment | Haas Automation VF-3YT, SN VF3YT-2023-4587, Tag RFID-A360-000123 | Main Plant / Production Floor 1 | Ramesh Kumar (Production) | Active |
| GEN-00045 | Diesel Generator – 250 kVA | Generator | Caterpillar, SN DG2023-4587, Tag RFID-GEN-00045 | Main Plant / Building A (Generator Room GR-01) | Maintenance Department | Under Maintenance |
| GEN-00046 | Standby Diesel Generator – 250 kVA | Generator | Caterpillar, SN DG2023-4611 | Main Plant / Building A | Maintenance Department | Active |
| AHU-03 | Air Handling Unit | HVAC | Trane | Building A / Roof | Facilities | Under Maintenance |
| AHU-02 | Air Handling Unit | HVAC | Trane | Main Plant / Floor 2 | Facilities | Active |
| FL-012 | Forklift – Electric | Vehicle / Material Handling | Toyota | Main Warehouse / Zone B | Rakesh Kumar | Active |
| FL-015 | Forklift – Electric | Vehicle / Material Handling | Toyota | Main Warehouse / Zone B | Suresh Kumar | Active |
| FP-0021 | Fire Pump | Pump | Grundfos | Building B / Ground Floor – Pump Room | Facilities | Active |
| LAP-0098 | Laptop – DELL Latitude 5430 | IT Equipment | Dell, SN 5CD1234XYZ, Tag RFID-LAP-0098 | IT Store (Dubai) – Head Office, Building A, Room 101 | Unassigned | Active |
| MTR-00123 | Main Motor – Line 1 | Electric Motor / Production Equipment | Siemens IE3-315M, SN SM315-2024-1182, Tag RFID-A360-000456 | Main Plant / Production Floor 1, Dubai | Ramesh Kumar (Production) | Active |
| MTR-007 | Motor – Line 2 | Electric Motor | Siemens | Production Line 2 | Production | Active |
| CNC-021 | CNC Machine | CNC Machine | Haas | Main Plant / Production Floor 1 | Production | Active |
| CR-001 | Cold Room | Storage | — | Storage Area | Warehouse | Active |
| TL-034 | Tool Box | Tools | — | Admin Block – 2nd Floor | Maintenance | Active |
| CAB-011 | Electrical Cabinet | Electrical | — | Utility Room | Facilities | Active |
| CAM-0044 | Camera – Canon EOS R50 | IT Equipment | Canon | Marketing | Marketing | In Transit |
| DRL-0043 | Drill Machine – Bosch GSB 180 | Tools | Bosch | Building B – Floor 1 | Maintenance | Active |
| PRJ-0042 | Projector – Epson EB-FH52 | IT Equipment | Epson | Meeting Room 3 | Admin | Active |
| CH-00021 | Chiller | HVAC | Carrier | Main Plant / Roof | Facilities | Active |
| LFT-01 | Passenger Lift | Lift | Otis | Admin Building | Facilities | Active |
| FE-0042 | Fire Extinguisher | Safety | — | Building A / Floor 2 | Facilities | Active |

For **CNC-00123** add the full detail from `design/03_assets_detail_iot.jpg`:
- Barcode CNC-00123, condition Good, operational status Running, criticality High, health score 87.
- Purchased 15 Jan 2023, commissioned 28 Feb 2023, **warranty expiry 28 Feb 2027** (the design's 2026 is a mistake). Age and days remaining are computed from DemoClock.
- AMC: Yes (ABC Engineering).
- IoT device: Teltonika TRB245, Industrial Gateway, IMEI 356789123456789, ICCID 8997102056789123456, battery 85%, signal −56 dBm, firmware v1.2.5, Online, last seen 25 Sep 2026 10:24 AM.
- Telemetry: runtime 3,245 hrs, spindle 1,200 rpm, temperature 42 °C, vibration 2.3 mm/s, energy 12.5 kW, feed rate 850 mm/min, plus 24 hourly temperature points shaped like the design chart.

Give the other assets similar but lighter detail (purchase date, warranty, health score, criticality). Assets without an IoT device show "No IoT device linked" on their IoT tab.

**Org summary** (hard-coded summary figures): 12,458 assets; Active 10,842, Under Maintenance 423, Inactive 412, Retired 521, Disposed 260. Asset health 87% (Condition 85, Utilization 92, Maintenance 80, Inspection 90, IoT Status 88). Maintenance KPIs: PM compliance 92%, MTTR 1.8 hrs, WO closure 98%, avg downtime 12 hrs. Cost (AED): Maintenance 480,000, Spare Parts 220,000, Labor 180,000, Energy 160,000, Contracts/AMC 130,000, Others 80,000 (total 1.25M; percentages computed).

## Tracking summary (shared by Home and Tracking screens)
Tracked 178 = People 24 + Equipment 142 + Vehicles 12. Online 166, Offline 12, Low Battery 8, Alerts 6.
- FL-012: battery 78%, speed 5 km/h, Moving, hours used 4.2 h, load 0.8 t (so load status "Loaded"), RSSI −62 dBm, voltage 48.5 V, current 12.8 A, motor temperature 42 °C, route points on the floor plan.
- FL-015: battery 18% (the low-battery alert is this forklift).

## Maintenance work orders
- **WO-2026-0045** GEN-00045 "Generator – High vibration": Critical, In Progress, Corrective Maintenance, work type Breakdown, SLA 4 Hours (Response). Opened 25 Sep 2026 10:24 AM, **due 25 Sep 2026 11:50 AM** (so it shows "1h 20m remaining"). Assigned to Mohammed Rafi, reported by Ahmed Ali. Issue description as in the design, 2 photos (generator images).
  - 6 tasks: Arrival & Safety Check (completed 10:30 AM), Inspection & Diagnosis (in progress, checklist of 6 items as in the design with vibration 2.3 mm/s and temperature 68 °C, 4 of 6 done, note text), Repair / Replacement, Testing & Verification, Handover & Sign-off, Close Work Order (pending).
  - Parts: Bearing 6205 ×2 reserved.
  - History: created, assigned, started.
  - Documents: Maintenance_Schedule.pdf.
- WO-2026-0044 AHU-03 "No cooling": High, Assigned, due 25 Sep.
- WO-2026-0043 FP-0021 "Routine Inspection": Medium, Open, due 26 Sep.
- WO-2026-0042 CNC-00123 "Annual PM": Low, Open, due 27 Sep.
- WO-2026-0041 FL-012 "Battery Check": Medium, Open, due 27 Sep.
- WO-2026-0040, WO-2026-0039, WO-2026-0038: assigned to Rex, Open, so "My Work Orders" = 8. Add 12 PM-due and 3 overdue records so the tab counts are real.
- WO-2026-0138 CH-00021 "Chiller service" (reserved 4 × Bearing 6205).
- WO-2026-0142 GEN-00045 "Preventive Maintenance" and WO-2026-0141 FL-012 "Breakdown Maintenance" are saved offline (used by Offline Sync).
- WO-2026-0125 AHU-03: Completed.
- Home upcoming activities: PM – AHU-02 25 Sep 10:00 AM Quarterly maintenance; Safety Inspection – LFT-01 25 Sep 02:00 PM; Asset Audit – Zone A 26 Sep 09:00 AM.

## Inspections
- **INS-2026-0045** FP-0021 "Fire Pump – Routine Inspection": due 25 Sep 2026 09:00 AM, so it is Overdue and In Progress.
  - Checklist of 12 items in 4 sections exactly as in `design/09_inspection.jpg`: Visual 4 items, Performance 4, Electrical 3, Safety & Compliance 1. Performance readings: discharge pressure 7.5 bar (normal 6–9), flow rate empty (LPM), motor current 12.8 A (normal 10–14), vibration Normal.
  - Answered so far: Visual 4/4, Performance 3/4, Electrical 1/3, Safety 0/1, so 8/12 overall. **Progress numbers are always computed from answers.**
  - 1 finding; 2 photos.
- INS-2026-0044 GEN-00045 Safety Inspection: due today 04:00 PM.
- INS-2026-0043 AHU-03 HVAC Inspection: In Progress, 26 Sep, Building A / Roof.
- INS-2026-0042 FE-0042 Monthly Check: Scheduled 27 Sep.
- INS-2026-0041 FL-012 Safety & Compliance: Scheduled 28 Sep.
- Add enough other records so My Inspections, Due, Overdue and Completed counts are real.
- INS-2026-0051 Safety Inspection and INS-2026-0050 Quality Inspection are saved offline.

## Issues (22 records total: 10 Open/In Progress, 12 Resolved)
- **ISS-2026-0056** GEN-00046 "Generator not starting": Critical, Breakdown, In Progress, reported by Rex Kumar 25 Sep 10:24 AM, Main Plant / Building A, assigned Mohammed Rafi (Maintenance Team), description as in the design, 3 photos, 1 linked work order.
- ISS-2026-0055 AHU-03 "AC not cooling": High, Mohammed Rafi, 24 Sep 04:15 PM.
- ISS-2026-0054 FL-012 "Hydraulic oil leakage": Medium, Suresh Kumar, 24 Sep 02:30 PM.
- ISS-2026-0053 LAP-0098 "Laptop not charging": Low, Fatima Noor, 23 Sep 11:10 AM.
- Mark 6 issues as reported by Rex ("My Issues") and 4 as In Progress.

## Alerts (45 total: Critical 8, High 12, Medium 18, Low 7)
Include:
- Low Battery FL-015 (Critical, 5 min ago, threshold < 20%, battery 18%, 24-hour trend points falling from 95% at 00:00 to 18% at 10:24).
- Maintenance Due GEN-00045 (High, 30 min).
- Temperature Out of Range CR-001 12 °C, threshold 2–8 °C (Critical, 45 min).
- Asset Moved to Unauthorized Area TL-034 (Medium, 1 h).
- Vibration Threshold Exceeded MTR-007 8.5 mm/s (Medium, 2 h).
- Door Opened CAB-011 (Low, 3 h).
- High temperature detected (85 °C) GEN-00045 (10:24 AM).
- Vibration level above threshold CNC-021 (09:15 AM).
- Asset moved to unauthorized zone FL-012 (08:42 AM).
- Plus generated ones to reach the totals.

Notifications: 18 total, 12 unread; types System 18 and Work Orders 6 (a notification can be in both). Include the ones in `design/11_alerts_notifications.jpg`, with these corrections:
- "WO-2026-0138 assigned to you for Chiller service (CH-00021)"
- "V-Belt VB-1120 stock below reorder point" (not Bearing 6205)
- The low-battery notification is for FL-015.

The bell badge = unread notification count.

## Inventory (124 items as a summary; about 20 detailed records)
- Low Stock 8, Reorder 12, Reserved 6, detailed as far as possible.
- Air Filter Element AF-250-001 (48, In Stock, Main Warehouse).
- V-Belt VB-1120 (5, Low Stock).
- **Motor Bearing 6205 BR-6205**: Bearings, SKF, deep groove ball bearing 6205 (25×52×15 mm), unit Piece. Current stock 36, reorder level 10, reorder qty 50. Main Warehouse, Rack A-12-03, reserved 4, available 32, last update 22 Sep 2026 10:25 AM. Lead time 7 days, unit cost USD 18.50, supplier SpareTech LLC, warranty 12 months.
- Spark Plug SP-001 (0, Out of Stock, Warehouse B).
- Temperature Sensor TS-110 (3, Low Stock).

Bearing 6205 stock history (newest first, balances must add up):
- 22 Sep Received GRN-2026-0045 **+22** → 36 (from SpareTech LLC, PO-2026-0123)
- 20 Sep Issued WO-2026-0142 −2 → 14
- 18 Sep Transferred TR-2026-0031 Main Warehouse → Warehouse B −5 → 16
- 15 Sep Reserved WO-2026-0138 −4 → 21
- 10 Sep Received GRN-2026-0039 +20 → 25 (Industrial Supplies, PO-2026-0107)

## Movement requests
- MOV-2026-0045 LAP-0098 IT Store (Dubai) → Finance Department, Pending Approval, 25 Sep.
- MOV-2026-0044 CAM-0044 Marketing → Event Team, In Transit, 24 Sep.
- MOV-2026-0043 DRL-0043 Maintenance Store → Building B – Floor 1, Completed, 23 Sep.
- MOV-2026-0042 PRJ-0042 Training Room → Meeting Room 3, Completed, 22 Sep.
- Plus others so My Requests = 8 and Pending Approval = 4.
- Rex is also the approver for 2 requests (Home "Approvals: 2").

## WIP / Operations
Production orders use prefix **MO-** so they never clash with maintenance WO numbers.
- Summary: In Process 78, Completed Today 82, Delayed 16, On Hold 6; All WIP = 78 + 16 + 6 + 24 queued = 124. Show the design's "124" as All WIP.
- **MO-2026-0018** PCB Assembly – Model A: unit PCB-A-4587, BATCH-2026-0915, Internal Production, planned 500, completed 320 (64%), due 25 Sep 2026.
  - Current station AOI Line 1.
  - Operations: SMT completed 12 Sep 09:10 AM (45 min); AOI Inspection in progress, started 12 Sep 11:20 AM, operator Alex Mathew, expected 30 min, actual 18 min; Manual Assembly 60 min, Functional Testing 45 min, Packing & Labeling 20 min.
  - Location: Factory 1 > Production Floor > AOI Line 1, last scanned 12 Sep 11:38 AM by John Smith, device Station-AOI-01. 2 photos (pcb, aoi_machine).
- MO-2026-0017 Control Panel – Type B, CPB-3201, Delayed, at Testing.
- MO-2026-0016 Pump Unit – Model X, PU-7789, In Process, Testing Station 1.
- MO-2026-0015 Chiller Module, Completed.

## Documents (64 as summary: Manuals 12, Warranty 8, Certificates 14, Others 30; Expiring Soon 8, Compliant 42, Pending 6)
Detailed records for GEN-00045:
- GEN-00045_User_Manual.pdf (Manual, Operation Manual, v2.1, 3.2 MB, uploaded 20 Sep 2026 10:24 AM by Rex Kumar, description as in the design, **no expiry**)
- GEN-00045_Warranty.pdf (1.1 MB, valid till 25 Sep 2028)
- CE_Certificate.pdf (0.8 MB, 15 Jan 2025)
- Maintenance_Schedule.pdf (1.5 MB, 10 Sep 2026)
- Installation_Photo.jpg (2.4 MB, 12 Sep 2026)
- Service_Report_2026-09-12.pdf (1.8 MB)

Add a few documents for CNC-00123 and LAP-0098. Bundle one small sample PDF and one sample image in `assets/` so "View" can really open something.

## Audits
- **Annual Asset Audit 2026**, Dubai Factory, 01–30 Sep 2026, 1,500 assets. Verified 850, Wrong Location 25, Not Found 15, Unregistered 10 (so 900 done, 60%). In Progress.
- IT Equipment Audit, Dubai Office, 10–20 Sep 2026, 450 assets, Pending, 0%.
- Campus Asset Audit, Education City, 20–31 Aug 2026, 320 assets, Completed 100%.
- My Audits 3, Assigned 2, Completed 1.

## Offline sync queue (8 pending items; 33 local items, 25 synced)
WO-2026-0142, INS-2026-0051, GEN-00045 Asset Location Update, Site_Photo_01.jpg, Site_Photo_02.jpg, WO-2026-0141, INS-2026-0050, Asset_Document.pdf, with the times from `design/16_offline_sync.jpg`. Completed Locally 5, Photos to Sync 2. Last sync 22 Sep 2026 04:18 PM. Wi-Fi auto-sync ON, mobile-data sync OFF.

## Done when
- All repositories exist with seed data and mutation methods.
- There is a debug-only "Data check" screen (reachable from More → Settings → Developer) that lists every count and confirms the tab totals add up.
- `flutter analyze` is clean.
