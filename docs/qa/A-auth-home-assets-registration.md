# QA — Group A: Auth, Home, Assets, Registration (Prompt 19)

Folders: `lib/features/auth`, `lib/features/home`, `lib/features/assets`, `lib/features/registration`.
Tests: `test/auth_flow_test.dart`, `test/home_test.dart`, `test/assets_test.dart`, `test/registration_test.dart`.

**Result:** none of the handlers were empty, `() {}`, TODO or print-only. One element looked tappable but did nothing
in one case: History tab rows for movement events had no route, so they are now linked (marked **(fixed)**).
Every tap below was checked in the code. "Demo" means a simulated process that ends with a SnackBar or sheet saying
what happened.

## 1. Button audit

### Login (`auth/login_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Login | Language pill "English ▾" | Opens the Language sheet |
| Login | Language sheet → English | Closes the sheet (already selected) |
| Login | Language sheet → العربية | Closes the sheet and shows the SnackBar "Arabic will be available in a later release" |
| Login | Username field (Next on keyboard) | Moves focus to Password |
| Login | Password field (Done on keyboard) | Signs in (unless locked or already loading) |
| Login | Eye icon | Shows or hides the password |
| Login | Remember me checkbox / label | Turns Remember me on or off |
| Login | "Forgot Username or Password?" | Pushes Forgot Password |
| Login | Sign In | Validates, waits 1 s, then signs in → Authenticator. Wrong details show an error with attempts left; 5 failures lock sign-in for 30 s with a countdown |
| Login | Sign in with Google / Microsoft | Shows a "Connecting to …" dialog for 1.5 s, then opens Authenticator |
| Login | "New to Asset360? Contact your administrator." | Opens the admin contact sheet |
| Login | Contact sheet → Copy (Email / Phone) | Copies the value to the clipboard and shows a SnackBar |

### Forgot Password (`auth/forgot_password_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Forgot Password | Back arrow | Pops to Login (or goes to Login) |
| Forgot Password | Email field (Send on keyboard) | Sends the instructions |
| Forgot Password | Reset my password / Recover my username radio cards | Selects what you need help with |
| Forgot Password | Send Instructions | Validates the email, simulates sending for 1.2 s, then opens the "Check your inbox" sheet with the masked email |
| Forgot Password | Sheet → Back to Login | Closes the sheet and returns to Login |
| Forgot Password | "‹ Back to Login" | Returns to Login |

### Authenticator (`auth/authenticator_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Authenticator | Back arrow / system back | Cancels the second factor and returns to Login |
| Authenticator | Open Google Authenticator row | Opens the authenticator app, or shows a SnackBar with instructions if it can't |
| Authenticator | 6 code boxes (typing) | Auto-verifies once 6 digits are entered |
| Authenticator | Code boxes (long-press) | Pastes the digits from the clipboard |
| Authenticator | Verify Code | Verifies the code (123456): goes to Home, or shows an error with attempts left; 5 wrong codes return to Login |
| Authenticator | Use a different method | Opens the method sheet |
| Authenticator | Sheet → Send code by email | SnackBar "Code sent to r***@… (demo: use 123456)" |
| Authenticator | Sheet → Use a backup code | Opens the backup-code dialog: Cancel / Verify (valid code → Home, invalid → inline error) |

### Splash (`auth/splash_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Splash | (no taps) | Goes to Login or Home after `SplashScreen.duration` |

