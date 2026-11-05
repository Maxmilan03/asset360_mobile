# Asset Registration — web / backend alignment report

Sources: `design/web_registration/1…5_*.png` (web app), `docs/api_samples/swagger.json` (backend DTOs),
`docs/api_samples/criticality_options.json`, `condition_ratings.json`, `assets_list_empty.json`.
Model: `lib/data/models/asset_registration.dart`. Rules: `lib/data/validation/asset_registration_validator.dart`.
Values: `lib/data/reference/asset_options.dart`.

## 1. Web screenshot fields with no backend field

| Step | Web field / control | What the app does |
|---|---|---|
| 1 | Category / Sub Category / Asset Type (shown in web step 1) | The backend stores them in `classification`, so the app edits them in step 2 only; step 1 shows the path read-only. |
| 1 | Identification Preview, Generate QR Code, Quick Actions (Scan Barcode, Read RFID, Print Label) | UI only (QR encodes the asset tag). |
| 2 | Category Reference panel, Change Category, Classification Hierarchy tree, ⚙ buttons next to Category / Sub Category | UI only; the hierarchy is `registration_options.dart` until `/api/asset-categories`. |
| 3 | Select Location panel (Hierarchy View, Map / Floor Plan, location search), the "Track Assets" root node | UI only. "Track Assets" may be the project (`projectId`) — not confirmed, so `projectId` stays null. |
| 3 | Current Assignment Preview, reset (↺) icons on Responsible Team / Assignment End Date | UI only. |
| 4 | "AED" suffix on Purchase Cost, reset (↺) on Tax | Display of `purchase.currency`; UI only. |
| 4 | Invoice & Documents: drag & drop box, per-file download and ⋮ menu | Files go to `purchaseWarranty.documents[]`; download / menu are UI actions. |
| 5 | Technical Specifications: Power Rating, Voltage, Frequency, Phase, Fuel Type, Fuel Tank Capacity, Operating Temperature Range, IP Rating, Noise Level (with unit dropdowns) | No dedicated backend fields: stored as `technical.specifications[] {name, value, unit}` from a per-type template (`technical_templates.dart`). |
| 5 | Custom Fields "Notes" with a 51/200 counter | Backend has no length rule for `customFields[].value`; the app does not limit it. |
| 5 | Web Submit on step 5 | The app adds a mobile-only Review step 6 with Submit. |
| — | Mobile-only extras: Parent Asset, linked IoT device, Assess-sheet ratings | Kept on the phone only (`RegistrationLocalExtras`, never in `toJson`). Backend homes later: `/api/asset-hierarchy`, IoT pairing, `POST /api/asset-criticality`. |
| — | Operational Status (old mobile field) | Removed from the wizard; on the Asset detail it is now read-only (live IoT state, not a registration field). |

## 2. Backend fields not shown in the app

| Backend field | Why |
|---|---|
| `id`, `createdBy`, `createdAt`, `updatedBy`, `updatedAt` | Set automatically (drafts show "Saved <updatedAt>"). |
| `CreateAssetRegistrationDraftRequest.clientId`, `tenantId` | Request-only fields of the create call, not part of the entity; to be filled from the session when the API is connected. |
| `basicInformation.criticality` | Not a separate input: the one Criticality field (step 2) writes both `basicInformation.criticality` and `classification.criticality`. |
| `location.projectId` | No project concept in the app yet (null). |
| `location.roomId` | Room / Location is free text (no room list), so only `roomName` is set. |
| `location.locationPath` | Computed ("UAE > Dubai Factory > Building A > …") and shown read-only; the server may rebuild it. |
| `location.countryId` … `zoneId` | Not displayed; set from the picked names (location codes, see §3). |
| `assignment.assignedToUserId` | Set by the person picker; the name is shown. |
| `purchase.totalCost`, `warranty.warrantyEndDate` | Shown as "calculated" previews only; the server recalculates them. |
| `documents[]/attachments[].url, contentType, uploadedAt` | Kept but not shown (file name and size are). |
| `technical.dimension*/weight*/expectedLifespan*` for Laptop, Forklift and Fire Pump | Their templates hide dimensions (Laptop, Forklift) or dimensions + weight (Fire Pump). Every other type, with or without a template, shows them. |
| Criticality request: `assessmentDate`, `validUntil`, `nextReviewDate`, `assessedBy`, `approvedBy`, `criteria[].justification`, `remarks` | Separate endpoint (`POST /api/asset-criticality`), not part of the registration. The Assess sheet keeps only likelihood, consequence and criteria scores. |

