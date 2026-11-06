# Asset edit / delete / move phase — report

Source re-read: `docs/backend_ref/Services/Asset` (`AssetRegistrationEndpoints.cs` UpdateAssetRegistrationAsync /
DeleteAssetRegistrationAsync, `AssetRegistrationDraftContracts.cs` UpdateAssetRegistrationRequest,
`AssetRegistrationDraftValidationExtensions.ValidateForUpdate`, `AssetRegistrationOptions.cs`,
`AssetAssignmentEndpoints.cs` / `AssetAssignmentContracts.cs`). No call was made to the server in this phase; all
behaviour is checked against the fake service in `test/live/` (it replaces sections on PUT the way the handler does).
Open points: `docs/questions_for_backend.md` 50, 52–57.

## Edit a registered asset

| What | How |
|---|---|
| Endpoint | `PUT /api/asset-registrations/{assetRegistrationId}` (`AssetsApi.update`). |
| Section rule | The server REPLACES each section it receives and keeps the ones left out. `UpdateAssetRegistrationRequest.changes(original, edited)` compares each section of the edited copy with the asset as loaded and sends only the sections that differ, each one COMPLETE (every stored value + the change). Unchanged sections are not in the body. |
| Round trip | Every field of the five DTOs is in the app model, so a re-sent section carries all stored values (checked field by field against `AssetBasicInformationDto` … `AssetOperationalDetailsDto`). |
| Edit Asset (⋮ → Edit Asset) | Route `/assets/detail/{id}/edit` → the registration wizard (`RegisterAssetScreen.edit`) pre-filled from `GET /api/asset-registrations/{id}`. Title "Edit Asset"; Next only checks the step (nothing is saved); no Save as Draft; Review says **Save changes**. Steps that fill defaults (custodian department, manufacturer) do not do it while editing. |
| Inline Edit (Overview → Key Information → Edit) | Status (`/options`), Condition and Criticality (Master Data), Purchase Date → Save sends the complete `basicInformation` (+ `classification` for Criticality, which is stored in both; + `purchaseWarranty` for Purchase Date). Location and Assigned To are read-only there (Move Asset / Assign Custodian). |
| Errors | 400 (`ValidateForUpdate`, keyed `Step.Field`): the wizard opens that step with the message under the field; the Key Information card shows its own fields' errors and names any other field ("… · fix it with Edit Asset"). 409 duplicate tag: under Asset Tag on step 1. 404 / network: SnackBar. The form keeps the input. |
| After saving | `LiveAssetEditor` invalidates the asset, its images / documents / condition / criticality, the asset list, Recent Assets, the status summary and the filters. "No changes to save" when nothing differs (no call). |

## Delete

⋮ → Delete → "Delete {asset name}? The asset will be removed from lists." → `DELETE /api/asset-registrations/{id}`
(soft delete, 204) → back to the Assets list, refreshed, SnackBar "{asset name} deleted"; the id is dropped from the
device favorites. Errors show as a SnackBar and the asset stays open. Create Disposal Request is unchanged in More
Actions.

## Move Asset

`PUT /api/asset-registrations/{id}` with the complete `locationAssignment` section (`movedTo`):
- `location` = the Master Data path picked (ids + names of every level, levels below the pick cleared, `locationPath`);
  `projectId` kept; **latitude / longitude cleared** (they belonged to the old place, question 53).
- `assignment` = the asset's current values, unchanged.
- Floor (or deeper) required before sending. A location error from the server shows under the picker; an error in
  another field (the whole asset is re-checked, question 54) is shown as "… · fix it with Edit Asset".
- **Move reason: not asked and not sent.** The backend has no field or history record for it (question 52); the
  only trace is the EventLog "Updated" entry.

## Assignments

- AssignTo comes from `GET /api/asset-assignments/options` (`assignmentOptionsProvider`, `AssignmentOptions.employee`
  = the server's spelling of "Employee"); while it loads or fails the form shows a spinner / error with Retry and
  sends nothing. assignmentType stays "Custodian" / "Check Out".
- Check In / Return: still "Not available yet" (question 50).

## Statuses

- Registration / Key Information status options = `GET /api/asset-registrations/options` → Active, Inactive,
  In Storage, Under Maintenance, In Repair, Out of Service, Disposed. A stored value not in the list (Assigned,
  Available) is still shown as the current value.
- Chip colours (`AssetOptions.toneOf`, case-insensitive): green Active / Available; blue Assigned; amber Under
  Maintenance / In Repair / In Storage; red Out of Service / Disposed; grey Inactive and anything unknown.
- The list summary is unchanged: the server's Active / Under Maintenance / In Repair / Disposed / Other.

## Tests

`test/live/asset_edit_live_test.dart`: full-section edit with unchanged fields preserved (unit + wizard + Key
Information), no-change, 400 / 409 on save, delete, move payload, status colours.
`test/live/assignment_live_test.dart`: AssignTo from `/options` (failure + Retry + server spelling).
