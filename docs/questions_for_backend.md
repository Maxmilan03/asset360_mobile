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

23. **Master data for registration dropdowns** — `GET /api/asset-registrations/options` covers the fixed lists only.
    Manufacturer, Department, Business Unit, Cost Center, Supplier, Service Provider, Team, Shift, UoM, Standards and
    the Location tree (sites / buildings / floors / zones) live in the Master Data service (`/api/master-data/*`,
    `/api/organization/locations`). Which port / base URL should the app use for it, and is it the next phase?
    Until then the app keeps its local lists for these and shows "Locations are not from the server yet".
24. **Location IDs** — the registration stores `countryId`, `siteId`, `buildingId`, `floorId`, `zoneId`, `roomId`.
    The app sends its local location codes (e.g. `BLD-A-GF`). What ids does the web send (Master Data ids)? Assets
    registered from the phone will not match the web's location filter until both use the same ids.
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
33. **Not in this phase** — asset-assignments (check out / in, custodian), asset-disposals, asset-dashboard,
    asset-audits and service-requests exist on the server; the app shows "Not available yet" for them. Also no
    endpoints yet for location history, IoT, maintenance / inspection history, financial (depreciation) and the
    asset activity history.
34. **Edit a registered asset** — there is no PUT for a registered asset (only drafts). How does the web edit an
    asset after submit?

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