### Home (`home/home_screen.dart`, `quick_actions.dart`, `home_style.dart`, `task_row.dart`)
| Screen | Element | Action |
|---|---|---|
| Home | Pull to refresh | Shows section skeletons for 1 s, then the content again |
| Home | Site picker "All Sites ▾" | Popup menu of sites → filters every Home count and shows a SnackBar |
| Home | "Showing <site> only" chip ✕ | Resets to All Sites |
| Home | Work Orders tile | Opens Maintenance on the `mine` tab |
| Home | Inspections tile | Opens Inspection on the `dueToday` tab |
| Home | Approvals tile | Pushes My Approvals |
| Home | Critical Alert tile | Opens Alerts on the `critical` tab |
| Home | Quick Actions → Customize | Opens the Customize sheet |
| Home | Customize sheet → Reset / switch / drag handle / Done | Restores the defaults / turns an action on or off / reorders / closes |
| Home | Quick action tiles (Scan Asset, Report Issue, Move Asset, Create Work Order, Start Inspection, Asset Audit, Inventory Issue, …) | `openRoute`: Scan pushes the scanner over the current tab; the others go to their module |
| Home | More Actions tile | Opens the More Actions sheet (12 modules); each tile closes the sheet and opens that module |
| Home | My Tasks → View All | Pushes My Tasks on the current tab |
| Home | My Tasks chips All / Work Orders / Inspections / Approvals | Switch the list (counts come from `homeDataProvider`) |
| Home | Task row | Opens the WO / inspection, or My Approvals for an approval |
| Home | "Show N more" | Pushes My Tasks |
| Home | Asset Overview → View All | Goes to the Assets tab |
| Home | Asset Overview legend row (Active, …) | Opens Assets filtered by that status (`?status=`) |
| Home | Maintenance Performance → View All | Opens Maintenance |
| Home | KPI box (PM Compliance, MTTR, …) | Opens the KPI sheet with a 6-month trend → Close |
| Home | Upcoming Activities → View Calendar | Opens the Maintenance Calendar |
| Home | Activity row | Pushes the WO / inspection / audit session |
| Home | Upcoming empty state → Open Calendar | Opens the Maintenance Calendar **(added: empty state)** |
| Home | Recent Alerts → View All | Opens Alerts |
| Home | Alert row | Opens Alert detail |
| Home | Asset Location → View Map / map / expand button / legend rows | Open Tracking |
| Home | Asset Health → View Details / card | Opens the Health sheet → Close |
| Home | Cost Summary → View Details / legend rows | Open the Cost sheet → Close |
| Home | Recent Assets → View All | Goes to the Assets tab |
| Home | Recent asset row | Records the view and opens Asset detail |

### My Tasks (`home/my_tasks_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| My Tasks | Back (AppScaffold header) | Pops to Home |
| My Tasks | Segment tabs All / Work Orders / Inspections / Approvals | Switch the list |
| My Tasks | Task row | Opens the WO / inspection / My Approvals |
| My Tasks | ⓘ help (PageTitle) | Help sheet |

### My Approvals (`home/my_approvals_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| My Approvals | Back | Pops to the origin |
| My Approvals | Approval card | Opens the Movement request detail |
| My Approvals | Reject | `rejectMovement`: asks for a reason, then rejects |
| My Approvals | Approve | Approves the request, shows a SnackBar, and Home's Approvals tile drops |
| My Approvals | Empty state → Open Movement & Custody | Opens the Movement hub |
| My Approvals | ⓘ help | Help sheet |

### Assets list (`assets/assets_list_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Assets | Search field | Filters by ID, name, serial or tag (live) |
| Assets | Scan icon in the search bar | Camera scan → opens the matching asset, or shows "No asset matches" |
| Assets | Chips All / My Assets / Nearby / Favorites | Change the scope |
| Assets | Filter | Filter sheet (Status / Category / Location / Criticality) |
| Assets | Active filter chip (tap / ✕) | Reopens the filter sheet / removes that filter |
| Assets | Clear all chip | Clears the filters |
| Assets | Asset row | Pushes Asset 360° detail |
| Assets | Empty state → Clear search & filters | Resets the search, filters and scope |
| Assets | FAB + | Pushes Asset Registration |

