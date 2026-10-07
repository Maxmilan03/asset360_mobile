# QA report: Group E (Documents, Asset Audit, Offline Sync)

Folders: `lib/features/documents`, `lib/features/audit`, `lib/features/sync`
Tests: `test/documents_test.dart`, `test/audit_test.dart`, `test/sync_test.dart` (22 tests, all passing; `flutter analyze` clean for these files)

## 1. Button audit

No handler in these folders was empty, `() {}`, TODO or print-only. Every element listed below does something real.
"(fixed)" marks an element that was added or changed during this pass.

### Documents (`documents/documents_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Documents | Help "?" | Opens the help sheet (how the counts are defined) |
| Documents | Tile All Documents / Expiring Soon / Compliant / Pending | Filters the list by that tile (border shows which one is selected) and resets the tab to All |
| Documents | Search field | Filters by file name, type or asset as you type |
| Documents | Filter button | Opens the filter sheet (Type / Asset / Expiry) and applies the choices |
| Documents | Tabs All / Manuals / Warranty / Certificates / Others | Switches the bucket and clears any tile filter |
| Documents | Tile filter chip ✕ | Removes the tile filter and shows everything |
| Documents | Document row | Opens Document Details |
| Documents | Row ⋮ View | Opens the in-app viewer |
| Documents | Row ⋮ Download | System save dialog, then a SnackBar with an "Open" action |
| Documents | Row ⋮ Share | Copies a link to the clipboard. The SnackBar says the share sheet would open (demo) |
| Documents | Row ⋮ Rename | Rename dialog. Updates the name everywhere |
| Documents | Row ⋮ Replace Version | File picker (10 MB limit), then adds a new version |
| Documents | Row ⋮ Delete | Confirm dialog, then removes the document and updates the counts |
| Documents | Empty state "Clear filters" (fixed: new) | Clears the search, filters and tile filter |
| Documents | FAB + | Opens Add Document |

### Document Details (`documents/document_detail_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Document Details | ⋮ (View / Download / Share / Rename / Replace Version / Delete) | Same as the list ⋮. Delete goes back to the list |
| Document Details | View | Opens the viewer |
| Document Details | Download | System save dialog |
| Document Details | Approve document (only for pending documents) | Clears Pending review, so the Pending count drops |
| Document Details | Edit (Document Information) | Switches to inline edit |
| Document Details | Edit: name / type / category / version / expiry date / description | Edits the draft (the date opens a date picker) |
| Document Details | Edit: Cancel / Save | Throws the draft away, or validates and saves through `documentsProvider` |
| Document Details | Asset (link) | Opens Asset 360° |
| Document Details | Related Documents "View All" | Shows every related document (hidden when there are 4 or fewer) |
| Document Details | Related document row | Opens that document |
| Document Details | Versions "Upload new" | File picker, then adds a new version |
| Document Details | Version row | Opens that version in the viewer |
| Document Details | Version "Restore" | Confirm dialog, then that version becomes the current one |
| Document not found | Back to Documents | Goes back |

### Add Document (`documents/add_document_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Add Document | Help "?" | Opens the help sheet |
| Add Document | Select Asset card | Asset picker sheet |
| Add Document | Scan icon | Camera scan of an asset tag; an unknown code shows a SnackBar |
| Add Document | Document Type dropdown | Sets the type. Types that expire show the Expiry Date field |
| Add Document | Upload box | File picker (allowed types, 10 MB). Fills the name from the file |
| Add Document | Selected file ✕ | Removes the file |
| Add Document | Category dropdown, Version, Expiry Date (date picker), Description | Edit the form |
| Add Document | Cancel | Asks before discarding unsaved input, then goes back |
| Add Document | Upload Document | Validates, runs a simulated 1.5 s upload with progress, adds the document, then opens Documents |

### Document Viewer (`documents/document_viewer_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Viewer | Download icon | System save dialog |
| Viewer | PDF / image | Pinch zoom, page change (updates "Page X of Y") |
| Viewer (no preview) | Download to open | System save dialog |

### Asset Audit (`audit/asset_audit_screen.dart`, `audit_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Asset Audit | Help "?" | Opens the help sheet |
| Asset Audit | Tile My Audits / Completed | Selects that tab |
| Asset Audit | Tile In Progress / Pending | Filters My Audits by that status |
| Asset Audit | Tabs My Audits / Assigned / Completed | Switches the list and clears the status filter |
| Asset Audit | Search, filter button (Status / Site) | Filters the list |
| Asset Audit | Status chip ✕ | Removes the status filter |
| Asset Audit | Audit card | Opens the audit session |
| Asset Audit | Start Audit / Resume Audit (on a card) | Sets the audit to In Progress and shows a SnackBar |
| Asset Audit | Compliance card | Opens Compliance |
| Asset Audit | Empty state "Create Audit Campaign" (fixed: new) | Opens Create Audit Campaign |
| Asset Audit | FAB + | Opens Create Audit Campaign |

