# PROMPT 01 — Foundation: project, rules, theme, shared widgets, navigation shell

We are building the **Purple IQ Asset360** mobile app in Flutter as a **fully clickable, hard-coded demo**. It must look exactly like the design images in `design/`. There is no backend; all data is in-memory mock data (built in Prompt 02). Every button must work.

This replaces any earlier plan in this folder (for example, an earlier OTP-login / real-API setup). If a Flutter project already exists here, keep it but remove code that conflicts with this plan. If not, create one: `flutter create --org com.purpleiq --platforms=android,ios asset360_mobile` and work inside it.

The folders `design/` (16 design images) and `assets/images/` (product photos and logo cropped from the designs) are already in the project root, next to this `prompts/` folder. If the Flutter project lives in a subfolder, move `design/` and `assets/` into the Flutter project root.

## Step 1 — Create `CLAUDE.md` in the project root with these permanent rules

```
# Asset360 — rules for every session
1. DESIGN FIDELITY: Before building any screen, open the matching image in design/ and study it.
   Match layout, order of sections, spacing, corner radius, colors, icons, font sizes and wording.
   Each design image shows 3 phone screens side by side (left, middle, right).
2. DATA: All data comes from lib/data/ (mock repositories). Never hard-code data inside widgets.
   Where a design image shows numbers or names that contradict the mock data, the MOCK DATA WINS.
3. COUNTS: Every count on a tab, badge, tile or "X of Y" is computed from the mock lists, so they
   always agree. Org-wide totals larger than 50 (e.g. 12,458 assets) are stored as summary figures;
   lists then show sample records plus a "Showing X of Y" footer.
4. EVERY TAP WORKS: Every button, tile, chip, tab, list row, icon and menu item must do something real:
   navigate, change state, open a dialog/bottom sheet, pick a photo/file, or start a simulated process.
   If a feature truly cannot work offline/hard-coded, show a SnackBar that says what WOULD happen
   (e.g. "Signed in with Google (demo)"). No dead taps, ever.
5. STATE: Actions change in-memory state through Riverpod notifiers, and every screen that shows that
   data updates immediately (e.g. closing a work order updates the list, badges and Home).
   State resets when the app restarts. That's fine for this demo.
6. DEMO CLOCK: "Now" is always DemoClock.now = Friday 25 Sep 2026, 10:30 AM (Asia/Dubai).
   All "5 mins ago", "Due in 1h 20m", "Overdue" etc. are computed from DemoClock, never DateTime.now().
7. STACK: Flutter stable, Dart 3, Material 3, flutter_riverpod (hand-written Notifier classes, no code
   generation), go_router, fl_chart, mobile_scanner, image_picker, file_picker, intl, shimmer.
   No freezed, no build_runner. Add other packages only when a prompt names them.
8. QUALITY: `flutter analyze` must be clean after every prompt. Reuse shared widgets from
   lib/core/widgets/. Don't duplicate UI code.
9. After finishing each prompt: run `flutter analyze`, fix everything, then give me a short summary
   of what was built and a checklist of every button on the new screens and what it does.
```

## Step 2 — Packages and assets
Add: `flutter_riverpod`, `go_router`, `fl_chart`, `mobile_scanner`, `image_picker`, `file_picker`, `intl`, `shimmer`, `package_info_plus`.
- Register `assets/images/` in `pubspec.yaml`.
- Bundle the **Inter** font (download the TTFs from the official Google Fonts GitHub repo into `assets/fonts/`, weights 400/500/600/700) and set it as the app font.
- Add camera and photo permissions in AndroidManifest and Info.plist (needed later for scanning and photos).
- Set the Android `minSdkVersion` to what mobile_scanner requires.

## Step 3 — Theme (`lib/app/theme/`)
Sample the exact colors from the design images, for example with a small Python + Pillow script on pixels of the header, primary button, chips and background. Put every color in one `AppColors` class. Starting values to verify:
- Header / bottom bar: deep purple, around `#2E1470` to `#43209A` (slight gradient)
- Primary button, active tab underline, FAB, Scan button: vivid violet, around `#5B2BE0`
- Screen background: very light lavender, around `#F5F3FB`; cards pure white
- Text: navy `#1A1446`; secondary grey `#6B6880`
- Status chips (text on pale background): green Active/Completed/Verified, amber Pending/Medium/Low Stock, red Critical/Overdue/Out of Stock, blue In Progress/In Transit/Low, purple Assigned
- Soft tile backgrounds: lavender, mint, peach, sky, pink (see the Home quick actions)

Cards: white, radius ~14, very soft shadow. Buttons: height ~48, radius ~10. Primary buttons are filled violet; secondary buttons are outlined violet.

## Step 4 — Shared widgets (`lib/core/widgets/`)
Build these once and use them everywhere:
- **AppHeader:** purple top bar with back arrow (optional), `assets/images/logo_on_dark.png` + "Purple IQ" | "Asset360", a bell with a red count badge that opens Notifications, and an avatar circle "RK" that opens Profile. A `HomeHeader` variant shows the avatar photo placeholder, "Rex Kumar / DCS" and a dropdown chevron.
- **PageTitle:** big title + grey subtitle + optional "?" help icon. The help icon opens a bottom sheet explaining the screen.
- **StatusChip**, **PriorityChip**, **KpiTile** (icon, number, label, colored background), **ActionTile** (icon + label in a soft colored square), **SectionCard** with header + "View All" / "Edit" link, **InfoRow** (label : value), **SearchFilterBar** (search field + filter button that opens a filter bottom sheet), **SegmentTabs** (underlined tabs with counts), **StepperHeader** (numbered 5-step progress), **AssetListTile** (photo, ID, name, location, chip, chevron), **PhotoStrip** with "Add Photo" (image_picker, from camera or gallery), **ProgressRing**, **EmptyState**, **ConfirmDialog**, **SuccessSheet**.

## Step 5 — Navigation shell (go_router + StatefulShellRoute)
- Bottom bar exactly as in every design: **Home, Assets, [big round violet Scan button in the centre, raised], Work, More**. The active tab is violet with a small top indicator line.
- **Home** → Home dashboard (placeholder until Prompt 04).
- **Assets** → Asset list (placeholder until Prompt 05).
- **Scan** → Scan & Identify (placeholder until Prompt 07).
- **Work** → a **Work hub** screen, which is not in the designs, so build it in the same style: title "Work", subtitle "Your work orders, inspections, issues and operations". It has a 2-column grid of ActionTiles: Maintenance, Inspection, Issues / Defects, WIP / Operations, Movement & Custody, Asset Audit. Below that, a "My Tasks" section (filled in later).
- **More** → a **More** menu screen in the same style, listing: Tracking & IoT, Inventory / Spare Parts, Documents, Asset Registration, Alerts & Notifications, Offline Sync, Profile, Settings, Help & Support, Logout.
- Create a route for every module screen that later prompts will build. Until built, each shows a styled "Coming in next step" placeholder that still has the real header and bottom bar.
- Android back button and header back arrow both pop correctly.

## Done when
- The app runs on a real Android phone. Bottom bar, Work hub and More menu match the design style, and every item navigates.
- `CLAUDE.md` exists with the rules above.
- `flutter analyze` is clean.
