
# CASMS - Complete Data Dictionary

Project: Campus Asset & Service Management System
Course: Advanced Database Management System Practical
Database: MySQL 8.0.46
Engine: InnoDB
Character Set: utf8mb4

Status: Draft for Phase 1 schema validation
Total Planned Tables: 24

---

# 1. Data Dictionary Conventions

PK = Primary Key
FK = Foreign Key
UK = Unique Key
NN = NOT NULL
AI = AUTO_INCREMENT

Null:
- NO = A value is required.
- YES = NULL is permitted.

Default:
- "-" = No explicit default.
- NULL = Defaults to NULL.
- TRUE/FALSE = Boolean default.
- CURRENT_TIMESTAMP = Current date and time.

All primary keys:
INT UNSIGNED AUTO_INCREMENT

Money values:
DECIMAL(12,2)

Foreign keys:
ON DELETE RESTRICT by default.

---

# 2. Campus and User Management

## Table 1: roles

Purpose: Stores application user roles.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| role_id | INT UNSIGNED | NO | PK | AI |
| role_name | VARCHAR(30) | NO | UK | - |

Allowed values:
Admin, Staff, Technician.

## Table 2: departments

Purpose: Stores academic and administrative departments.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| department_id | INT UNSIGNED | NO | PK | AI |
| department_code | VARCHAR(20) | NO | UK | - |
| department_name | VARCHAR(100) | NO | - | - |
| is_active | BOOLEAN | NO | - | TRUE |

Example:
MCA - Master of Computer Applications.

## Table 3: buildings

Purpose: Stores campus buildings.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| building_id | INT UNSIGNED | NO | PK | AI |
| building_code | VARCHAR(20) | NO | UK | - |
| building_name | VARCHAR(100) | NO | - | - |
| notes | TEXT | YES | - | NULL |

## Table 4: rooms

Purpose: Stores classrooms, labs and offices.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| room_id | INT UNSIGNED | NO | PK | AI |
| building_id | INT UNSIGNED | NO | FK | - |
| department_id | INT UNSIGNED | YES | FK | NULL |
| room_number | VARCHAR(20) | NO | - | - |
| floor_number | INT | YES | - | NULL |
| room_type | VARCHAR(40) | NO | - | - |

Foreign keys:
- building_id -> buildings(building_id)
- department_id -> departments(department_id)

Unique:
(building_id, room_number)

## Table 5: users

Purpose: Stores application user accounts.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| user_id | INT UNSIGNED | NO | PK | AI |
| employee_code | VARCHAR(30) | NO | UK | - |
| full_name | VARCHAR(100) | NO | - | - |
| email | VARCHAR(150) | NO | UK | - |
| password_hash | VARCHAR(255) | NO | - | - |
| role_id | INT UNSIGNED | NO | FK | - |
| department_id | INT UNSIGNED | NO | FK | - |
| is_active | BOOLEAN | NO | - | TRUE |
| must_change_password | BOOLEAN | NO | - | TRUE |
| last_login | DATETIME | YES | - | NULL |

Foreign keys:
- role_id -> roles(role_id)
- department_id -> departments(department_id)

Security:
- Store password hashes, never plaintext.
- Admin creates user accounts.
- Role permissions are checked by the backend.

## Table 6: technician_profiles

Purpose: Stores technician-specific information.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| profile_id | INT UNSIGNED | NO | PK | AI |
| user_id | INT UNSIGNED | NO | FK, UK | - |
| specialization | VARCHAR(100) | YES | - | NULL |
| max_open_requests | INT | NO | - | 5 |
| is_available | BOOLEAN | NO | - | TRUE |

Foreign key:
user_id -> users(user_id)

Constraints:
max_open_requests > 0

Only Technician users should have technician profiles.

---

# 3. Asset Management

## Table 7: asset_categories

Purpose: Stores categories of institutional assets.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| category_id | INT UNSIGNED | NO | PK | AI |
| category_code | VARCHAR(20) | NO | UK | - |
| category_name | VARCHAR(100) | NO | - | - |
| default_useful_life_years | INT | YES | - | NULL |
| is_active | BOOLEAN | NO | - | TRUE |

Constraint:
default_useful_life_years > 0 when provided.