### Audit session (`audit/audit_session_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Audit session | ⋮ Complete Audit | Summary dialog (unscanned assets become Not Found), completes the audit, then opens the report |
| Audit session | ⋮ Export Report | Opens the Audit Report |
| Audit session | ⋮ Pause / Start / Resume Audit | Changes the status. The camera stops or starts with it |
| Audit session | Result tiles (Verified / Wrong Location / Not Found / Unregistered) | Open the list of assets with that result |
| Audit session | Status banner Start / Resume Audit / View Report | Starts the audit, or opens the report |
| Audit session | Mode Scan / Search / Manual Entry | Switches the pane. The camera only runs in Scan |
| Audit session | Camera (auto-detect) | Known asset → Asset Found; unknown code → Unregistered sheet |
| Audit session | Torch | Toggles the torch |
| Audit session | Capture | Uses the code in view. If nothing is in view, or the audit is not running, a SnackBar explains why |
| Audit session | Gallery | image_picker, then reads the code from the photo |
| Audit session | "Simulate scan" chip (debug builds) | Scans GEN-00045 |
| Audit session | Camera error Search / Manual Entry | Switches the pane |
| Audit session | Search field / asset row | Filters the audit's assets. A row opens Asset Found |
| Audit session | Search empty state "Manual Entry" (fixed: new) | Switches to Manual Entry with the search text filled in |
| Audit session | Manual Entry Find Asset / keyboard submit | Looks the code up (an empty field shows a SnackBar) |
| Dialogs | Outside this audit / Already audited, re-audit? | Confirm or cancel |
| Unregistered sheet | Capture Photo, photo ✕ | Adds or removes a photo |
| Unregistered sheet | Location field | Location picker |
| Unregistered sheet | Cancel / Save as Unregistered | Closes, or validates and records it, then the success sheet appears |
| Success sheet | Register now / Continue Scanning | Opens New Registration with the details filled in, or closes |

### Asset Found (`audit/audit_asset_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Asset Found | Asset card | Opens Asset 360° |
| Asset Found | Audit Action Verified / Wrong Location / Not Found | Selects the result |
| Asset Found | Audit Action Unregistered | SnackBar: this asset is already registered (by design) |
| Asset Found | Scanned Location field / pin button | Location picker. Picking a different place switches the result to Wrong Location |
| Asset Found | "Update asset location" checkbox | Adds an audit-correction movement when you save |
| Asset Found | Condition dropdown, Remarks | Edit the result |
| Asset Found | Add Photo, photo ✕ | Photo picker, or removes the photo |
| Asset Found | Close | Goes back without saving |
| Asset Found | Save & Next | Validates, records the result, then goes back to the scanner with a SnackBar |
| Asset not found | Back to the audit | Goes back |

### Audit pages (`audit/audit_pages.dart`)
| Screen | Element | Action |
|---|---|---|
| Create Audit Campaign | Help "?" | Opens the help sheet |
| Create Audit Campaign | Name, Site, scope chips, Start / End date | Edit the form (the dates open a picker; scope chips change the "N assets in scope" count) |
| Create Audit Campaign | Auditors card | Auditor sheet with checkboxes (built lazily (fixed)), then Done |
| Create Audit Campaign | Blind count switch | Toggles blind count |
| Create Audit Campaign | Cancel / Create Audit | Goes back, or validates and creates a Pending audit |
| Audit results | Asset row | Opens Asset 360°. An unregistered row opens New Registration with the details filled in |
| Audit results | Empty state "Back to the audit" (fixed: new) | Goes back |
| Audit Report | Share icon / Share button (fixed) | Copies a text summary of the report to the clipboard and shows a SnackBar (it was a SnackBar only before) |
| Audit Report | Section "View All" (fixed) | Opens the result list. It is now hidden when the section is empty |
| Audit Report | Entry rows | Same as the result rows |

### Compliance (`audit/compliance_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Compliance | Help "?" | Opens the help sheet |
| Compliance | Certificates "Documents" | Opens Documents |
| Compliance | Certificate row | Opens Document Details |
| Compliance | Inspections "Inspection" | Opens the Inspection hub |
| Compliance | Inspection row | Opens the inspection |

### Offline Sync (`sync/offline_sync_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Offline Sync | Help "?" | Opens the help sheet |
| Offline Sync | Tile Pending Sync / Completed Locally | Opens Pending Sync |
| Offline Sync | Tile Photos to Sync | Opens Pending Sync on the Photos tab |
| Offline Sync | Tile Syncing Now | Opens Syncing Data while a run is going; otherwise a SnackBar says nothing is syncing |
| Offline Sync | Sync Status card / chevron | Sync History sheet (with an empty state (fixed)) |
| Offline Sync | Automatic Sync, Wi-Fi, Mobile Data switches | Change the sync settings (Wi-Fi and Mobile Data are disabled while Automatic Sync is off) |
| Offline Sync | Sync Now | Starts a run and opens Syncing Data. Offline, it asks first and offers "Try anyway (demo)". With nothing to sync, a SnackBar says so |
| Offline Sync | Pending Items "View All" | Opens Pending Sync |
| Offline Sync | Pending group row | Opens Pending Sync on that tab |

