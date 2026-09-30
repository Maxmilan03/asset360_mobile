# PROMPT 16 — Documents (design/14_documents.jpg)

Follow `CLAUDE.md`. Build the 3 screens. Use asset ID **GEN-00045** consistently (the design also calls this generator GEN-01).

## Screen 1 (left): Documents
- 4 tiles: All Documents 64 / Expiring Soon 8 / Compliant 42 / Pending 6. Each is tappable and filters the list.
- Tabs: All (64) / Manuals (12) / Warranty (8) / Certificates (14) / Others (30).
- Search (file name, type, asset) and filter (type, asset, expiry range).
- Rows: file-type thumbnail (PDF icon, or an image thumbnail), file name, type chip (colour per type), asset ID + name, size, date or "Valid till".
  - Row ⋮ menu: View, Download, Share, Rename, Replace Version, Delete (confirm).
  - Tap → Document Details.
- "+" FAB → Add Document.

## Screen 2 (middle): Document Details
- Asset photo, file name, type chip, asset name and ID; ⋮ menu (same actions).
- **View:** opens the bundled sample PDF in an in-app viewer screen (add the `pdfx` package for PDFs; images open in a zoomable viewer).
- **Download:** saves a copy to the device's Downloads/Documents and shows a SnackBar with a path and an "Open" action.
- **Document Information** with Edit (inline, Save/Cancel): Name, Type, Asset (link → Asset detail), Category, Version, File Size, Upload Date, Uploaded By, Description.
- **Related Documents (n)**, the other documents of the same asset, with "View All". **n must equal the number of rows** (the design says 6 but shows 4).
- A **Versions** section (v2.1 current, v2.0, v1.0) with "Restore" per old version.

## Screen 3 (right): Add Document
- Select Asset* card → asset picker (search/scan).
- Document Type* dropdown: Manual, Warranty, Certificate, Maintenance, Photo, Service Report, Invoice, Other.
- File* dashed upload box: "Tap to upload or drag and drop / Supports PDF, DOC, DOCX, XLS, XLSX, JPG, PNG / Max size: 10 MB".
  - Use file_picker with those extensions.
  - Reject files over 10 MB with an error.
  - After picking, show the file name, size and a remove ✕.
- Document Name* (auto-filled from the file name, editable), Category dropdown, Version.
- **Expiry Date:** shown **only for types that expire** (Warranty, Certificate, Contract/AMC, Insurance). The design shows an expiry date on a manual, which is wrong. The date picker can't be in the past.
- Description with a character counter "56/500".
- **Cancel** / **Upload Document:**
  - Validates, shows a 1.5-second upload progress bar, adds the document, and returns to Documents with the new item at the top.
  - Counts and the Expiring Soon tile update (expiry within 30 days of DemoClock counts as expiring).

## Done when
Documents can be added, viewed, downloaded, edited, versioned and deleted, and all tiles and tabs are computed.
