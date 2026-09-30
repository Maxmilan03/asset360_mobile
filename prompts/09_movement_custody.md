# PROMPT 09 — Movement & Custody (design/07_movement_custody.jpg)

Follow `CLAUDE.md`. Build the 3 screens plus the other actions from the hub.

## Screen 1 (left): Movement & Custody hub
- 6 action tiles, each opening a working flow:
  - **Transfer Asset** → the 5-step flow below.
  - **Check Out:** pick asset (scan/search) → custodian → expected return date → purpose → confirm. The asset's custodian changes and a movement record is added.
  - **Check In:** list of checked-out assets; pick one → condition + remarks + photo → confirm, which clears the custodian.
  - **Assign Custodian:** pick asset → pick person → effective date → confirm.
  - **Return Asset:** pick asset → return-to location → condition → confirm.
  - **Movement History:** timeline of all movement records, with filters by date and type.
- Tabs: **My Requests (8)** / **Pending Approval (4)** / **Completed**, with counts computed.
- Search (asset ID, name, request no.) and filter sheet (status, date range, type).
- Request rows: photo, MOV number, asset, From → To, status chip, date. Tap → Request detail (the Review layout in read-only mode, plus a status timeline Submitted → Approved → In Transit → Completed).
  - While Pending, show a "Cancel Request" action.
  - When Rex is the approver, show Approve / Reject.
  - In Transit shows "Mark as Received".

## Screen 2 (middle): Transfer Asset, step 1 "Select Asset"
- StepperHeader: Asset, From, To, Details, Review.
- Toggle: **Scan Asset** (selected) / Search Asset / My Assets.
  - Scan: the big dashed violet box "Tap to Scan QR / Barcode / RFID" opens the scanner and returns the asset.
  - Search: a search field with results.
  - My Assets: assets where Rex is custodian.
- "OR" divider, then **Enter Asset ID Manually** (sheet with autocomplete).
- **Selected Asset** card: photo, ID, name, serial, current location, current custodian, status chip. Tap → Asset detail.
- **Next →** is disabled until an asset is selected.
- **Step 2 From:** prefilled with the current location and custodian (read-only, with "Change" if wrong).
- **Step 3 To:** destination type (Location / Department / Person), then cascading Site → Building → Floor/Room, or a department or person picker.
- **Step 4 Details:** new custodian, required date (date picker, not in the past), reason dropdown (Department Transfer, Repair, Project, Return, Other), remarks, attachments (file_picker).
- Completed steps show ✓ in the stepper (the design's review screen forgot this; show ✓ on steps 1–4).

## Screen 3 (right): Review, step 5
- Transfer Summary card with Edit → step 1.
- Asset photo, ID, name, status and info rows.
- Transfer Details: From card → arrow → To card, New Custodian ("Sara Khan (Finance)" in the example), Required Date, Reason, Remarks; Edit → step 4.
- Attachments (n): file row with size; tap to preview; Edit → step 4.
- **Back** / **Submit for Approval**: creates a new MOV-2026-00xx record with status Pending Approval, shows a success sheet with the request number, and returns to the hub with My Requests updated.

## Done when
Every hub tile runs its own complete flow, requests can be approved/rejected/received, and statuses and counts update everywhere, including Home Approvals.