### Pending Sync (`sync/pending_sync_screen.dart`, `sync_widgets.dart`)
| Screen | Element | Action |
|---|---|---|
| Pending Sync | Tabs All / Work Orders / … | Filter by kind |
| Pending Sync | Row | Opens the real record (WO, inspection, issue, document, asset, part, audit). If it is gone, a SnackBar says so |
| Pending Sync | Row ⋮ View Item / Sync This Item / Discard | Opens the record; syncs just that item; or confirms and removes it from the queue |
| Pending Sync | Empty state "Show all (N)" (fixed: new) | Goes back to the All tab when the current tab is empty |
| Pending Sync | Clear All | Confirm dialog, then empties the queue |
| Pending Sync | Sync All (N) | Same as Sync Now |

### Syncing Data (`sync/syncing_screen.dart`)
| Screen | Element | Action |
|---|---|---|
| Syncing Data | Cancel Sync | Stops after the current item |
| Syncing Data | Row Retry (failed item) | Queues that item again |
| Syncing Data | Retry Failed | Queues every failed item again |
| Syncing Data | Done | Dismisses the run and opens Offline Sync |
| Syncing Data (idle) | Sync All (N) | Starts a run |

## 2. Design check

- **14 Documents**
  - The list, details and add-document screens match the design for section order, tiles, tabs, row layout, the ⋮ menu, the View / Download buttons and the info rows.
  - Changed:
    - The Add Document subtitle now uses the design wording, "Upload and link document to an asset".
    - The Document Type dropdown now has the document icon prefix shown in the design.
  - Kept on purpose:
    - Counts come from the mock data (64 / 8 / 42 / 6, tabs 12 / 8 / 14 / 30).
    - The expiry date field only appears for types that expire. The design always shows it as "(if applicable)".
- **15 Asset Audit**
  - The tiles, the tabs-then-search order, the audit cards, the session (progress card, 4 result tiles, Scan / Search / Manual Entry, the camera card with torch / capture / gallery, the info strip) and Asset Found (green banner, asset card, info rows, 4 action cards, Audit Details, Close / Save & Next) all match.
  - Kept on purpose:
    - The tab counts equal the tiles (My Audits 3, Completed 1), not the design's "Assigned (2) / Completed (5)" (rule 3).
    - The Tag ID label names the method that was actually used.
- **16 Offline Sync**
  - The offline card, the 4 tiles, the Sync Status ring with its legend, the Automatic Sync switches, the Last Sync card with Sync Now, the Pending Items groups, the Pending Sync tabs and rows with Clear All / Sync All, and Syncing Data (ring, percentage, "X of Y items synced", per-item states, Cancel Sync) all match.
  - Kept on purpose: the counts come from the sync queue (the ring shows 76%, "25 of 33"; the design shows 75%).

## 3. Robustness

**Loading shimmer and empty states**
- Documents list: `SliverLoadingGate`, plus an `EmptyState` with "Clear filters".
- Pending Sync: `SliverLoadingGate`, plus an `EmptyState` with "Show all".
- Asset Audit list: `LoadingGate`, plus an `EmptyState` with "Create Audit Campaign".
- Audit session Search pane: `LoadingGate`, plus an `EmptyState` with "Manual Entry".
- Audit result lists: `LoadingGate`, plus an `EmptyState`.
- Compliance: `LoadingGate`.
- Sync History sheet: an `EmptyState`.

**Lazy lists**
- Documents and Pending Sync are now a `CustomScrollView` (`LazyListPage`) with `SliverCardList` / `SliverList.separated`.
- Syncing Data builds its run rows with `SliverList.builder`.
- The auditor picker uses `ListView.builder`.

**Ellipsis**
- Document Details: name (2 lines) and asset name / ID.
- Audit card: name (2 lines).
- Asset Found: asset ID and name.
- Audit session: scope row ID.
- Audit result entry: title (2 lines).
- Compliance card: subtitle.

**Scrolling, keyboard and back navigation**
- Every screen scrolls: a ListView or CustomScrollView inside `AppScaffold`.
- Forms (Add Document, the inline edit in Document Details, Create Audit Campaign, Asset Found, the Unregistered sheet) are scrollable bodies or sheets, so the keyboard does not cover fields.
- Every pushed screen has the AppScaffold back button.

**Overflow tests**
- Each module test now opens every main screen at 360×640 dp and 430×932 dp and asserts `takeException()` is null.
- The documents test also checks that the shimmer shows before the rows, and that a search with no match shows the empty state and Clear filters.

## 4. Requests for shared files (not edited, outside this group)

> Update (integration pass): all of these were made — see `docs/QA_REPORT.md` → Shared changes.


- `lib/features/alerts/sliver_card_list.dart` (`SliverLoadingGate`, `SliverCardList`, `LazyListPage`) is now used by Documents, Pending Sync and Syncing Data too. Move it into `lib/core/widgets/loading_list.dart` (or `core/widgets/sliver_card_list.dart`) and export it from `widgets.dart`. `features/maintenance/gated_sliver_list.dart` is a duplicate of the same idea.
- `lib/core/widgets/page_title.dart`: give the title `maxLines: 2, overflow: TextOverflow.ellipsis`. This matters for long names such as the document name in the viewer and the audit name in the session.
