# PROMPT 05 — Assets list and Asset 360° detail (design/03_assets_detail_iot.jpg)

Follow `CLAUDE.md`. Build the 3 screens in the image. Also build the tabs that the image only hints at (Location, Maintenance, Inspection, Financial, Documents, History) in the same style.

## Screen 1 (left): Assets list (Assets tab of the bottom bar, no back arrow)
- Title "Assets", subtitle "Search, scan or filter assets".
- Search field. Searching by ID, name, serial or location filters live. A scan icon inside the field → Scan screen; the scan result returns here and opens the asset.
- Chips: All / My Assets (custodian = Rex or assigned to him) / Nearby (assets in "Main Plant") / Favorites (starred assets).
- "Total Assets (12,458)" with a "Filter" link. The filter sheet has Status, Category, Location and Criticality multi-selects, plus Apply / Reset. It shows active filter chips that can be removed.
- Rows (AssetListTile): photo, ID, name, location, two small tags (category, manufacturer), status chip, chevron. Tap → Asset detail.
- Footer "Showing 21 of 12,458".
- Floating "+" button → Asset Registration.

## Screen 2 (middle): Asset detail, Overview tab
- Header: ID, status chip, subtitle.
  - The ☆ button toggles Favorite (filled star, SnackBar).
  - The ⋮ menu: Edit Asset, Print Tag, Share, Duplicate, Retire Asset (confirm dialog, which changes status to Retired), Delete (confirm).
- Photo on the left and a spec block on the right: Asset Type, Category, Model, Manufacturer, Serial No., Tag ID (RFID), and a drawn barcode with its label. Tapping the photo opens a full-screen zoomable viewer.
- 4 stat cards:
  - Health Score ring 87%. Tap opens a sheet explaining the score.
  - Criticality with a gauge icon.
  - Age, computed from purchase date to DemoClock, e.g. "3.7 Years".
  - Warranty Expiry "28 Feb 2027".
- 8 action tiles:
  - Create Work Order → WO form prefilled with this asset
  - Create Inspection → inspection form prefilled
  - Move Asset → Transfer flow with this asset selected
  - Report Issue → issue form prefilled
  - Check Out → check-out sheet (custodian picker, due-back date, remarks; confirming changes the custodian)
  - View on Map → Tracking, focused on this asset
  - Add Photo → image_picker; the photo is added to the gallery
  - More Actions → sheet with Print QR Tag, Transfer Ownership, Link IoT Device, Clone
- Tabs: Overview | Location | IoT | Maintenance | Inspection | Financial | Documents | History (scrollable).
- **Overview → Key Information** card with "Edit ▾":
  - Asset Status, Condition, Operational Status as chips.
  - Location, Custodian, Purchase Date, Commissioned Date.
  - Warranty Expiry in red with days remaining computed. It turns red when under 180 days, and shows "Expired" if past.
  - AMC.
  - Edit makes the fields editable inline (dropdowns and date pickers) with Save / Cancel. Saving updates the asset everywhere.

## Screen 3 (right): IoT tab
- **Live Telemetry** card: Online chip, "Last Updated", and a 3×2 grid of Runtime, Spindle Speed, Temperature, Vibration (RMS), Energy Consumption and Feed Rate.
  - Values tick slightly every 5 seconds (small random walk around the seed values) to feel live.
  - Tapping a tile selects it for the chart.
- **Live Data Trend (Last 24 Hours)** line chart (fl_chart) with a metric dropdown (Temperature, Vibration, Spindle Speed, Energy). Switching changes the data. Tapping a point shows a tooltip.
- **Device Information:** IoT Device, Device Type, IMEI, SIM/ICCID (long-press to copy), battery bar, signal bars, Last Seen, Firmware Version, Connectivity Status.

## Other tabs (build in the same card style)
- **Location:** current location path, mini floor plan with the asset pin, a "View on Map" button, and a location history list.
- **Maintenance:** this asset's work orders (tap → WO detail), next PM date, and a "Create Work Order" button.
- **Inspection:** this asset's inspections and "Create Inspection".
- **Financial:**
  - Purchase cost, current book value (straight-line depreciation computed), AMC cost, maintenance cost to date.
  - TCO = acquisition + maintenance + spares + labor + energy − resale, shown as a small breakdown bar.
- **Documents:** this asset's documents → Document details. "+ Add" → Add Document prefilled.
- **History:** a timeline of events (registered, moved, WOs, inspections).

## Done when
All 3 designed screens match, every tab has real content, and every star, menu, tile and edit action works and persists in memory.
