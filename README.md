# CASMS — Campus Asset & Service Management System

**MCA Semester I — Advanced Database Management Systems (ADBMS) mini-project**

CASMS is a **local-first, responsive full-stack web application** for tracking college assets, ownership, service requests, technicians, repairs, warranties, and maintenance costs. It demonstrates SQL design, advanced querying, stored objects, referential integrity, auditing, atomic transactions, and three-role access control.

## Technology
- Frontend: HTML5, responsive CSS, vanilla JavaScript and browser-based charts
- Backend: Node.js >=20, Express 4, `mysql2`, session cookies, `bcryptjs`
- Database: MySQL 8.0/InnoDB, parameterized SQL, stored procedures/functions/triggers/views
- Tools: VS Code, MySQL Workbench, Windows PowerShell

## Prerequisites
MySQL Server running with the `casms` database, completed Phase 1–4 SQL, Phase 5 session table, npm dependencies installed, and a private `.env` configured with a database account and 32+ character session secret. The project has already been developed in Phases 1–5; **do not drop or reseed** the database for final testing.

## Launch (Windows PowerShell)
```powershell
cd "D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS"
node -v
npm.cmd install
npm.cmd run check
npm.cmd run dev
```
Open **http://localhost:3000**. The API health endpoint is **http://localhost:3000/api/health**.

For a clean-machine install rather than an update, follow the original `README_PHASE5_BATCH1.md` and execute SQL in numbered order; create `database/13_webapp_sessions.sql` after the Phase 4 security account. Older SQL snippets are an academic lab sequence; use existing credentials and never rerun password-resetting scripts unnecessarily.

## Roles and screens
- **Admin** — master data, users, assets/assignments/transfers/retirement, request assignment, dashboards, reports, CSV exports, audit log
- **Staff** — scoped assets, raise/manage own tickets, feedback, own notifications and permitted reports
- **Technician** — assigned repair queue, start/hold/resume, maintenance work and closure, own notifications and permitted reports

See `docs/USER_GUIDE.md`, `docs/API_REFERENCE.md`, and `docs/ROLE_PERMISSION_MATRIX.md`.

## Phase 6 release verification
```powershell
npm.cmd run check
npm.cmd run test:offline
```
Start the site in **one terminal**, then in **another terminal**:
```powershell
npm.cmd run test:integration
```
Authenticated scenarios are optional until local test-role credentials are supplied as PowerShell environment variables. The script prints **PASS / FAIL / SKIP**, writes non-sensitive output to `tests/phase6-results.json`, and performs only read-only requests (except login/logout with no permanent domain-data changes).

Run `database/14_release_integrity.sql` in MySQL Workbench (read only), capture results, and complete the manual workflow checklist in `docs/TEST_PLAN_AND_RESULTS.md` using disposable sample records. See `PHASE6_RUN_GUIDE.md` for exact steps.

## Critical security notes
- Never commit `.env`, `node_modules/`, backups, session secrets, user passwords, or local test-result files containing sensitive operational data.
- All state-changing API requests require header `X-CASMS-Request: 1` in addition to an authenticated session. This is a **local academic demo**; deploy behind HTTPS and harden cookie and infrastructure settings before production use. The configured local cookie is `secure:false` because this project is served on localhost over HTTP.
- Database accounts and permissions are demonstrated in Phase 4; do **not** use MySQL `root` in the application.
- Use temporary demo accounts only; change seeded credentials during first login.

## Repository
`database/` numbered SQL labs, `server/` Express controllers and middleware, `public/` responsive pages, `docs/` design + report + test artifacts, `tests/` offline and live smoke testing.

## Demonstration workflow
1. Admin logs in; views dashboard, inventory, and notification center.
2. Admin creates a disposable asset, assigns/transfers it, and checks its history.
3. Staff raises a service request on an eligible asset.
4. Admin assigns an available technician.
5. Technician starts work, records diagnosis/parts/cost, and closes request through the stored procedure.
6. Staff views resolution and submits feedback. Admin inspects audit trail, maintenance report, and exports CSV.

## Acceptance and limitations
Phases 1–4 and Phase 5 Batches 1, 3, and 4 were reported tested by the project developer. Final automated suite and release checks are run locally in Phase 6. Some optional proposal items (attachments, scheduled preventive maintenance, cloud deployment) remain out of the initial academic release. Screenshots and the final signed test report must reflect actual local results, not assumed successes.