## Table 8: vendors

Purpose: Stores suppliers and service providers.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| vendor_id | INT UNSIGNED | NO | PK | AI |
| vendor_name | VARCHAR(150) | NO | - | - |
| contact_number | VARCHAR(20) | YES | - | NULL |
| email | VARCHAR(150) | YES | - | NULL |
| vendor_type | VARCHAR(30) | NO | - | - |
| is_active | BOOLEAN | NO | - | TRUE |

Allowed vendor types:
Supplier, Service Provider, Both.

## Table 9: asset_statuses

Purpose: Stores asset lifecycle statuses.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| asset_status_id | INT UNSIGNED | NO | PK | AI |
| status_name | VARCHAR(30) | NO | UK | - |

Allowed values:
- In Stock
- Active
- Under Repair
- Retired

## Table 10: assets

Purpose: Main register of campus assets.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| asset_id | INT UNSIGNED | NO | PK | AI |
| asset_tag | VARCHAR(50) | NO | UK | - |
| serial_number | VARCHAR(100) | YES | UK | NULL |
| asset_name | VARCHAR(150) | NO | - | - |
| category_id | INT UNSIGNED | NO | FK | - |
| department_id | INT UNSIGNED | NO | FK | - |
| room_id | INT UNSIGNED | YES | FK | NULL |
| vendor_id | INT UNSIGNED | YES | FK | NULL |
| asset_status_id | INT UNSIGNED | NO | FK | - |
| parent_asset_id | INT UNSIGNED | YES | FK | NULL |
| brand | VARCHAR(100) | YES | - | NULL |
| model | VARCHAR(100) | YES | - | NULL |
| purchase_date | DATE | YES | - | NULL |
| purchase_cost | DECIMAL(12,2) | NO | - | - |
| useful_life_years | INT | YES | - | NULL |
| salvage_value | DECIMAL(12,2) | NO | - | 0.00 |
| retirement_date | DATE | YES | - | NULL |
| retirement_reason | TEXT | YES | - | NULL |
| needs_retirement_review | BOOLEAN | NO | - | FALSE |

Foreign keys:
- category_id -> asset_categories(category_id)
- department_id -> departments(department_id)
- room_id -> rooms(room_id)
- vendor_id -> vendors(vendor_id)
- asset_status_id -> asset_statuses(asset_status_id)
- parent_asset_id -> assets(asset_id)

Checks:
- purchase_cost >= 0
- salvage_value >= 0
- useful_life_years > 0 when provided
- parent_asset_id differs from asset_id

Additional rules:
- Asset tags must be generated uniquely.
- Retired assets cannot receive new requests.
- Asset hierarchy must not contain cycles.
- Asset ownership and location must remain consistent.

## Table 11: warranties

Purpose: Tracks standard, extended and AMC warranties.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| warranty_id | INT UNSIGNED | NO | PK | AI |
| asset_id | INT UNSIGNED | NO | FK | - |
| vendor_id | INT UNSIGNED | YES | FK | NULL |
| coverage_type | VARCHAR(30) | NO | - | - |
| start_date | DATE | NO | - | - |
| end_date | DATE | NO | - | - |
| terms | TEXT | YES | - | NULL |

Foreign keys:
- asset_id -> assets(asset_id)
- vendor_id -> vendors(vendor_id)

Constraints:
end_date >= start_date

Coverage:
Standard, Extended, AMC.

## Table 12: asset_assignments

Purpose: Stores current and historical assignments.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| assignment_id | INT UNSIGNED | NO | PK | AI |
| asset_id | INT UNSIGNED | NO | FK | - |
| assigned_user_id | INT UNSIGNED | YES | FK | NULL |
| assigned_department_id | INT UNSIGNED | YES | FK | NULL |
| assigned_room_id | INT UNSIGNED | YES | FK | NULL |
| assigned_by_user_id | INT UNSIGNED | NO | FK | - |
| assigned_from | DATE | NO | - | - |
| assigned_to | DATE | YES | - | NULL |
| remarks | TEXT | YES | - | NULL |

Foreign keys:
- asset_id -> assets(asset_id)
- assigned_user_id -> users(user_id)
- assigned_department_id -> departments(department_id)
- assigned_room_id -> rooms(room_id)
- assigned_by_user_id -> users(user_id)

