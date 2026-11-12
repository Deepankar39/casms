# CASMS — preserved project state at Phase 6 handover

**Goal:** MCA Semester I ADBMS mini-project: functional, responsive **Campus Asset & Service Management System**, with Node.js/Express + vanilla JS frontend + MySQL 8.0/InnoDB, Admin/Staff/Technician roles and academically demonstrable SQL concepts.

**Root on student's Windows machine:** `D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS`.

## Verified or confirmed by student
- Phase 1 database modeling/docs prepared (early documentation drafts may need schema reconciliation).
- Phase 2 `01_schema.sql`, `02_seed.sql`, `03_basic_queries.sql`: student executed and fixed MySQL errors 3818, 1137, 1175 and confirmed final success.
- Phase 3 `04_analytics.sql`, `05_views.sql`, `06_functions_procedures.sql`, `07_triggers.sql`, `10_indexes_explain.sql`: confirmed no execution errors.
- Phase 4 `08_transactions.sql`, `09_integrity_tests.sql`, `11_security_users.sql`, `12_final_validation.sql`, concurrency and backup materials: student reported Phase 4 done.
- Phase 5 Batch 1: browser/login/session/dashboard/assets/requests/responsive confirmed tested.
- Phase 5 Batch 2: delivered and used as installed prerequisite for later batches; no separate explicit test confirmation.
- Phase 5 Batch 3: service request/technician workflows confirmed tested.
- Phase 5 Batch 4: user explicitly confirmed tests passed on Oct 15, 2026.

## Decisions not to reopen
- 22 academic core/supporting DB tables; optional `maintenance_schedules` and `attachments` deferred.
- Plus `sessions` table for the web app = 23 expected current base tables.
- Separate priority/status lookup tables and warranties.
- Audit triggers; close service request through DB procedure; asset transfers through a Node.js transaction.
- Staff can submit requests only for eligible own-department/assigned assets.
- Roles: Admin, Staff, Technician. Generated asset tags by counter.
- Implement Phase 5 as batch overlays; preserve all previous working app files and `.env`.
- Aim for a clean responsive real web application, not console only and not SQL-only.

## Next immediate action
Install Phase 6 overlay without changing `.env`, execute offline tests, live role-specific smoke tests, SQL integrity checks, manual checklist and backup/restore verification. Insert actual evidence and student metadata into the final report; do not mark phase 6 verified until local tests pass.
