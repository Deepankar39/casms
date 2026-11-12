
-- ====================================================
-- CASMS - BASIC SQL QUERIES AND DATA CLEANING
-- File: database/03_basic_queries.sql
-- Course: ADBMS Practical
-- Phase 2: Data Preparation and Basic Queries
-- MySQL: 8.0.46
-- ====================================================

USE casms;

-- ====================================================
-- PART 1: VERIFY EXISTING DATABASE DATA
-- ====================================================

SELECT 'Users' AS entity, COUNT(*) AS total
FROM users

UNION ALL

SELECT 'Departments', COUNT(*)
FROM departments

UNION ALL

SELECT 'Assets', COUNT(*)
FROM assets

UNION ALL

SELECT 'Service Requests', COUNT(*)
FROM service_requests

UNION ALL

SELECT 'Maintenance Records', COUNT(*)
FROM maintenance_records

UNION ALL

SELECT 'Maintenance Parts', COUNT(*)
FROM maintenance_parts;

-- ====================================================
-- PART 2: BASIC SELECT QUERY
-- ====================================================

-- Display registered college assets.

SELECT
    asset_id,
    asset_tag,
    asset_name,
    purchase_cost
FROM assets
ORDER BY asset_id
LIMIT 10;

-- ====================================================
-- PART 3: WHERE CLAUSE
-- ====================================================

-- Show assets costing more than 20000.

SELECT
    asset_tag,
    asset_name,
    purchase_cost
FROM assets
WHERE purchase_cost > 20000
ORDER BY purchase_cost DESC
LIMIT 20;

-- ====================================================
-- PART 4: ORDER BY
-- ====================================================

-- List assets from most expensive to least expensive.

SELECT
    asset_tag,
    asset_name,
    purchase_cost
FROM assets
ORDER BY purchase_cost DESC
LIMIT 10;

-- ====================================================
-- PART 5: LIKE OPERATOR
-- ====================================================

-- Find assets with Computer in the name.

SELECT
    asset_tag,
    asset_name
FROM assets
WHERE asset_name LIKE '%Computer%'
ORDER BY asset_name
LIMIT 20;

-- ====================================================
-- PART 6: IN OPERATOR
-- ====================================================

-- Find active or under-repair assets.

SELECT
    a.asset_tag,
    a.asset_name,
    s.status_name
FROM assets a
JOIN asset_statuses s
    ON a.asset_status_id = s.asset_status_id
WHERE s.status_name IN (
    'Active',
    'Under Repair'
)
ORDER BY a.asset_id
LIMIT 20;

-- ====================================================
-- PART 7: BETWEEN OPERATOR
-- ====================================================

-- Find assets within a purchase-cost range.

SELECT
    asset_tag,
    asset_name,
    purchase_cost
FROM assets
WHERE purchase_cost BETWEEN 10000 AND 30000
ORDER BY purchase_cost
LIMIT 20;

-- ====================================================
-- PART 8: NULL HANDLING
-- ====================================================

-- Find assets that do not have an assigned room.

SELECT
    asset_tag,
    asset_name,
    room_id
FROM assets
WHERE room_id IS NULL
ORDER BY asset_id;

-- Replace NULL display values with readable text.

SELECT
    a.asset_tag,
    a.asset_name,
    COALESCE(r.room_number, 'Not Assigned')
        AS room_location
FROM assets a
LEFT JOIN rooms r
    ON a.room_id = r.room_id
ORDER BY a.asset_id
LIMIT 20;

-- ====================================================
-- PART 9: AGGREGATE FUNCTIONS
-- ====================================================

-- COUNT, SUM, AVG, MIN and MAX.

SELECT
    COUNT(*) AS total_assets,
    SUM(purchase_cost) AS total_purchase_value,
    ROUND(AVG(purchase_cost), 2)
        AS average_purchase_cost,
    MIN(purchase_cost) AS minimum_cost,
    MAX(purchase_cost) AS maximum_cost
FROM assets;

-- ====================================================
-- PART 10: GROUP BY
-- ====================================================

-- Number of assets belonging to each department.

SELECT
    d.department_code,
    d.department_name,
    COUNT(a.asset_id) AS total_assets
FROM departments d
LEFT JOIN assets a
    ON d.department_id = a.department_id
GROUP BY
    d.department_id,
    d.department_code,
    d.department_name
ORDER BY total_assets DESC;

-- ====================================================
-- PART 11: HAVING CLAUSE
-- ====================================================

-- Departments containing at least 20 assets.

SELECT
    d.department_name,
    COUNT(a.asset_id) AS total_assets
FROM departments d
JOIN assets a
    ON d.department_id = a.department_id
GROUP BY
    d.department_id,
    d.department_name
HAVING COUNT(a.asset_id) >= 20
ORDER BY total_assets DESC;

-- ====================================================
-- PART 12: SERVICE REQUEST SUMMARY
-- ====================================================

-- Count requests by their current status.

SELECT
    s.status_name,
    COUNT(r.request_id) AS total_requests
