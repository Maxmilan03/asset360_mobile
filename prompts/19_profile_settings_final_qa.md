# PROMPT 19 — Profile, Settings, Help, and final "every button works" QA

Follow `CLAUDE.md`. These screens are not in the designs; build them in the same visual style. Then do a full quality pass over the whole app.

## Profile
- Avatar (initials "RK", tap → change photo with image_picker), Rex Kumar, DCS, email, phone, department, site.
- Stats row: my open WOs, inspections this month, audits.
- Edit Profile (name, phone, photo) and Change Password (current/new/confirm with strength rules; the current password must be `Asset@360`).
- **Logout:** confirm dialog → clears the session and returns to Login.

## Settings
- Appearance: Light / Dark / System. Build a matching dark theme: dark navy background, purple header kept, cards #1E1A3A.
- Notifications: category toggles.
- Scanning: default scan mode, beep and vibration toggles.
- Offline & Sync: shortcuts to Offline Sync settings.
- Language: English / العربية ("coming soon" SnackBar for Arabic).
- **Developer (debug builds only):** Data check screen, Simulate offline, Simulate sync failures, Print demo tags, "Reset demo data" (reloads the seed data after a confirm).
- About: app version (package_info_plus), licenses (showLicensePage).

## Help & Support
- A searchable FAQ with accordion items (8 realistic Q&As about scanning, work orders, offline mode).
- "Contact support": email/phone rows with copy buttons.
- "Report a bug": a form with a screenshot attachment that shows a success sheet.

## Final QA pass (do all of this and report back)
1. **Button audit:** go through every screen file. List every tappable widget (onTap / onPressed) and what it does. Fix any that are empty, `() {}`, TODO, or only print. Give me the full table: Screen | Element | Action.
2. **Design check:** for each design image in `design/`, compare the screens side by side and fix differences in layout, spacing, colours, icons and wording. Keep the data corrections that the prompts asked for.
3. **Consistency check:** run the Data check screen logic as a unit test. Every tab/badge/tile count must equal its list length, stock balances must add up, and each asset ID must appear with the same name, location and status everywhere.
4. **Cross-module flows** (write widget/integration tests where practical, or verify manually and list the results):
   - Report a critical issue → alert + notification appear → create WO from it → complete tasks → close WO → asset status Active → Home counts update.
   - Scan an asset → Move → submit → approve from My Approvals → location updates in Asset detail and Tracking.
   - Inspection with an out-of-range reading → finding → WO.
   - Go offline → complete a task and add a photo → Pending Sync shows them → go online → sync runs.
   - Receive a PO → stock and history balance update.
5. **Robustness:**
   - No overflow stripes on a small (360×640) or large phone.
   - Long text uses ellipsis.
   - Scroll works everywhere.
   - Back navigation is correct.
   - The keyboard doesn't cover form fields.
   - Loading shimmers and empty states exist on every list.
6. **Performance:** use const widgets where possible, and lazy-load lists with ListView.builder.
7. Make `flutter analyze` clean and all tests pass (`flutter test`).
8. Update `README.md`: how to run, the demo login (rex.kumar / Asset@360, code 123456), the developer toggles, and a module list.
9. Build the release APK:
   `flutter build apk --release --split-per-abi`
   Tell me the output path of the arm64-v8a APK.

## Done when
The QA table shows no dead taps, all flows pass, and the APK installs and runs on my phone.
