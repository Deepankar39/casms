# CASMS Phase 4 — Two-session concurrency lab (MySQL Workbench)

**Database:** `casms_perf`, table `phase4_lock_lab`. The table is initialized by `08_transactions.sql` with row 1 = 100 and row 2 = 200. All tests use this isolated lab table, never the 22 CASMS business tables.

Open **two separate MySQL Workbench connections** (Connection A and Connection B), not merely two tabs sharing the same connection. Run each numbered instruction only when indicated. You may need to cancel a waiting query to recover. Do not run all snippets automatically.

## Lab 1 — Lost update when applications use stale data

Reset in Connection A (with no active transaction):

```sql
UPDATE casms_perf.phase4_lock_lab SET amount=100 WHERE row_id=1;
```

1. A: `START TRANSACTION; SELECT amount FROM casms_perf.phase4_lock_lab WHERE row_id=1;` → observes 100.
2. B: `START TRANSACTION; SELECT amount FROM casms_perf.phase4_lock_lab WHERE row_id=1;` → observes 100.
3. A: `UPDATE casms_perf.phase4_lock_lab SET amount=110 WHERE row_id=1; COMMIT;`
4. B: Based on **stale 100**, uses `UPDATE casms_perf.phase4_lock_lab SET amount=120 WHERE row_id=1; COMMIT;`
5. A: `SELECT amount FROM casms_perf.phase4_lock_lab WHERE row_id=1;` → 120. A's +10 was lost instead of total 130. This demonstrates a stale read-and-replace in application logic, not that InnoDB loses writes automatically.

**Safer pattern:** `UPDATE ... SET amount=amount+10 WHERE row_id=1;` plus transactions/locking when multi-step decisions require them.

## Lab 2 — SELECT ... FOR UPDATE (row locks)

Reset row 1 to 100 in A, ensuring no transaction is open.

1. A: `START TRANSACTION; SELECT amount FROM casms_perf.phase4_lock_lab WHERE row_id=1 FOR UPDATE;` → 100, locked.
2. B: `START TRANSACTION; SELECT amount FROM casms_perf.phase4_lock_lab WHERE row_id=1 FOR UPDATE;` → should **wait** (launch in B while A transaction remains open).
3. A: `UPDATE casms_perf.phase4_lock_lab SET amount=110 WHERE row_id=1; COMMIT;`
4. B's waiting query completes and reads 110. B: `ROLLBACK;`

**Isolation concept:** InnoDB defaults to `REPEATABLE READ`; test `SELECT @@transaction_isolation;`. Compare to `SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;` in a new transaction. `SELECT ... FOR UPDATE` obtains a locking read in either isolation level.

## Lab 3 — Controlled deadlock

Reset row 1 to 100 and row 2 to 200 in A. Make sure both connections have no active transaction. Then:

1. A: `START TRANSACTION; UPDATE casms_perf.phase4_lock_lab SET amount=101 WHERE row_id=1;` (locks row 1).
2. B: `START TRANSACTION; UPDATE casms_perf.phase4_lock_lab SET amount=201 WHERE row_id=2;` (locks row 2).
3. A: execute `UPDATE casms_perf.phase4_lock_lab SET amount=202 WHERE row_id=2;` → waits for B.
4. While A waits, B: execute `UPDATE casms_perf.phase4_lock_lab SET amount=102 WHERE row_id=1;` → deadlock; **one transaction** receives error 1213 and rolls back automatically.
5. In **both** connections, run `ROLLBACK;` to release any remaining transaction. A blocked query should then finish or be cancelled.
6. Reset the two rows to 100 and 200 using A and check `SELECT * FROM casms_perf.phase4_lock_lab;`.

**Prevention:** All workflows lock resources in a consistent order, keep transactions short, and retry complete transactions if error 1213 occurs.

## Optional lab 4 — Real CASMS closure race

`08_transactions.sql` also creates an **In Progress** fixture request `P4-CONCURRENCY`. If you want to demonstrate actual double-close prevention, have two connections call `sp_close_service_request` for that same request with valid dates, technician/Admin actor, and an empty JSON array `JSON_ARRAY()`. One closes it, the other should fail the `In Progress` validation after waiting on the request row. This modifies the fixture permanently; only do it once you understand the procedure parameters. **The row-lock and deadlock labs above already cover the university's conceptual concurrency requirement without risking business data.**

## Evidence to save

- Screenshot of initial/stale-value final output from Lab 1.
- Screenshot of B waiting on a row lock and the resulting 110 from Lab 2.
- Screenshot of error 1213 and subsequent recovered values from Lab 3.
- Short explanation of atomicity, isolation, lost updates, row locking, and deadlocks for your viva.
