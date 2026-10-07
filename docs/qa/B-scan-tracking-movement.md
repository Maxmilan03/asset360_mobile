# QA report — Group B: Scan, Tracking, Movement, Common

Folders: `lib/features/scan`, `lib/features/tracking`, `lib/features/movement`, `lib/features/common`
Tests: `test/scan_test.dart`, `test/tracking_test.dart`, `test/movement_test.dart` (24 tests, all passing)

## 1. Button audit

No handler was empty, `() {}`, TODO or print-only. Every element below does something real.
"(fixed)" marks an element that was added or given a handler during this pass.

### Scan & Identify (`scan/scan_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Scan & Identify | History icon (badge = scan count) | Pushes Scan History on the current tab |
| Scan & Identify | Mode tabs QR / Barcode, NFC, RFID, BLE | Switches mode; NFC/RFID start a simulated 2 s tag read, BLE a 3 s beacon search |
| Scan & Identify | Camera (auto-detect) | A code in the frame opens it through `openScannedCode` (adds to history, then routes) |
| Scan & Identify | Flash button | Toggles the camera torch (greyed out when there is no torch) |
| Scan & Identify | Gallery button | image_picker → reads a QR/barcode in the photo and opens it, or shows "No QR code found" |
| Scan & Identify | "Simulate scan" chip (debug builds) | Opens MTR-00123 as if scanned |
| Scan & Identify | Shutter "Tap to Scan" / "Tap to Read" / "Rescan" | QR: opens the code in view or looks for 3 s. NFC/RFID: starts a read. BLE: searches again |
| Scan & Identify | Manual Entry | Manual Entry sheet → opens the typed code |
| Scan & Identify | Multi Scan / Done | Turns on Multi Scan; Done opens the Multi Scan summary |
| Scan & Identify | Multi Scan chip ✕ | Removes that asset from the batch |
| Scan & Identify | Multi Scan strip "Done" | Opens the Multi Scan summary |
| Scan & Identify | BLE beacon card | Identifies that asset (Asset Identified) |
| Scan & Identify | BLE empty state (no beacons) (fixed: new) | Tells the user to tap Rescan |
| Scan & Identify | Camera error "Open Settings" | Opens the app settings, or shows a SnackBar with the path |
| Scan & Identify | Camera error "Enter ID manually" | Manual Entry sheet |
| Scan & Identify | Camera error "Try again" | Restarts the camera |

### Sheets from `scan/scan_flow.dart`
| Screen | Element | Action |
|---|---|---|
| Tag not registered sheet | Register this asset | Opens New Registration, with the barcode or tag filled in |
| Tag not registered sheet | Scan again | Closes the sheet |
| Manual Entry sheet | Asset ID field (type / submit) | Suggests up to 5 matches; Enter submits |
| Manual Entry sheet | Clear ✕ | Clears the field |
| Manual Entry sheet | Suggestion row | Submits that asset ID |
| Manual Entry sheet | Find Asset | Submits the typed code (disabled while empty) |
| Multi Scan summary | Move | Opens Transfer Asset with every scanned asset (`?assets=`) |
| Multi Scan summary | Audit | Marks every asset Verified in your open audit (asks which one if you have several), then opens the audit session |
| Multi Scan summary | Keep scanning | Closes the sheet and keeps the batch |
| Add to Audit sheet | Audit row | Picks that audit for the bulk Verify |

### Asset Identified (`scan/scan_result_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Asset Identified | Asset card (chevron) | Opens Asset 360° |
| Asset Identified | View Details | Opens Asset 360° |
| Asset Identified | Create Work Order | Opens Create Work Order for this asset |
| Asset Identified | Create Inspection | Opens Create Inspection for this asset |
| Asset Identified | Move Asset | Opens Transfer Asset for this asset |
| Asset Identified | Report Issue | Opens Report Issue for this asset |
| Asset Identified | Check Out | Opens the Check Out sheet (`assetActions`) |
| Asset Identified | View on Map | Opens Asset Tracking |
| Asset Identified | Add Photo | Photo picker (camera / gallery) → photo added to the asset |
| Asset Identified | More Actions | More Actions sheet (Print QR Tag and the rest) |
| Asset Identified (not found) | Back to Scan | Goes back to the scanner |

