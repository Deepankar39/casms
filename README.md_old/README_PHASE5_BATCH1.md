# CASMS Phase 5 — Batch 1 (full-stack foundation + UI/UX)

**Scope:** Step 5.1 (Express/MySQL foundation), Step 5.2 (sessions/login/password security), and an initial *read-only* live UI slice of dashboard, assets and service requests. Real CRUD workflows follow in the next batch. No database history is dropped or reseeded.

## 0. What you already finished

Phases 1–4 of the MCA ADBMS mini-project have been reported complete, including MySQL database `casms` and Phase 3 stored objects. Phase 4 SQL created user `casms_app` with a private password. This package is **additive** and does not overwrite `01_schema.sql` through `12_final_validation.sql`.

## 1. Install prerequisites (Windows)

Open **PowerShell** or VS Code Terminal:

```powershell
node -v
npm -v
```

If either is missing, install the **current Node.js LTS** from https://nodejs.org/en/download and reopen VS Code/PowerShell. Do **not** start Express setup until Node and npm work.

## 2. Extract into your EXISTING CASMS folder

Your current project root is:

`D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS`

Extract ZIP contents **into this directory**, so these paths exist:

```
CASMS/
├── database/13_webapp_sessions.sql       <-- new file
├── docs/                                <-- leave existing diagrams/docs intact
├── public/
│   ├── css/styles.css
│   ├── js/common.js, login.js, change-password.js, dashboard.js, assets.js, requests.js
│   ├── login.html, change-password.html, dashboard.html, assets.html, requests.html
├── server/
│   ├── app.js
│   ├── config/db.js
│   ├── middleware/auth.js, error.js
│   ├── routes/auth.js, dashboard.js, assets.js, requests.js
│   └── scripts/set-admin-password.js
├── .env.example
├── .gitignore
├── package.json
└── README_PHASE5_BATCH1.md
```

## 3. Add the sessions table (MySQL Workbench as root)

Run **only** `database/13_webapp_sessions.sql` in MySQL Workbench as a MySQL administrator. Expected `session_table_exists = 1`. It grants the preexisting `casms_app` user scoped read/write for `sessions`. The base-table count will increase from **22 to 23**. No other existing table is modified.

**Do not re-run `11_security_users.sql`: that resets the app DB password.**

## 4. Install npm dependencies and configure .env

PowerShell, from project root:

```powershell
cd "D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS"
npm install
Copy-Item .env.example .env
```

Open `.env` in VS Code. Enter the *actual* password that Phase 4 generated for `casms_app` under `DB_PASSWORD`. Generate a new secret **locally** by running:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Paste the output as `SESSION_SECRET=` in `.env`. Keep `.env` private and out of Git. `DB_HOST=127.0.0.1`; `DB_NAME=casms`; `PORT=3000`.

If the Phase 4-generated `casms_app` password is unavailable, use your MySQL *administrator* account in Workbench to set a **new private password for `casms_app` only** and put that value in `.env`. Do not publish it in chat, use root as the web app's database user, or rerun all Phase 4 scripts.

## 5. Create a ONE-TIME demo admin password

PowerShell:

```powershell
npm run setup:admin
```

This changes only demo user `EMP001`, marks it for mandatory password change, and prints a random temporary login password **once**. Copy it privately. It uses `casms_app` permissions; no app secret or user password is hard-coded in HTML/JS.

## 6. Start the web application

```powershell
npm run check
npm run dev
```

Expected terminal shows `CASMS running: http://localhost:3000` and `Database connection and session store initialized.`

Open:

- Health test: http://localhost:3000/api/health (JSON: `ok: true`, `database: "casms"`)
- Web login: http://localhost:3000
- Demo admin email: `emp001@casms.example.test`
- Password: the generated one-time password from `setup:admin`

On first login, the app redirects to **Change password**. Choose a 12–72-character password, confirm it, then continue to dashboard. Do not share this password.

## 7. Acceptance checks — report outcomes

1. `/api/health` returns `{ "ok": true, "database": "casms" }` (plus service label).
2. Admin login works; incorrect password returns a generic error (does not reveal whether a user exists).
3. First login requires changing the password. Dashboard loads afterward.
4. Dashboard shows live stats, status distribution, and recent requests. Admin sees all records.
5. Assets page shows 12 records per page; search and status filter work.
6. Requests page lists actual tickets; status filter and paging work.
7. Logout returns to login. Visiting `/api/assets` after logout responds `401` (can verify by navigating URL).
8. Responsive layout: narrow browser window and test sidebar menu.
9. `npm run check` passes.

**Role access tests:** To test Staff or Technician in this batch, repeat the password bootstrap process later for a test user in that role (the provided `setup:admin` task only changes Admin `EMP001`). Authentication and SQL scoping are implemented, but do not mark multi-role UI tests complete until tested with actual accounts.

## Security and architecture

- Plain HTML/CSS/JS responsive UI; no external CSS/font dependencies.
- Express 4 APIs, mysql2 parameterized SQL, least-privilege DB user.
- Sessions stored in MySQL (`express-mysql-session`), `HttpOnly`, `SameSite=Lax`, 8-hour expiry.
- `bcryptjs`, `express-validator`, `helmet`, login rate limit.
- Mutating API requests require JSON and custom `X-CASMS-Request: 1` header from same-origin scripts (additional CSRF guard for this local app; full CSRF review needed before deployment).
- API enforces user active status and role-based row filtering; the HTML pages themselves contain no private data.
- Browser/Node app binds to localhost only. `secure:false` cookies require **HTTPS + secure:true** before any production hosting.
- Static dashboard charts are drawn with CSS bars in this first batch; local Chart.js can be added with richer reporting views in a later batch.

## Known limitations / next Phase 5 batch

- No create/edit forms yet; those routes are **not** claimed implemented.
- Next: Step 5.3 master data Admin CRUD, Step 5.4 asset register/assignment/transfer, Step 5.5 requests, Step 5.6 maintenance/atomic closure; then dashboard enhancements, reports, audit/notifications and testing.
- Existing `02_seed.sql` data remains as-is; no seeded user passwords need to be known except after `setup:admin`.
- Database version fixed in our working environment: MySQL 8.0.46. We have syntax-checked the JS files in this package but cannot execute against your Windows MySQL server from here.

## Common errors

- `ER_ACCESS_DENIED_ERROR`: `DB_USER/DB_PASSWORD` incorrect or Phase 4 password was rotated; don't put root in `.env`.
- `Table 'casms.sessions' doesn't exist`: run `13_webapp_sessions.sql` as admin.
- `ER_TABLEACCESS_DENIED_ERROR` mentioning sessions: run its GRANT in `13_webapp_sessions.sql`.
- `ECONNREFUSED 127.0.0.1:3306`: start MySQL80 Windows service and verify Workbench connection.
- `EADDRINUSE`: another process is using port 3000; change `PORT=3001` in `.env`.
- Empty dashboards or missing table content: verify seed queries / Phase 3 views; do not assume a UI bug.
- Password-change page loops: ensure you're loading `http://localhost:3000` (not opening HTML files directly with file://).
