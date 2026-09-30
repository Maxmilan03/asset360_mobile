# PROMPT 14 — Inventory / Spare Parts (design/12_inventory_spare_parts.jpg)

Follow `CLAUDE.md`. Build the 3 screens plus the hub tiles. Use the corrected stock history from `lib/data` (balances must add up).

## Screen 1 (left): Inventory hub
- 4 large tiles:
  - **View Inventory** → all parts list
  - **Request Part:** form with part picker, quantity, needed-by date, linked WO (optional), reason. It creates a Part Request (Pending) and shows it in a "My Requests" list.
  - **Purchase Orders:** PO list (PO-2026-0123 Received, PO-2026-0107 Received, plus 2 Open). PO detail shows its lines, and "Receive (GRN)" on open POs adds stock and a history entry.
  - **Stock Reports:** usage chart for the last 6 months (bar chart), top 5 consumed parts, and a forecast line with a reorder-date estimate.
- Tabs: All Items (124) / Low Stock (8) / Reorder (12) / Reserved (6). Because All Items exceeds 50, it follows the summary rule: show the detailed records with "Showing 20 of 124".
- Search (part no., name, category) and filter sheet (category, warehouse, stock status).
- Rows: part photo, name, part no., category, warehouse (📍), stock chip (In Stock green / Low Stock amber / Out of Stock red, **computed from qty vs reorder level**), and qty. Tap → Part Details.

## Screen 2 (middle): Part Details
- Photo: use `assets/images/bearing.jpg` for Motor Bearing 6205. The design wrongly shows a motor.
- Name, In Stock chip, Part No, Category, Unit, Manufacturer, Description; chevron → full spec sheet.
- **Stock Overview** with Edit:
  - Current Stock 36 (green), Reorder Level 10 (amber, ⚠), Reorder Qty 50 (blue).
  - Edit lets you change reorder level and quantity, with validation.
- **Location Details** with Manage:
  - Primary Location, Rack/Bin, Reserved Qty, Available Qty (current − reserved, computed), Last Stock Update.
  - Manage opens a sheet to change the bin, or **transfer stock** between warehouses (quantity, destination). This creates a Transferred history entry.
- **Additional Information:** Lead Time, Unit Cost, Preferred Supplier, Warranty, Remarks.
- **Create Request** (the Request Part form, prefilled) / **Create Purchase Order**:
  - The PO form has supplier (prefilled), quantity (default = reorder qty), unit cost, expected date, and computes the total.
  - Saving creates PO-2026-01xx (Open).
- A stock-adjust ⋮ menu: "Issue to Work Order" (pick WO + qty → Issued entry, stock decreases) and "Stock Count Adjustment" (new counted qty + reason).

## Screen 3 (right): Stock Movement
- Part card at the top.
- Tabs: **Stock History** | Usage | Reserved | Purchase Orders.
- Search (reference, work order, remarks) and filter (type, date range).
- History entries: icon by type (Received green +, Issued red −, Transferred blue ⇄, Reserved orange 🔧), title, REF, From/To/Asset lines, date and time, signed quantity (green + / red −), and running "Balance".
  - **Balances must be mathematically consistent**, and every new action in the app appends a correct entry.
  - Tapping REF deep-links: WO → WO detail, PO → PO detail, GRN → receipt view.
- **Usage:** a monthly consumption bar chart. **Reserved:** active reservations by WO, with "Release". **Purchase Orders:** this part's POs.
- When any action pushes available stock to or below the reorder level, create a "Stock Level Low" notification.

## Done when
Every stock action (receive, issue, transfer, reserve, release, adjust) updates the quantities, chips, history and balances consistently, and the POs and requests work.
