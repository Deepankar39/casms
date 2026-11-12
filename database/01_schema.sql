
-- =====================================================
-- CASMS - Campus Asset & Service Management System
-- File: database/01_schema.sql
-- Phase 2: Database Creation (DDL)
-- MySQL Version: 8.0.46
-- =====================================================

CREATE DATABASE IF NOT EXISTS casms
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;

USE casms;

-- =====================================================
-- SECTION 1: CAMPUS AND USER MANAGEMENT
-- =====================================================

-- 1. ROLES

CREATE TABLE IF NOT EXISTS roles (
    role_id INT UNSIGNED AUTO_INCREMENT,
    role_name VARCHAR(30) NOT NULL,

    PRIMARY KEY (role_id),
    CONSTRAINT uq_roles_name UNIQUE (role_name),
    CONSTRAINT ck_roles_name CHECK (
        role_name IN ('Admin', 'Staff', 'Technician')
    )
) ENGINE=InnoDB;

-- 2. DEPARTMENTS

CREATE TABLE IF NOT EXISTS departments (
    department_id INT UNSIGNED AUTO_INCREMENT,
    department_code VARCHAR(20) NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (department_id),
    CONSTRAINT uq_departments_code UNIQUE (department_code)
) ENGINE=InnoDB;

-- 3. BUILDINGS

CREATE TABLE IF NOT EXISTS buildings (
    building_id INT UNSIGNED AUTO_INCREMENT,
    building_code VARCHAR(20) NOT NULL,
    building_name VARCHAR(100) NOT NULL,
    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (building_id),
    CONSTRAINT uq_buildings_code UNIQUE (building_code)
) ENGINE=InnoDB;

-- 4. ROOMS

