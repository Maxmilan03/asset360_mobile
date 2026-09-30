# PROMPT 18 — Offline Sync (design/16_offline_sync.jpg)

Follow `CLAUDE.md`. Build the 3 screens and an app-wide offline mode.

## App-wide offline mode
- Add `connectivity_plus`. Also add a **"Simulate offline"** toggle in More → Settings → Developer, since this is a demo.
- When offline, a slim banner under every header reads "You're offline – changes will sync later". Tapping it → Offline Sync.
- **While offline, every create or update action in other modules** (new WO, task completed, inspection answers, issue, asset move, photo, document) is **still applied locally** and **also added to the sync queue** with its type, reference, title and time. The Pending badge updates.
- When back online with auto-sync allowed (Wi-Fi ON, or mobile data ON), sync starts automatically.

## Screen 1 (left): Offline Sync
- "You're Offline" card with a cloud-off icon (or "You're Online" with a green cloud when connected).
- 4 tiles, all computed from the queue:
  - Pending Sync
  - Completed Locally
  - Photos to Sync ("2"; the design's "8" didn't add up)
  - Syncing Now
- **Sync Status** card: ring % = synced / total local items, with a legend "Synced 25 / Pending 8 / Failed 0". A chevron opens the history of sync runs.
- **Automatic Sync:** master toggle, "Sync when connected to Wi-Fi" toggle, "Sync when connected to Mobile Data" toggle. All work and persist in state.
- **Last Sync:** date/time + "Synced 25 items successfully", and a **⟳ Sync Now** button.
  - When offline, it shows "No internet connection" and offers "Try anyway (demo)".
- **Pending Items (n)** grouped (Work Orders, Inspections, Asset Updates, Photos & Attachments) with count bubbles; each → Pending Sync filtered to that type. "View All" → Pending Sync.

## Screen 2 (middle): Pending Sync
- Tabs: All (8) / Work Orders (3) / Inspections (2) / Assets (1) / Photos (2) / Documents (1), scrollable and computed.
- Rows: type icon square, reference, subtitle, date/time, "Pending Sync" chip.
  - ⋮ menu: View Item (opens the real record), Sync This Item, Discard (confirm; this removes it from the queue).
- **🗑 Clear All:** a confirm dialog warning that local changes will be lost.
- **Sync All (n)** → Screen 3.

## Screen 3 (right): Syncing Data
- Cloud-upload icon in an animated progress ring, "Syncing… / Uploading data to server", and "Please keep the app open while syncing".
- Overall "%" and "x of n items synced" with a bar. **x counts only fully synced items.**
- A per-item list with states:
  - Synced (green ✓ + time)
  - Uploading (ring + %, animating 0→100)
  - Waiting (clock)
  - Failed (red, with Retry)
- Process items one at a time for about 0.6–1.5 seconds each, with photos taking longer.
- Add a 10% chance (Developer toggle "Simulate sync failures") that an item fails.
- **✕ Cancel Sync:** stops after the current item; the rest stay pending.
- When finished: a success state "All items synced", Last Sync updates to DemoClock, the ring goes to 100% (or shows failures), and a "Done" button returns to the Offline Sync screen.

## Done when
Going offline (real or simulated) queues changes from every module, and syncing processes them visibly with cancel, retry and failure handling. All counts are computed.
