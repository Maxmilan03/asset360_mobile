# PROMPT 13 — Alerts & Notifications (design/11_alerts_notifications.jpg)

Follow `CLAUDE.md`. Build the 3 screens. The bell in every header opens the **Notifications** screen, and its badge = unread count.

## Screen 1 (left): Alerts & Notifications
- 4 severity tiles: Critical 8 / High 12 / Medium 18 / Low 7, computed. Tapping a tile selects the matching tab.
- Tabs: All (45) / Critical / High / Medium / Low.
- Search (asset, type, location) and filter sheet (type, status Active / Acknowledged / Resolved, date).
- Rows: severity icon square, asset photo, alert title, asset ID | name, location, severity chip, time ago (from DemoClock). Tap → Alert Details.
- Swipe left → Acknowledge. Long-press → multi-select, with a bulk "Acknowledge" / "Resolve" bar.
- A generated "live" alert arrives every 60 seconds while this screen is open: an in-app banner at the top, and the badge increments.

## Screen 2 (middle): Alert Details (Low Battery, FL-015)
- Red banner: icon, title, description, Critical chip.
- Asset card → Asset detail.
- Tabs: **Details** | History | Actions | Related Assets.
- Details: Alert Type, Severity chip, Asset ID, Alert Time, Battery Level (red), Threshold, Current Location, Reported By "System (IoT Sensor)", Description.
- **Battery Level Trend (Last 24 Hours)** chart. The x-axis runs 12 AM → **10:24 AM (the alert time)**; the design's axis ran to 9 PM, which doesn't fit. Show a red end-point label "18%".
- **History:** earlier occurrences of this alert on this asset.
- **Actions:** log of who acknowledged or resolved it and when.
- **Related Assets:** other assets in the same zone with active alerts.
- Buttons:
  - **Acknowledge** (optional note) sets the status to Acknowledged, adds to Actions, and changes the button to **Resolve**.
  - **Create Work Order** opens the WO form prefilled from the alert and links them.

## Screen 3 (right): Notifications
- Tabs: All / Unread (12) / System / Work Orders, computed.
- Rows: coloured icon square, title, message, time ago, red unread dot.
  - Tapping marks the item read (the dot disappears, the badge decreases) and deep-links: WO → WO detail, alert → Alert detail, stock → Part detail, asset moved → Tracking.
- AppBar ⋮ menu: "Mark all as read", "Notification settings" (a toggles screen for categories and quiet hours).
- Swipe left to delete, with an Undo SnackBar.

## Done when
The badge, read/unread state, acknowledge/resolve and deep links all work, and alerts created by other modules (e.g. critical issues) appear here.
