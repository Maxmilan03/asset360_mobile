# QA — Group C: Maintenance, Inspection, Issues (Prompt 19)

Folders: `lib/features/maintenance`, `lib/features/inspection`, `lib/features/issues`.
Tests: `test/maintenance_test.dart`, `test/inspection_test.dart`, `test/issues_test.dart` (25 tests, all passing).

## 1. Button audit

"(fixed)" marks a handler that was changed or added in this pass. Taps inside shared core widgets
(`CheckItemView` answers, `PhotoStrip` add/remove/open, `SearchFilterBar` filter sheet, `AttachmentTile`
preview, `SignaturePad`, header back/bell/avatar) are owned by `lib/core` and listed once where used.

### Maintenance hub (`maintenance_hub_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Maintenance hub | Help (?) on page title | Opens the help sheet explaining the tabs |
| Maintenance hub | Tile "My Work Orders" (badge) | Switches to the My Work Orders tab |
| Maintenance hub | Tile "Preventive Maintenance" | Pushes PM Schedules |
| Maintenance hub | Tile "Breakdown Requests" | Pushes Breakdown Requests list |
| Maintenance hub | Tile "Service History" | Pushes Service History list |
| Maintenance hub | Tile "Spare Parts" | Goes to Inventory |
| Maintenance hub | Tile "Maintenance Calendar" | Pushes Maintenance Calendar |
| Maintenance hub | Tabs My Work Orders / PM Due / Overdue / All | Switch the list (counts from repository queries) |
| Maintenance hub | Search field | Filters by WO no., title, asset ID/name, location |
| Maintenance hub | Filter button | Filter sheet: Priority / Status / Type / Date; applies to list |
| Maintenance hub | WO row | Pushes Work Order detail |
| Maintenance hub | FAB + | Pushes Create Work Order |

### Work order detail (`work_order_screen.dart`, `wo_actions.dart`, `wo_tasks_tab.dart`)
| Screen | Element | Action |
|---|---|---|
| Work order | Status chip ▾ (popup) | Menu of statuses → `changeWoStatus` (On Hold asks a reason, Completed/Closed need all tasks, Closed runs close-out) |
| Work order | Tabs Overview / Tasks / Parts / History / Documents | Switch tab |
| Overview | Asset card | Pushes Asset 360° detail |
| Overview | "Assigned To" | Reassign sheet (people picker) → updates assignee |
| Overview | Issue Description "Edit" | Inline editor; Cancel / Save (validates non-empty) |
| Overview | Photos: Add Photo / thumbnail / ✕ | Camera/gallery picker adds photo; opens viewer; removes photo |
| Overview | Update Status ▾ | Status sheet (radio + comment) → `changeWoStatus` |
| Overview | Close Work Order | All tasks done → close-out sheet; otherwise SnackBar "Complete all tasks first (x of y)" |
| On Hold dialog | Quick-reason chips / Cancel / Put On Hold | Fill reason / dismiss / set On Hold with reason (validated) |
| Close-out sheet | − / + per reserved part | Adjust used quantity |
| Close-out sheet | Signature pad | Captures signature |
| Close-out sheet | Close Work Order | Validates resolution, hours, signature → closes WO (asset Active, parts issued) → success sheet |
| Tasks | Task header row | Expand / collapse task |
| Tasks | Checklist ticks | Toggle item (only the open task is editable) |
| Tasks | Notes field | Saves task notes |
| Tasks | Mic button | Simulated recorder sheet (timer; Discard / Stop adds "Voice note m:ss") |
| Tasks | Voice-note chip | (fixed) Opens a simulated playback sheet (play/pause, progress, Close); was a SnackBar only |
| Tasks | Camera / Gallery / Video buttons | image_picker → adds photo/video to the task |
| Tasks | Complete Task | Enabled when checklist complete → completes, opens next task |
| Parts | Reserved part row | Confirm dialog → releases reservation |
| Parts | Issued part row (or closed WO) | Pushes Part detail |
| Parts | Add Part | Part picker sheet (search, select, − / +, Reserve n × part) |
| History | — | Read-only timeline (empty state added) |
| Documents | Document row | Pushes Document detail |
| Documents | Empty state "Add Document" | (fixed) Pushes Add Document prefilled with the asset (new empty state) |

### PM schedules / Breakdowns / Service History (`maintenance_lists.dart`)
| Screen | Element | Action |
|---|---|---|
| PM Schedules | Schedule card | Pushes Asset detail |
| PM Schedules | Generate WO now | Confirm → creates preventive WO; SnackBar with "View" → WO detail |
| Breakdowns / History | Search | Filters list |
| Breakdowns | Chips Active / All | Filter |
| Service History | Chips All / Corrective / Preventive and Last 7 days / Last 30 days / All time | Filter |
| Breakdowns / History | WO row | Pushes WO detail |

