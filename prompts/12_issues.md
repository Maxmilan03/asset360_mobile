# PROMPT 12 — Issues / Defects (design/10_issues_defects.jpg)

Follow `CLAUDE.md`. Build the 3 screens.

## Screen 1 (left): Issues list
- 4 tiles:
  - **Report Issue** → form
  - **My Issues** (badge)
  - **In Progress** (badge)
  - **Resolved** (badge)
- Tabs: All Issues (22) / My Issues (6) / Open (10) / Resolved (12), all computed.
- Search (issue no., asset, location, description) and filter sheet (priority, type, status, date).
- Rows: photo, ISS number, priority chip, title, asset ID + location, reporter, date and time. Fix the overlapping text seen in the design ("Suresh Ku26(" …): use ellipsis and a proper row layout.
- Tap → issue detail. Swipe right on your own open issue → "Mark Resolved" (confirm).

## Screen 2 (middle): Report Issue / Defect
- Asset*: selected asset card with a scan button (the scanner fills it); tapping the card opens an asset search picker.
- Issue Type*: dropdown with Breakdown, Malfunction, Damage, Leakage, Safety Hazard, Electrical, Other.
- Priority*: 4 selectable cards with icons (Critical / High / Medium / Low); the selected card gets a coloured border.
- Issue Title* and Description* (character counter "112/500").
- Location: prefilled from the asset, with a scan-location button.
- Reported By: current user, with ✕ to change (people picker).
- Attachments (n): thumbnails with ✕, and "Add Photo / Video" (camera, gallery or video).
- **Cancel** (confirm-discard if anything was entered) / **Submit Issue**:
  - Validates the required fields, creates ISS-2026-00xx, shows a success sheet "Issue ISS-2026-0057 submitted", and offers "Create Work Order now".
  - For Critical issues, it also creates an alert and a notification (the bell badge updates).

## Screen 3 (right): Issue detail
- Header: ISS number, priority chip, status dropdown (Open / In Progress / On Hold / Resolved / Closed), subtitle.
- Tabs: **Details** | Work Orders (n) | Timeline | Attachments.
- Asset card → Asset detail.
- Issue Information with Edit (inline): Issue No, Title, Description, Type, Priority chip, Status chip, Reported By, Reported Date, Location, Asset, Assigned To (chevron → reassign).
- Photos (n) with "View All" (gallery grid), each photo removable.
- Buttons:
  - **Close Issue** asks for resolution notes, then sets Closed.
  - **Create Work Order** opens the WO form prefilled (asset, title, priority, description, photos), links the WO to the issue, and increments the Work Orders (n) tab.
  - **Update Status** opens a sheet with status + comment, and adds the change to the Timeline.
- **Work Orders tab:** linked WOs → WO detail.
- **Timeline:** every event (reported, assigned, status changes, comments) plus an "Add comment" field.
- **Attachments:** all files; add more with file_picker.

## Done when
Issues can be reported, converted to work orders, updated and closed, and all counts, alerts and notifications update.