Rules:
- At least one assignee must exist.
- assigned_to >= assigned_from when provided.
- NULL assigned_to means current assignment.
- Only one current assignment per asset.

## Table 13: asset_transfers

Purpose: Tracks asset location and department changes.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| transfer_id | INT UNSIGNED | NO | PK | AI |
| asset_id | INT UNSIGNED | NO | FK | - |
| from_room_id | INT UNSIGNED | YES | FK | NULL |
| to_room_id | INT UNSIGNED | YES | FK | NULL |
| from_department_id | INT UNSIGNED | NO | FK | - |
| to_department_id | INT UNSIGNED | NO | FK | - |
| transferred_by_user_id | INT UNSIGNED | NO | FK | - |
| transferred_at | DATETIME | NO | - | - |
| reason | TEXT | NO | - | - |

Foreign keys:
- asset_id -> assets(asset_id)
- from_room_id -> rooms(room_id)
- to_room_id -> rooms(room_id)
- from_department_id -> departments(department_id)
- to_department_id -> departments(department_id)
- transferred_by_user_id -> users(user_id)

Rules:
- Preserve old and new location history.
- Retired assets cannot be transferred.
- Location changes must be atomic.

## Table 14: asset_tag_counters

Purpose: Generates sequential asset tag numbers.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| counter_id | INT UNSIGNED | NO | PK | AI |
| department_id | INT UNSIGNED | NO | FK | - |
| category_id | INT UNSIGNED | NO | FK | - |
| last_number | INT UNSIGNED | NO | - | 0 |

Foreign keys:
- department_id -> departments(department_id)
- category_id -> asset_categories(category_id)

Unique:
(department_id, category_id)

Example:
MCA-COM-0001

The counter must be updated safely under concurrency.

---

# 4. Service Requests and Maintenance

## Table 15: request_statuses

Purpose: Stores service request lifecycle statuses.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| request_status_id | INT UNSIGNED | NO | PK | AI |
| status_name | VARCHAR(30) | NO | UK | - |

Allowed:
- Open
- Assigned
- In Progress
- On Hold
- Closed
- Cancelled

Reopened requests return to Assigned.
Reopening is recorded in the timeline.

## Table 16: priorities

Purpose: Stores service priority and SLA targets.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| priority_id | INT UNSIGNED | NO | PK | AI |
| priority_name | VARCHAR(30) | NO | UK | - |
| target_hours | INT UNSIGNED | NO | - | - |

Values:
- Critical: 4 hours
- High: 24 hours
- Medium: 72 hours
- Low: 168 hours

Constraint:
target_hours > 0

## Table 17: service_requests

Purpose: Stores reported asset problems.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| request_id | INT UNSIGNED | NO | PK | AI |
| request_number | VARCHAR(50) | NO | UK | - |
| asset_id | INT UNSIGNED | NO | FK | - |
| raised_by_user_id | INT UNSIGNED | NO | FK | - |
| assigned_technician_id | INT UNSIGNED | YES | FK | NULL |
| request_status_id | INT UNSIGNED | NO | FK | - |
| priority_id | INT UNSIGNED | NO | FK | - |
| title | VARCHAR(200) | NO | - | - |
| description | TEXT | NO | - | - |
| raised_at | DATETIME | NO | - | - |
| assigned_at | DATETIME | YES | - | NULL |
| started_at | DATETIME | YES | - | NULL |
| due_at | DATETIME | NO | - | - |
| closed_at | DATETIME | YES | - | NULL |
| resolution_summary | TEXT | YES | - | NULL |
| cancellation_reason | TEXT | YES | - | NULL |
| reopen_count | INT UNSIGNED | NO | - | 0 |
| feedback_rating | INT | YES | - | NULL |
| feedback_comment | TEXT | YES | - | NULL |

Foreign keys:
- asset_id -> assets(asset_id)
- raised_by_user_id -> users(user_id)
- assigned_technician_id -> users(user_id)
- request_status_id -> request_statuses(request_status_id)
- priority_id -> priorities(priority_id)

Constraints:
- feedback_rating BETWEEN 1 AND 5
  when provided
