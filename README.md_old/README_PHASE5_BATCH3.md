# CASMS — Phase 5 Batch 3: Service Requests, Technicians and Maintenance

## Starting state

- Keep your working Phase 5 Batch 1 and Batch 2 installation.
- Database phases 1–4 remain intact; **no SQL migration**, reset or reseeding is required.
- Batch 3 adds request creation, request details/timeline, assignment, statuses, technician work, maintenance closure, cancellation, feedback and reopening.
- Uses your existing `sp_assign_technician`, `sp_close_service_request` and `sp_reopen_request` from Phase 3.
- **Runtime behavior is not yet verified on your Windows/MySQL installation.** Test before calling this batch complete.

## Install (Windows, VS Code)

1. Stop the existing server using **Ctrl+C**.
2. Make a backup of the current working project or create a Git commit. No need to delete the database.
3. Extract `CASMS_Phase5_Batch3_Service_Workflows.zip` **into the root** of:

   `D:\KRISTU JAYNATI MCA\SEM I\ADBMS\CASMS`

   Merge/overwrite files when asked; the ZIP paths start with `server/` and `public/`. **Do not extract into a nested Batch3 directory.**
4. The ZIP does **not** contain `.env`, any SQL schema replacements, sample data, or user credentials.
5. In VS Code PowerShell at your project root:

   ```powershell
   npm.cmd run check
   npm.cmd run dev
   ```
6. Open http://localhost:3000 . The existing login, dashboard, assets, Master Data, and Users screens should still load.

Expected offline check: `PASS: 28 JavaScript files passed syntax checks` (the exact number can increase if you added your own `.js` files).

## New screens

- `http://localhost:3000/requests.html` — role-scoped service queue and link to request details.
- `http://localhost:3000/request-new.html` — Staff/Admin creates service requests with priority, due date and duplicate warning.
- `http://localhost:3000/request.html?id=123` — details, timeline, assignment, status, maintenance, cancellation, feedback/reopening based on role and status.

## Test all three roles — recommended order

Use the **Users** page from Batch 2 to create a *fresh Staff and Technician test account* if you do not already have their passwords. Select the Technician role for the technician so `technician_profiles` is created automatically. Copy each one-time temporary password locally, and change it on first sign-in. Never post passwords in chat.

1. **Regression (Admin)**: login, dashboard, Master Data, Users, Assets and logout still work.
2. **Create eligible test asset (Admin)**: register a new asset with Batch 2, activate it, and assign or keep it in the Staff account's department. Avoid using a retired/in-stock asset for the repair.
3. **Create ticket (Staff)**: login as Staff; open **Service requests → New service request**; select that asset, priority, title and description. Verify a `WEB-...` request number and `Open` status.
4. **Permission check (Staff)**: a Staff user cannot see another department's unassigned assets. The direct `/api/users` endpoint should return **403**, and a technician should not be allowed to create a ticket.
5. **Assign (Admin)**: open the newly raised request; choose the active Technician; verify status `Assigned` and notification/timeline entry.
6. **Work (Technician)**: login as the assigned Technician; ticket appears in their queue; open and **Start repair → On hold → Resume**. Verify the status and timeline each time. The asset should show `Under Repair` while work is ongoing.
7. **Close (Technician)**: enter diagnosis, work, start/end date-time, labour amount, outcome, warranty flag, and optionally add 1–2 replacement parts. Choose end time <= now. Click **Close request**. Verify request status `Closed`, maintenance and part records, and asset status `Active` (or retirement-review flag for `Beyond Repair`).
8. **Feedback (Staff)**: open your closed request, submit a 1–5 rating and optional comment; verify saved feedback.
9. **Reopen (Admin, optional)**: within 7 days of closing, use Reopen; status returns to `Assigned`; test technician work and closure again if needed. Earlier maintenance remains as history.
10. **Cancel (Staff)**: create a *second* new request (prefer another active test asset), cancel while `Open`, verify `Cancelled` and cancellation reason. Only Admin may cancel an `Assigned` request.
11. **Privacy (Staff/Technician)**: try accessing another user's request ID manually in the URL and via API; expect 404 (no data returned). Admin can view all requests.
12. **Mobile**: resize browser narrower than 850 px, check request table horizontal scrolling, cards/forms, and sidebar toggle.

If all steps pass, Batch 3 can be marked complete. **Do not share login credentials or secrets** when reporting results.

## API endpoints added

| Method | Endpoint | Who may use it |
|---|---|---|
| GET | `/api/requests/lookups` | Signed-in role-scoped |
| POST | `/api/requests` | Admin, Staff |
| GET | `/api/requests/:id` | Role-scoped |
| POST | `/api/requests/:id/assign` | Admin |
| POST | `/api/requests/:id/status` | Admin, assigned Technician |
| POST | `/api/requests/:id/comments` | Admin, requester Staff, assigned Technician |
| POST | `/api/requests/:id/cancel` | Admin, Staff while Open |
| POST | `/api/requests/:id/close` | Admin, assigned Technician |
| POST | `/api/requests/:id/reopen` | Admin within 7 days |
| POST | `/api/requests/:id/feedback` | Requester Staff after closure |

Every route uses the existing session checks, same-origin custom write header, server-side role checks, raw bound SQL and MySQL integrity rules. Stored procedures are called through **one borrowed pooled connection**, and the custom multi-table mutations use a **single transaction**. The service closure procedure itself controls its own transaction; we do not nest it in a Node transaction.

## Known implementation boundaries

- Batch 3 uses your existing Phase 3 close procedure; ensure it was successfully deployed.
- Service repair start prevents starting two simultaneous active repairs on the same asset. This keeps the asset's repair status consistent for normal UI workflows.
- Email/SMS, photo uploads and external notifications are not part of this academic version.
- Dashboard/reports enhancement, the notification inbox, audit viewer, CSV export and final visual/security hardening belong to **Batch 4**.
- Live browser/database testing happens on your Windows machine. Offline checks do not prove real DB connectivity or stored-procedure success.

## If an error happens

Send: (a) the page / button, (b) exact server terminal error text or the browser message, and (c) relevant query/row ID with personal data removed. Do not rerun database setup or reset existing accounts.
