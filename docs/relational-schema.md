
# CASMS - Relational Schema
## Campus Asset & Service Management System

Course: Advanced Database Management System Practical
Project: MCA Semester I Mini-Project
Database: MySQL 8.x
Engine: InnoDB
Character Set: utf8mb4

---

# 1. Campus and User Management

## 1. roles
Purpose: Stores the three system roles.

- role_id: INT UNSIGNED, PK, AUTO_INCREMENT
- role_name: VARCHAR(30), NOT NULL, UNIQUE

Values: Admin, Staff, Technician

## 2. departments
Purpose: Stores college departments.

- department_id: INT UNSIGNED, PK, AUTO_INCREMENT
- department_code: VARCHAR(20), NOT NULL, UNIQUE
- department_name: VARCHAR(100), NOT NULL
- is_active: BOOLEAN, NOT NULL, DEFAULT TRUE

## 3. buildings
Purpose: Stores campus buildings.

- building_id: INT UNSIGNED, PK, AUTO_INCREMENT
- building_code: VARCHAR(20), NOT NULL, UNIQUE
- building_name: VARCHAR(100), NOT NULL
- notes: TEXT, NULL

## 4. rooms
Purpose: Stores classrooms, labs and offices.

- room_id: INT UNSIGNED, PK, AUTO_INCREMENT
- building_id: INT UNSIGNED, NOT NULL, FK
- department_id: INT UNSIGNED, NULL, FK
- room_number: VARCHAR(20), NOT NULL
- floor_number: INT, NULL
- room_type: VARCHAR(40), NOT NULL

Foreign Keys:
- building_id -> buildings(building_id)
- department_id -> departments(department_id)

Constraints:
- UNIQUE(building_id, room_number)

## 5. users
Purpose: Stores login accounts and user details.

- user_id: INT UNSIGNED, PK, AUTO_INCREMENT
- employee_code: VARCHAR(30), NOT NULL, UNIQUE
- full_name: VARCHAR(100), NOT NULL
- email: VARCHAR(150), NOT NULL, UNIQUE
- password_hash: VARCHAR(255), NOT NULL
- role_id: INT UNSIGNED, NOT NULL, FK
- department_id: INT UNSIGNED, NOT NULL, FK
- is_active: BOOLEAN, NOT NULL, DEFAULT TRUE
- must_change_password: BOOLEAN, DEFAULT TRUE
- last_login: DATETIME, NULL

Foreign Keys:
- role_id -> roles(role_id)
- department_id -> departments(department_id)

Rules:
- Only Admin creates user accounts.
- Passwords must be securely hashed.
- Inactive users cannot log in.

## 6. technician_profiles
Purpose: Stores additional technician information.

- profile_id: INT UNSIGNED, PK, AUTO_INCREMENT
- user_id: INT UNSIGNED, NOT NULL, UNIQUE, FK
- specialization: VARCHAR(100), NULL
- max_open_requests: INT, NOT NULL, DEFAULT 5
- is_available: BOOLEAN, DEFAULT TRUE

Foreign Key:
- user_id -> users(user_id)

Constraints:
- max_open_requests > 0

---

# 2. Asset Management

## 7. asset_categories
Purpose: Stores asset categories.

- category_id: INT UNSIGNED, PK, AUTO_INCREMENT
- category_code: VARCHAR(20), NOT NULL, UNIQUE
- category_name: VARCHAR(100), NOT NULL
- default_useful_life_years: INT, NULL
- is_active: BOOLEAN, DEFAULT TRUE

Constraints:
- default_useful_life_years > 0 when provided

## 8. vendors
Purpose: Stores suppliers and service providers.

- vendor_id: INT UNSIGNED, PK, AUTO_INCREMENT
- vendor_name: VARCHAR(150), NOT NULL
- contact_number: VARCHAR(20), NULL
- email: VARCHAR(150), NULL
- vendor_type: VARCHAR(30), NOT NULL
- is_active: BOOLEAN, DEFAULT TRUE

Values:
- Supplier
- Service Provider
- Both

## 9. asset_statuses
Purpose: Stores asset lifecycle statuses.

- asset_status_id: INT UNSIGNED, PK, AUTO_INCREMENT
- status_name: VARCHAR(30), NOT NULL, UNIQUE

Values:
- In Stock
- Active
- Under Repair
- Retired

## 10. assets
Purpose: Stores registered college assets.

