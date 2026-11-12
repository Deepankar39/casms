# CASMS — Final test plan and actual results

**Date:** [FILL AFTER RUN]  
**Tester:** [STUDENT NAME / ROLL NUMBER]  
**System:** Windows, MySQL 8.0.46, Node.js [ACTUAL VERSION], browser [ACTUAL VERSION]  
**Environment:** localhost:3000  
**Scope:** Phase 6, final regression

> **Evidence rule:** Never change "Not Run" to "Pass" unless executed successfully. Phase 5 Batches 1, 3, and 4 have been reported tested by the developer, but this Phase 6 run still needs its own evidence.

## Automated checks
| Check | Evidence | Actual status |
|---|---|---|
| `npm run check` | Copy pass summary / screenshot | Not Run |
| `npm run test:offline` | Node test summary | Not Run |
| `npm run test:integration` | `tests/phase6-results.json` summary | Not Run |
| All three-role integration tests (zero SKIP) | Three role credentials supplied locally | Not Run |
| `database/14_release_integrity.sql` | Objects, orphan checks | Not Run |
| Backup and restore | Restored counts screenshot | Not Run |

## Manual functional and security test cases
| ID | Scenario | Expected behavior | Status | Evidence / notes |
|---|---|---|---|---|
| TC-01 | Invalid login repeatedly | Generic failure, rate limiter after 10 failures per 15 min | Not Run | |
| TC-02 | Staff calls Admin-only API | HTTP 403, no data | Not Run | |
| TC-03 | Raise request for retired asset | Rejected, no request created | Not Run | |
| TC-04 | Register duplicate asset tag directly in DB | Unique key rejects duplicate | Not Run | |
| TC-05 | Assign inactive technician | Rejected | Not Run | |
| TC-06 | Close request with invalid part quantity | Transaction rolled back, no maintenance part saved | Not Run | |
| TC-07 | Two simultaneous closes | Exactly one succeeds, one rejected | Not Run | |
| TC-08 | Modify closed request status outside workflow | Rejected | Not Run | |
| TC-09 | Search with SQL-injection characters | Search treated as text, database intact | Not Run | |
| TC-10 | Delete referenced department | FK restrict blocks deletion; deactivate allowed | Not Run | |
| TC-11 | Change audited asset status | Audit row records old/new state | Not Run | |
| TC-12 | Attempt audit UPDATE/DELETE via privileged test connection | Trigger/permissions reject | Not Run | |
| TC-13 | Back up and restore to separate DB | Referential integrity and counts match | Not Run | |
| TC-14 | Admin creates disposable asset | Generated unique tag, visible details | Not Run | |
| TC-15 | Assign then transfer test asset | Old assignment ends; one current destination, history retained | Not Run | |
| TC-16 | Staff raises eligible service request | Request created, `Open` status | Not Run | |
| TC-17 | Admin assigns technician | Ticket `Assigned`, assigned technician can see it | Not Run | |
| TC-18 | Technician start/hold/resume | Allowed transitions saved in timeline | Not Run | |
| TC-19 | Close maintenance ticket with work and parts | Closed, maintenance/parts stored atomically | Not Run | |
| TC-20 | Staff leaves feedback | Own eligible request updates rating/comment | Not Run | |
| TC-21 | CSV export with special characters | Output downloads; spreadsheet formula strings neutralized | Not Run | |
| TC-22 | Staff/Tech reports vs Admin reports | 4 restricted reports each; Admin has all 10 | Not Run | |
| TC-23 | Notification inbox | Only own notifications; read/unread updated | Not Run | |
| TC-24 | Audit viewer | Admin visible; Staff and Technician HTTP 403 | Not Run | |
| TC-25 | Logout and reuse old session | API returns 401 | Not Run | |
| TC-26 | Mobile viewport 375px and tablet 768px | No horizontal overflow, readable nav/tables | Not Run | |
| TC-27 | Asset/dept cost dashboard statistics | Match the database for selected scope | Not Run | |
| TC-28 | Restore Phase 4 integrity fixture check | `P4-CLOSE-OK` closed with repair; `P4-CLOSE-FAIL` still open and no repair | Not Run | |

### Test execution protocol
1. Use **disposable** test assets/users and write down generated IDs; never modify real campus records.
2. For expected-error tests, verify the operation was rejected **and** that no unwanted row was created.
3. For two-session concurrency, use the existing Phase 4 lab guide with two Workbench connections; record which statement waited and which committed.
4. Capture SQL results and screenshots in `docs/screenshots/`, with filenames keyed to test IDs.
5. Record any failures in the defect log; fix, retest and only then mark Pass.

## Defect log
| Defect ID | Test ID | Description | Severity | Fix | Retest |
|---|---|---|---|---|---|
| — | — | Complete from actual testing | — | — | — |

## Release decision
- Automated: **[X PASS / Y FAIL / Z SKIP]**
- Manual: **[X PASS / Y FAIL / Z NOT RUN]**
- SQL integrity: **[PASS / FAIL / NOT RUN]**
- Backup/restore: **[PASS / FAIL / NOT RUN]**
- Approved for submission: **[YES / NO]**

**Tester signature:** ___________________    **Date:** ______________
