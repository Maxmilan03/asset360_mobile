# Questions for the backend developer

Short questions the mobile app cannot answer from the API documents. Please reply inline.
The app copes with any of the answers below (it reads replies tolerantly); the answers let us remove the guesses.
Auth diagnostics in the app (Sign in → Diagnostics → Copy report) shows exactly what your services returned.

## Security (please look at this first)

1. **`POST /api/auth/register` lets anyone create an account with any `userRoleId`, including Administrator.**
   Can it be limited to the basic User role, or require an administrator's token?

## Login service (UserAccount, port 5018)

`docs/api/useraccount_swagger.json` describes request bodies only; every response is "200 OK" with no schema.
Could the swagger include response schemas (and the 400 / 401 replies)? Until then, the app assumes:

2. **verify-totp / verify-otp reply** — the app looks for the access token in `accessToken`, `token`,
   `access_token` or `jwt`, and the refresh token in `refreshToken` / `refresh_token`, at the top level or inside
   a `data` / `tokens` / `result` object. What is the exact shape?
3. **Expiry** — is there an `expiresIn` (seconds) or `expiresAt` field? If not, the app reads the JWT `exp` claim,
   and assumes 30 minutes when that is missing too.
4. **refresh reply** — the same shape as verify-totp? Does it always return a NEW refresh token (rotation), or should
   the app keep the old one? (The app keeps the old one when none is sent.)
5. **login without 2-step** — can `twoFactorRequired` be false? If so, are the tokens in the login reply itself, with
   the same names? (The app signs in directly in that case.)
6. **`GET /api/auth/me` reply** — which fields? The app reads the name from `fullName` / `name` / `shortName`, plus
   `userName`, `email`, `userRoleId` / `roleId` (or a `role` object), `contactNo`. Is the role name included, or must
   the app look it up in `GET /api/auth/roles`?
7. **`GET /api/auth/roles`** — does it need the Bearer token? The app sends it.
8. **Error bodies** — always `{"message": "..."}`, for 400 and 401 alike? Which status does a wrong password, a wrong
   code, and an expired login token return? (The app shows `message` for each.)
9. **Lockout** — does the server lock an account after several wrong passwords or codes? The app no longer locks on
   its own in API mode.
10. **Code lifetime** — is `otpExpiresInSeconds` also the lifetime of the `loginToken` for verify-totp? When it is
    missing the app assumes 5 minutes.
11. **Code length** — the app's code boxes take 6 digits for both TOTP and emailed OTP. Is the emailed OTP also 6 digits?
12. **`method` values** — exactly `"totp"` and `"otp"` (lower case)? Anything else is treated as `"totp"`.
13. **Switching methods** — can the app switch between TOTP and email OTP (e.g. "send me a code by email instead")?
    There is no endpoint for it, so "Can't access your authenticator?" says "Contact your administrator".
14. **Forgot / reset password** — is there an endpoint? Today the app says "Contact your administrator to reset your
    password". Also: change password and edit own profile (name, phone) — endpoints planned?
15. **Re-setup** — when `setupRequired` is true, is a new `manualEntryKey` / QR issued on every login until the first
    successful verify-totp?
16. **Logout** — does `POST /api/auth/logout {refreshToken}` also need the Bearer token? The app sends only the body.

## Asset service (port 5401) and Media service (port 5300) — Assets live phase

Read from the source in `docs/backend_ref/Services/Asset` and `Services/Media` (the app calls both directly).

23. ~~Master data for registration dropdowns~~ — answered: the Master Data Management service (port 5500); see
    the Master Data section below.
24. ~~Location IDs~~ — the app now sends the Master Data location ids and names (see 36).
25. **Image type / document type lists** — `ImageType` (images) and `DocumentType` / document `LifecycleStage` are
    required but free text on the server. What values does the web offer? The app uses a temporary list
    (General, Front View, Nameplate, Installation, Damage) and the registration lifecycle stages.
26. **Media URL host** — `MediaFileStorageService` returns `BaseUrl` + `/uploads/...`, default
    `http://localhost:5300`. Phones cannot reach `localhost`; the app rewrites localhost / 127.0.0.1 to
    MEDIA_BASE_URL. Can `BaseUrl` be set to the server's real address (or return a relative `/uploads/...` path)?
27. **Media upload limits** — the Media service accepts only jpg, jpeg, png, webp and pdf; the Asset service's
    document form allows doc/docx/xls/xlsx and images allow gif/bmp. Should the Media service accept those too?
    What is the Media service's maximum file size? (The app checks 20 MB for images, 25 MB for documents, from the
    Asset service contracts.) Are `/uploads/...` files protected (Bearer needed)? The app sends the header anyway.