- asset_id: INT UNSIGNED, PK, AUTO_INCREMENT
- asset_tag: VARCHAR(50), NOT NULL, UNIQUE
- serial_number: VARCHAR(100), NULL, UNIQUE
- asset_name: VARCHAR(150), NOT NULL
- category_id: INT UNSIGNED, NOT NULL, FK
- department_id: INT UNSIGNED, NOT NULL, FK
- room_id: INT UNSIGNED, NULL, FK
- vendor_id: INT UNSIGNED, NULL, FK
- asset_status_id: INT UNSIGNED, NOT NULL, FK
- parent_asset_id: INT UNSIGNED, NULL, FK
- brand: VARCHAR(100), NULL
- model: VARCHAR(100), NULL
- purchase_date: DATE, NULL
- purchase_cost: DECIMAL(12,2), NOT NULL
- useful_life_years: INT, NULL
- salvage_value: DECIMAL(12,2), DEFAULT 0
- retirement_date: DATE, NULL
- retirement_reason: TEXT, NULL
- needs_retirement_review: BOOLEAN, DEFAULT FALSE

Foreign Keys:
- category_id -> asset_categories(category_id)
- department_id -> departments(department_id)
- room_id -> rooms(room_id)
- vendor_id -> vendors(vendor_id)
- asset_status_id -> asset_statuses(asset_status_id)
- parent_asset_id -> assets(asset_id)

Constraints:
- purchase_cost >= 0
- salvage_value >= 0
- useful_life_years > 0 when provided
- parent_asset_id cannot equal asset_id

Rules:
- Asset tags are automatically generated.
- Retired assets cannot receive new requests.
- Retired assets retain their history.
- Parent-child cycles must be prevented.

## 11. warranties
Purpose: Stores warranties and AMC coverage.

- warranty_id: INT UNSIGNED, PK, AUTO_INCREMENT
- asset_id: INT UNSIGNED, NOT NULL, FK
- vendor_id: INT UNSIGNED, NULL, FK
- coverage_type: VARCHAR(30), NOT NULL
- start_date: DATE, NOT NULL
- end_date: DATE, NOT NULL
- terms: TEXT, NULL

Foreign Keys:
- asset_id -> assets(asset_id)
- vendor_id -> vendors(vendor_id)

Constraints:
- end_date >= start_date

Coverage Types:
- Standard
- Extended
- AMC

## 12. asset_assignments
Purpose: Preserves asset assignment history.

- assignment_id: INT UNSIGNED, PK, AUTO_INCREMENT
- asset_id: INT UNSIGNED, NOT NULL, FK
- assigned_user_id: INT UNSIGNED, NULL, FK
- assigned_department_id: INT UNSIGNED, NULL, FK
- assigned_room_id: INT UNSIGNED, NULL, FK
- assigned_by_user_id: INT UNSIGNED, NOT NULL, FK
- assigned_from: DATE, NOT NULL
- assigned_to: DATE, NULL
- remarks: TEXT, NULL

Foreign Keys:
- asset_id -> assets(asset_id)
- assigned_user_id -> users(user_id)
- assigned_department_id -> departments(department_id)
- assigned_room_id -> rooms(room_id)
- assigned_by_user_id -> users(user_id)

Rules:
- At least one assignee must exist.
- assigned_to >= assigned_from when provided.
- NULL assigned_to indicates current assignment.
- Only one current assignment per asset.
- Previous assignments are preserved.

## 13. asset_transfers
Purpose: Stores asset movement history.

- transfer_id: INT UNSIGNED, PK, AUTO_INCREMENT
- asset_id: INT UNSIGNED, NOT NULL, FK
- from_room_id: INT UNSIGNED, NULL, FK
- to_room_id: INT UNSIGNED, NULL, FK
- from_department_id: INT UNSIGNED, NOT NULL, FK
- to_department_id: INT UNSIGNED, NOT NULL, FK
- transferred_by_user_id: INT UNSIGNED, NOT NULL, FK
- transferred_at: DATETIME, NOT NULL
- reason: TEXT, NOT NULL

Foreign Keys:
- asset_id -> assets(asset_id)
- from_room_id -> rooms(room_id)
- to_room_id -> rooms(room_id)
- from_department_id -> departments(department_id)
- to_department_id -> departments(department_id)
- transferred_by_user_id -> users(user_id)

Rules:
- Retired assets cannot be transferred.
- Previous locations must remain in history.
- Current asset location must be updated atomically.

## 14. asset_tag_counters
Purpose: Generates sequential asset tag numbers.

- counter_id: INT UNSIGNED, PK, AUTO_INCREMENT
- department_id: INT UNSIGNED, NOT NULL, FK
- category_id: INT UNSIGNED, NOT NULL, FK
- last_number: INT UNSIGNED, NOT NULL, DEFAULT 0

Foreign Keys:
- department_id -> departments(department_id)
- category_id -> asset_categories(category_id)

Constraints:
- UNIQUE(department_id, category_id)

Examples:
- MCA-COM-0001
- MCA-COM-0002
- CSE-PRJ-0001

Rule:
- Counter updates must be concurrency-safe.

