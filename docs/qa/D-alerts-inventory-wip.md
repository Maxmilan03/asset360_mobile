# QA — Group D: Alerts, Inventory, WIP (Prompt 19)

Folders: `lib/features/alerts`, `lib/features/inventory`, `lib/features/wip`.
Tests: `test/alerts_test.dart`, `test/inventory_test.dart`, `test/wip_test.dart`.

Items marked **(fixed)** were dead, missing, or changed during this pass.

## 1. Button audit

### Alerts & Notifications (`alerts_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| Alerts | Bell icon (title row) | Pushes Notifications on the current tab |
| Alerts | Critical / High / Medium / Low tiles | Switch to that severity tab |
| Alerts | Tabs All / Critical / High / Medium / Low | Filter the list by severity (counts come from the list) |
| Alerts | Search field | Filters by asset, type and location as you type |
| Alerts | Filter button | Filter sheet (Type, Status, Date) → applies the filters |
| Alerts | Alert row tap | Opens Alert Details (in select mode: toggles the selection) |
| Alerts | Alert row long-press | Enters multi-select with that alert selected |
| Alerts | Row checkbox (select mode) | Toggles the selection |
| Alerts | Swipe row left | Acknowledges the alert and shows a SnackBar (already acknowledged/resolved → SnackBar says so) |
| Alerts | Bulk bar: Cancel | Leaves select mode |
| Alerts | Bulk bar: Acknowledge | Acknowledges the selected alerts |
| Alerts | Bulk bar: Resolve | Resolves the selected alerts |
| Alerts | Live banner: Dismiss | Hides the MaterialBanner |
| Alerts | Live banner: View | Opens the new alert's details |
| Alerts | Empty state: Clear filters | Clears the search text and filters **(fixed: new empty state + action)** |

### Alert Details (`alert_detail_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| Alert Details | Asset card | Opens Asset 360° detail |
| Alert Details | Tabs Details / History / Actions / Related Assets | Switch tab |
| Alert Details | History row | Opens that earlier alert |
| Alert Details | Related Assets row | Opens that alert |
| Alert Details | Acknowledge (bottom) | Note dialog → acknowledges and logs the action; the button then becomes Resolve |
| Alert Details | Resolve (bottom) | Note dialog → resolves the alert; the button is hidden afterwards |
| Alert Details | Note dialog Cancel / Acknowledge / Resolve | Closes the dialog; the confirm button applies the action |
| Alert Details | Create Work Order | Opens Create Work Order pre-filled (`WoPrefill(alertId:)`); the alert links to the work order |
| Alert Details | WO-… button (once linked) | Opens the linked work order |

### Notifications (`notifications_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| Notifications | ⋮ → Mark all as read | Marks all as read and shows a SnackBar with the count |
| Notifications | ⋮ → Notification settings | Opens Notification Settings |
| Notifications | Tabs All / Unread / System / Work Orders | Filter the list |
| Notifications | Notification row | Marks it read and deep-links via `notificationRoute`; with no target it shows the message in a SnackBar |
| Notifications | Swipe row left | Deletes it, with a SnackBar **Undo** that restores it at the same position |
| Notification Settings | Category switches | Turn that category on or off and show a SnackBar |
| Notification Settings | Quiet hours switch | Turns quiet hours on or off |
| Notification Settings | From / To rows | Time picker → saves the time (disabled while quiet hours are off) |

### Inventory hub (`inventory_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| Inventory | "?" help | Help sheet (counts now computed: total items / detailed records) **(fixed: no hard-coded numbers)** |
| Inventory | View Inventory tile | Switches to All Items |
| Inventory | Request Part tile | Opens My Requests (with the Request Part button) |
| Inventory | Purchase Orders tile | Opens the Purchase Orders list |
| Inventory | Stock Reports tile | Opens Stock Reports |
| Inventory | Tabs All Items / Low Stock / Reorder / Reserved | Filter the list |
| Inventory | Search / Filter (Category, Warehouse, Stock status) | Filter the list |
| Inventory | Part row | Opens Part Details |
| Inventory | Empty state: Clear filters | Clears the search and filters **(fixed)** |