### Scan History (`scan/scan_history_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Scan History | Clear All | Confirm dialog → empties the history (SnackBar if it is already empty) |
| Scan History | Filter chips All / Assets (n) / Parts (n) / Locations (n) | Filters the list (counts come from the list) |
| Scan History | Asset row | Opens Asset 360° |
| Scan History | Part row | Opens Part Detail |
| Scan History | Location row | Opens Tracking & IoT |
| Scan History | Deleted-record row | SnackBar saying the record was deleted from the register |
| Scan History | Swipe a row left | Removes it, with an Undo SnackBar |
| Scan History | Empty state "Scan now" | Goes back to the scanner |

### Client demo scan (`scan/demo_scan_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Demo Scan | Camera (auto-detect) | Opens the result sheet (asset, or "Tag not registered") |
| Demo Scan | Flash | Toggles the torch |
| Demo Scan result sheet | Scan Again | Closes the sheet and restarts the camera |

### Tracking & IoT hub (`tracking/tracking_hub_screen.dart`, `tracking_map.dart`, `tracking_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Tracking & IoT | Help (?) on the title | Help sheet |
| Tracking & IoT | Tabs Live Map / Asset List / Sensors / Geofencing | Switches the tab |
| Tracking & IoT | Search field | Filters pins (Map) or rows (Asset List) |
| Tracking & IoT | Filter button (Map) | Filter sheet: Type / Zone / Status |
| Tracking & IoT | Counters Online / Offline / Low Battery / Alerts | Toggles that filter on the map and the list |
| Tracking & IoT | Map pin | Selects it and shows a callout (tap again to hide) |
| Tracking & IoT | Callout (chevron) | Opens Asset Tracking, or a SnackBar for a person or pallet that has no asset record |
| Tracking & IoT | Layers | Layers sheet: People / Equipment / Vehicles / Alerts / Zones switches + Apply |
| Tracking & IoT | 2D / 3D | Tilts the floor plan |
| Tracking & IoT | Zoom + / − and pinch | Zooms the plan |
| Tracking & IoT | Chips All / People / Equipment / Vehicles | Filters the pins by kind |
| Tracking & IoT | Recent Activity "View All" | Opens the Activity Log |
| Tracking & IoT | Activity row | Opens Asset Tracking, or a SnackBar with the event details |
| Tracking & IoT › Asset List | Row | Opens Asset Tracking |
| Tracking & IoT › Sensors | Sensor card (chevron) | Opens the full-screen telemetry chart for that sensor |
| Tracking & IoT › Geofencing | Map pin (fixed) | SnackBar naming the geofences the pin is inside (it was not tappable before) |
| Tracking & IoT › Geofencing | Add Zone | Opens Add Zone |
| Tracking & IoT › Geofencing | Alert on exit / Alert on entry switch | Saves the setting + SnackBar |
| Tracking & IoT › Geofencing | Empty state "Add Zone" (fixed: new) | Opens Add Zone |