28. **Total cost** — the server computes `totalCost = purchaseCost × (1 + taxPercent / 100)`, ignoring `quantity`.
    Is `purchaseCost` the total for all units, or the unit price? (The app now shows the server's formula.)
29. **Draft `currentStep`** — the server keeps the highest step saved (1–5). The app resumes a draft AT that step
    (step number `currentStep`). Should it resume at the NEXT step instead?
30. **"My Assets"** — the list filter `custodianUserId` matches `assignment.assignedToUserId`. Is that the same id as
    `GET /api/auth/me` returns (`id`)? If /me has no id the app hides My Assets.
31. **Favorites** — there is no favorites endpoint; the app keeps favorites on the device. Planned?
32. **Health** — `GET /health` on Asset and Media (and Login) are public? The connection test calls them without a token.
33. **Not in this phase** — asset-assignment Check In / Return (see 50), asset-disposals, asset-dashboard,
    asset-audits and service-requests exist on the server; the app shows "Not available yet" for them. Also no
    endpoints yet for location history, IoT, maintenance / inspection history, financial (depreciation) and the
    asset activity history.
34. **Edit a registered asset** — there is no PUT for a registered asset (only drafts). How does the web edit an
    asset after submit?

## Master Data Management service (port 5500) — Master data phase

Read from `docs/backend_ref/Services/MasterDataManagement` (endpoints, contracts, repositories) and the Asset service
code that reads its collections (`AssignmentMasterDataRepository`). Only read-only GETs were made against the
server. The app calls it directly at `MASTER_DATA_BASE_URL` (DEV default `http://172.16.100.26:5500`).

35. **The server has no data** — on 172.16.100.26:5500 every list (asset-categories, asset-subcategories,
    asset-types, asset-models, manufacturers, conditions, criticalities, departments, business-units, suppliers,
    amc-vendors, service-providers, teams, shifts, uoms, employees, users, locations, locations/tree, sites,
    buildings, floors, zones, master-data-items) returns `[]`. The app shows "No … on the server yet" with Retry.
    Can the dev server be seeded (at least a location tree, categories → sub categories → types, departments and
    employees)?
36. **Two location models** — there is (a) the generic `locations` collection with `type`, `parentLocationId` and
    `GET /locations/tree`, and (b) separate `sites`, `buildings`, `floors`, `zones` collections (sites hold the
    country as a NAME only; there are no country or room records). The app uses the TREE, the only source with an id
    for every level the Asset DTO stores (countryId … roomId). Which one does the web use? The Asset service's
    `AssetLocation` comment says "Levels come from the Project service hierarchy (Site = Area, Room = SubZone)" and
    has `projectId`, and bulk assignment matches against BOTH `master_sites/buildings/floors` and
    `master_locations`. Which source is authoritative for `locationAssignment.location`?
37. **Location `type` values** — free text, not validated. The app takes the level from the tree depth (roots =
    Country, then Site, Building, Floor, Zone, Room). Is there a fixed list of types, and does the tree always start at
    the country?
38. **Map data** — no location record (location, site, building, floor, zone) has latitude / longitude, a floor-plan
    image, or zone geometry (polygon / bounds). Only `capacity` and `area` (buildings / floors / zones) and
    `city` / `country` (sites) exist. The asset itself has `latitude` / `longitude` (`AssetLocation`). Where will
    floor plans and zone shapes for the IoT map come from (Locating / Tracking service?)
39. **Asset types ↔ sub categories** — an asset type links to an asset CATEGORY (`category` reference, filter
    `categoryId`); a sub category only has a free-text `assetType`. The app lists the types of the chosen category
    and, when the sub category's `assetType` names one of them, offers only that one. Will types link to sub
    categories?
40. **Category hierarchy** — `asset-categories` has `parentCategory` (children via `/{id}/children`) AND there is a
    separate `asset-subcategories` collection. The app shows only top-level categories (no parent) in Category and
    the `/{categoryId}/subcategories` in Sub Category. Are child categories used anywhere?
41. **Names, not ids** — the Asset service stores category, subCategory, assetType, criticality, condition,
    department, businessUnit, custodianDepartment, responsibleTeam, manufacturer, model, supplierVendor,
    serviceProvider, quantityUnit and operatingShift as TEXT, so the app sends the Master Data NAME. Renaming in
    Master Data updates the other Master Data records only, not registered assets. Does the web also send names?
42. **Condition / criticality values** — registration only checks that Criticality is present, so the app offers
    Master Data `/conditions` and `/criticalities` there. Condition and criticality ASSESSMENTS validate fixed values
    (`AssetConditionRatings` Excellent / Good / Fair / Poor / Critical; `AssetRiskRatings` for criticality), so
    Update Condition keeps the Asset service's `/ratings`. Should the Master Data names match those values? (They
    cannot be compared yet: the server lists are empty.)
