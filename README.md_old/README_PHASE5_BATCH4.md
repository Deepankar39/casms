# CASMS — Phase 5 Batch 4: Reports, Notifications, Audit & UI

This **additive overlay** installs over your already-working Phase 5 Batch 3 project. **It does not include or replace `.env`, MySQL schema, seed data or previous SQL scripts**. The same `casms_app` account and existing tables/views from Phases 1–4 are used. No new npm dependencies.

## Install on Windows

1. Keep a backup of your currently working CASMS project (or make a Git commit). Stop the Node server with **Ctrl+C**.
2. Extract `CASMS_Phase5_Batch4_Reports_UI.zip` **directly into** `D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS`. Merge included `server` and `public` folders; agree to overwrite the included files. Do **not** create a nested Batch4 subfolder.
3. In the existing VS Code PowerShell terminal at the project root, run:

   ```powershell
   npm.cmd run check
   npm.cmd run dev
   ```

4. Expected offline message: `PASS: 37 JavaScript files pass syntax checks.` plus mocked reporting-permission and CSV checks. This is **not** a MySQL runtime test.
5. Open <http://localhost:3000> and sign in using your **existing accounts**. No password rotation or database reset is needed.

## New screens and endpoints

| Screen | Who can open | What to verify |
|---|---|---|
| `/reports.html` | Admin, Staff, Technician | Catalog, filters, table pagination, CSV export; role-filtered records |
| `/notifications.html` | All roles | Read/unread, unread-only filter, mark one or all read, topbar badge |
| `/audit.html` | Admin | Date/table/action filters, record details, before/after JSON |
| `/dashboard.html` | All roles | Category and request trends; Admin additionally sees monthly spend and expiring warranties |

Reports include Asset register; Service request queue; Maintenance history; Asset category breakdown; and Admin-only Department repair costs, Monthly repair costs, Technician workload, Warranties, Repeat failures, Warranty cost allocation.

New APIs, guarded by existing `requireAuth` and `requireReady`:

- `GET /api/reports/catalog`; `GET /api/reports/:id` (pagination 15), `GET /api/reports/:id/export` (CSV maximum 5,000 rows).
- `GET /api/notifications/summary`, `GET /api/notifications`, `POST /api/notifications/:id/read`, `POST /api/notifications/read-all`.
- `GET /api/audit`, `GET /api/audit/tables` (Admin only).
- `GET /api/insights` (role-scoped chart data).

## End-to-end test checklist

Use a **test request** created during Batch 3 to avoid changing important sample records.

1. **Regression:** Admin login → Dashboard, Assets, request lifecycle, Master Data, Users; Staff and Technician login; password protection; logout; mobile sidebar.
2. **Admin reports:** Open Reports and switch through all 10 entries. Verify real values are shown (some date-dependent reports may show empty results). Download at least one CSV and open it. Check column headings and characters.
3. **Staff reports:** Login as Staff. Only four scoped reports should appear. Asset register must show own-department or assigned assets; request/history must show only own raised requests. Direct `/api/reports/department` must return **403**.
4. **Technician reports:** Login as Technician. Four permitted scoped reports; requests/history limited to assigned tickets. Direct `/api/reports/warranties` must return **403**.
5. **Notification inbox:** Use Batch 3 to create/assign/close a test request, then open inbox on the addressed account. Verify unread badge increments, **Mark read** decrements it, **Mark all read** only affects that user's notifications. One user must not be able to read another user's notification by changing its ID in a POST URL.
6. **Audit Admin:** Register/modify a test asset, or change a test request status. In Audit Trail, filter by `assets` or `service_requests`, inspect old/new values. Staff or Technician direct `/api/audit` must return **403**. Audit is read-only.
7. **CSV restriction:** Use Admin to export Warranty and Department reports. Use Staff to try calling `/api/reports/department/export` directly; it must return **403**. CSV escapes formulas for text values beginning with `=`, `+`, `-`, `@`, even if preceded by whitespace.
8. **Dashboard insights:** Category chart data and request trends should respect role; Admin alone sees total monthly maintenance expense and warranty expiry count.
9. **Responsive:** At phone width, check nav overlay dismissal, reports filters stack, inbox actions reflow and audit detail dialog scrolls.
10. **Security:** No `.env` exposed; API calls without session return 401; modifying notification endpoints without `X-CASMS-Request: 1` return 403; audit cannot be modified.

## Files added / replaced

- **Replace:** `server/app.js`, `package.json`, `public/js/common.js`, `public/js/dashboard.js`, `public/dashboard.html`, `public/css/styles.css`.
- **Add:** `server/routes/reports.js`, `server/routes/notifications.js`, `server/routes/audit.js`, `server/routes/insights.js`, `server/scripts/check-batch4.js`, `public/reports.html`, `public/notifications.html`, `public/audit.html`, `public/js/reports.js`, `public/js/notifications.js`, `public/js/audit.js`, `public/js/charts.js`, `public/css/analytics.css`.
- **Documentation:** `README_PHASE5_BATCH4.md` and `PROJECT_STATE_BATCH4.md`.

## Design and limits

- All SQL is raw mysql2 with bind parameters. Staff/Technician assets and requests are restricted on the server, not just hidden in the UI. Admin-only reports and audit are rejected with 403.
- Read and unread changes affect only `notifications.user_id = authenticated user`.
- MySQL audit log remains append-only; the website has no audit edit/delete endpoint.
- Reports are capped at 5,000 CSV rows for this academic app. If larger, refine the filters.
- Native CSS data bars are deliberately bundled locally instead of loading an external chart CDN, so the UI works without internet.
- We did **not** run a live MySQL session or browser in the build environment. Offline syntax, packaging, and mocked role/CSV checks passed; you must confirm results against your local MySQL and Windows browser.
- Optional preventive-maintenance schedules and attachments remain deferred under D8; this batch does not claim to implement them.

### When tests pass

Report: `Batch 4 passed` (or attach exact console/browser errors). We will then start **Phase 6 — system integration tests, security test cases, deployment/setup documentation, final screenshots and submission package** without repeating earlier phases.
