# Home dashboard phase — report

Dashboard service (port 5470, `DASHBOARD_BASE_URL`, DEV default `http://172.16.100.26:5470`). Sources read:
`MobileDashboardEndpoints.cs`, `Contracts/MobileDashboardContracts.cs`, `Mobile/MobileDashboardService.cs`,
`NetworkStatusEndpoints.cs`, `Contracts/NetworkStatusContracts.cs`. Real data checked with read-only GETs on
7 Nov 2026 (nothing created or changed).

## Query parameters per endpoint (from the C# endpoints)

| Endpoint | Parameters the server reads | App sends |
|---|---|---|
| `/mobile/home` | `utcOffsetMinutes` | phone offset |
| `/mobile/asset-overview` | `search` | drill-down search box |
| `/mobile/maintenance-performance` | `months` (1–24), `assetType`, `site`, `utcOffsetMinutes` | period menu 3/6/12, filter sheet, Home site |
| `/mobile/upcoming-activities` | `from`, `to` (≤ 1 year), `type`, `utcOffsetMinutes` | this week's Sunday + 8 weeks |
| `/mobile/recent-alerts` | `severity`, `days` (1–90), `page`, `pageSize` (≤ 100) | tabs, period menu (1/7/30/90), paging 20 |
| `/mobile/asset-locations` | `status`, `search` | status chips, search box |
| `/mobile/asset-health` | `top` (1–50) | 10 |
| `/mobile/cost-summary` | `period` (ytd / year / last-12-months), `year` | YTD this year / last year / last 12 months |
| `/mobile/recent-assets` | `status`, `search`, `assetType`, `site`, `page`, `pageSize` | chips, search, links from Overview / Health / Cost, Home site |
| `/network-status`, `/network-status/tags` | none | — |
| `/network-status/live` (WebSocket) | none | Bearer token on the upgrade request when signed in |

**No `site` parameter** on home, asset-overview, upcoming-activities, recent-alerts, asset-locations, asset-health or
cost-summary. The Home site selector therefore narrows only Maintenance Performance and Recent Assets; Home says so
under the "Showing X only" chip. Site names = `byLocation` of `/asset-overview` (asset `SiteName`).

## Home sections → endpoint

| Section | Endpoint | Notes |
|---|---|---|
| Greeting + 4 counters | `/mobile/home` (`greeting`, `quickActions`) | Open WOs, open inspections, pending approvals, critical alerts. Counters for WOs / inspections / approvals say "Not available yet" on tap (modules not connected); Critical opens Recent Alerts → Critical. |
| Quick Actions | — | unchanged (navigation) |
| My Tasks | — | **no endpoint** → "Not available yet" |
| Asset Overview | `/mobile/asset-overview` | legend → Recent Assets by status group |
| Maintenance Performance | `/mobile/maintenance-performance?months=6[&site]` | Planned %, overdue WOs, MTTR |
| Upcoming Activities | `/mobile/upcoming-activities` | first 3 items |
| Recent Alerts | `/mobile/recent-alerts?days=7` | first 3 items |
| Asset Location (Live) | `/mobile/asset-locations` | map preview + status counts |
| **Live Devices** (new) | `/network-status` + WebSocket `/network-status/live` | Live dot, backoff 2/5/10/30 s, closed when Home is hidden or app in background; tap → Devices (`/network-status/tags`) |
| Asset Health | `/mobile/asset-health?top=10` | ring + healthy / warning / critical |
| Cost Summary | `/mobile/cost-summary?period=ytd` | donut by category |
| Recent Assets | `/mobile/recent-assets[?site]` | first 3, rows → live Asset detail |

Each card loads on its own (own shimmer, own error + Retry, own empty message). The `/mobile/home` card fields
(assetOverview, maintenancePerformance, upcomingActivities summary, recentAlerts, assetLocation, assetHealth) are
parsed and tested, but the cards use the per-screen endpoints so one failure stays in one card and the site filter
works. Pull-to-refresh reloads every section.

## Drill-downs → endpoint

| Screen | Endpoint | Tabs / filters | Links |
|---|---|---|---|
| Asset Overview | asset-overview | By Status / Type / Location, server search | Recent Assets filtered (status / type / site) |
| Maintenance Performance | maintenance-performance | Overview / Trends / By Asset Type; period; site + asset type sheet | WO count cards → "Not available yet" |
| Upcoming Activities | upcoming-activities | List (type chips) / Calendar (week strip, dots from `days`) | rows → "Not available yet" |
| Recent Alerts | recent-alerts | All / Critical / Warning / Info (`counts`), period | rows → "Not available yet" (alert details) |
| Asset Location | asset-locations | status chips, search; flutter_map (OSM), pins coloured by status group | pin → card → View Details (live Asset detail) |
| Asset Health | asset-health | Overview / By Asset Type / By Location | critical asset → live detail; groups → Recent Assets |
| Cost Summary | cost-summary | YTD / last year / last 12 months | asset type → Recent Assets |
| Recent Assets | recent-assets | status chips, search, type + site chips, paging | live Asset detail |
| Devices (new) | network-status/tags | — | tag with asset → live Asset detail |

## Fields not provided by the server

