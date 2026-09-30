# PROMPT 17 — Asset Audit (design/15_asset_audit.jpg)

Follow `CLAUDE.md`. Build the 3 screens.

## Screen 1 (left): Asset Audit
- 4 tiles: My Audits 3 / In Progress 1 / Pending 1 / Completed 1, computed.
- Tabs: My Audits / Assigned / Completed. **Tab counts must match the tiles** (the design shows Completed 5 vs 1).
- Search (audit name, site, asset type) and filter.
- Audit cards: building photo, name, status chip, site (📍), date range (📅), Total Assets, progress bar + %. Tap → Audit session.
- "+" FAB → **Create Audit Campaign:** name, site, scope (location / category multi-select), date range, auditors (multi people picker), and "Blind count" toggle. Saving creates a Pending audit.
- Pending audits show a **Start Audit** button, which sets the status to In Progress.

## Screen 2 (middle): Audit session (Annual Asset Audit 2026)
- Title, site | date range.
- Progress "900 / 1,500" with bar and "60%", computed from results.
- 4 result tiles, each tappable to show the list of those assets:
  - Verified 850 (green ✓)
  - Wrong Location 25 (amber pin)
  - Not Found 15 (red ✕)
  - Unregistered 10 (violet +)
- Mode toggle: **Scan** (selected) | Search | Manual Entry.
  - Scan: a real camera preview (mobile_scanner) in the rounded card with the violet frame, plus flash, capture and gallery buttons. The hint bar reads "Position the QR / Barcode within the frame".
  - A scanned known asset goes to Screen 3. An unknown tag opens "Unregistered asset found": capture photo + description + location, which increments Unregistered and offers "Register now" (→ Registration).
  - Search / Manual: pick an asset → Screen 3.
- ⋮ menu:
  - **Complete Audit:** confirm, with a summary of the unscanned assets that will become Not Found. The audit becomes Completed.
  - **Export Report:** shows a report screen with a summary, charts and discrepancy lists, plus "Share" (SnackBar).
  - **Pause Audit.**

## Screen 3 (right): Asset Found
- Green ✓ banner.
- Asset card: photo, ID, name, location lines, and a result chip (Verified once saved).
- Info rows: Asset Type, Serial Number, **Tag ID** (show the actual tag technology scanned, QR or RFID, consistently; the design says RFID but shows a QR label), Status, Current Location, Custodian.
- **Audit Action:** 4 selectable cards (Verified / Wrong Location / Not Found / Unregistered). Selecting **Wrong Location** reveals "Scanned Location" and an "Update asset location to scanned location" checkbox.
- **Audit Details:**
  - Scanned Location field with a 📍 button that picks from the location tree.
  - Condition dropdown (Good / Fair / Poor / Damaged).
  - Remarks.
  - Add Photo.
- **Close** (discard) / **Save & Next →:**
  - Saves the result and updates the tiles and progress.
  - If "update location" was ticked, it changes the asset's location everywhere and adds a movement record.
  - Then returns to scanning for the next asset.
  - Scanning an asset that was already audited shows "Already verified at 10:12 AM – re-audit?".

## Done when
Audit campaigns can be created, started, run by scanning, and completed with a report, with every tile and count computed from the results.
