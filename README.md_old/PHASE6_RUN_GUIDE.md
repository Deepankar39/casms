# CASMS Phase 6 — Final release batch

## 0. Install safely
1. Back up your current working `CASMS` project directory and MySQL database.
2. Extract this ZIP **into the existing project root** `D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS`. Allow adding/replacing `package.json`, and adding `tests/`, `docs/`, `database/14_release_integrity.sql`, `README.md`.
3. **Do not overwrite `.env` or rerun any old password-generating SQL.** The ZIP contains no secrets, SQL migrations or additional npm packages.

## 1. Syntax and offline security-contract checks
In VS Code PowerShell at the project root:
```powershell
npm.cmd run check
npm.cmd run test:offline
```
Expected: the batch-4 source check passes; offline test suite finishes with zero failing tests. This does **not** prove database or UI behavior.

## 2. Start application (terminal 1)
```powershell
npm.cmd run dev
```
Check http://localhost:3000 and http://localhost:3000/api/health.

## 3. Automated live integration (terminal 2)
```powershell
npm.cmd run test:integration
```
Without role credentials, anonymous security, headers, validation, and health tests run; role-specific tests are **SKIPPED**, not falsely marked PASS.

To test all roles, use three **existing, non-temporary accounts**. Do not send credentials in chat or store them in the repository:
```powershell
$env:CASMS_TEST_ADMIN_EMAIL = 'your-admin@example.test'
$env:CASMS_TEST_ADMIN_PASSWORD = Read-Host 'Admin password'
$env:CASMS_TEST_STAFF_EMAIL = 'your-staff@example.test'
$env:CASMS_TEST_STAFF_PASSWORD = Read-Host 'Staff password'
$env:CASMS_TEST_TECH_EMAIL = 'your-technician@example.test'
$env:CASMS_TEST_TECH_PASSWORD = Read-Host 'Technician password'
npm.cmd run test:integration
```
**Do not type actual passwords in shared screenshots.** Integration tests make no domain-data changes. Clear variables afterward:
```powershell
Remove-Item Env:\CASMS_TEST_ADMIN_PASSWORD,Env:\CASMS_TEST_STAFF_PASSWORD,Env:\CASMS_TEST_TECH_PASSWORD -ErrorAction SilentlyContinue
```
See `tests/phase6-results.json` for machine-readable test results. This JSON deliberately excludes passwords and cookies. If you must submit the file, inspect it first.

## 4. SQL release validation (MySQL Workbench)
Open `database/14_release_integrity.sql` and execute it. Expected: **23 base tables** after the Phase 5 session table (22 academic domain tables + 1 sessions table), 7 views, 4 functions, 6 procedures and 14 triggers unless modified. Data counts need not equal original seed counts after browser testing. The orphan/negative-value counts should be zero. Capture only the key result-grid screenshots and actual counts.

## 5. Manual regression (non-destructive testing first)
Complete the case table in `docs/TEST_PLAN_AND_RESULTS.md`. Use a labeled test asset for any create/assign/transfer/retire workflow; avoid changing canonical demo examples, especially Phase 4 fixture requests. For rollback/concurrency proof, refer to your already completed Phase 4 scripts and two-session lab.

## 6. Backup verification and documents
Use existing `database/phase4_backup_restore.ps1` as documented in Phase 4 (or the original file location). Verify restore in a separate database and compare counts. Include actual screenshots in `docs/screenshots/` and fill out the bracketed student/college/execution information in `docs/FINAL_PROJECT_REPORT.md` or DOCX before submitting.

## 7. Record and freeze a local release
```powershell
npm.cmd run test:offline
npm.cmd run test:integration
```
Mark all tests **Pass / Fail / Not Run**, not aspirational Pass. If Git is in use, verify `.env`, database dumps and `node_modules` are ignored before committing and tagging `v1.0`.

## Troubleshooting
- `ECONNREFUSED` / health FAIL: start `npm run dev`, check port and MySQL service.
- `401`: missing/expired login or wrong credentials.
- `403`: expected for unauthenticated mutation without the special header or unauthorized role; unexpected 403 after login may mean password change required.
- CSV test fails: ensure Batch 4 files were installed and logged-in role has the report permission.
- `tests/phase6-results.json` is created locally and is not included in the release ZIP.

**Completion criterion:** offline suite 0 failures, integration suite 0 failures and 0 skips for full three-role coverage, SQL integrity checks valid, manual workflow checklist signed off, screenshots added, and backup restored successfully. No outcome is pre-certified by this package.