- closed_at >= raised_at when provided
- Due date is fixed when request is created.

Rules:
- Requests cannot target retired assets.
- Only active authorized technicians can be assigned.
- Status transitions must be valid.
- Closure requires a maintenance record.
- Reopening requires Admin authorization.

## Table 18: request_updates

Purpose: Stores request comments and timeline events.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| update_id | INT UNSIGNED | NO | PK | AI |
| request_id | INT UNSIGNED | NO | FK | - |
| author_user_id | INT UNSIGNED | NO | FK | - |
| update_type | VARCHAR(30) | NO | - | - |
| old_value | VARCHAR(100) | YES | - | NULL |
| new_value | VARCHAR(100) | YES | - | NULL |
| comment | TEXT | YES | - | NULL |
| created_at | DATETIME | NO | - | CURRENT_TIMESTAMP |

Foreign keys:
- request_id -> service_requests(request_id)
- author_user_id -> users(user_id)

Examples:
Assignment, status change, comment and closure.

## Table 19: maintenance_records

Purpose: Stores asset repair and maintenance activities.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| maintenance_id | INT UNSIGNED | NO | PK | AI |
| request_id | INT UNSIGNED | NO | FK | - |
| technician_id | INT UNSIGNED | NO | FK | - |
| vendor_id | INT UNSIGNED | YES | FK | NULL |
| maintenance_type | VARCHAR(30) | NO | - | - |
| diagnosis | TEXT | NO | - | - |
| work_performed | TEXT | NO | - | - |
| start_date | DATETIME | NO | - | - |
| end_date | DATETIME | NO | - | - |
| labour_cost | DECIMAL(12,2) | NO | - | 0.00 |
| outcome | VARCHAR(50) | NO | - | - |
| warranty_covered | BOOLEAN | NO | - | FALSE |

Foreign keys:
- request_id -> service_requests(request_id)
- technician_id -> users(user_id)
- vendor_id -> vendors(vendor_id)

Constraints:
- labour_cost >= 0
- end_date >= start_date

Normalization:
- asset_id is intentionally not stored here.
- The asset is identified through service_requests.
- This removes a redundant dependency.

Rule:
Closure records maintenance and updates
the request in one transaction.

## Table 20: maintenance_parts

Purpose: Stores individual parts used in repairs.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| part_id | INT UNSIGNED | NO | PK | AI |
| maintenance_id | INT UNSIGNED | NO | FK | - |
| part_name | VARCHAR(150) | NO | - | - |
| quantity | INT UNSIGNED | NO | - | - |
| unit_cost | DECIMAL(12,2) | NO | - | - |

Foreign key:
maintenance_id -> maintenance_records(maintenance_id)

Constraints:
- quantity >= 1
- unit_cost >= 0

Calculated cost:
quantity * unit_cost

Parts are repair cost entries,
not warehouse inventory.

---

# 5. System Support

## Table 21: notifications

Purpose: Stores in-application alerts.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| notification_id | INT UNSIGNED | NO | PK | AI |
| user_id | INT UNSIGNED | NO | FK | - |
| request_id | INT UNSIGNED | YES | FK | NULL |
| notification_type | VARCHAR(50) | NO | - | - |
| message | TEXT | NO | - | - |
| is_read | BOOLEAN | NO | - | FALSE |
| created_at | DATETIME | NO | - | CURRENT_TIMESTAMP |

Foreign keys:
- user_id -> users(user_id)
- request_id -> service_requests(request_id)

## Table 22: audit_log

Purpose: Records important database changes.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| audit_id | INT UNSIGNED | NO | PK | AI |
| table_name | VARCHAR(100) | NO | - | - |
| record_id | VARCHAR(64) | NO | - | - |
| action | VARCHAR(20) | NO | - | - |
| old_values | JSON | YES | - | NULL |
| new_values | JSON | YES | - | NULL |
| changed_by_user_id | INT UNSIGNED | YES | FK | NULL |
| changed_at | DATETIME | NO | - | CURRENT_TIMESTAMP |

Foreign key:
changed_by_user_id -> users(user_id)

Allowed actions:
INSERT, UPDATE, DELETE.