### Part Details (`part_detail_screen.dart`, `inventory_actions.dart`)

| Screen | Element | Action |
|---|---|---|
| Part Details | Camera icon (before the title) | Scans a part label (camera or demo chips) → opens that part; an unknown code or the same part shows a SnackBar **(fixed: was a dead icon)** |
| Part Details | ⋮ → Issue to Work Order | Sheet: choose WO + qty → `issuePart` (stock and ledger update) |
| Part Details | ⋮ → Stock Count Adjustment | Sheet: counted qty + reason → adjusts stock with a ledger entry |
| Part Details | ⋮ → Stock Movement | Opens Stock Movement for the part |
| Part Details | Part card (chevron) | Specification sheet |
| Part Details | Stock Overview: Edit | Edit reorder level / qty sheet (validated) |
| Part Details | Current Stock tile | Opens Stock Movement |
| Part Details | Reorder Level / Reorder Qty tiles | Edit levels sheet |
| Part Details | Location Details: Manage | Sheet: Change Bin or Transfer Stock (qty + destination) |
| Part Details | Manage sheet segment buttons | Switch between Change Bin and Transfer Stock |
| Part Details | Reserved Qty row (chevron) | Stock Movement → Reserved tab |
| Part Details | Stock Movement (n) button | Opens Stock Movement |
| Part Details | Create Request | Request Part form pre-filled with this part |
| Part Details | Create Purchase Order | PO form pre-filled (supplier, reorder qty, cost, lead-time date) |

### Stock Movement (`stock_movement_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| Stock Movement | Camera icon | Scans a part label → opens that part **(fixed: was a dead icon)** |
| Stock Movement | Part card | Opens Part Details |
| Stock Movement | Tabs Stock History / Usage / Reserved / Purchase Orders | Switch tab |
| Stock Movement | Search / Filter (Type, Date) | Filter the ledger |
| Stock Movement | REF: link | WO → work order; PO → purchase order; GRN → goods-receipt sheet; other → SnackBar that explains the reference |
| Stock Movement | GRN sheet: Open PO-… | Opens the purchase order |
| Stock Movement | Reserved: WO row | Opens the work order |
| Stock Movement | Reserved: Release | Confirm → removes the part from the WO; stock becomes available again |
| Stock Movement | Reserved: Other reservations → Release | Releases the reservations that have no WO |
| Stock Movement | Purchase Orders row | Opens the PO |
| Stock Movement | Create Purchase Order | PO form for the part |
| Stock Movement | Empty state: Clear filters | Clears the search and filters **(fixed)** |

### Procurement (`procurement_screens.dart`)

| Screen | Element | Action |
|---|---|---|
| Purchase Orders | Chips All / Open / Received | Filter the list |
| Purchase Orders | PO row | Opens PO detail |
| Purchase Orders | + FAB | New Purchase Order form |
| Purchase Orders | Empty state: New Purchase Order | Opens the PO form **(fixed: list had no empty state)** |
| PO detail | Receive (GRN) | Confirm → `receivePo` (stock + ledger) → goods-receipt sheet |
| PO detail | Part row | Opens Part Details |
| PO detail | Goods receipt GRN-… | Goods-receipt sheet |
| PO form | Part field | Searchable part picker → fills supplier, qty, cost and date |
| PO form | Qty / Unit cost | Total updates live |
| PO form | Expected date | Date picker |
| PO form | Create PO · total | Validates → creates the PO → success sheet (View PO / Done) |
| My Requests | Request Part (bottom) | Request Part form |
| My Requests | Pending request row | Confirm → cancels the request |
| My Requests | Other request row | Opens Part Details |
| My Requests | Empty state: Request Part | Request Part form **(fixed)** |
| Request Part | Part field / Needed by / WO / Reason | Part picker, date picker and dropdowns |
| Request Part | Submit Request | Validates → creates the request → success sheet → My Requests |
| Stock Reports | Top-5 row | Selects that part for the forecast (dropdown syncs; a SnackBar confirms) **(fixed: dropdown did not follow the tap)** |
| Stock Reports | Forecast part dropdown | Changes the forecast part |
| Stock Reports | Open part | Opens Part Details |

