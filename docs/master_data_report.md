# Master Data phase — report

Source read: `docs/backend_ref/Services/MasterDataManagement` (endpoints, contracts, repositories) and the Asset
service code that uses its collections. Server checked with read-only GETs on `http://172.16.100.26:5500`:
`/health` is Healthy, and **every list is empty (`[]`)**, so the app currently shows "No … on the server yet" + Retry
in every Master Data dropdown. Open points: `docs/questions_for_backend.md` 35–49.

## How the lists are loaded

- Base URL `MASTER_DATA_BASE_URL` (dart-define, DEV default `http://172.16.100.26:5500`, also in `env/api_dev.json`).
  Shown on Auth diagnostics; Test connection now calls `/health` on AUTH, ASSET, MEDIA and MASTER DATA.
- Bearer token sent when signed in (same `AuthInterceptor` as the other services; the service itself has no auth).
- Every list is a bare JSON array, no paging. Lists are requested with `status=Active` (case-insensitive exact
  match on the server) and inactive rows are dropped again by the parser.
- Kept in memory for the session (Riverpod `FutureProvider`s in `master_data_repository.dart`); reopening the
  Register Asset form or pulling down on it reloads them. Each good reply is also saved in the drift
  `CachedResponses` table; with no network / timeout the saved copy is used. Server errors are shown with Retry, and
  no local list is ever used in API mode.

## Dropdowns and their source (API mode)

| Field (step) | Source | Saved as |
|---|---|---|
| Category (2) | `GET /api/master-data/asset-categories` — top-level only (no `parentCategory`) | name |
| Sub Category (2) | `GET /api/master-data/asset-categories/{categoryId}/subcategories`; reloads on category change, clears Sub Category / Asset Type / Sub Type | name |
| Asset Type (2) | `GET /api/master-data/asset-types?categoryId=` (types link to a category); narrowed to the sub category's `assetType` name when it names one | name |
| Model (1, suggestions) | `GET /api/master-data/asset-models?assetTypeId=` (all models until a type is chosen); free text allowed | name |
| Manufacturer (1, 4, suggestions) | `GET /api/master-data/manufacturers` | name |
| Condition (1) | `GET /api/master-data/conditions` (default = the one with `defaultCondition`) | name |
| Criticality (2) | `GET /api/master-data/criticalities` | name |
| Department (2), Custodian / Department (3) | `GET /api/master-data/departments` | name |
| Business Unit (2) | `GET /api/master-data/business-units` | name |
| Supplier / Vendor (4, suggestions) | `GET /api/master-data/suppliers` | name |
| Service Provider (4) | `GET /api/master-data/service-providers`; `GET /api/master-data/amc-vendors` when Warranty Type = AMC | name |
| Responsible Team (3) | `GET /api/master-data/teams` | name |
| Operating Shift (5) | `GET /api/master-data/shifts` | name |
| Quantity Unit (4) | `GET /api/master-data/uoms` (default = first) | name |
| Assigned To (3) | `GET /api/master-data/employees` (searchable; shows designation, department, employee number) | `assignedToUserId` = employee record id, `assignedToName` = `employeeName` |
| Location (3) | `GET /api/master-data/locations/tree?status=Active` | ids AND names of every level + `locationPath` |

Assets filter sheet (API mode): Category, Asset Type (by category), Department, Criticality, Manufacturer and
Condition list the Master Data values first, then any other value the assets already hold (`/filters`). Status,
Location and Custodian stay on the Asset service `/filters`.

### Why names

The Asset service DTOs (`AssetRegistrationDraftContracts.cs`) declare every one of these as `string?` and never look
them up (only Tagging Method is checked against a list), and the existing web-aligned registration sends names. The
only ids the Asset service expects are the location level ids and `assignedToUserId`.

### Condition / criticality difference

Registration accepts any non-empty criticality (and any condition), so Master Data values are used there. The
condition and criticality ASSESSMENT endpoints validate fixed values (`AssetConditionRatings`: Excellent, Good,
Fair, Poor, Critical; `AssetRiskRatings`), so **Update Condition keeps the Asset service `/ratings` list**. The
Master Data lists are empty on the server, so the actual values cannot be compared yet (question 42).

## Lists still NOT from Master Data

