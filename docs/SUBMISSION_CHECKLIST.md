# CASMS — final hand-in checklist

## Source and reproducibility
- [ ] `package.json`, `server/`, `public/`, `database/` scripts and `docs/` included
- [ ] `README.md` quick start checked on Windows
- [ ] Verify numbered SQL scripts run on a **separate clean test database** only if time permits; do not reset your verified database
- [ ] `.env`, node_modules, password logs, session data and private database backups excluded from submitted archive
- [ ] Third-party package dependencies declared in `package.json`; license requirements respected
- [ ] Screenshots added to `docs/screenshots/` and referenced accurately in the report

## Database demonstration
- [ ] ER and relational schema align with current implemented 22 academic tables
- [ ] 23 total base tables counted after session table
- [ ] 7 views, 4 functions, 6 procedures, 14 triggers verified (unless intentionally changed)
- [ ] Data cleaning, joins, group/having, subquery, ranking, recursion, indexing and EXPLAIN evidence captured
- [ ] COMMIT/ROLLBACK/SAVEPOINT and concurrency demonstrated, with honest test results
- [ ] Integrity check orphan/negative-value counts zero
- [ ] Successful backup/restore evidence retained

## App and test evidence
- [ ] Admin CRUD/assignment/transfer/retirement tested
- [ ] Staff create request and feedback tested
- [ ] Technician assigned work, maintenance and closure tested
- [ ] Reports and CSV export, notifications and audit tested
- [ ] 3-role access restrictions and logout session invalidation tested
- [ ] `npm run check` completed
- [ ] `npm run test:offline` = 0 failures
- [ ] `npm run test:integration` = 0 failures and 0 skips for full role coverage
- [ ] `docs/TEST_PLAN_AND_RESULTS.md` filled with actual pass/fail/evidence

## Academic presentation
- [ ] Cover page has student name/roll/college/faculty/year
- [ ] Final report description uses implemented features, not future assumptions
- [ ] Screenshots from the real running app, not design inspiration images
- [ ] 5-minute demonstration practiced (Admin → Staff → Technician → report)
- [ ] Source code and report packaged into a `CASMS_Final_Submission.zip` locally after removing secrets
- [ ] If GitHub requested, repository is private or reviewed for leaks, and tagged `v1.0`