### Asset Tracking (`tracking/asset_tracking_screen.dart`, `telemetry_view.dart`)
| Screen | Element | Action |
|---|---|---|
| Asset Tracking | Asset card (chevron) | Opens Asset 360° |
| Asset Tracking | Tabs Live Tracking / Details / Telemetry / History / Geofence | Switches the tab |
| Asset Tracking › Live | Own pin | SnackBar with the zone and status |
| Asset Tracking › Live | Other pin | Opens that asset's tracking, or a SnackBar |
| Asset Tracking › Live | Layers / 2D-3D / Zoom | Same as the hub map |
| Asset Tracking › Live | KPI tile (Speed, Battery …) | Switches to the Telemetry tab |
| Asset Tracking › Live | View History | Route playback sheet (vehicles), or the History tab |
| Asset Tracking › Live | Create Work Order | Opens Create Work Order for this asset |
| Asset Tracking › Live (no tracker) | Link IoT Device | Link IoT sheet |
| Asset Tracking › Details | Open Asset 360° | Opens Asset 360° |
| Asset Tracking › Telemetry | Range dropdown | Changes the range (1 h / 24 h / 7 d / 30 d) |
| Asset Tracking › Telemetry | Metric tile | Charts that metric; a value-only tile (e.g. Location) shows a SnackBar with the value |
| Asset Tracking › Telemetry | Sensor History "View All" | Full-screen chart for the metric and range |
| Asset Tracking › Geofence | Zone switch | Allows or blocks the asset in that zone + SnackBar |
| Route playback sheet | Range dropdown | Loads that range |
| Route playback sheet | Play / Pause | Animates the route |
| Route playback sheet | Slider | Scrubs to a time |
| Telemetry chart screen | Range chips | Changes the range |
| Telemetry chart screen | Chart touch / pinch | Shows a tooltip / zooms |
| Asset not found | Back | Pops |

### Activity Log and Add Zone (`tracking/tracking_pages.dart`)
| Screen | Element | Action |
|---|---|---|
| Activity Log | Activity card | Opens Asset Tracking, or a SnackBar with the event |
| Add Zone | Zone name field | Typing clears the error |
| Add Zone | Drag on the plan | Draws the zone rectangle |
| Add Zone | Clear | Clears the drawing (disabled until something is drawn) |
| Add Zone | Save Zone | Checks the name and the drawing, adds the geofence, SnackBar, goes back |

### Movement & Custody hub (`movement/movement_hub_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Movement & Custody | Help (?) | Help sheet |
| Movement & Custody | Transfer Asset tile | Opens Transfer Asset |
| Movement & Custody | Check Out tile | Opens Check Out |
| Movement & Custody | Check In tile | Opens Check In |
| Movement & Custody | Assign Custodian tile | Opens Assign Custodian |
| Movement & Custody | Return Asset tile | Opens Return Asset |
| Movement & Custody | Movement History tile | Opens Movement History |
| Movement & Custody | Tabs My Requests (n) / Pending Approval (n) / Completed | Switches the list |
| Movement & Custody | Search | Filters by asset ID, asset name or request number |
| Movement & Custody | Filter | Filter sheet: Status / Type / Date |
| Movement & Custody | Request row (chevron) | Opens Request detail |

### Transfer Asset (`movement/transfer_asset_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Transfer Asset | Completed step in the stepper | Goes back to that step |
| Transfer Asset | Scan Asset / Search Asset / My Assets toggle | Switches how you pick the asset |
| Transfer Asset | "Tap to Scan" box | Camera scan capture → selects the asset |
| Transfer Asset | Search field / result row | Searches / selects the asset |
| Transfer Asset | My Assets row | Selects the asset |
| Transfer Asset | Enter Asset ID Manually | Manual Entry sheet → selects the asset |
| Transfer Asset | Selected Asset card (chevron) | Opens Asset 360° |
| Transfer Asset › From | Change / Done | Edits the current location and custodian |
| Transfer Asset › From | Location / Custodian dropdowns | Overrides the prefilled values |
| Transfer Asset › To | Location / Department / Person toggle | Switches the destination type |
| Transfer Asset › To | Site › Building › Floor › Zone, Department, Person dropdowns | Picks the destination (dependent lists) |
| Transfer Asset › Details | New Custodian / Reason dropdowns | Pick the value |
| Transfer Asset › Details | Required Date | Date picker (today or later) |
| Transfer Asset › Details | Add File | file_picker → attachment added |
| Transfer Asset › Details | Attachment ✕ / tap | Removes it / opens the preview |
| Transfer Asset › Review | Edit (Transfer Summary) | Goes to step 1 |
| Transfer Asset › Review | Edit (Details, Attachments) | Goes to step 4 |
| Transfer Asset › Review | Asset row | Opens Asset 360° |
| Transfer Asset | Back (bottom) / system back | Previous step; on step 1 leaves the screen |
| Transfer Asset | Next | Checks the step and goes on |
| Transfer Asset | Submit for Approval | Creates one request per asset → success sheet → Movement & Custody |

