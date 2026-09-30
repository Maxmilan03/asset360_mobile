# PROMPT 06 — Asset Registration (design/04_asset_registration.jpg)

Follow `CLAUDE.md`. Build the 3 screens.

## Screen 1 (left): Asset Registration hub
- Toggle cards: **Single Asset** (selected, violet border) / **Bulk Registration**.
- "Capture Asset Information / Scan tag or enter details manually", then 4 tiles:
  - **Scan QR / Barcode** → camera scanner. The scanned value fills Barcode/QR; if it matches an existing asset, show "This tag belongs to MTR-00123 – View asset?".
  - **Scan RFID / NFC** → a "Hold the tag near the phone" sheet with a pulsing animation. After 2 seconds it simulates a read, e.g. "RFID-A360-000789", and fills Tag ID.
  - **Manual Entry** → form step 1 with empty fields.
  - **Capture from Photo** → image_picker; the photo becomes the Asset Photo, then open form step 1.
- **Recent Scans** list with a "New" chip. Show only assets registered during this session plus MTR-00123, FL-012 and LAP-0098 as examples, but label the existing ones **"Existing"** (grey), not "New". "View All" → Scan History.

**Bulk Registration** screen (same style):
- "Download CSV template" shows a SnackBar with the column list and copies the header row to the clipboard.
- "Upload CSV" (file_picker, .csv) parses rows and shows a preview table with a valid/invalid count per row.
- "Import" adds the valid assets and shows a success sheet.

## Screen 2 (middle): 5-step form, step 1 "Basic"
- StepperHeader: Basic, Classification, Location & Custody, Additional, Review. The current step is filled violet, completed steps show a ✓, and tapping a completed step jumps back to it.
- Step 1 fields as in the design:
  - Asset Photo with a camera button.
  - Asset ID* with a scan icon; auto-suggest the next ID by category prefix.
  - Asset Name*, Serial Number.
  - Tag ID (RFID) with a scan icon, Barcode / QR with a scan icon.
  - Status*, Condition, Operational Status, Criticality dropdowns, each with a coloured dot.
  - Purchase Date and Commissioned Date pickers (commissioned can't be before purchase).
- **Validation:** Asset ID, Tag ID and Barcode must be **unique**. If a value already exists, show an inline error "Already used by CNC-00123". The design's example reuses CNC-00123's tag; that must be rejected.
- **Step 2 Classification:** Category, Asset Type, Manufacturer, Model, Parent Asset (picker), Tags.
- **Step 3 Location & Custody:** Site, Building, Floor, Room/Zone (cascading dropdowns), Custodian (people picker), Department.
- **Step 4 Additional:** purchase cost (AED), supplier, PO number, warranty expiry, AMC yes/no + vendor, expected life (years), documents (file_picker, multiple), and link an IoT device (optional, picker of unlinked devices).
- Buttons: Cancel (confirm-discard dialog if anything was typed) / Next → (validates the current step).

## Screen 3 (right): Review
- Green banner "Asset details are ready to be registered".
- Summary card with photo, ID, name, category and location.
- Two-column Asset Details grid.
- Collapsible "Location & Custody", "Financial Information" and "Documents (n)" sections. Each "Edit" jumps to its step.
- **Back** / **✓ Register Asset**:
  - Register adds the asset to the repository and shows a success sheet with the new asset ID and a drawn QR code.
  - The sheet has buttons "View Asset", "Print Tag" (SnackBar) and "Register Another".
  - The Assets list and Home counts update.

## Done when
A new asset can be registered end to end on the phone and appears in the Assets list and search. Duplicate tags are blocked. Bulk import works with a CSV.