---

# 3. Service Request and Maintenance

## 15. request_statuses
Purpose: Stores service request statuses.

- request_status_id: INT UNSIGNED, PK, AUTO_INCREMENT
- status_name: VARCHAR(30), NOT NULL, UNIQUE

Values:
- Open
- Assigned
- In Progress
- On Hold
- Closed
- Cancelled

Rule:
- A reopened request returns to Assigned status.
- Reopening is recorded in request history.

## 16. priorities
Purpose: Defines service request urgency.

- priority_id: INT UNSIGNED, PK, AUTO_INCREMENT
- priority_name: VARCHAR(30), NOT NULL, UNIQUE
- target_hours: INT UNSIGNED, NOT NULL

Example Values:
- Critical: 4 hours
- High: 24 hours
- Medium: 72 hours
- Low: 168 hours

Constraints:
- target_hours > 0

## 17. service_requests
Purpose: Stores problems reported for campus assets.

- request_id: INT UNSIGNED, PK, AUTO_INCREMENT
- request_number: VARCHAR(50), NOT NULL, UNIQUE
- asset_id: INT UNSIGNED, NOT NULL, FK
- raised_by_user_id: INT UNSIGNED, NOT NULL, FK
- assigned_technician_id: INT UNSIGNED, NULL, FK
- request_status_id: INT UNSIGNED, NOT NULL, FK
- priority_id: INT UNSIGNED, NOT NULL, FK
- title: VARCHAR(200), NOT NULL
- description: TEXT, NOT NULL
- raised_at: DATETIME, NOT NULL
- assigned_at: DATETIME, NULL
- started_at: DATETIME, NULL
- due_at: DATETIME, NOT NULL
- closed_at: DATETIME, NULL
- resolution_summary: TEXT, NULL
- cancellation_reason: TEXT, NULL
- reopen_count: INT UNSIGNED, DEFAULT 0
- feedback_rating: INT, NULL
- feedback_comment: TEXT, NULL

Foreign Keys:
- asset_id -> assets(asset_id)
- raised_by_user_id -> users(user_id)
- assigned_technician_id -> users(user_id)
- request_status_id -> request_statuses(request_status_id)
- priority_id -> priorities(priority_id)

Constraints:
- feedback_rating BETWEEN 1 AND 5 when provided
- closed_at >= raised_at when provided

Rules:
- A request must reference a non-retired asset.
- Only authorized users can raise requests.
- Technician assignment requires an active technician.
- Status transitions must follow the workflow.
- Closure requires a maintenance record.

## 18. request_updates
Purpose: Stores request comments and timeline events.

- update_id: INT UNSIGNED, PK, AUTO_INCREMENT
- request_id: INT UNSIGNED, NOT NULL, FK
- author_user_id: INT UNSIGNED, NOT NULL, FK
- update_type: VARCHAR(30), NOT NULL
- old_value: VARCHAR(100), NULL
- new_value: VARCHAR(100), NULL
- comment: TEXT, NULL
- created_at: DATETIME, NOT NULL

Foreign Keys:
- request_id -> service_requests(request_id)
- author_user_id -> users(user_id)

Examples:
- Request created
- Technician assigned
- Status changed
- Comment added
- Request closed
- Request reopened

## 19. maintenance_records
Purpose: Stores asset repair and service details.

- maintenance_id: INT UNSIGNED, PK, AUTO_INCREMENT
- request_id: INT UNSIGNED, NOT NULL, FK
- asset_id: INT UNSIGNED, NOT NULL, FK
- technician_id: INT UNSIGNED, NOT NULL, FK
- vendor_id: INT UNSIGNED, NULL, FK
- maintenance_type: VARCHAR(30), NOT NULL
- diagnosis: TEXT, NOT NULL
- work_performed: TEXT, NOT NULL
- start_date: DATETIME, NOT NULL
- end_date: DATETIME, NOT NULL
- labour_cost: DECIMAL(12,2), NOT NULL, DEFAULT 0
- outcome: VARCHAR(50), NOT NULL
- warranty_covered: BOOLEAN, DEFAULT FALSE

Foreign Keys:
- request_id -> service_requests(request_id)
- asset_id -> assets(asset_id)
- technician_id -> users(user_id)
- vendor_id -> vendors(vendor_id)

Constraints:
- labour_cost >= 0
- end_date >= start_date

Rules:
- Maintenance must reference the correct asset.
- All repair costs must be non-negative.
- Closure and maintenance recording are atomic.

## 20. maintenance_parts
Purpose: Stores parts used during maintenance.

- part_id: INT UNSIGNED, PK, AUTO_INCREMENT
- maintenance_id: INT UNSIGNED, NOT NULL, FK
- part_name: VARCHAR(150), NOT NULL
- quantity: INT UNSIGNED, NOT NULL
- unit_cost: DECIMAL(12,2), NOT NULL