Rules:
- Created automatically by database triggers.
- Audit records are append-only.
- Application users cannot update or delete them.

## Table 23: maintenance_schedules

Priority: Could-have

Purpose: Stores preventive maintenance schedules.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| schedule_id | INT UNSIGNED | NO | PK | AI |
| asset_id | INT UNSIGNED | NO | FK | - |
| task | VARCHAR(200) | NO | - | - |
| frequency_days | INT UNSIGNED | NO | - | - |
| last_done | DATE | YES | - | NULL |
| next_due | DATE | NO | - | - |
| is_active | BOOLEAN | NO | - | TRUE |

Foreign key:
asset_id -> assets(asset_id)

Constraint:
frequency_days > 0

## Table 24: attachments

Priority: Could-have

Purpose: Stores service request file references.

| Column | Type | Null | Key | Default |
|---|---|---|---|---|
| attachment_id | INT UNSIGNED | NO | PK | AI |
| request_id | INT UNSIGNED | NO | FK | - |
| uploaded_by_user_id | INT UNSIGNED | NO | FK | - |
| file_name | VARCHAR(255) | NO | - | - |
| stored_path | VARCHAR(500) | NO | - | - |
| uploaded_at | DATETIME | NO | - | CURRENT_TIMESTAMP |

Foreign keys:
- request_id -> service_requests(request_id)
- uploaded_by_user_id -> users(user_id)

---

# 6. Common Timestamp Columns

The following main tables will also have:

created_at:
- Type: DATETIME
- Null: NO
- Default: CURRENT_TIMESTAMP

updated_at:
- Type: DATETIME
- Null: NO
- Default: CURRENT_TIMESTAMP
- Automatically updated when a row changes.

Applies to:
- departments
- buildings
- rooms
- users
- asset_categories
- vendors
- assets
- warranties
- asset_assignments
- asset_transfers
- service_requests
- maintenance_records

These columns are additional to those listed above.

---

# 7. Data Integrity Rules

1. Every table must have a primary key.
2. Foreign keys reference existing records.
3. Asset tags must be unique.
4. User emails must be unique.
5. Request numbers must be unique.
6. Monetary values cannot be negative.
7. Maintenance part quantities must be positive.
8. Warranty end dates cannot precede start dates.
9. Closed requests require maintenance records.
10. Retired assets cannot receive new service requests.
11. Asset assignments retain historical records.
12. Only one current assignment is allowed per asset.
13. Audit records are append-only.
14. Invalid status transitions must be rejected.
15. Multi-step updates must use transactions.
16. Historical records must not be cascade-deleted.

Some rules need triggers, stored procedures,
generated-column constraints, or transactional
application logic beyond ordinary foreign keys.

---

# 8. Planned Database Objects

Views:
- vw_asset_overview
- vw_pending_requests
- vw_overdue_requests
- vw_service_history
- vw_warranty_status
- vw_department_cost_summary
- vw_technician_workload

Functions:
- fn_warranty_days_remaining
- fn_asset_total_maintenance_cost
- fn_asset_book_value

Procedures:
- sp_close_service_request
- sp_assign_technician
- sp_assign_asset
- sp_transfer_asset
- sp_retire_asset
- sp_reopen_request

Additional database logic:
- Concurrency-safe asset tag generation
- Audit triggers
- Status-validation triggers
- Integrity constraints
- Performance indexes

Object implementations are planned for
the appropriate database development phases.

---

# 9. Final Review Before SQL Creation

Items to confirm:
- D1-D8 design decisions
- Foreign key optionality
- Candidate keys and functional dependencies
- Third Normal Form compliance
- One current assignment constraint
- Asset tag generation strategy
- Technician assignment restrictions
- Status-transition validation
- Common timestamp columns
- Optional feature implementation

The database schema will be finalized after
these checks.

---

# 10. Conclusion

This data dictionary documents the proposed
CASMS relational database structure.

Total planned tables: 24

It identifies:
- Column names
- MySQL data types
- NULL requirements
- Primary keys
- Foreign keys
- Unique constraints
- Default values
- Relationships
- Validation rules

It serves as the reference for the upcoming
MySQL database creation scripts.

Status: Documented, pending final schema approval.