### Custody screens (`movement/custody_screen.dart`, `AssetChooser` in `movement_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Check Out / Assign / Return | Scan Tag | Camera scan capture → selects the asset |
| Check Out / Assign / Return | Search / Change | Asset picker sheet (Check In: only checked-out assets) |
| Check Out / Assign / Return | ID | Manual Entry sheet |
| Check Out / Assign / Return | Selected asset card | Opens Asset 360° |
| Check In | Checked-out asset row | Selects it (radio) |
| Check Out | Custodian dropdown, Expected return date, Purpose | Fill in the form |
| Check In / Return | Condition chips | Pick the condition |
| Check In | Add photo / remove photo | Photo picker / removes the photo |
| Assign Custodian | Person dropdown, Effective date | Fill in the form |
| Return Asset | Return to dropdown | Picks the location |
| All custody screens | Confirm <action> | Checks the form → confirm dialog → movement record + asset updated → success sheet → back |
| All custody screens | Movement History link | Opens Movement History |

### Request detail and Movement History (`movement/movement_pages.dart`, `movement_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Request detail | Approve (approver) | Approves the request + SnackBar |
| Request detail | Reject (approver) | Dialog that requires a reason → rejects + SnackBar |
| Request detail | Cancel Request (requester) | Confirm dialog → cancels |
| Request detail | Mark In Transit (approved) | Sets the request In Transit |
| Request detail | Mark as Received (in transit) | Confirm dialog → completes the request; the asset's location and custodian update |
| Request detail | Asset row in the summary | Opens Asset 360° |
| Request detail | Attachment tile | Attachment preview |
| Request detail | Photo | Photo viewer |
| Movement History | Type chips (All, Transfer, Check Out …) | Filters by type |
| Movement History | Date range button | Date range picker |
| Movement History | Clear dates ✕ | Clears the range |
| Movement History | Today / Last 7 days / Last 30 days chips | Sets the range |
| Movement History | Record | Opens Request detail |

### Common (`common/`)
| Screen | Element | Action |
|---|---|---|
| Asset picker sheet | Search field | Filters the assets |
| Asset picker sheet | Asset row | Returns the asset |
| Location picker sheet | Site / Building / Floor nodes | Expand or collapse |
| Location picker sheet | Zone row | Returns "Building / Floor – Zone" |
| Scan capture page | Close (app bar) | Pops with no result |
| Scan capture page | Torch | Toggles the torch |
| Scan capture page | Camera (auto-detect) | Returns the code |
| Scan capture page | Demo tag chips | Returns that code |
| Scan capture page | Enter code manually | Dialog → returns the code (fixed: the dialog now owns its controller, so it is no longer disposed during the closing animation) |

## 2. Design check

- **05 Scan & Identify:** the layout, mode tabs, violet corner frame, flash and gallery buttons, Manual Entry / Tap to Scan / Multi Scan, the Asset Identified banner + card + 3×3 action grid, and Scan History (Clear All, filter chips, rows with a status chip and time) all match the design.
  - Kept on purpose: the design's chip counts (Assets 8 / Parts 2 / Locations 1) and GEN-01. The counts come from the mock history (6 / 0 / 0) and the ID is GEN-00045 (rule 2).
- **06 Tracking & IoT:**
  - Changed: Recent Activity now matches the design, with the header on the page and each event in its own card. It used to be a single section card with dividers. The Activity Log uses the same cards.
  - Kept on purpose: counters 166 online and others, chip counts People 24 / Equipment 142, and the ID FL-012. The design shows FLT-012, 152, 98 and so on; the mock data wins.
  - Everything else matches: four hub tabs, counters, map controls (layers, 2D, zoom), the callout, the Asset Tracking card, the 5 tabs, the 3×2 KPI tiles, View History / Create Work Order, the telemetry grid and Sensor History with View All.
