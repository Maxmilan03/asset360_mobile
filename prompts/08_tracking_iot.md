# PROMPT 08 — Tracking & IoT (design/06_tracking_iot.jpg)

Follow `CLAUDE.md`. Build the 3 screens. No map SDK: draw the indoor floor plan with **CustomPaint** (rooms, aisles and labelled zones: Receiving, Storage, Zone B, Dispatch), in the same light-grey isometric-flat look as the design.

## Screen 1 (left): Tracking & IoT hub
- 4 top tabs with icons: **Live Map** (selected) | **Asset List** | **Sensors** | **Geofencing**. Each shows real content:
  - **Live Map:** the full hub as below.
  - **Asset List:** all tracked assets with online/offline dot, battery and last seen. Tap → Asset Tracking.
  - **Sensors:** sensor cards (temperature, vibration, door, battery), each with its current value and threshold. Tap → a telemetry chart.
  - **Geofencing:** the zones list (Main Warehouse, Production Floor, Admin Block – Restricted) with toggles for "Alert on exit" / "Alert on entry", and "+ Add Zone" (name + draw a rectangle on the floor plan by dragging).
- Search bar and filter.
- 4 counters: Online 166, Offline 12, Low Battery 8, Alerts 6 (from the tracking summary). Each is tappable and filters the map/list.
- **Map card:**
  - Pins for people (blue person), equipment (green) and alerts (red).
  - The FL-012 forklift pin has a callout "Forklift FL-012 · Moving · Main Warehouse · 1 min ago" with a chevron → Asset Tracking.
  - Layers button: a sheet with toggles People / Equipment / Vehicles / Alerts / Zones.
  - "2D" toggle between 2D and a slightly tilted pseudo-3D view (transform).
  - Zoom + / − and pinch-zoom (InteractiveViewer).
  - Tapping any pin shows its callout.
- Category chips: All Assets (178) / People (24) / Equipment (142) / Vehicles (12). They filter the pins.
- **Recent Activity:** "Forklift FL-012 moved to Warehouse – Zone B", "Pallet TR-0458 exited Production Line 2". "View All" opens the activity log.
- **Live simulation:** every 3 seconds, move the FL-012 pin along its route and add an activity entry when it changes zone.

## Screen 2 (middle): Asset Tracking (FL-012)
- Asset card: photo, ID, Online chip, type, location, "Assigned to: Rakesh Kumar", chevron → Asset detail.
- Tabs: **Live Tracking** | Details | Telemetry | History | Geofence.
- **Live Tracking:**
  - Floor plan with the dotted route trail and a moving forklift marker with a "Moving · 5 km/h" bubble.
  - Layers / 2D / zoom controls.
  - "Last Updated … · Live" bar that updates.
  - 6 tiles: Speed, Battery, Hours Used, Engine Status, Load Status ("Loaded" since load is 0.8 t; the design's "No Load" contradicted this), RSSI.
- **View History:** plays back the route for the chosen time range with a slider.
- **Create Work Order:** WO form prefilled with FL-012.
- **Details:** asset info.
- **History:** a timeline of zone entries and exits.
- **Geofence:** which zones the asset is allowed in, with toggles.

## Screen 3 (right): Telemetry tab
- Time range dropdown (Last 1 Hour / Last 24 Hours / Last 7 Days); changing it regenerates the chart data.
- 3×3 tiles, each with a mini sparkline: Battery Level (with progress bar), Operating Hours, Motor Temperature ("42 °C"; fix the design's doubled "℃C"), Voltage, Current, Load, Speed ("Speed", not "GPS Speed": this is indoor positioning), Location, Signal Strength (bars).
- Tapping a tile switches the **Sensor History** chart to that metric (the tooltip shows value and time).
- "View All" → a full-screen chart with a pinch-zoomable timeline.

## Done when
The map animates live, every control (layers, 2D, zoom, chips, pins, tabs, time range) works, and all three screens match the design.