CREATE TABLE IF NOT EXISTS rooms (
    room_id INT UNSIGNED AUTO_INCREMENT,
    building_id INT UNSIGNED NOT NULL,
    department_id INT UNSIGNED NULL,
    room_number VARCHAR(20) NOT NULL,
    floor_number INT NULL,
    room_type VARCHAR(40) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (room_id),
    CONSTRAINT uq_rooms_building_number
        UNIQUE (building_id, room_number),

    CONSTRAINT fk_rooms_building
        FOREIGN KEY (building_id)
        REFERENCES buildings(building_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rooms_department
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5. USERS

CREATE TABLE IF NOT EXISTS users (
    user_id INT UNSIGNED AUTO_INCREMENT,
    employee_code VARCHAR(30) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT UNSIGNED NOT NULL,
    department_id INT UNSIGNED NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
    last_login DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    CONSTRAINT uq_users_employee UNIQUE (employee_code),
    CONSTRAINT uq_users_email UNIQUE (email),

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id)
        REFERENCES roles(role_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_users_department
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 6. TECHNICIAN PROFILES

CREATE TABLE IF NOT EXISTS technician_profiles (
    profile_id INT UNSIGNED AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    specialization VARCHAR(100) NULL,
    max_open_requests INT NOT NULL DEFAULT 5,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,

    PRIMARY KEY (profile_id),
    CONSTRAINT uq_technician_user UNIQUE (user_id),
    CONSTRAINT ck_technician_workload CHECK (
        max_open_requests > 0
    ),

    CONSTRAINT fk_technician_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================
-- SECTION 2: ASSET MANAGEMENT
-- =====================================================

-- 7. ASSET CATEGORIES

CREATE TABLE IF NOT EXISTS asset_categories (
    category_id INT UNSIGNED AUTO_INCREMENT,
    category_code VARCHAR(20) NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    default_useful_life_years INT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (category_id),
    CONSTRAINT uq_categories_code UNIQUE (category_code),
    CONSTRAINT ck_categories_life CHECK (
        default_useful_life_years IS NULL
        OR default_useful_life_years > 0
    )
) ENGINE=InnoDB;

-- 8. VENDORS

CREATE TABLE IF NOT EXISTS vendors (
    vendor_id INT UNSIGNED AUTO_INCREMENT,
    vendor_name VARCHAR(150) NOT NULL,
    contact_number VARCHAR(20) NULL,
    email VARCHAR(150) NULL,
    vendor_type VARCHAR(30) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (vendor_id),
    CONSTRAINT ck_vendor_type CHECK (
        vendor_type IN (
            'Supplier',
            'Service Provider',
            'Both'
        )
    )
) ENGINE=InnoDB;

-- 9. ASSET STATUSES

CREATE TABLE IF NOT EXISTS asset_statuses (
    asset_status_id INT UNSIGNED AUTO_INCREMENT,
    status_name VARCHAR(30) NOT NULL,

    PRIMARY KEY (asset_status_id),
    CONSTRAINT uq_asset_status_name UNIQUE (status_name),
    CONSTRAINT ck_asset_status_name CHECK (
        status_name IN (
            'In Stock',
            'Active',
            'Under Repair',
            'Retired'
        )
    )
) ENGINE=InnoDB;

-- 10. ASSETS

CREATE TABLE IF NOT EXISTS assets (
    asset_id INT UNSIGNED AUTO_INCREMENT,
    asset_tag VARCHAR(50) NOT NULL,
    serial_number VARCHAR(100) NULL,
    asset_name VARCHAR(150) NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    department_id INT UNSIGNED NOT NULL,
    room_id INT UNSIGNED NULL,
    vendor_id INT UNSIGNED NULL,
    asset_status_id INT UNSIGNED NOT NULL,
    parent_asset_id INT UNSIGNED NULL,
    brand VARCHAR(100) NULL,
    model VARCHAR(100) NULL,
    purchase_date DATE NULL,
    purchase_cost DECIMAL(12,2) NOT NULL,
    useful_life_years INT NULL,
    salvage_value DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    retirement_date DATE NULL,
    retirement_reason TEXT NULL,
    needs_retirement_review BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (asset_id),
    CONSTRAINT uq_assets_tag UNIQUE (asset_tag),
    CONSTRAINT uq_assets_serial UNIQUE (serial_number),

    CONSTRAINT ck_assets_purchase CHECK (
        purchase_cost >= 0
    ),
    CONSTRAINT ck_assets_salvage CHECK (
        salvage_value >= 0
    ),
    CONSTRAINT ck_assets_life CHECK (
        useful_life_years IS NULL
        OR useful_life_years > 0
    ),
   

    CONSTRAINT fk_assets_category
        FOREIGN KEY (category_id)
        REFERENCES asset_categories(category_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assets_department
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assets_room
        FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assets_vendor
        FOREIGN KEY (vendor_id)
        REFERENCES vendors(vendor_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assets_status
        FOREIGN KEY (asset_status_id)
        REFERENCES asset_statuses(asset_status_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assets_parent
        FOREIGN KEY (parent_asset_id)
        REFERENCES assets(asset_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 11. WARRANTIES

CREATE TABLE IF NOT EXISTS warranties (
    warranty_id INT UNSIGNED AUTO_INCREMENT,
    asset_id INT UNSIGNED NOT NULL,
    vendor_id INT UNSIGNED NULL,
    coverage_type VARCHAR(30) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    terms TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (warranty_id),

    CONSTRAINT ck_warranty_dates CHECK (
        end_date >= start_date
    ),
    CONSTRAINT ck_warranty_type CHECK (
        coverage_type IN ('Standard', 'Extended', 'AMC')
    ),

    CONSTRAINT fk_warranty_asset
        FOREIGN KEY (asset_id)
        REFERENCES assets(asset_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_warranty_vendor
        FOREIGN KEY (vendor_id)
        REFERENCES vendors(vendor_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 12. ASSET ASSIGNMENTS

CREATE TABLE IF NOT EXISTS asset_assignments (
    assignment_id INT UNSIGNED AUTO_INCREMENT,
    asset_id INT UNSIGNED NOT NULL,
    assigned_user_id INT UNSIGNED NULL,
    assigned_department_id INT UNSIGNED NULL,
    assigned_room_id INT UNSIGNED NULL,
    assigned_by_user_id INT UNSIGNED NOT NULL,
    assigned_from DATE NOT NULL,
    assigned_to DATE NULL,
    remarks TEXT NULL,

    active_asset_id INT UNSIGNED
        GENERATED ALWAYS AS (
            CASE
                WHEN assigned_to IS NULL THEN asset_id
                ELSE NULL
            END
        ) STORED,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (assignment_id),

    CONSTRAINT uq_current_asset_assignment
        UNIQUE (active_asset_id),

    CONSTRAINT ck_assignment_dates CHECK (
        assigned_to IS NULL
        OR assigned_to >= assigned_from
    ),

    CONSTRAINT ck_assignment_assignee CHECK (
        assigned_user_id IS NOT NULL
        OR assigned_department_id IS NOT NULL
    ),

    CONSTRAINT fk_assignment_asset
        FOREIGN KEY (asset_id)
        REFERENCES assets(asset_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assignment_user
        FOREIGN KEY (assigned_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assignment_department
        FOREIGN KEY (assigned_department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assignment_room
        FOREIGN KEY (assigned_room_id)
        REFERENCES rooms(room_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assignment_created_by
        FOREIGN KEY (assigned_by_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 13. ASSET TRANSFERS

CREATE TABLE IF NOT EXISTS asset_transfers (
    transfer_id INT UNSIGNED AUTO_INCREMENT,
    asset_id INT UNSIGNED NOT NULL,
    from_room_id INT UNSIGNED NULL,
    to_room_id INT UNSIGNED NULL,
    from_department_id INT UNSIGNED NOT NULL,
    to_department_id INT UNSIGNED NOT NULL,
    transferred_by_user_id INT UNSIGNED NOT NULL,
    transferred_at DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,
    reason TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (transfer_id),

    CONSTRAINT fk_transfer_asset
        FOREIGN KEY (asset_id)
        REFERENCES assets(asset_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_from_room
        FOREIGN KEY (from_room_id)
        REFERENCES rooms(room_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_to_room
        FOREIGN KEY (to_room_id)
        REFERENCES rooms(room_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_from_department
        FOREIGN KEY (from_department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_to_department
        FOREIGN KEY (to_department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transfer_by
        FOREIGN KEY (transferred_by_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 14. ASSET TAG COUNTERS

CREATE TABLE IF NOT EXISTS asset_tag_counters (
    counter_id INT UNSIGNED AUTO_INCREMENT,
    department_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    last_number INT UNSIGNED NOT NULL DEFAULT 0,

    PRIMARY KEY (counter_id),
    CONSTRAINT uq_counter_department_category
        UNIQUE (department_id, category_id),

    CONSTRAINT fk_counter_department
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_counter_category
        FOREIGN KEY (category_id)
        REFERENCES asset_categories(category_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================
-- SECTION 3: SERVICE REQUESTS AND MAINTENANCE
-- =====================================================

-- 15. REQUEST STATUSES

CREATE TABLE IF NOT EXISTS request_statuses (
    request_status_id INT UNSIGNED AUTO_INCREMENT,
    status_name VARCHAR(30) NOT NULL,

    PRIMARY KEY (request_status_id),
    CONSTRAINT uq_request_status_name UNIQUE (status_name),
    CONSTRAINT ck_request_status_name CHECK (
        status_name IN (
            'Open',
            'Assigned',
            'In Progress',
            'On Hold',
            'Closed',
            'Cancelled'
        )
    )
) ENGINE=InnoDB;

-- 16. PRIORITIES

CREATE TABLE IF NOT EXISTS priorities (
    priority_id INT UNSIGNED AUTO_INCREMENT,
    priority_name VARCHAR(30) NOT NULL,
    target_hours INT UNSIGNED NOT NULL,

    PRIMARY KEY (priority_id),
    CONSTRAINT uq_priority_name UNIQUE (priority_name),
    CONSTRAINT ck_priority_name CHECK (
        priority_name IN (
            'Critical', 'High', 'Medium', 'Low'
        )
    ),
    CONSTRAINT ck_priority_hours CHECK (
        target_hours > 0
    )
) ENGINE=InnoDB;

-- 17. SERVICE REQUESTS

CREATE TABLE IF NOT EXISTS service_requests (
    request_id INT UNSIGNED AUTO_INCREMENT,
    request_number VARCHAR(50) NOT NULL,
    asset_id INT UNSIGNED NOT NULL,
    raised_by_user_id INT UNSIGNED NOT NULL,
    assigned_technician_id INT UNSIGNED NULL,
    request_status_id INT UNSIGNED NOT NULL,
    priority_id INT UNSIGNED NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    raised_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_at DATETIME NULL,
    started_at DATETIME NULL,
    due_at DATETIME NOT NULL,
    closed_at DATETIME NULL,
    resolution_summary TEXT NULL,
    cancellation_reason TEXT NULL,
    reopen_count INT UNSIGNED NOT NULL DEFAULT 0,
    feedback_rating INT NULL,
    feedback_comment TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (request_id),

    CONSTRAINT uq_request_number
        UNIQUE (request_number),

    CONSTRAINT ck_request_feedback CHECK (
        feedback_rating IS NULL
        OR feedback_rating BETWEEN 1 AND 5
    ),

    CONSTRAINT ck_request_closed_date CHECK (
        closed_at IS NULL OR closed_at >= raised_at
    ),

    CONSTRAINT ck_request_due_date CHECK (
        due_at >= raised_at
    ),

    CONSTRAINT fk_request_asset
        FOREIGN KEY (asset_id)
        REFERENCES assets(asset_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_request_raised_by
        FOREIGN KEY (raised_by_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_request_technician
        FOREIGN KEY (assigned_technician_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_request_status
        FOREIGN KEY (request_status_id)
        REFERENCES request_statuses(request_status_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_request_priority
        FOREIGN KEY (priority_id)
        REFERENCES priorities(priority_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 18. REQUEST UPDATES

CREATE TABLE IF NOT EXISTS request_updates (
    update_id INT UNSIGNED AUTO_INCREMENT,
    request_id INT UNSIGNED NOT NULL,
    author_user_id INT UNSIGNED NOT NULL,
    update_type VARCHAR(30) NOT NULL,
    old_value VARCHAR(100) NULL,
    new_value VARCHAR(100) NULL,
    comment TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (update_id),

    CONSTRAINT fk_update_request
        FOREIGN KEY (request_id)
        REFERENCES service_requests(request_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_update_author
        FOREIGN KEY (author_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 19. MAINTENANCE RECORDS
-- asset_id intentionally omitted for 3NF.
-- The asset is retrieved through service_requests.

CREATE TABLE IF NOT EXISTS maintenance_records (
    maintenance_id INT UNSIGNED AUTO_INCREMENT,
    request_id INT UNSIGNED NOT NULL,
    technician_id INT UNSIGNED NOT NULL,
    vendor_id INT UNSIGNED NULL,
    maintenance_type VARCHAR(30) NOT NULL,
    diagnosis TEXT NOT NULL,
    work_performed TEXT NOT NULL,
    start_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    labour_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    outcome VARCHAR(50) NOT NULL,
    warranty_covered BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (maintenance_id),

    CONSTRAINT ck_maintenance_dates CHECK (
        end_date >= start_date
    ),

    CONSTRAINT ck_maintenance_cost CHECK (
        labour_cost >= 0
    ),

    CONSTRAINT ck_maintenance_type CHECK (
        maintenance_type IN (
            'Corrective', 'Preventive'
        )
    ),

    CONSTRAINT fk_maintenance_request
        FOREIGN KEY (request_id)
        REFERENCES service_requests(request_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_maintenance_technician
        FOREIGN KEY (technician_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_maintenance_vendor
        FOREIGN KEY (vendor_id)
        REFERENCES vendors(vendor_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 20. MAINTENANCE PARTS

CREATE TABLE IF NOT EXISTS maintenance_parts (
    part_id INT UNSIGNED AUTO_INCREMENT,
    maintenance_id INT UNSIGNED NOT NULL,
    part_name VARCHAR(150) NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    unit_cost DECIMAL(12,2) NOT NULL,

    PRIMARY KEY (part_id),

    CONSTRAINT ck_part_quantity CHECK (
        quantity >= 1
    ),

    CONSTRAINT ck_part_cost CHECK (
        unit_cost >= 0
    ),

    CONSTRAINT fk_part_maintenance
        FOREIGN KEY (maintenance_id)
        REFERENCES maintenance_records(maintenance_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================
-- SECTION 4: SYSTEM SUPPORT
-- =====================================================

-- 21. NOTIFICATIONS

CREATE TABLE IF NOT EXISTS notifications (
    notification_id INT UNSIGNED AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    request_id INT UNSIGNED NULL,
    notification_type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (notification_id),

    CONSTRAINT fk_notification_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_notification_request
        FOREIGN KEY (request_id)
        REFERENCES service_requests(request_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 22. AUDIT LOG

CREATE TABLE IF NOT EXISTS audit_log (
    audit_id INT UNSIGNED AUTO_INCREMENT,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(64) NOT NULL,
    action VARCHAR(20) NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    changed_by_user_id INT UNSIGNED NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (audit_id),

    CONSTRAINT ck_audit_action CHECK (
        action IN ('INSERT', 'UPDATE', 'DELETE')
    ),

    CONSTRAINT fk_audit_user
        FOREIGN KEY (changed_by_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================
-- VERIFY DATABASE CREATION
-- =====================================================

SELECT DATABASE() AS selected_database;

SHOW TABLES;

SELECT COUNT(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'casms'
AND table_type = 'BASE TABLE';

-- Expected total: 22
-- No sample records are inserted in this file.
-- Seed data will be added in 02_seed.sql.
-- Views, routines and triggers will be added later.
-- =====================================================
-- END OF 01_schema.sql
-- =====================================================