| Field | Source now | Why |
|---|---|---|
| Cost Center (2, 3) | local list (`AssetOptions.costCenters`) | No Master Data entity, no Asset `/options` list, no `masterType` defined. |
| Status, Function / Purpose, Tagging Method, Compliance Category, Lifecycle Stage, Ownership Type, Currency, Payment Terms, Procurement Method, Warranty Type, Warranty Period Unit, Support Coverage, step-5 units, Utilization, Compliance Standards, Custom field types | Asset service `GET /api/asset-registrations/options` | Master Data has no entity for them and `master-data-items` has no `masterType` values defined in code (exact, case-sensitive match; server empty). Tagging Method is validated by the Asset service against its own list. |
| Asset Sub Type picture cards (2) | local | No backend field list. |

## People (Custodian / Assigned To / Check Out)

Source: **Master Data `/employees`**. Evidence in the Asset service:
- `AssetAssignmentEndpoints.cs`: `current.AssignedToUserId = assignment.Employee?.EmployeeId` (the employee
  reference of the assign wizard).
- `AssetBulkAssignmentValidationExtensions.cs` + `AssignmentMasterDataRepository.cs`: rows are matched against the
  `master_employees` collection and `EmployeeId = employee.Id` (the Mongo `_id`), `EmployeeCode` = `employee_id`.
- Nothing in the Asset service references `/api/master-data/users` or UserAccount `/api/users` for assignment.

So every person picker in API mode lists employees and stores the employee record id + name.

### Assign Custodian / Check Out / Move (API mode)

| Screen | What it does |
|---|---|
| Assign Custodian (More Actions, `/work/movement/assign`) | Employee picker (`/employees`) + details card, Effective Date*, End Date (empty = open ended), Notes → `POST /api/asset-assignments` with `assignTo` "Employee", `assignmentType` "Custodian", `employee` = { employeeId = record id, employeeCode, employeeName, designation, departmentId, departmentName }. The server copies it onto the asset (`assignedToUserId`, `assignedToName`, `custodianDepartment`) and sets the asset status to "Assigned". |
| Check Out (More Actions, Asset grid, `/work/movement/check-out`) | Same request with `assignmentType` "Check Out", from today, Expected Return Date → `toDate` (empty = open ended), Purpose, Notes. |
| Check In / Return | "Not available yet": the only way to end an assignment is `DELETE /api/asset-assignments/{id}` (soft-deletes the record), see question 50. |
| Move Asset (Asset grid, `/work/movement/transfer?asset=`) | Current location + Master Data `MasterLocationField` (Country → Room, scan-to-fill; floor required) + Reason. **Move** says "Move Asset: Not available yet." and saves nothing: no service has a move / transfer endpoint and registered assets cannot be updated (question 51). |

Server rule shown to the user: one active assignment per asset (an "already assigned" notice appears when the asset's
status is "Assigned"; the server's error is shown if it refuses).

## Locations

- Hierarchy: `GET /locations/tree` (one source with ids for every level). Levels by depth: Country → Site →
  Building → Floor → Zone → Room (`type` is free text on the server). Picking a level clears the levels below;
  picking the same value keeps them. Country, Site, Building and Floor are required (Asset service rule).
- Saved: `countryId/countryName, siteId/siteName, buildingId/buildingName, floorId/floorName, zoneId/zoneName,
  roomId/roomName, locationPath` = real Master Data ids and names. The local tree, the free-text Room and the
  "Locations are not from the server yet" notice are gone in API mode (mock mode unchanged).
- Scan-to-fill: `LOC:<code>` resolves through the location's `code` (unique per client: 409 on duplicates); a tag
  linked to a location stores the Master Data location id (TagLinks.targetId) and resolves through the tree.
- Used by registration step 3 and Move Asset; shared for the IoT map: `MasterLocationSelector` / `MasterLocationField`
  (`core/widgets/master_location_field.dart`), `MdLocationIndex` / `MdLocationPath`.

### Location fields available for the map

| Record | Geo / plan fields |
|---|---|
| Location tree node / `locations` | id, locationName, code, type, parentLocationId, building / floor / zone (text), status — **no lat/lng, no floor plan, no geometry** |
| Site | siteName, code, siteType, city, country (name), businessUnit, department — **no lat/lng** |
| Building / Floor / Zone | name, code, site ref, building / floor ids + names, parentLevel, capacity, **area** — **no lat/lng, no floor plan, no polygon** |
| Asset (`locationAssignment.location`) | latitude, longitude (WGS84) — the only coordinates in the system |

The app stores the full tree and has typed models + providers for sites, buildings, floors and zones
(`mdSitesProvider`, `mdBuildingsProvider`, `mdFloorsProvider`, `mdZonesProvider`) ready for the IoT map phase.