43. **master-data-items types** — `GET /api/master-data-items/type/{masterType}` matches `masterType` exactly
    (case-sensitive) and has no status filter, and no masterType value is defined anywhere in the code. Which
    masterType names will hold Cost Center, Lifecycle Stage, Ownership Type, Payment Terms, Procurement Method,
    Warranty Type, Function / Purpose and Compliance Category? Until then Cost Center stays a local list and the
    others come from the Asset service's `/options`.
44. **Quantity Unit / Operating Shift** — now Master Data `/uoms` and `/shifts` (names). The Asset service's own
    `/options` lists differ ("Unit(s)", "Day Shift" …) but are not validated. Confirm the web uses Master Data.
45. **AMC vendor** — the Asset DTO has no AMC vendor field; the app offers `/amc-vendors` in Service Provider when
    Warranty Type is "AMC" (otherwise `/service-providers`). Is that right?
46. **People** — `assignment.assignedToUserId` holds the Master Data EMPLOYEE record id: the Asset service's assign
    wizard sets `AssignedToUserId = Employee.EmployeeId`, and bulk assignment resolves rows against
    `master_employees` and stores its `_id`. The app's person pickers therefore use `/api/master-data/employees`
    (id + `employeeName`; `employeeId` = the employee number is only shown). But "My Assets" filters on the /me
    user id (UserAccount), and there is no link between a login user / system user and an employee. How does the web
    find "my" assets?
47. **No authentication** — the Master Data API has no `RequireAuthorization` and allows any origin. Intended? The
    app sends the Bearer token anyway.
48. **No paging** — every list returns all rows. Fine for dropdowns; will `/employees` stay small enough?
49. **Location codes** — the app prints / reads location labels as `LOC:<code>` and resolves the code through the
    tree (codes are unique per client: create / update answer 409). Is `code` meant to be printed on labels?

50. **Ending an assignment (Check In / Return)** — Assign Custodian and Check Out now `POST /api/asset-assignments`
    (assignTo "Employee", assignmentType "Custodian" / "Check Out"). The only way to end one is
    `DELETE /api/asset-assignments/{id}`, which soft-deletes the record (it disappears from the list) and gives the
    asset back its previous status. Is there (or will there be) a "return / release" call that keeps the history?
    Until then the app shows "Not available yet" for Check In and Return. Also: are "Custodian" and "Check Out" the
    right `assignmentType` values (free text on the server)?
51. **Moving an asset** — no service has a move / transfer endpoint, assignments never change
    `locationAssignment.location`, and a registered asset cannot be updated (34). How should the app move an asset
    to a new Master Data location? The Move screen is built with the Master Data pickers and says "Not available yet".

## API Gateway (port 5296) — not used for now (the app calls the services directly)

17. **Gateway is not reachable** — `http://172.16.100.26:5296/openapi/all.json` refused the connection, so
    `docs/api/openapi.json` is still missing. Is the gateway running, and is that the right URL?
18. **One base URL** — will the gateway expose `/api/auth/*` too, so the app needs only one address?
19. **Gateway tokens** — does the gateway accept the access token from the login service (issuer `A360.UserAccount`)
    as is? On 401 the app refreshes once and retries.
20. **Error format** — for 400 errors, is the body ASP.NET `ValidationProblemDetails`
    (`{ "title", "status", "errors": { "Purchase.PurchaseCost": ["…"] } }`), keyed relative to each draft step's
    request body (e.g. `Purchase.PurchaseCost`, `AssetName`) in PascalCase?
21. **Route prefix** — are service paths passed through unchanged (e.g. gateway `GET /api/asset-categories`
    → Asset service `GET /api/asset-categories`)?
22. **Connection test** — the app's "Test connection" calls `GET /api/asset-categories`. Is that a good cheap,
    read-only, authenticated endpoint?

## Answered

- ~~Security scheme~~ — Bearer JWT (useraccount_swagger.json: "Access token returned by POST /api/auth/verify-totp").
- ~~Token lifetime / login API~~ — access token 30 minutes, refresh token 7 days, login via the UserAccount service.