### Asset 360° detail (`asset_detail_screen.dart`, `asset_overview_tab.dart`, `asset_tabs.dart`, `asset_iot_tab.dart`, `asset_actions.dart`)
| Screen | Element | Action |
|---|---|---|
| Asset detail | Back | Pops to the origin |
| Asset detail | ☆ | Adds to / removes from Favorites (SnackBar) |
| Asset detail | ⋮ → Edit Asset | Switches to Overview with Key Information in edit mode |
| Asset detail | ⋮ → Print Tag | Print sheet (printer dropdown, copies −/+, Print → demo SnackBar) |
| Asset detail | ⋮ → Share | Copies the asset link to the clipboard (demo SnackBar) |
| Asset detail | ⋮ → Duplicate | Confirm → creates a new ID and opens it |
| Asset detail | ⋮ → Retire Asset | Confirm → status Retired |
| Asset detail | ⋮ → Delete | Confirm → removes the asset and pops |
| Asset detail | Photo | Opens the photo viewer (or the photo picker when there's no photo) |
| Asset detail | Health Score card | Health score sheet → Got it |
| Asset detail | Criticality card | Criticality help sheet |
| Asset detail | Age card | Switches to the Financial tab |
| Asset detail | Warranty Expiry card | Switches to the Documents tab |
| Asset detail | Create Work Order / Create Inspection / Move Asset / Report Issue | Push the form prefilled with `?asset=` |
| Asset detail | Check Out | Check-out sheet (custodian, due date, remarks → Confirm submits a movement) |
| Asset detail | View on Map | Pushes asset tracking |
| Asset detail | Add Photo | Photo picker → adds to the gallery |
| Asset detail | More Actions | Sheet: Print QR Tag / Transfer Ownership (custodian picker → movement) / Link IoT Device / Clone |
| Asset detail | Tabs Overview … History | Switch the tab |
| Overview | Key Information → Edit ▾ | Edit mode: dropdowns, date pickers, AMC switch + provider; Cancel / Save (validated) |
| Location | Floor Plan → Live / View on Map | Push asset tracking |
| Location | Pin on the floor plan | SnackBar with zone and location |
| IoT | No device → Link IoT Device | Device picker sheet → links the device (now scrollable, lazy) |
| IoT | Telemetry tile | Selects the trend metric (SnackBar if there is no trend) |
| IoT | Trend dropdown | Changes the metric |
| IoT | SIM / ICCID (long-press) | Copies the ICCID |
| Maintenance | Generate PM Work Order | Creates the WO and opens it |
| Maintenance | Work Orders → View All | Opens Maintenance |
| Maintenance | WO row | Opens the WO |
| Maintenance | Create Work Order | Pushes Create WO for this asset |
| Inspection | View All / row / Create Inspection | Inspection hub / detail / create form |
| Documents | + Add | Pushes Add Document for this asset |
| Documents | Document row | Opens Document detail |
| History | WO / inspection / issue event | Opens that record |
| History | Movement event | Opens the Movement request detail **(fixed — had no route)** |

### Registration hub (`registration/registration_hub_screen.dart`, `bulk_registration_panel.dart`, `registration_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Registration | Back / ⓘ help | Pop / help sheet |
| Registration | Single Asset / Bulk Registration cards | Switch the mode |
| Registration | Scan QR / Barcode | Camera scan → "belongs to X – View asset?" dialog, or opens the form with the barcode filled in |
| Registration | Scan RFID / NFC | Simulated reader sheet (Cancel) → opens the form with the Tag ID filled in |
| Registration | Manual Entry | Opens the 5-step form |
| Registration | Capture from Photo | Photo picker → opens the form with the photo |
| Registration | Recent Scans → View All | Pushes Scan History under the current tab |
| Registration | Recent scan row | Opens Asset detail |
| Registration | Recent Scans empty state → Open Scan History | Opens Scan History **(added: empty state)** |
| Bulk | Download CSV template | Copies the header row to the clipboard (SnackBar) |
| Bulk | Upload CSV area | file_picker (.csv) → validates and shows the preview |
| Bulk | "No file? Use the sample CSV" | Loads the sample CSV into the preview |
| Bulk | Import N valid assets | Simulated import → success sheet → View Assets / Done |

### Register Asset form (`register_asset_screen.dart`, `registration_review.dart`)
| Screen | Element | Action |
|---|---|---|
| Form | Back arrow / system back | Asks to discard when there are changes, then pops |
| Form | Cancel / Back (sticky) | Step 1: leave; later steps: previous step |
| Form | Next / Register Asset (sticky) | Validates the step and moves on / registers the asset |
| Form | Completed step in the stepper | Jumps back to that step |
| Step 1 | Photo box / camera button | Photo picker / photo viewer |
| Step 1 | Asset ID scan icon, Barcode scan icon | Camera scan into the field |
| Step 1 | "Suggest next ID" menu | Fills the next free ID and the type |
| Step 1 | Tag ID scan | RFID reader sheet → fills the Tag ID |
| Step 1 | Status / Condition / Operational / Criticality dropdowns, Purchase / Commissioned dates | Set the values |
| Step 2 | Category / Asset Type dropdowns, Manufacturer autocomplete, Model | Set the values |
| Step 2 | Parent Asset row / ✕ | Asset picker / clear |
| Step 2 | Tag + / suggested tag chips / tag ✕ | Add / add / remove tags |
| Step 3 | Site → Building → Floor → Zone dropdowns | Cascading location |
| Step 3 | Custodian row | Custodian picker sheet (also sets the Department) |
| Step 3 | Department dropdown | Sets the department |
| Step 4 | Cost, life, Supplier autocomplete, PO, Warranty date, AMC switch + vendor | Set the values |
| Step 4 | Add Documents / document ✕ | file_picker / remove |
| Step 4 | Link IoT Device row / ✕ | Device picker / unlink |
| Review | Asset card / Asset Details → Edit | Back to step 1 |
| Review | Location & Custody / Financial / Documents rows | Expand or collapse; Edit → step 3 / 4 / 4 |
| Registered sheet | View Asset / Print Tag / Register Another / Done | Open the asset / demo print SnackBar / new blank form / back to the hub |

## 2. Design check

| Design | Result |
|---|---|
| 01 Login & Security | Matches in layout, order, radii and colours. **Kept on purpose:** "Can't access your authenticator?" replaces the design's "Didn't receive the code?" (prompt 03). |
| 02 Home Dashboard | Matches in section order, tiles, legend layouts, "View All →" links and Upcoming date boxes. **Kept on purpose:** every number (tiles, My Tasks counts, donut legends, costs, location counts) comes from the mock data / summary objects, so it can differ from the image. The floor-plan legend uses the vehicle / people / equipment / alerts kinds from tracking data. |
| 03 Assets / Detail / IoT | Matches in chips, the "Total Assets (12,458)" + Filter row, row layout (thumbnail, ID, name, location, tags, status, chevron), header ☆ ⋮, photo + spec panel with barcode, the 4 stat cards, the 8-action grid, tabs, Key Information with "Edit ▾", the telemetry grid, the trend dropdown and Device Information. **Changed:** the asset name under the ID now ellipsizes on 2 lines. **Kept on purpose:** the warranty, age and health values follow the demo clock and mock data. |
| 04 Asset Registration | Matches in the mode toggle, the 4 capture tiles, the stepper, the step-1 two-column form, the Review layout (green banner, asset card, two-column details, collapsible rows with Edit) and the Back / Register Asset buttons. **Changed:** Recent Scans rows now show "25 Sep 2026 10:24 AM" with the pin icon as in the design (was "25 Sep · 10:24 AM" with a clock). **Kept on purpose:** example assets are labelled "Existing" (grey), not "New" (prompt 06). |

## 3. Robustness changes

- **Lazy lists:** the Assets list is now a `CustomScrollView` with a `SliverList.separated` inside a `DecoratedSliver` card. It shows a shimmer (`ListSkeleton`, for `LoadingGate.delay`) on first appearance and an `EmptyState` with Clear search & filters. The IoT device picker and the Transfer Ownership picker use `ListView.builder` inside a height-capped sheet (the device picker could overflow before).
- **Loading shimmers (`LoadingGate`):** My Tasks list, My Approvals list, Registration Recent Scans, and the asset-tab lists (Work Orders, Inspections, Documents, History). Home already showed skeletons on pull-to-refresh.
- **Empty states:** Home Upcoming Activities, Registration Recent Scans, Asset Location History, Asset History. My Tasks, My Approvals, the Assets list and the IoT tab already had them.
- **Ellipsis:** asset detail ID and name, PM title and frequency, Device Information values, approval ID, "Total Assets" label, registration mode labels, Review card ID / name / type and collapsible titles, the Parent Asset / Custodian / IoT ListTile titles, the device and custodian picker rows, `ArrowLabel` (Sign In / Verify Code / Send Instructions) and the Forgot Password radio labels. These last two overflowed by 21 px on a 360-dp phone in the new test.
- **Scrolling and keyboard:** the "Asset registered" sheet now scrolls. Every screen body is a ListView, CustomScrollView or SingleChildScrollView; forms use `AppScaffold` (viewInsets) or scrolling auth pages.
- **Back:** every pushed screen uses the AppScaffold header back, or its own back on the auth pages; the registration form asks before discarding.
- **Tests:** each of the 4 test files now opens its screens on a 360×640 and a 430×932 phone, scrolls every page to the end and asserts `tester.takeException()` is null. That covers Login, Forgot Password, Authenticator, Home, My Tasks (all tabs), My Approvals, the Assets list (plus the empty search), all 8 Asset 360° tabs for CNC-00123 and LAP-0098, the Registration hub (Single, Bulk with preview) and all 5 form steps plus the success sheet.