- **07 Movement & Custody:** the 3×2 action tiles (same tones and icons), My Requests (n) / Pending Approval (n) / Completed tabs, search + filter, request rows with From / To and status chip + date, the 5-step stepper, Scan / Search / My Assets toggle, the dashed scan box, OR + Enter Asset ID Manually, the Selected Asset card, and the Review sections with Edit links, From → To cards and Back / Submit for Approval all match.
  - Kept on purpose: the request numbers and counts come from the mock data.

## 3. Robustness

- **Overflow tests:** a new test in each module file opens every main screen and tab at 360×640 (1080×1920 @3x) and at 430×932 (1290×2796 @3x), and asserts `takeException()` is null.
  - Scan: all four modes, a NFC/RFID result, the Multi Scan strip and summary, Asset Identified, Scan History.
  - Tracking: 4 hub tabs, 5 asset tabs, chart, activity, Add Zone, and Add Zone with the keyboard up.
  - Movement: hub, transfer with 1 asset and with several, transfer steps 1→3, request detail, history, and the 4 custody screens.
- **Add Zone with the keyboard:** below 420 px of height the page now scrolls and the plan keeps a fixed 260 px. It could overflow before. With room to spare, the plan still fills the page and the drag still draws.
- **Ellipsis added:**
  - Scan: BLE beacon ID, the Asset Identified card (ID, name, type, site), the demo scan result, the Add to Audit rows.
  - Tracking: the asset card ID and name, sensor name and threshold, geofence names on the hub and the asset tab, activity titles.
  - Movement: Movement Summary ID and name, PlaceCard name and lines, Selected Asset ID, Movement History title, route and meta, the date-range button.
- **Loading shimmer (`LoadingGate`) added to:**
  - Scan History
  - Tracking › Asset List, Tracking › Sensors, Tracking › Geofencing zone list
  - Asset Tracking › History
  - Activity Log
  - the Movement hub list (re-keyed per tab, so it shows on each tab change)
  - Movement History
- **Empty states:**
  - New: BLE "No beacons nearby", Recent Activity, Sensors, Geofencing (with Add Zone), Activity Log.
  - Already there: Scan History, Asset List, the movement tabs, Movement History, zone history, telemetry, the asset picker.
- **Lazy lists:** Scan History and the Activity Log (both can grow without limit) now use `ListView.separated` / `ListView.builder` under a fixed header. The asset picker was already lazy.
  - The hub lists (tracked sample, movement requests, sensors, geofences) are short mock samples inside the page's scrolling ListView. They stay eager so the tiles and tabs above them scroll with the page.
- **Back:** every pushed screen uses AppScaffold (header back). Transfer's back steps through the wizard via PopScope.
- **Forms:** all forms sit in a ListView inside AppScaffold, which resizes for the keyboard. Sheets use `sheetFrame`, which pads by viewInsets.

## 4. Requests for shared files (not done; outside this group)

> Update (integration pass): all of these were made — see `docs/QA_REPORT.md` → Shared changes.


- `lib/core/widgets/loading_list.dart` — `ListSkeleton`'s Column overflows when it sits in a bounded box shorter than `rows` × ~78 px. This happens when a LoadingGate fills an `Expanded` on a 360×640 phone. Wrap the Column in `SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: …)` or a `ClipRect` + `OverflowBox(alignment: Alignment.topCenter, maxHeight: double.infinity)`. Until then, the Activity Log uses `rows: 4`.

## 5. Results

- `flutter analyze lib/features/{scan,tracking,movement,common}`: no issues.
- `flutter test test/scan_test.dart test/tracking_test.dart test/movement_test.dart`: 24/24 passed.