FROM request_statuses s
LEFT JOIN service_requests r
    ON s.request_status_id = r.request_status_id
GROUP BY
    s.request_status_id,
    s.status_name
ORDER BY total_requests DESC;

-- ====================================================
-- PART 13: PRIORITY SUMMARY
-- ====================================================

SELECT
    p.priority_name,
    p.target_hours,
    COUNT(r.request_id) AS request_count
FROM priorities p
LEFT JOIN service_requests r
    ON p.priority_id = r.priority_id
GROUP BY
    p.priority_id,
    p.priority_name,
    p.target_hours
ORDER BY p.target_hours;

-- ====================================================
-- PART 14: MAINTENANCE COST SUMMARY
-- ====================================================

-- Labour cost, parts cost and total repair cost.

SELECT
    COUNT(*) AS maintenance_jobs,
    ROUND(SUM(m.labour_cost), 2)
        AS total_labour_cost,
    ROUND(SUM(COALESCE(p.parts_cost, 0)), 2)
        AS total_parts_cost,
    ROUND(
        SUM(m.labour_cost +
            COALESCE(p.parts_cost, 0)),
        2
    ) AS total_maintenance_cost
FROM maintenance_records m
LEFT JOIN (
    SELECT
        maintenance_id,
        SUM(quantity * unit_cost) AS parts_cost
    FROM maintenance_parts
    GROUP BY maintenance_id
) p
    ON m.maintenance_id = p.maintenance_id;

-- ====================================================
-- PART 15: CREATE DIRTY STAGING DATA
-- ====================================================

-- Temporary table for data-cleaning practice.
-- No permanent asset records are changed.

DROP TEMPORARY TABLE IF EXISTS
    cleaned_asset_import;

DROP TEMPORARY TABLE IF EXISTS
    staging_asset_import;

CREATE TEMPORARY TABLE staging_asset_import (
    import_id INT UNSIGNED AUTO_INCREMENT
        PRIMARY KEY,
    asset_tag VARCHAR(50) NULL,
    asset_name VARCHAR(150) NULL,
    department_code VARCHAR(20) NULL,
    room_number VARCHAR(20) NULL,
    purchase_cost DECIMAL(12,2) NULL
) ENGINE=InnoDB;

-- Generate 50 sample import rows.
-- Include duplicates, blank values,
-- inconsistent text and invalid data.

INSERT INTO staging_asset_import
(
    asset_tag,
    asset_name,
    department_code,
    room_number,
    purchase_cost
)
SELECT
    CASE
        WHEN n = 45 THEN 'STG-0044'
        WHEN n = 46 THEN ' stg-0044 '
        WHEN n = 47 THEN NULL
        ELSE CONCAT('STG-', LPAD(n, 4, '0'))
    END,

    CASE
        WHEN n = 3 THEN '  Lab Monitor  '
        WHEN n = 4 THEN NULL
        WHEN n = 49 THEN '   '
        ELSE CONCAT('Training Asset ', n)
    END,

    CASE
        WHEN n = 48 THEN 'UNKNOWN'
        WHEN MOD(n, 6) = 0 THEN ' mca '
        WHEN MOD(n, 6) = 1 THEN 'cse'
        ELSE 'MCA'
    END,

    CASE
        WHEN MOD(n, 5) = 0 THEN ' '
        ELSE 'R001'
    END,

    CASE
        WHEN n = 7 THEN NULL
        WHEN n = 50 THEN -100.00
        ELSE 5000.00 + n * 100.00
    END

FROM (
    SELECT 1 + ones.d + 10 * tens.d AS n
    FROM (
        SELECT 0 AS d UNION ALL SELECT 1
        UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5
        UNION ALL SELECT 6 UNION ALL SELECT 7
        UNION ALL SELECT 8 UNION ALL SELECT 9
    ) ones
    CROSS JOIN (
        SELECT 0 AS d UNION ALL SELECT 1
        UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4
    ) tens
) numbers
ORDER BY n;

-- ====================================================
-- PART 16: INSPECT DIRTY DATA
-- ====================================================

SELECT *
FROM staging_asset_import
ORDER BY import_id;

-- Count staging rows.

SELECT
    COUNT(*) AS staging_rows
FROM staging_asset_import;

-- Expected: 50

-- ====================================================
-- PART 17: DEMONSTRATE DATA CLEANING
-- ====================================================

-- TRIM removes unwanted spaces.
-- UPPER standardizes code capitalization.
-- NULLIF converts empty strings to NULL.

SELECT
    import_id,
    NULLIF(UPPER(TRIM(asset_tag)), '')
        AS cleaned_asset_tag,
    NULLIF(TRIM(asset_name), '')
        AS cleaned_asset_name,
    NULLIF(UPPER(TRIM(department_code)), '')
        AS cleaned_department_code,
    NULLIF(UPPER(TRIM(room_number)), '')
        AS cleaned_room_number,
    purchase_cost
FROM staging_asset_import
ORDER BY import_id;

-- ====================================================
-- PART 18: IDENTIFY INVALID AND DUPLICATE ROWS
-- ====================================================

