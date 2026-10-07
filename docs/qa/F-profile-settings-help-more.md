# QA — Group F: Profile, Settings, Help, More, Work hub, Admin, Contracts, Financial, Reports

Folders: `lib/features/{profile,settings,help,more,work,admin,contracts,financial,reports}`.
Tests: `test/profile_settings_test.dart` (new), `test/navigation_test.dart`, `test/shell_test.dart`.

None of these screens appear in `design/`, so they follow the style of the other module screens: a white rounded sheet over the purple header, `PageTitle`, `AppCard` / `SectionCard`, `IconSquare` tiles and `AppColors`.

## Button audit

Items marked "(fixed)" had a dead tap, a SnackBar-only placeholder, or a misleading empty state before this pass.

### Header / bottom bar (shared, every screen)
| Screen | Element | Action |
|---|---|---|
| All | Back arrow (AppScaffold header) | Pops to the screen it came from |
| All | Bell / avatar | Notifications / Profile under the current tab (core, not owned) |

### Work hub (`/work`)
| Screen | Element | Action |
|---|---|---|
| Work | Maintenance / Inspection / Issues / WIP / Movement / Asset Audit tiles | `context.go` to that module's hub |
| Work | PageTitle (?) help | Help sheet that describes each module |
| Work | My Tasks pills All / Work Orders / Inspections / Approvals (fixed) | Switch the task list. The counts are the same `homeDataProvider` lists that Home uses |
| Work | My Tasks row (fixed) | Opens the work order, the inspection, or My Approvals (`taskRoute`) |
| Work | "View All" / "Show Less" link and "Show N more" button (fixed) | Expand or collapse the full list in place. Before, "View All" opened Maintenance under an empty state that wrongly said "No tasks to show yet" |
| Work | Empty state "Open Maintenance" | Goes to Maintenance (shown only when a tab has no tasks) |

### All Modules (`/more` and the More sheet)
| Screen | Element | Action |
|---|---|---|
| All Modules | 13 module tiles | `openModule` → `go(route)` |
| All Modules | Issues, Alerts (unread badge), Documents, Registration, Offline Sync, Settings, Help | `go(route)` |
| All Modules | Profile | Pushes Profile on the current tab |
| All Modules | Logout | Confirm dialog → `logout()` → Sign In |
| More sheet | Close (✕) | Closes the sheet |
| Client demo | Logout row | Same Logout confirm |

### Profile (`…/profile`)
| Screen | Element | Action |
|---|---|---|
| Profile | Avatar (initials RK) / camera badge | `pickPhoto` (image_picker camera or gallery) → `setPhoto`, SnackBar |
| Profile | Stat "Open WOs" | Maintenance `?tab=mine` |
| Profile | Stat "Inspections (month)" | Inspection `?tab=mine` |
| Profile | Stat "Audits" | Asset Audit |
| Profile | Edit Profile | Sheet: photo picker, name and phone with validation, Save → session, SnackBar; Cancel |
| Profile | Change Password | Sheet: current (must equal the session password, seed `Asset@360`), new (5 rules + strength bar), confirm; show/hide eye; Update → `changePassword`; Cancel |
| Profile | Switch Site | Site sheet → `switchSite`, SnackBar |
| Profile | Settings | Push Settings |
| Profile | Help & Support | Push Help |
| Profile | Logout | Confirm dialog → clears the session → Sign In (Cancel keeps the session) |

### Settings (`/more/settings`)
| Screen | Element | Action |
|---|---|---|
| Settings | Light / Dark / System segments | `setThemeMode`; the app re-themes at once |
| Settings | Notification category switches | `notificationSettingsProvider.setCategory` |
| Settings | Quiet hours | Push Notification Settings |
| Settings | Default scan mode dropdown | `setScanMode` (the tab the Scan screen opens on) |
| Settings | Beep / Vibrate switches | `setBeep` / `setVibrate` |
| Settings | Offline Sync / Pending Sync | Push those screens |
| Settings | Language English | Selected |
| Settings | Language العربية | SnackBar "Arabic (العربية) is coming soon"; the language stays English |
| Settings (debug) | Data check | Push the Data check screen |
| Settings (debug) | Print demo tags | Push Demo Tags |
| Settings (debug) | Simulate offline | `networkProvider.setSimulatedOffline` |
| Settings (debug) | Simulate sync failures | `syncProvider.setSimulateFailures` |
| Settings (debug) | Reset demo data | Confirm → `resetDemoData` (invalidates every repository) → SnackBar |
| Settings | Open-source licenses | `showLicensePage` (useRootNavigator: false) |
| Settings | Help & Support | Push Help |
| Settings | Version row | Information only (package_info_plus) |

