# PROMPT 07 — Scan & Identify and Scan History (design/05_scan_identify.jpg)

Follow `CLAUDE.md`. Build the 3 screens. This is the centre Scan button of the bottom bar.

## Screen 1 (left): Scan & Identify
- Title and subtitle. Tabs with icons: **QR / Barcode | NFC | RFID | BLE**.
- **QR / Barcode:** a real camera preview using `mobile_scanner`, with the rounded violet corner frame overlay.
  - Scanning auto-detects; the "Tap to Scan" button also triggers a capture.
  - A detected code matching an asset ID, barcode or tag goes to Screen 2.
  - An unknown code shows a sheet: "Tag not registered" with "Register this asset" (→ Registration, prefilled) and "Scan again".
  - Right-side round buttons: flash toggle (torch on/off), and gallery (pick an image and scan the QR code from it).
  - Handle camera permission denial with a friendly screen and an "Open Settings" button.
- **NFC / RFID:** a "Hold your phone near the tag" animation. After 2 seconds, simulate reading the tag of a random existing asset → Screen 2.
- **BLE:** a "Searching nearby beacons…" list that fills in over 3 seconds with 4 nearby assets and their signal strength. Tap one → Screen 2.
- Bottom buttons:
  - **Manual Entry** → sheet with an Asset ID field that autocompletes from assets.
  - **Multi Scan** → continuous mode: each scan adds to a counter list at the bottom; "Done" shows the list, with bulk actions Move / Audit.
- **Demo helper (debug builds only):** a small "Simulate scan" chip that pretends MTR-00123 was scanned, because it's hard to scan without a printed tag. Also add More → Settings → Developer → "Print demo tags", which shows QR codes for the assets on screen so they can be scanned from a second phone.

## Screen 2 (middle): Asset Identified
- Green ✓ banner "Asset Identified / Asset details loaded successfully". Play a short haptic vibration on success.
- Asset card: photo, ID, name, type, location, status chip, chevron → Asset detail.
- 3×3 action grid, each prefilled with this asset:
  - View Details → Asset detail
  - Create Work Order → WO form
  - Create Inspection → inspection form
  - Move Asset → transfer flow
  - Report Issue → issue form
  - Check Out → check-out sheet
  - View on Map → Tracking focused on the asset
  - Add Photo → image_picker, added to the asset's photos
  - More Actions → sheet

## Screen 3 (right): Scan History
- Title, and a "🗑 Clear All" button (confirm dialog).
- Filter chips: All / Assets (n) / Parts (n) / Locations (n), counted from history.
- Rows: photo, ID, name, location, time scanned, status chip → Asset detail.
- Every scan in the app (from any mode) is added to the top of this history. Seed it with the 6 scans shown in the design (status from the asset data).
- Swipe a row left to remove it.

## Done when
Real QR scanning works on the phone camera, NFC/RFID/BLE are simulated convincingly, and every action tile opens the right prefilled flow.