Foreign Key:
- maintenance_id -> maintenance_records(maintenance_id)

Constraints:
- quantity >= 1
- unit_cost >= 0

Calculated Value:
- total_part_cost = quantity * unit_cost

Rule:
- Parts are cost line items only.
- Spare-parts inventory is outside project scope.

---

# 4. System Support

## 21. notifications
Purpose: Stores in-application user notifications.

- notification_id: INT UNSIGNED, PK, AUTO_INCREMENT
- user_id: INT UNSIGNED, NOT NULL, FK
- request_id: INT UNSIGNED, NULL, FK
- notification_type: VARCHAR(50), NOT NULL
- message: TEXT, NOT NULL
- is_read: BOOLEAN, DEFAULT FALSE
- created_at: DATETIME, NOT NULL

Foreign Keys:
- user_id -> users(user_id)
- request_id -> service_requests(request_id)

Examples:
- Technician assigned
- Request status changed
- Request closed
- Warranty expiring

## 22. audit_log
Purpose: Tracks important database changes.

- audit_id: INT UNSIGNED, PK, AUTO_INCREMENT
- table_name: VARCHAR(100), NOT NULL
- record_id: VARCHAR(64), NOT NULL
- action: VARCHAR(20), NOT NULL
- old_values: JSON, NULL
- new_values: JSON, NULL
- changed_by_user_id: INT UNSIGNED, NULL, FK
- changed_at: DATETIME, NOT NULL

Foreign Key:
- changed_by_user_id -> users(user_id)

Actions:
- INSERT
- UPDATE
- DELETE

Rules:
- Database triggers record important changes.
- Application users cannot modify audit records.
- Audit records cannot be deleted by the application.

## 23. maintenance_schedules
Purpose: Stores preventive maintenance schedules.

Priority: Could-have

- schedule_id: INT UNSIGNED, PK, AUTO_INCREMENT
- asset_id: INT UNSIGNED, NOT NULL, FK
- task: VARCHAR(200), NOT NULL
- frequency_days: INT UNSIGNED, NOT NULL
- last_done: DATE, NULL
- next_due: DATE, NOT NULL
- is_active: BOOLEAN, DEFAULT TRUE

Foreign Key:
- asset_id -> assets(asset_id)

Constraints:
- frequency_days > 0

## 24. attachments
Purpose: Stores service request file references.

Priority: Could-have

- attachment_id: INT UNSIGNED, PK, AUTO_INCREMENT
- request_id: INT UNSIGNED, NOT NULL, FK
- uploaded_by_user_id: INT UNSIGNED, NOT NULL, FK
- file_name: VARCHAR(255), NOT NULL
- stored_path: VARCHAR(500), NOT NULL
- uploaded_at: DATETIME, NOT NULL

Foreign Keys:
- request_id -> service_requests(request_id)
- uploaded_by_user_id -> users(user_id)

---

# 5. General Database Standards

1. Database engine: InnoDB.
2. Character set: utf8mb4.
3. Table names use plural snake_case.
4. Primary keys use INT UNSIGNED AUTO_INCREMENT.
5. Foreign keys use ON DELETE RESTRICT by default.
6. Money uses DECIMAL(12,2), never FLOAT.
7. Main tables will include created_at and updated_at.
8. Historical records must be preserved.
9. Records referenced elsewhere use soft deactivation.
10. Statuses use lookup tables.
11. CHECK constraints validate supported values.
12. Application SQL must use parameterized queries.
13. Multi-step operations use transactions.
14. Database objects use these prefixes:
    - Views: vw_
    - Functions: fn_
    - Procedures: sp_
    - Triggers: trg_
    - Indexes: idx_
15. SQL scripts will be numbered and executable in order.

# 6. Database Relationships Summary

- One role has many users.
- One department has many users and assets.
- One building contains many rooms.
- One category contains many assets.
- One vendor can supply many assets.
- One asset can have many warranty records.
- One asset can have many historical assignments.
- One asset can have many transfers.
- One asset can have many service requests.
- One request can have many timeline updates.
- One request can have many maintenance records.
- One maintenance record can have many parts.
- One user can receive many notifications.
- One technician can handle many assigned requests.

# 7. Design Status

Total planned tables: 24

Core and supporting schema documented.

Pending before final schema approval:
- Confirm design decisions D1 to D8.
- Verify all foreign keys and relationship optionality.
- Verify 1NF, 2NF and 3NF.
- Prepare the complete data dictionary.
- Finalize integrity and lifecycle enforcement.
- Decide which optional tables are implemented.

This document describes the proposed relational schema.
It is not executable SQL.
