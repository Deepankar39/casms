# University ADBMS syllabus → CASMS implementation map

| University phase | Competency | CASMS files / evidence |
|---|---|---|
| Phase 1 | Entities, ER relationships, relational schema, 3NF | `docs/er-diagram.mmd`, `docs/relational-schema.md`, `docs/normalization.md`, `docs/data-dictionary.md` (prior work; verify latest schema aligns with DDL) |
| Phase 2 | DDL, DML, constraints, data cleaning, SELECT/JOIN basics | `database/01_schema.sql`, `02_seed.sql`, `03_basic_queries.sql` |
| Phase 3 | Joins, correlated subqueries, views, GROUP BY/HAVING, windows, stored functions/procedures, triggers, indexes and EXPLAIN | `database/04_analytics.sql`, `05_views.sql`, `06_functions_procedures.sql`, `07_triggers.sql`, `10_indexes_explain.sql` |
| Phase 4 | COMMIT/ROLLBACK/SAVEPOINT, transaction atomicity, concurrency, referential/business integrity, access controls | `database/08_transactions.sql`, `09_integrity_tests.sql`, `11_security_users.sql`, `12_final_validation.sql`, Phase 4 concurrency lab and backup script |
| Phase 5 | Functional full-stack web application with database connectivity and role-based UI/UX | `server/`, `public/`, `database/13_webapp_sessions.sql`, Phase 5 Batches 1–4 |
| Phase 6 | Automated/manual testing, reproducible setup, report and viva evidence | `tests/`, `database/14_release_integrity.sql`, this mapping and final documentation |

**Note:** The official university blueprint defines four database phases. Phases 5 and 6 are the expanded implementation/testing plan from the approved CASMS proposal, not extra university database syllabus phases.

## Database concepts demonstrated
- **3NF:** Separate stable reference tables and relationship tables for departments, rooms, users, categories, roles, status codes, priorities, assets, assignments, requests, repairs and parts.
- **Joins and aggregations:** Asset registers, pending/overdue requests, repair costs, warranty and technician metrics.
- **Stored functions and procedures:** Reporting helpers, generated tags, asset/technician assignment, retirement, closure/reopen rules.
- **Triggers:** Change auditing, validation and append-only audit protection.
- **Atomicity and concurrency:** Closure/transfer transactions; deliberate rollback, savepoint and two-session lock demonstration.
- **Optimization:** Indexed filtered queries, `EXPLAIN` and a separate performance dataset.
- **Security:** Least-privilege DB app user, bcrypt, session lifecycle, authorization checks and parameter binding.

## Viva starters
1. **Why MySQL/InnoDB?** Foreign-key constraints, transactions, row locking and stored objects support ADBMS experiments.
2. **What is 3NF?** Non-key attributes depend on the key, the whole key and no other non-key attribute; lookups and relationship tables reduce repeated data.
3. **Why raw SQL instead of ORM?** It exposes query design and advanced SQL directly for the coursework.
4. **Why a stored procedure to close requests?** It coordinates multiple related writes atomically under server-enforced rules.
5. **What does SAVEPOINT do?** It rolls back part of a transaction without aborting every earlier statement.
6. **What is a window function?** Computes a ranking or cumulative total over related rows while retaining row-level results.
7. **What is role-based access?** API and DB operations are allowed by authenticated role and row scope; the UI menu is not the security control.
8. **Why indexes/EXPLAIN?** To observe how the database selects access paths and reduce scanned rows.