### Maintenance calendar (`maintenance_calendar_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Calendar | ‹ / › | Previous / next month |
| Calendar | Day cell | Selects day, lists its events |
| Calendar | "Today" link | Jumps to today |
| Calendar | Event row | Opens WO / inspection / audit session |

### Create Work Order (`create_work_order_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Create WO | Help (?) | Help sheet |
| Create WO | Asset tile | Asset picker sheet |
| Create WO | Priority chips | Select priority |
| Create WO | Corrective / Preventive segmented | Select type (sets work type) |
| Create WO | Work type dropdown | Select work type |
| Create WO | Due date field | Date picker then time picker |
| Create WO | Assign to dropdown | Select technician (or Unassigned) |
| Create WO | Cancel | Pops |
| Create WO | Create Work Order | Validates → creates WO (links finding/issue/alert, copies photos) → success sheet: View Work Order / Done |

### Inspection hub + Findings (`inspection_hub_screen.dart`, `inspection_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Inspection hub | Help (?) | Help sheet |
| Inspection hub | Tiles My Inspections / Due Today / Overdue / Completed | Show that list (tabs or a filter chip) |
| Inspection hub | Tile Findings | Pushes Findings list |
| Inspection hub | Tile Inspection Calendar | Pushes Maintenance Calendar |
| Inspection hub | Tabs My Inspections / Due / Overdue / All | Switch list |
| Inspection hub | "Due Today (n)" / "Completed (n)" chip ✕ | Back to All |
| Inspection hub | Search / Filter | Filter by text; Status / Type sheet |
| Inspection hub | Inspection row | Pushes Inspection detail |
| Inspection hub | FAB + | Pushes Create Inspection |
| Findings | Status chips All / Open / Action Taken / Closed | Filter |
| Findings | Finding row | Pushes Finding detail |
| Finding detail | Open Inspection | Pushes inspection on the Checklist tab |
| Finding detail | WO-xxxx button | Pushes linked WO |
| Finding detail | Close Finding | Confirm → closes finding |
| Finding detail | Create Work Order | Pushes Create WO prefilled (finding → Action Taken) |
| Finding detail | Photos | Opens photo viewer |

### Inspection detail (`inspection_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Inspection | Status chip ▾ | Set status; "Completed" jumps to Summary & Submit |
| Inspection | Tabs Details / Checklist / Findings / Documents | Switch tab |
| Details | Asset row | Pushes Asset detail |
| Details | Reschedule | Date picker → reschedules |
| Checklist | Section header | Expand / collapse section |
| Checklist | Answer chips / number fields / ticks | Record answers; a new negative answer opens Add Finding |
| Checklist | "Add Finding" on an item | Add Finding sheet |
| Checklist | Notes / Photos | Save notes; add / remove / view photos |
| Checklist | Save as Draft / Previous | Saves draft (SnackBar) / previous section |
| Checklist | Next / Save & Next / Save & Review | Next section / Summary |
| Summary | "Still to answer" row | Jumps to that section |
| Summary | Findings "Add" / finding row | Add Finding sheet / Finding detail |
| Summary | Signature pad, Submit | Validates every item + signature → completes, success sheet, then "Open findings" sheet |
| Open findings sheet | Create Work Order / Later | Create WO prefilled from finding / dismiss |
| Add Finding sheet | Severity chips, Photos, Skip, Save Finding | Select / add photos / dismiss / save (validated) |
| Findings tab | Finding row / Add Finding | Finding detail / Add Finding sheet |
| Documents tab | Document row / Upload Document | Document detail / file_picker → document added and linked |

### Create Inspection (`create_inspection_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Create Inspection | Asset tile | Asset picker |
| Create Inspection | Template dropdown | Select template (shows sections/items) |
| Create Inspection | Due date and time | Date + time pickers |
| Create Inspection | Inspector dropdown | Select inspector |
| Create Inspection | Cancel / Schedule | Pop / validate → create → success sheet: Open Inspection / Done |

### Issues list (`issues_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Issues | Help (?) | Help sheet |
| Issues | Tile Report Issue | Pushes Report Issue |
| Issues | Tiles My Issues / Resolved | Switch to that tab |
| Issues | Tile In Progress | Shows the In Progress list (chip with ✕ back to All) |
| Issues | Tabs All / My / Open / Resolved | Switch list |
| Issues | Search / Filter | Text filter; Priority / Type / Status / Date sheet |
| Issues | Issue row | Pushes Issue detail |
| Issues | Swipe right on own open issue | Confirm → Mark Resolved |