### Data check (`/more/settings/data-check`)
| Screen | Element | Action |
|---|---|---|
| Data check | Run again | Re-runs `runDataChecks`, SnackBar with the result |
| Data check | All checks / Differences chips | Filter the groups |
| Data check | Group "OK" / "n differ" link | SnackBar summary of the group |

### Print demo tags (`/more/settings/demo-tags`)
| Screen | Element | Action |
|---|---|---|
| Demo tags | Assets / Parts / Locations / Not registered chips | Switch the tag group |
| Demo tags | Tag card (fixed) | Opens a large QR dialog with a selectable code, so a second phone can scan it. Before, it only showed a SnackBar |

### Help & Support (`/more/help`)
| Screen | Element | Action |
|---|---|---|
| Help | Search field | Filters the 8 FAQs by question and answer |
| Help | Clear (✕) in search (fixed: new) | Clears the search |
| Help | FAQ rows (accordion) | Expand / collapse the answer |
| Help | Empty state "Clear search" (fixed: new) | Clears the search |
| Help | Email row and copy icon | Copies `asset360-support@purpleiq.ai`, SnackBar |
| Help | Phone row and copy icon | Copies `+971 4 555 0360`, SnackBar |
| Help | Report a bug card | Push Report a Bug |
| Report a Bug | Area dropdown | Select the area (required) |
| Report a Bug | Attach Screenshot (PhotoStrip) | Camera or gallery picker; remove (✕) per thumbnail |
| Report a Bug | Cancel | Pop |
| Report a Bug | Send Report | Validates, sends (simulated, 0.8 s spinner), shows the success sheet with a reference number → Done pops |

### Contracts & Warranty (`/more/contracts`)
| Screen | Element | Action |
|---|---|---|
| Contracts | Warranties / AMC Contracts tabs | Switch the list (counts = list lengths) |
| Contracts | All / Expired / Ending in 90 days / Active chips (fixed) | Filter the list. Before, these were status chips that looked tappable but did nothing |
| Contracts | Row | Asset 360° detail |
| Contracts | Renew | Sheet: date picker, cost, vendor, validation → `renewWarranty` / `renewAmc`, SnackBar |
| Contracts | Empty state "Show all" (fixed: new) | Resets the filter |

### Financial (`/more/financial`)
| Screen | Element | Action |
|---|---|---|
| Financial | Cost Summary "View Details" / legend rows | Cost sheet (shared `CostSummaryCard`) |
| Financial | Value by Category row (fixed) | Sheet that lists the category's assets with cost and book value. A row opens Asset detail on the Financial tab |
| Financial | Top 5 TCO row | Asset detail on the Financial tab |

### Reports & Analytics (`/more/reports`, `/more/reports/:id`)
| Screen | Element | Action |
|---|---|---|
| Reports | Report card | Push the report chart |
| Report | Range dropdown (Week / Month / Quarter / …) | Re-draws the chart |
| Report | Chart bars / points | Tooltip |
| Report | Export icon and Export button (fixed) | Export sheet. **Save as CSV** opens the system save dialog (`FilePicker.saveFile`); if no dialog is available, the CSV is copied to the clipboard. **Copy summary** copies the KPIs and totals. Before, both showed only "Report exported (demo)" |
| Report | Not found → All Reports | `go(Routes.reports)` |

### Administration (`/more/admin`, `/more/admin/users/:id`)
| Screen | Element | Action |
|---|---|---|
| Admin | Users / Roles / Sites / Master Data tabs | Switch the tab |
| Admin | User row | User detail |
| User detail | Role dropdown | `peopleProvider.update`, SnackBar |
| User detail | Not found → All users | `go(Routes.admin)` |
| Admin | Roles table | Read-only, scrolls horizontally |
| Admin | Site / building rows | Expand / collapse (ExpansionTile) |
| Admin | Categories / Asset Types / Manufacturers "+ Add" | Add dialog (name, category for types) → `masterDataProvider`, SnackBar for added or duplicate |