### WIP / Operations hub (`wip_hub_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| WIP | "?" help | Help sheet (figures now computed from the summary) **(fixed: no hard-coded numbers)** |
| WIP | KPI tiles WIP in Process / Completed Today / Delayed / On Hold | Switch to that view (On Hold shows a removable chip) |
| WIP | On Hold chip ✕ | Back to All WIP |
| WIP | Scan to Move | Scan the unit serial → sheet (current/next station, progress) → Move to next station (confirm + QC) or Open WIP Tracking |
| WIP | Start Operation | Sheet of startable orders → starts the next operation |
| WIP | End Operation | Sheet of running operations → End sheet (good/scrap qty, QC pass/fail with note) |
| WIP | Report Issue | Report Issue pre-filled with the running MO (Production type); with nothing running it opens a blank report |
| WIP | Tabs All WIP / In Process / Completed / Delayed | Switch view |
| WIP | Search / Filter (Status, Area) | Filter the list |
| WIP | MO row | Opens the Production Order |
| WIP | "Serial No" link in a row | Opens WIP Tracking for the unit |
| WIP | Empty state: Clear filters | Clears the search and filters **(fixed)** |

### WIP Tracking (`wip_unit_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| WIP Tracking | "?" help | Help sheet |
| WIP Tracking | Unit card | Opens the Production Order |
| WIP Tracking | Tabs Overview / Process Flow / Location History / Documents | Switch tab |
| WIP Tracking | Current Operation: Edit | Sheet: operator + expected duration → saves |
| WIP Tracking | Operator name | Opens the user's admin profile |
| WIP Tracking | Photo zoom button | Full-screen photo viewer |
| WIP Tracking | Location Details: View on Map | Opens Tracking |
| WIP Tracking | Scan button (location row) | Scans a station tag → records the scan (warns when the station is not the expected one) |
| WIP Tracking | Photos: Add Photo | Camera/gallery → adds the photo to the unit |
| WIP Tracking | Location History empty: Scan station tag | Scans a station tag **(fixed: new action)** |
| WIP Tracking | Document tile | Attachment preview |
| WIP Tracking | Move to Next Operation | Confirm → "Passed quality check?" (Yes, or No + note → red step + finding + Delayed) |
| WIP Tracking | Report Issue | Report Issue pre-filled with the MO/unit |

### Production Order (`production_order_screen.dart`)

| Screen | Element | Action |
|---|---|---|
| Production Order | "?" help | Help sheet |
| Production Order | "Unit … – open WIP Tracking" link | Opens WIP Tracking |
| Production Order | Tabs Operations / Components / Resources / Quality / Notes | Switch tab |
| Production Order | View (done operation) | Operation detail sheet |
| Production Order | Start | Starts the operation (only the next one in sequence is enabled) |
| Production Order | Pause / Resume (running operation) | Pauses or resumes the operation |
| Production Order | End (running operation) | End sheet (good/scrap, QC) |
| Production Order | Rework (failed operation) | Restarts the operation as rework |
| Production Order | Component row | Opens Part Details |
| Production Order | Issue from Inventory | Issues the outstanding qty from stock (ledger: issued to production) |
| Production Order | Notes: send | Adds the note; an empty note shows a "Type a note first" SnackBar **(fixed: silent no-op)** |
| Production Order | Pause WO | Reason sheet → order On Hold |
| Production Order | Resume (on hold) | Resumes the order |
| Production Order | Complete Work Order | Every operation done → confirm → success sheet; otherwise a SnackBar shows "n of m done" |

No empty, `() {}`, TODO-only or print-only handlers remain in these folders.

## 2. Design check

