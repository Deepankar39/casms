# CASMS API Reference — implemented endpoints

**Base:** `http://localhost:3000/api`  
**Format:** JSON (`Content-Type: application/json`)  
**Authentication:** session cookie (`casms.sid`) created after successful login.  
**State change:** POST/PUT/PATCH/DELETE requests must include `X-CASMS-Request: 1` (in addition to the session).  
**Errors:** `{ "error": "Message" }`, with 400, 401, 403, 404, 409, 429 or 500 as appropriate.

## Health and authentication
| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/health` | Public | Database connection and service status |
| POST | `/auth/login` | Public + rate limited | `{email,password}`, creates session |
| GET | `/auth/me` | Session | Current user, role, department and password-change status |
| POST | `/auth/change-password` | Session | `{currentPassword,newPassword}`; new password 12–72 chars |
| POST | `/auth/logout` | Session | Destroy session |

## Dashboard, assets, and users
| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/dashboard` | Scoped | Totals, status groups, recent requests |
| GET | `/insights` | Scoped | Chart datasets |
| GET | `/assets` | Scoped | Paginated searchable asset register |
| GET | `/assets/lookups` | Signed in | Active lookups for asset forms |
| GET | `/assets/:id` | Scoped | Asset details |
| GET | `/assets/:id/history` | Scoped | Transfers, assignments, warranties, permitted requests |
| POST | `/assets` | Admin | Register with generated tag via `sp_register_asset` |
| PUT | `/assets/:id` | Admin | Modify permitted asset fields |
| POST | `/assets/:id/assign` | Admin | Assign via `sp_assign_asset` |
| POST | `/assets/:id/end-assignment` | Admin | Close current assignment |
| POST | `/assets/:id/transfer` | Admin | Atomic transfer with assignment history |
| POST | `/assets/:id/activate` | Admin | Activate an asset |
| POST | `/assets/:id/retire` | Admin | Retire via `sp_retire_asset` |
| GET | `/master/:resource` | Signed in | List master-data rows (`departments`, `buildings`, `rooms`, `asset_categories`, `vendors`) |
| POST | `/master/:resource` | Admin | Create master-data record |
| PUT | `/master/:resource/:id` | Admin | Edit master-data record |
| PATCH | `/master/:resource/:id/status` | Admin | Activate/deactivate record |
| GET | `/users` | Admin | Account list |
| GET | `/users/roles` | Admin | Role lookup |
| POST | `/users` | Admin | Add staff/technician/admin account |
| PUT | `/users/:id` | Admin | Edit account |
| PATCH | `/users/:id/status` | Admin | Activate/deactivate account |

## Service requests and maintenance
| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/requests` | Scoped | Ticket queue |
| GET | `/requests/lookups` | Signed in | Priorities, eligible assets, technicians for Admin |
| POST | `/requests` | Admin/Staff | Raise request (asset, priority, title, description) |
| GET | `/requests/:id` | Scoped | Detail, history, maintenance records and parts |
| POST | `/requests/:id/assign` | Admin | Technician assignment procedure |
| POST | `/requests/:id/status` | Admin/assigned Technician | Start / hold / resume |
| POST | `/requests/:id/comments` | Scoped | Add comment |
| POST | `/requests/:id/cancel` | Admin/eligible Staff | Cancel with reason |
| POST | `/requests/:id/close` | Admin/assigned Technician | Stored-procedure closure + parts |
| POST | `/requests/:id/reopen` | Admin | Reopen procedure |
| POST | `/requests/:id/feedback` | Staff | Feedback on eligible request |

## Reporting and audit
| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/reports/catalog` | Signed in | List accessible reports for current role |
| GET | `/reports/:id` | Scoped | Paginated report (`page`, `search`, `from`, `to`) |
| GET | `/reports/:id/export` | Scoped | CSV export (max 5,000 rows) |
| GET | `/notifications/summary` | Signed in | Unread count |
| GET | `/notifications` | Signed in | Own paginated notification list |
| POST | `/notifications/:id/read` | Signed in | Mark own notification as read |
| POST | `/notifications/read-all` | Signed in | Mark all own notifications read |
| GET | `/audit/tables` | Admin | Audited entity list |
| GET | `/audit` | Admin | Paginated audit events |

Reports: `assets`, `requests`, `history`, `category` (all three roles, appropriately scoped); `department`, `monthly`, `technicians`, `warranties`, `repeat`, `savings` (Admin only).

## Examples (PowerShell)
Use the web login page to create an authenticated browser session; use browser Developer Tools to inspect requests rather than pasting live session cookies into documents. To exercise APIs from a tool, include the saved cookie and `X-CASMS-Request: 1` on mutations.

**Important:** This API document reflects the merged Phase 5 code. It is not an OpenAPI machine contract. Exact request body requirements and validation are in the corresponding `server/routes/*.js` files.