## 3. Guesses (to confirm with the backend team)

1. **Status strings** "Active", "Under Maintenance", "In Repair", "Disposed" are inferred from the list `summary` keys (`active`, `underMaintenance`, `inRepair`, `disposed`, `other`). Any other stored value (mock: Inactive, Retired) is counted as Other.
2. **Error keys**: PascalCase paths relative to each step's request DTO — step 1/2 `AssetName`, `AssetTag`, `Category` …; step 3 `Location.CountryId`, `Assignment.AssignmentEndDate`; step 4 `Purchase.PurchaseCost`, `Warranty.WarrantyPeriodUnit`. Only "Purchase.PurchaseCost" was given as an example.
3. **Message wording**: only the duplicate-tag message ("An asset with tag 'X' is already registered.") is the backend's; "X is required.", "Quantity must be greater than 0.", etc. are written in the same style.
4. **Duplicate check**: tags are trimmed and upper-cased before comparing. Barcode and RFID uniqueness is an app rule (scans match them); the backend rule is only known for Asset Tag.
5. **Required location** = `countryId`, `siteId`, `buildingId`, `floorId` (IDs, not names). Location IDs are the local location codes (`DF`, `BLD-A`, `BLD-A-GF`, …), country `AE`, until a location API exists.
6. **`currentStep`** is 0-based (0 = Basic Information … 5 = Review). Local drafts get `assetRegistrationId` "DRAFT-0001"…; the real format is unknown.
7. **Dates** are sent as local ISO-8601 without a time zone (swagger says `date-time`).
8. **Total Cost** = purchaseCost × quantity × (1 + taxPercent / 100). **Warranty End** = start + period − 1 day (matches the web's 28 Jun 2026 + 5 Year(s) = 27 Jun 2031); months clamp to the month end.
9. **Currency** is stored as the ISO code ("AED"); the web shows "AED - UAE Dirham".
10. **TEMP lists** (until the Master Data API): every web dropdown shows only its selected value — In Use, Backup Power, Facilities Management, FM-001 - Building Operations, Head Office, Safety Critical Equipment, Company Owned, MEP Team, Unit(s), AED, 30 Days, Direct Purchase, Manufacturer Warranty, 24x7, Caterpillar (UAE), Primary, Hours, ISO 8528 / UAE Civil Defence / Manufacturer Standard. Those come first in each list; the other values are guesses.
11. **Department**: the web shows "Facilities Management"; the register's custodian text still says "Facilities" for older mock assets (mock data kept).
12. **Category tree**: Power Generation → Generator, Transformer, UPS, Switchgear, Control Panel, Others is from the web hierarchy. The other categories and types are guesses. The register's category (e.g. "Power Equipment") maps to the sub-category level.
13. **Technical templates** for types other than Generator are guesses. Units are fixed per field, whereas the web has unit dropdowns.
14. **Custom field types** Text / Number / Date / Dropdown. A Dropdown's options are not stored (the backend has only fieldName / fieldType / value), and Date values are stored as `yyyy-MM-dd`.
15. **Criticality assessment** maths (how likelihood, consequence and weighted criteria combine) is a stand-in; `criticality_options.json` gives only the scales and weights.
16. **Quantity** accepts decimals (swagger `number/double`); the rule is only > 0.