| Design | Screen | Result |
|---|---|---|
| 11 left | Alerts | Section order, tiles, tab labels and counts, search hint, row layout (icon square · photo · type · "ID \| type" · location · severity chip · time ago · chevron) match. The **bell icon** in the title row and the "Swipe left …" hint are kept (extra, both functional). Counts come from mock data (rule 2/3). |
| 11 middle | Alert Details | Banner, asset card, tabs, InfoRows and the trend chart match. A second **status chip** (Active / Acknowledged / Resolved) is kept in the banner, and after a WO is created the bottom button shows the WO number (intentional). |
| 11 right | Notifications | "All" tab without a count, counted Unread / System / Work Orders, unread red dot and chevron match. Read rows now use `AppColors.surface` instead of `Colors.white` **(fixed: dark theme)**. |
| 12 left | Inventory | Help "?", 2×2 tiles, tabs, search, row layout and "Showing X of Y" match. |
| 12 middle | Part Details | Camera icon before the title is now a real button **(fixed)**. Stock Overview / Location / Additional Information and the two bottom buttons match. Numbers follow the mock ledger (BR-6205: 36 stock, 6 reserved, 30 available), so the design's "Reserved 4 / Available 32" is **intentionally not copied** (prompt 14 correction). |
| 12 right | Stock Movement | Camera icon is now a button **(fixed)**. Tabs, search hint and ledger rows (REF link, From/To/Asset, signed qty, Balance) match. The design's balances are inconsistent, so the mock ledger wins. |
| 13 left | WIP hub | KPI tiles, the 4 action tiles, tabs (All WIP / In Process / Completed / Delayed), search hint, MO rows with station progress match. Order numbers use **MO-** instead of the design's WO- (prompt 15 correction, kept). |
| 13 middle | WIP Tracking | Header card, tabs, step flow with times, Current Operation (Edit), Location Details (View on Map, scan button), Photos (Add Photo) and the bottom buttons match. Label "Production Order" instead of "Work Order" is kept. |
| 13 right | Production Order | Header with progress ring, tabs, numbered operation rows with View/Start, and the bottom "Pause WO" / "Complete Work Order" buttons match the design wording. The page title "Production Order" (prompt 15) is kept. |

Spacing, radii (cards 14, tiles 12) and colours all come from `AppColors` / `AppRadius`; no differences were found.

## 3. Robustness

- **Lazy lists:** the Alerts, Notifications, Inventory, Stock Movement (history), Purchase Orders, My Requests and WIP hub lists are now `SliverList.separated` inside one card (`SliverCardList`, new in `alerts/sliver_card_list.dart`), using `CustomScrollView` + `SliverMainAxisGroup` (`LazyListPage`). The page header still scrolls with the list.
- **Loading shimmer:** every main list uses `SliverLoadingGate` (a sliver twin of `LoadingGate`; same `LoadingGate.delay`, same `ListSkeleton`). Tab lists use `LoadingGate`: Alert Details History / Related; Stock Movement Usage / Reserved / POs; WIP Tracking Location History / Documents; Production Order Operations / Components / Resources / Quality.
- **Empty states:** every list shows `EmptyState`, with "Clear filters" when a search or filter caused it. Added for Purchase Orders, and for Production Order components / quality / notes (these were plain text before).
- **Ellipsis added:** asset ID (Alert Details), part name (PartCard), ledger type / From / To / PO / Asset lines (TxnRow), PO subtitle, request title/subtitle, Stock Reports names, MO id / serial (MoRow), unit serial, MO id / product, operation names, Location History titles.
- **Hard-coded data removed:** the Inventory and WIP help texts now use the summary figures. Stock Reports no longer hard-codes `'BR-6205'`: it defaults to the most-consumed part, which is null-safe.
- **Forms / keyboard:** every form is a scrolling `ListView` inside `AppScaffold`. All sheets use `sheetFrame`, which pads by `viewInsets` and scrolls.
- **Back navigation:** every pushed screen uses `AppScaffold` (AppHeader back). Sheets and dialogs use the tab navigator.
- **Tests:** the 360×640 (1080×1920 @3) and 430×932 (1290×2796 @3) layout tests open every screen in each module. Alert Details, WIP Tracking and Production Order also open each of their tabs. A new inventory test checks the skeleton → content step and the empty state → Clear filters.

## 4. Results

- `flutter analyze` on the three folders and three test files: no issues.
- `flutter test test/alerts_test.dart test/inventory_test.dart test/wip_test.dart`: all 18 tests pass.