-- ROW_NUMBER helps detect duplicate asset tags.
-- Missing values and negative costs are rejected.

SELECT
    result.validation_status,
    COUNT(*) AS total_rows
FROM (
    SELECT
        CASE
            WHEN x.clean_tag IS NULL
                THEN 'Missing Asset Tag'
            WHEN x.clean_name IS NULL
                THEN 'Missing Asset Name'
            WHEN x.clean_department IS NULL
                THEN 'Missing Department'
            WHEN d.department_id IS NULL
                THEN 'Invalid Department'
            WHEN x.purchase_cost IS NULL
                THEN 'Missing Purchase Cost'
            WHEN x.purchase_cost < 0
                THEN 'Negative Purchase Cost'
            WHEN x.tag_rank > 1
                THEN 'Duplicate Asset Tag'
            ELSE 'Valid'
        END AS validation_status
    FROM (
        SELECT
            import_id,
            NULLIF(UPPER(TRIM(asset_tag)), '')
                AS clean_tag,
            NULLIF(TRIM(asset_name), '')
                AS clean_name,
            NULLIF(UPPER(TRIM(department_code)), '')
                AS clean_department,
            purchase_cost,
            ROW_NUMBER() OVER (
                PARTITION BY UPPER(TRIM(asset_tag))
                ORDER BY import_id
            ) AS tag_rank
        FROM staging_asset_import
    ) x
    LEFT JOIN departments d
        ON d.department_code =
            x.clean_department
) result
GROUP BY result.validation_status
ORDER BY total_rows DESC;

-- ====================================================
-- PART 19: PREPARE VALID CLEANED RECORDS
-- ====================================================

CREATE TEMPORARY TABLE cleaned_asset_import (
    import_id INT UNSIGNED PRIMARY KEY,
    asset_tag VARCHAR(50) NOT NULL UNIQUE,
    asset_name VARCHAR(150) NOT NULL,
    department_id INT UNSIGNED NOT NULL,
    room_number VARCHAR(20) NULL,
    purchase_cost DECIMAL(12,2) NOT NULL,
    CONSTRAINT ck_clean_asset_purchase
        CHECK (purchase_cost >= 0)
) ENGINE=InnoDB;

INSERT INTO cleaned_asset_import (
    import_id,
    asset_tag,
    asset_name,
    department_id,
    room_number,
    purchase_cost
)
SELECT
    x.import_id,
    x.clean_tag,
    x.clean_name,
    d.department_id,
    x.clean_room,
    x.purchase_cost
FROM (
    SELECT
        import_id,
        NULLIF(UPPER(TRIM(asset_tag)), '')
            AS clean_tag,
        NULLIF(TRIM(asset_name), '')
            AS clean_name,
        NULLIF(UPPER(TRIM(department_code)), '')
            AS clean_department,
        NULLIF(UPPER(TRIM(room_number)), '')
            AS clean_room,
        purchase_cost,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(asset_tag))
            ORDER BY import_id
        ) AS tag_rank
    FROM staging_asset_import
) x
JOIN departments d
    ON d.department_code =
        x.clean_department
WHERE x.clean_tag IS NOT NULL
AND x.clean_name IS NOT NULL
AND x.purchase_cost IS NOT NULL
AND x.purchase_cost >= 0
AND x.tag_rank = 1;

-- ============================================
-- PART 20: VERIFY DATA CLEANING
-- Fixed: MySQL Error 1137
-- ============================================

SELECT
    s.original_rows,
    c.cleaned_rows,
    s.original_rows - c.cleaned_rows
        AS rejected_rows
FROM
    (
        SELECT COUNT(*) AS original_rows
        FROM staging_asset_import
    ) AS s
CROSS JOIN
    (
        SELECT COUNT(*) AS cleaned_rows
        FROM cleaned_asset_import
    ) AS c;


-- Expected:
-- original_rows = 50
-- cleaned_rows  = 42
-- rejected_rows = 8

-- View cleaned records.

SELECT
    c.import_id,
    c.asset_tag,
    c.asset_name,
    d.department_code,
    c.room_number,
    c.purchase_cost
FROM cleaned_asset_import c
JOIN departments d
    ON c.department_id = d.department_id
ORDER BY c.import_id
LIMIT 20;

-- ====================================================
-- PART 21: FINAL DATABASE VALIDATION
-- ====================================================

-- Verify database tables.

SELECT
    COUNT(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'casms'
AND table_type = 'BASE TABLE';

-- Expected: 22

-- Final database record summary.

SELECT
    (SELECT COUNT(*) FROM users)
        AS total_users,

    (SELECT COUNT(*) FROM assets)
        AS total_assets,

    (SELECT COUNT(*) FROM service_requests)
        AS total_requests,

    (SELECT COUNT(*) FROM maintenance_records)
        AS total_maintenance,

    (SELECT COUNT(*) FROM maintenance_parts)
        AS total_parts;

-- ====================================================
-- END OF 03_basic_queries.sql
-- ====================================================

