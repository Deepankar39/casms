
# CASMS - Database Normalization

Project: Campus Asset & Service Management System
Course: Advanced Database Management System Practical
Target Normal Form: Third Normal Form (3NF)

---

# 1. Introduction

Database normalization organizes data into tables
to reduce duplication and prevent inconsistencies.

CASMS uses relational tables for departments,
users, buildings, rooms, assets, service requests,
maintenance records and other information.

Our database design targets:

1. First Normal Form (1NF)
2. Second Normal Form (2NF)
3. Third Normal Form (3NF)

---

# 2. First Normal Form (1NF)

## Definition

A table satisfies 1NF when:
- Each column contains a single atomic value.
- Each row can be uniquely identified.
- Repeating groups are removed.

## Example: Maintenance Parts

Incorrect design:

maintenance_id | part1 | part2 | part3
1 | Cable | Switch | Adapter

Problems:
- A repair may require more than three parts.
- Adding parts requires additional columns.
- Searching and calculating costs is difficult.

## Correct Design

Table: maintenance_records

maintenance_id | diagnosis
1 | Projector not working

Table: maintenance_parts

part_id | maintenance_id | part_name
1 | 1 | Cable
2 | 1 | Switch
3 | 1 | Adapter

Each part is stored in a separate row.

## Result

The maintenance_parts table removes repeating
groups and supports First Normal Form.

---

# 3. Second Normal Form (2NF)

## Definition

A table satisfies 2NF when:
- It satisfies 1NF.
- Every non-key attribute depends on the whole
  candidate key, not only part of a composite key.

## Example: Room Information

Consider this incorrect combined table:

building_id | room_number | building_name | room_type

Suppose the combination of building_id and
room_number uniquely identifies a room.

Functional Dependencies:

building_id -> building_name

(building_id, room_number) -> room_type

Problem:

building_name depends only on building_id,
not on the complete composite key.

This is a partial dependency.

## Correct Design

Table: buildings

building_id | building_name
1 | Main Block
2 | Science Block

Table: rooms

room_id | building_id | room_number | room_type
1 | 1 | 101 | Classroom
2 | 1 | 102 | Laboratory
3 | 2 | 201 | Computer Lab

The building name belongs in buildings.

The rooms table references buildings through
building_id.

## Result

The partial dependency is removed.

Our actual CASMS tables primarily use single-column
primary keys, which simplifies 2NF compliance.

---

# 4. Third Normal Form (3NF)

## Definition

A table satisfies 3NF when:
- It satisfies 2NF.
- Non-key attributes do not have inappropriate
  transitive dependencies on candidate keys.

Formally, for every non-trivial dependency X -> A,
either X is a superkey or A is a prime attribute.

## Example: User and Department

Incorrect design:

user_id | full_name | department_id | department_name

Functional Dependencies:

user_id -> department_id
department_id -> department_name

Therefore:

user_id -> department_id -> department_name

This creates a transitive dependency.

## Correct Design

Table: departments

department_id | department_name
1 | MCA
2 | Computer Science

Table: users

user_id | full_name | department_id
1 | Rahul | 1
2 | Priya | 2
3 | Amit | 1

The department name is stored only once.

Users reference departments using department_id.

## Result

The transitive dependency is removed.

---

# 5. Functional Dependencies in CASMS

Examples:

roles:
role_id -> role_name

departments:
department_id -> department_code,
                 department_name

buildings:
building_id -> building_code,
               building_name

users:
user_id -> employee_code,
           full_name,
           email,
           role_id,
           department_id

asset_categories:
category_id -> category_code,
               category_name

assets:
asset_id -> asset_tag,
            asset_name,
            category_id,
            department_id,
            asset_status_id

priorities:
priority_id -> priority_name,
               target_hours

service_requests:
request_id -> request_number,
              asset_id,
              raised_by_user_id,
              priority_id,
              request_status_id

maintenance_parts:
part_id -> maintenance_id,
           part_name,
           quantity,
           unit_cost

These are representative dependencies,
not the complete dependency inventory.

Unique natural keys are also candidate keys.

---

# 6. Database Anomalies

## Insertion Anomaly

Problem:

A department cannot be registered unless a
user record also exists in a combined table.

Solution:

Store departments in a separate table.

## Update Anomaly

Problem:

Changing the MCA department name requires
updating multiple user records.

Solution:

Store the name once in departments.

## Deletion Anomaly

Problem:

Deleting the last user in a department may
accidentally remove department information.

Solution:

Keep department information independently.

---

# 7. Normalization of Main CASMS Modules

## Campus Structure

Tables:
- departments
- buildings
- rooms

Department and building details are separated
from individual room records.

## User Management

Tables:
- roles
- users
- technician_profiles

Roles are stored independently.
Technician-specific details use a separate table.

## Asset Management

Tables:
- asset_categories
- asset_statuses
- assets
- warranties
- asset_assignments
- asset_transfers

Categories and statuses use lookup tables.
Warranties and historical records are separated.

## Service Management

Tables:
- request_statuses
- priorities
- service_requests
- request_updates

Request priorities and statuses are maintained
in independent reference tables.

## Maintenance Management

Tables:
- maintenance_records
- maintenance_parts

Repair information is separated from the
individual parts used during maintenance.

---

# 8. Important Schema Refinement

The draft relational schema currently contains:

maintenance_records.request_id
maintenance_records.asset_id

Every maintenance record references a mandatory
service request.

But:

request_id -> asset_id

Therefore storing asset_id again inside
maintenance_records creates redundant information.

Recommended correction:

Remove asset_id from maintenance_records.

Retrieve the related asset using:

maintenance_records.request_id
    -> service_requests.request_id
    -> service_requests.asset_id

This preserves asset-level maintenance reporting
without duplicating the asset reference.

The correction must be applied before the final
SQL schema is created.

---

# 9. Intentional Historical Information

Some CASMS values record historical events.

Example:

service_requests.due_at

The due date is calculated using the priority
target when the request is created.

We preserve that deadline even when the
priority configuration changes later.

Historical values must be distinguished from
unnecessary duplicated current information.

Audit logs also preserve historical snapshots
for traceability.

---

# 10. Remaining Design Checks

Before final database approval:

1. Apply the maintenance asset_id correction.
2. Confirm all candidate keys and dependencies.
3. Verify ownership department versus room department.
4. Check optional and mandatory relationships.
5. Ensure historical assignment values are meaningful.
6. Enforce one current assignment per asset.
7. Validate business rules and integrity constraints.
8. Confirm decisions D1 through D8.

---

# 11. Conclusion

CASMS uses normalization principles to organize
campus, asset and service management information.

1NF removes repeating groups.
2NF removes partial dependencies.
3NF removes inappropriate transitive dependencies.

The relational schema is designed toward 3NF.

Final 3NF compliance will be confirmed after the
remaining dependency checks and schema refinement,
before implementing SQL tables.
