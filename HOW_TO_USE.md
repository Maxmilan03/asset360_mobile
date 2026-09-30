# Asset360 Flutter build — how to use these prompts

## 1. Put the files in your project folder
Unzip this package so the folders sit in your project root:

```
~/Documents/Asset360/asset360_mobile/
  design/          <- the 16 design images, renamed by module
  assets/images/   <- product photos and logo cropped from the designs
  prompts/         <- 19 prompts, run in order
  HOW_TO_USE.md
  (your Flutter files: lib/, pubspec.yaml, android/, ios/ ...)
```

The logo in `assets/images/` was cropped from the mockups and is low resolution. Replace `logo_on_light.png` and `logo_on_dark.png` with the official Purple IQ logo files when you have them (same names).

## 2. Run the prompts one by one in Claude Code (VS Code)
Open the project folder in VS Code, open Claude Code, and send:

```
Read prompts/01_foundation.md and do everything in it.
```

When it finishes, test on your phone (`flutter run`), then send the next one:

```
Read prompts/02_mock_data.md and do everything in it.
```

…and so on up to `19_profile_settings_final_qa.md`.

| # | Prompt | Design image |
|---|---|---|
| 01 | Foundation: rules, theme, widgets, navigation | all (style) |
| 02 | Mock data (single source of truth) | all |
| 03 | Login, Forgot password, Authenticator | 01_login_security |
| 04 | Home dashboard | 02_home_dashboard |
| 05 | Assets list and Asset 360° detail | 03_assets_detail_iot |
| 06 | Asset registration | 04_asset_registration |
| 07 | Scan & Identify, Scan history | 05_scan_identify |
| 08 | Tracking & IoT | 06_tracking_iot |
| 09 | Movement & Custody | 07_movement_custody |
| 10 | Maintenance and Work Orders | 08_maintenance |
| 11 | Inspection | 09_inspection |
| 12 | Issues / Defects | 10_issues_defects |
| 13 | Alerts & Notifications | 11_alerts_notifications |
| 14 | Inventory / Spare Parts | 12_inventory_spare_parts |
| 15 | WIP / Operations | 13_wip_operations |
| 16 | Documents | 14_documents |
| 17 | Asset Audit | 15_asset_audit |
| 18 | Offline Sync | 16_offline_sync |
| 19 | Profile, Settings, Help, final QA and APK | — |

## 3. Tips
- **Don't skip 01 and 02.** Every later prompt depends on them.
- **One prompt per step.** If Claude Code stops before finishing, send: `Continue prompt 05 from where you stopped.`
- **After each prompt, check on the phone.** If a screen doesn't match, send something specific, e.g. `On the Maintenance list, the priority chip should be left of the WO number like in design/08_maintenance.jpg.`
- **Start a fresh Claude Code session if it gets slow.** CLAUDE.md keeps the rules, so you only need to say which prompt to run.
- **Commit to git after each prompt** so you can roll back:
  `git add -A && git commit -m "Prompt 05 done"`

## Demo login
Username `rex.kumar`, password `Asset@360`, authenticator code `123456`.
