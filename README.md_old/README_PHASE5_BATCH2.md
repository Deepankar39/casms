# CASMS Phase 5 — Batch 2: Admin management + asset lifecycle

**Project:** Campus Asset & Service Management System (MCA Semester I ADBMS mini-project)

**This is an incremental overlay for the working Batch 1 app.** It adds Admin master-data CRUD, Admin user accounts, asset creation and edit, asset history, asset assignment and closure, location transfer, activation and retirement. Read-only dashboard and requests, login/sessions and password change remain as implemented and tested in Batch 1.

## 1. Prerequisites

- Windows; VS Code; Node.js/npm; MySQL Workbench; MySQL Server 8.0.46.
- CASMS project root: `D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS`.
- Working Batch 1 app, with `.env`, installed `node_modules`, and existing MySQL DB `casms`.
- Existing stored routines `sp_register_asset`, `sp_assign_asset`, `sp_retire_asset` and Phase 3 asset triggers installed.
- No database reinstallation, seed rerun or new npm packages required.

## 2. Protect your working Batch 1

**Stop your local Node server (Ctrl + C).** Back up the existing project before copying the overlay:

```powershell
cd "D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS"
Copy-Item "server\app.js" "server\app.batch1-backup.js"
Copy-Item "public\js\common.js" "public\js\common.batch1-backup.js"
Copy-Item "public\js\assets.js" "public\js\assets.batch1-backup.js"
```

Optionally use Git to create a checkpoint. **Never overwrite `.env`, reset your CASMS database, or rerun `11_security_users.sql`.**

## 3. Install this overlay

1. Open `CASMS_Phase5_Batch2_Admin_Assets.zip`.
2. Extract its **contents** into the existing CASMS root (not into a new nested `CASMS_Phase5_Batch2` folder).
3. Allow replacement only of same-named files from the overlay. All other Batch 1 files remain intact.
4. New files and replacements are listed below. There is **no new SQL migration** in this batch.

```text
CASMS/
  package.json                             (replace: expanded check script)
  server/app.js                            (replace: mounts new API routers)
  server/middleware/error.js               (replace: friendly constraint errors)
  server/routes/master.js                  (new: Admin CRUD for master tables)
  server/routes/users.js                   (new: Admin account management)
  server/routes/asset-actions.js           (new: asset lifecycle operations)
  server/scripts/check-batch2.js           (new: source check)
  public/assets.html                      (replace: adds management.css)
  public/asset.html                        (new: asset detail/history/operations)
  public/asset-new.html                    (new: asset registration)
  public/master.html                       (new: master-data management)
  public/users.html                        (new: user account management)
  public/js/common.js                      (replace: Admin navigation links)
  public/js/assets.js                      (replace: linked asset register)
  public/js/forms.js                       (new: safe DOM form/table helpers)
  public/js/asset.js                       (new: asset detail and workflows)
  public/js/asset-new.js                   (new: asset registration form)
  public/js/master.js                      (new: master-data CRUD UI)
  public/js/users.js                       (new: account-management UI)
  public/css/management.css                (new: responsive management styling)
```

**Important:** The existing `server/routes/assets.js` is not replaced; its read-only register API remains active. The additional `asset-actions.js` router is mounted afterward for asset detail and writes. Neither session authentication nor the existing dashboard/request code is replaced.

## 4. Start and check

Open PowerShell in the project root:

```powershell
cd "D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS"
npm.cmd run check
npm.cmd run dev
```

Expected syntax output: `PASS: 20 JavaScript files passed syntax checks.`

Go to http://localhost:3000, sign in as Admin using your **existing** login password. Your sidebar should now show **Master data** and **Users** as well as Dashboard, Assets and Service requests.

## 5. End-to-end tests (perform in this order)

1. **Regression:** login, dashboard, asset search, request queue and logout still work. An unauthenticated visit to `/api/assets` is still 401. Log back in.
2. **Master data:** open `/master.html`, create a uniquely named department such as `DEMO2` and a new category `TEST` (use unique names/codes); edit its name; deactivate and reactivate it. Try a duplicate department code and confirm it is rejected.
3. **Users:** open `/users.html` as Admin; create a test Staff account in an active department. **Copy the temporary password shown only once**. Edit its name, then confirm activation/deactivation works (do not deactivate your own Admin).
4. **Register:** open `/asset-new.html`. Register an inexpensive test asset using an active department, category, room (optional) and purchase cost. It should generate an asset tag and redirect to the asset detail page.
5. **Edit:** on `/asset.html?id=<new ID>`, set its serial number, brand, vendor, purchase date, useful life, etc. Save and reload to confirm persistence. Try an existing serial number to see the unique-value error.
6. **Activate:** new assets start `In Stock`. Click **Activate asset**; the status should become `Active`.
7. **Assign:** in the same asset detail page, select an active user/department and click **Create assignment**. Verify assignment history. A second current assignment should be rejected until the current one ends.
8. **Transfer:** move that asset to a different department or room, and enter a reason. Verify the new location, transfer record and continued current assignment in the history. Transfer uses **one Node.js MySQL transaction**.
9. **End assignment:** end the current assignment; the historical record must be retained.
10. **Retire:** retire this new test asset with a reason. It should show `Retired`. Retired assets are immutable, and new assignment/transfer controls should be hidden. **Use a newly created test asset with no outstanding requests**, not a seeded asset with open tickets.
11. **Role guard:** sign in to a Staff or Technician account. Admin-only Master data, Users and asset action APIs must return `403`, and Admin navigation links should not appear. (To test a new Staff account, its first login must complete the required password change.)
12. **Responsive UI:** verify desktop and mobile-sized browser windows; the existing collapsible sidebar must continue working.

## 6. Security and data safety

- State-changing endpoints require authenticated session, first-login password change, CSRF-mitigation header and Admin authorization.
- Generated asset tags use the existing `sp_register_asset` with a locked database counter.
- Asset assignments use the existing `sp_assign_asset` and database unique-current-assignment rule.
- Retirement uses the existing `sp_retire_asset` procedure (fails if requests are pending).
- Transfers use a **single pooled connection and atomic transaction** to insert history, change location and carry forward a current assignment.
- User account passwords are bcrypt-hashed. Temporary passwords are returned to Admin **once**. Do not screenshot, share or commit credentials.
- No existing demo records are deleted; master-data deactivation uses `is_active`.

## 7. Known limits and next work

This batch does **not** yet include: request creation, technician assignment/status changes, maintenance closure UI, feedback/reopen, report catalogue/exports, notifications and audit viewer. Those are planned for Batches 3–4. The existing MySQL routines/triggers/views remain the source of truth for database business rules.

Backend and browser JS passed syntax/static layout checks **in the preparation environment**. No claim of live MySQL integration testing is made until the user runs the app locally.

**Next after your pass:** Phase 5 Batch 3 — service request workflows and technician repair/atomic closure UI.