### Report Issue (`report_issue_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Report Issue | Back (header) / system back / Cancel | Discard confirm when dirty, then pop |
| Report Issue | Scan asset button | Camera scan → selects asset |
| Report Issue | Asset card | Asset picker |
| Report Issue | Issue Type dropdown | Select type |
| Report Issue | Priority cards | Select priority |
| Report Issue | Location scan button | Scan location tag → fills location |
| Report Issue | Reported By field / ✕ | People picker sheet |
| Report Issue | Add Photo / Video, thumbnail ✕ | Camera / gallery / video picker; remove |
| Report Issue | Submit Issue | Validates → reports (Critical raises alert + notification) → success sheet: Create Work Order now / Done (→ issue detail) |

### Issue detail (`issue_detail_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Issue detail | Status chip ▾ | Set status; Closed asks for resolution notes |
| Issue detail | Tabs Details / Work Orders / Timeline / Attachments | Switch tab |
| Details | Asset card | Pushes Asset detail |
| Details | Edit → Cancel / Save | Inline edit of title, description, type, priority, location |
| Details | Assigned To row | Assign sheet (people) |
| Details | Photos "View All" | Gallery sheet (tap = viewer, ✕ = remove) |
| Details | Add Photo / ✕ | Adds / removes photo |
| Work Orders | WO row / Create Work Order | WO detail / Create WO prefilled from the issue |
| Timeline | Comment field + send | Adds a comment to the timeline |
| Attachments | Photo / file tiles | Photo viewer / attachment preview |
| Attachments | Add Files | file_picker → files attached |
| Bottom bar | Close Issue | Resolution-notes dialog → closes |
| Bottom bar | Create Work Order | Create WO prefilled (links back to issue) |
| Bottom bar | Update Status | Status sheet (radio + comment) |

**Result:** no empty `() {}`, TODO or print-only handlers. The only SnackBar-only tap (voice-note playback) now opens a simulated player. Every chevron or link-styled element has a handler.

## 2. Design check (design/08, 09, 10)

Changed:
- 08 Maintenance list: WO rows have no chevron in the design. `WoRow` now uses `showChevron: false`.
- 08 / 09 detail headers: the design uses the same camera glyph before the ID on WO, inspection and issue
  details. WO (`build_circle_outlined`) and inspection (`fact_check_outlined`) now use `camera_alt_outlined`,
  the same as Issues.

Checked and matching: section order, tile tones and badge colours, tab labels, the Overview cards (asset /
dates + countdown / people / Issue Description Edit / Photos + Add Photo / Update Status ▾ + Close Work Order),
the task accordion (done = green tick + time, in progress = purple + chip, pending = grey chip), the inspection
checklist (progress bar, numbered sections, Save as Draft / Next, Previous / Save & Next), the Report Issue form
(scan buttons, four priority cards, 500-character counter, Reported By ✕, Add Photo / Video) and the issue detail
(Issue Information with Edit, Photos View All, the three bottom buttons).

Kept on purpose:
- Counts and names come from the mock data, not the design numbers, e.g. the Overdue tile badge "2" vs tab "3",
  the task progress figures and the photo counts.
- ~~Issue rows show the priority chip at the top right.~~ Fixed in the integration pass: `AssetListTile.titleTrailing`
  now puts the chip inline after the issue number, as in design 10.

## 3. Robustness
- **Lazy lists:** the main lists (Maintenance hub, PM Schedules, Breakdowns, Service History, Inspection hub,
  Findings, Issues) are now `CustomScrollView` pages built with `SliverList.separated`. They use the new
  `features/maintenance/gated_sliver_list.dart`: `GatedSliverList` (shimmer for `LoadingGate.delay`, then
  `EmptyState` or the rows) and `gatedListPage`.
- **Loading shimmer:** the tab lists (WO Parts / History / Documents, Inspection Findings / Documents,
  Issue Work Orders / Timeline / Attachments) are wrapped in `LoadingGate`.
- **Empty states:** added for WO History, WO Documents (with an Add Document action), Inspection Documents,
  Issue Timeline and Issue files. Findings now has a status-specific empty message.
- **Ellipsis:** added to WO / inspection / issue header subtitles, asset-card IDs, PM schedule title and asset
  line, the service-history closed line, task titles, the closed-card line, calendar event titles, finding row
  details, document subtitles, the summary "still to answer" rows, the Assigned To value and the issue-type
  dropdown items.
- **Overflow bug found by the new test:** Create Work Order's "Assign to" dropdown (long name + role)
  overflowed by 344 px at 360 dp. It now uses `isExpanded` and ellipsis; the same was applied to the Work type
  and issue-edit type dropdowns.
- **Keyboard and back:** every form is a scrolling `ListView` inside `AppScaffold`, and the sheets use
  `sheetFrame`, which pads for `viewInsets`. Every pushed screen has the `AppHeader` back button. Report Issue
  asks before discarding.
- **Tests:** at 360×640 and 430×932, each test visits every route in the three modules, including long-text
  records. It waits for the shimmer, scrolls to the end and back, and asserts no exception. Search-to-empty-state
  tests and a voice playback test were also added.