- **My Tasks** (no endpoint at all).
- **MTTR / MTBF per month**: one value per period only → the Trends tab shows the WO chart and "Not available yet" for MTTR / MTBF trends.
- Upcoming Activities: **no audits** (mock had them); approvals have no asset id or location.
- Alerts: no location, no acknowledge / resolve; alert, WO and inspection ids cannot be opened (modules not connected).
- Asset Location: no floor / indoor position (lat / lng only; no floor plan).
- Asset Health: no per-asset score breakdown (Condition / Utilization / Maintenance / IoT) like the mock legend.
- Cost Summary: **no site filter**, no "top assets" per cost category.
- Greeting `userName` is null on the server → the app keeps the signed-in user's first name.
- Devices: tags give `assetId` from the IoT `assets` collection (`assetid`); if that is not an asset registration id the detail shows "not found".

## Server data on 7 Nov 2026

Non-empty: asset-overview (6 assets: 5 Operational, 1 Under Maintenance; 6 types; sites Dubai HQ 4, Jebel Ali
Warehouse 1, Building B 1), asset-health (66.7 % healthy, 4 / 2 / 0, no critical assets), recent-assets (6),
quick-action counts (all 0).

**Empty**: maintenance-performance (0 WOs, even with `months=24`), upcoming-activities (0, whole of 2026),
recent-alerts (0, `days=90`), cost-summary (0 for YTD, 2025 and last 12 months), asset-locations (0),
network-status (0 online / 0 offline), network-status/tags ([]). These show their empty messages, not zeros.

## Coordinates

`/mobile/asset-locations` **does return lat / lng per asset** (`latitude`, `longitude`, plus a `center`), so the map
view is built (flutter_map + OpenStreetMap tiles). On the DEV server no asset has coordinates yet (`totalCount: 0`,
`center: null`), so Home and the drill-down show "No assets on the map yet".

## WebSocket

`ws://172.16.100.26:5470/api/dashboards/network-status/live` upgrades (101) and sends
`{"totalOnline":0,"totalOffline":0}` on connect. The endpoints answered without a token; the app still sends the
Bearer token when signed in.

## Tests

`test/live/dashboard_test.dart` (21): parsing of every endpoint + the query parameters sent, tolerant parsing,
ws / wss URL, reconnect backoff / reset / stop with a fake channel and fake timers, the notifier's REST → socket
counts, Home in API mode (every section from its endpoint, no mock value), one failing section + Retry, site
filter, every drill-down's tabs / filters, Devices → asset detail, pull-to-refresh.

---

# Update — Dashboard service refresh (7 Nov 2026)

Re-read MobileDashboardEndpoints.cs, MobileDashboardContracts.cs and Mobile/MobileDashboardService.cs.

## Changes on the server and in the app

| Item | Server | App |
|---|---|---|
| My Tasks | NEW `GET /mobile/my-tasks?type=&site=&utcOffsetMinutes=`: the bearer token's user (no `user` parameter), no paging, `counts` (total / workOrders / inspections / approvals / overdue / dueToday) | Home card (tabs with server counts, "N overdue · N due today", 3 rows) + `/home/tasks` screen. Rows: WO / inspection / approval modules are not connected → "Not available yet"; the asset tag link opens the asset. 401 → that card's error + Retry. |
| Counters | `/mobile/home` `quickActions` | unchanged (already used) |
| Device tags | `assetRegistrationId` added, `assetId` null | rows open `assetRegistrationId` |
| Alerts → asset | `assetId` = asset TAG | tag link → `GET /api/asset-registrations/lookup?code=&type=assetTag` → live detail; 404 → snack "No asset with tag X was found". The row itself: "Alert details: Not available yet". |
| Site | **every** mobile endpoint takes `site` (name or id) | every Home card + drill-down sends it; the "only some cards" note is removed. Site list = `/asset-overview` `byLocation` (unfiltered). |
| Greeting | `userName` filled when a token is sent | `greeting.userName` ?? signed-in first name |
| Status keys | operational / under-maintenance / out-of-service / retired (+ other) | server labels; colour by key: green / amber / red / grey (chips, filter-chip dots, legends, donuts, map pins) |

## Real data now (read-only, 7 Nov)

| Section | Data |
|---|---|
| Counters (`/home`) | 10 open WOs, 5 inspections, 3 approvals, 5 critical alerts (Dubai HQ: 8 / 3 / 0 / 4) |
| Asset Overview | 6 assets (5 Operational, 1 Under Maintenance) |
| Maintenance Performance | 32 WOs in 6 months, 78.1 % planned (25 / 3 / 4) |
| Upcoming Activities | 15 in the next 30 days |
| Recent Alerts | 13 in 7 days (5 critical, 6 warning, 2 info) |
| Asset Location | **6 assets with lat / lng → 6 pins** (Dubai, centre 25.1713, 55.2486) |
| Asset Health | 6 assets, 66.7 % healthy |
| Cost Summary | real costs (Dubai HQ YTD AED 46,765) |
| Recent Assets | 6 |
| Live Devices | 3 online / 1 offline; 4 tags (TAG-DEMO-001…004 → AR000002…AR000005) |
| My Tasks | 401 without a token — **not verified with a real token** (see below) |

## Token checks

- Without a token: everything 200 except `my-tasks` (401).
- With an invalid token: the same (the other endpoints ignore it; `my-tasks` 401).
- With a real token: not run — no token / test credentials were available to this session. `greeting.userName` and
  My Tasks contents are therefore only verified with contract-shaped test data.

## Tests

`test/live/dashboard_test.dart` now 26 tests (+ my-tasks parsing, site on every endpoint, status tones, alert tag →
lookup / not-found snack, My Tasks tabs / View All / 401, greeting userName). Full suite: 336 passing.