## Design check

No design image covers these screens. They were checked against the module style instead: a rounded white sheet over the purple header, `SectionCard` headers with link-style actions, `IconSquare` tiles with soft tones, 14 px card radius, and colours only from `AppColors`.

- Dark theme: background `#120F2A` (dark navy), cards `AppColors.surface` = `#1E1A3A`, and the purple header gradient (`headerTop` / `headerBottom` constants) is kept. Light and Dark are both verified in `test/profile_settings_test.dart`.
- Data is unchanged; nothing is hard-coded. Profile stats come from `wos.mine`, the inspections due this month and `audits.mine`. Work hub tasks come from `homeDataProvider`, so they match Home.
- The Financial page is back on the standard 16 px padding: the integration pass made the Cost Summary legend value shrink to fit (`_LegendRow` in home_screen.dart).

## Robustness

- **Overflow:** `profile_settings_test.dart` opens 18 routes at 360×640 and 430×932, flings to the end of each, and asserts there are no exceptions. All of them pass.
- **Ellipsis added:** Profile name and role, Profile row titles, Admin user names, site and building names, user detail name and role, Report card title, subtitle and KPI line, Financial category names and TCO IDs, Category sheet rows, Help contact values, Data-check labels, Renew sheet title. Password rule texts are now `Expanded`.
- **Scroll / keyboard:**
  - Every page is a `ListView`.
  - The Renew sheet is now a `SingleChildScrollView` with viewInsets (before, it was a fixed Column that could overflow above the keyboard).
  - The Admin "Add" dialog is `scrollable: true`.
  - The Edit Profile and Change Password sheets use `sheetFrame`.
  - Report a Bug is a ListView inside AppScaffold.
- **Loading and empty states:**

| Screen | LoadingGate | EmptyState |
|---|---|---|
| Work hub My Tasks | yes | yes |
| Help FAQ | yes | yes ("No answers found" + Clear search) |
| Reports list | yes | yes |
| Financial category list | yes | yes |
| Financial Top 5 | yes | yes |
| Admin Users | yes | yes |
| Admin Sites | yes | — |
| Data check groups | yes | existing "No differences" |
| Contracts | shimmer via `ListSkeleton` + `LoadingGate.delay` (the list is lazy) | yes, with Show all |

- **Lazy lists:** Contracts (which grows with registrations) is now `ListView.builder`, one card per row. The Financial category sheet uses `ListView.builder`. The remaining lists are small and fixed (≤ 21 assets, 10 people, 8 FAQs, 5 reports).
- **Back navigation:** every pushed screen uses the AppScaffold back arrow. Report a Bug → Done pops back to Help (tested).

## Shared changes requested (not owned)

> Update (integration pass): all of these were made — see `docs/QA_REPORT.md` → Shared changes.


1. `lib/features/home/home_screen.dart`, `_LegendRow`: wrap the value `Text(value, …)` in `Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: …))`. With 16 px page padding (the Financial screen) on a 360 dp phone, the Cost Summary legend overflows by 1.3 px. After this change, Financial can go back to `context.pagePadding`.

## Tests

`flutter test test/profile_settings_test.dart test/navigation_test.dart test/shell_test.dart` → all pass (19 tests). `profile_settings_test.dart` covers:
- overflow at both sizes
- Change Password: wrong current password rejected, weak and mismatched passwords rejected, `Asset@360` → new password saved
- Edit Profile
- Logout: Cancel keeps the session, confirm goes to Sign In
- Dark theme colours, then back to Light
- Arabic coming-soon SnackBar
- Beep toggle
- Reset demo data confirm restores the seed
- FAQ search, accordion, empty state and clear
- Copy email and phone (clipboard)
- Report a bug validation and success sheet
- Work hub tasks match Home
- Report export copy summary
- Contracts filter

Not covered by tests: the screenshot attachment and avatar photo (both need the platform image_picker).
