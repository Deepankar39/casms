
-- =====================================================
-- CASMS - ADVANCED SQL ANALYTICS
-- File: database/04_analytics.sql
-- Phase 3: Data Querying and Analytical Operations
-- Compatible with MySQL 8.0.46
-- =====================================================

USE casms;

-- All queries are read-only.
-- No permanent data is modified.

-- =====================================================
-- PART 1: INNER JOIN
-- R1 - ASSET REGISTER REPORT
-- =====================================================

-- Combine assets, departments, categories and statuses.

SELECT
    d.department_code,
    c.category_name,
    s.status_name,
    COUNT(a.asset_id) AS total_assets,
    ROUND(SUM(a.purchase_cost), 2)
        AS total_asset_value
FROM assets a
INNER JOIN departments d
    ON a.department_id = d.department_id
INNER JOIN asset_categories c
    ON a.category_id = c.category_id
INNER JOIN asset_statuses s
    ON a.asset_status_id = s.asset_status_id
GROUP BY
    d.department_code,
    c.category_name,
    s.status_name
ORDER BY
    d.department_code,
    total_assets DESC
LIMIT 30;

-- =====================================================
-- PART 2: LEFT JOIN
-- SHOW ASSETS WITH OR WITHOUT SERVICE REQUESTS
-- =====================================================

SELECT
    a.asset_tag,
    a.asset_name,
    COUNT(r.request_id) AS request_count
FROM assets a
LEFT JOIN service_requests r
    ON a.asset_id = r.asset_id
GROUP BY
    a.asset_id,
    a.asset_tag,
    a.asset_name
ORDER BY request_count DESC
LIMIT 20;

-- =====================================================
-- PART 3: SELF JOIN
-- PARENT AND CHILD ASSETS
-- =====================================================

SELECT
    parent.asset_tag AS parent_asset,
    child.asset_tag AS child_asset,
    child.asset_name AS component_name
FROM assets child
INNER JOIN assets parent
    ON child.parent_asset_id = parent.asset_id
ORDER BY parent.asset_tag
LIMIT 20;

-- =====================================================
-- PART 4: PENDING SERVICE REQUESTS
-- R2 - PENDING REQUESTS WITH AGE IN HOURS
-- =====================================================

SELECT
    r.request_number,
    r.title,
    a.asset_tag,
    s.status_name,
    p.priority_name,
    r.raised_at,
    r.due_at,
    TIMESTAMPDIFF(
        HOUR, r.raised_at, NOW()
    ) AS age_in_hours
FROM service_requests r
JOIN assets a
    ON r.asset_id = a.asset_id
JOIN request_statuses s
    ON r.request_status_id = s.request_status_id
JOIN priorities p
    ON r.priority_id = p.priority_id
WHERE s.status_name NOT IN (
    'Closed', 'Cancelled'
)
ORDER BY r.due_at
LIMIT 20;

-- =====================================================
-- PART 5: OVERDUE SERVICE REQUESTS
-- R3 - OVERDUE REPORT
-- =====================================================

SELECT
    r.request_number,
    a.asset_tag,
    p.priority_name,
    s.status_name,
    r.due_at,
    TIMESTAMPDIFF(
        HOUR, r.due_at, NOW()
    ) AS overdue_hours
FROM service_requests r
JOIN assets a
    ON r.asset_id = a.asset_id
JOIN priorities p
    ON r.priority_id = p.priority_id
JOIN request_statuses s
    ON r.request_status_id = s.request_status_id
WHERE r.due_at < NOW()
AND s.status_name NOT IN (
    'Closed', 'Cancelled'
)
ORDER BY overdue_hours DESC
LIMIT 20;

-- =====================================================
-- PART 6: GROUP BY WITH ROLLUP
-- R4 - MONTHLY DEPARTMENT MAINTENANCE COST
-- =====================================================

WITH parts_total AS (
    SELECT
        maintenance_id,
        SUM(quantity * unit_cost) AS parts_cost
    FROM maintenance_parts
    GROUP BY maintenance_id
),
cost_data AS (
    SELECT
        d.department_code,
        DATE_FORMAT(m.end_date, '%Y-%m')
            AS maintenance_month,
        m.labour_cost +
            COALESCE(p.parts_cost, 0)
            AS total_cost
    FROM maintenance_records m
    JOIN service_requests r
        ON m.request_id = r.request_id
    JOIN assets a
        ON r.asset_id = a.asset_id
    JOIN departments d
        ON a.department_id = d.department_id
    LEFT JOIN parts_total p
        ON m.maintenance_id = p.maintenance_id
)
SELECT
    CASE
        WHEN GROUPING(department_code) = 1
            THEN 'ALL DEPARTMENTS'
        ELSE department_code
    END AS department,
    CASE
        WHEN GROUPING(maintenance_month) = 1
            THEN 'SUBTOTAL'
        ELSE maintenance_month
    END AS month,
    ROUND(SUM(total_cost), 2)
        AS maintenance_cost
FROM cost_data
GROUP BY
    department_code,
    maintenance_month WITH ROLLUP;

-- =====================================================
-- PART 7: NESTED / SCALAR SUBQUERY
-- R5 - ASSETS WITH ABOVE-AVERAGE REPAIR COST
-- =====================================================

WITH part_costs AS (
    SELECT
        maintenance_id,
        SUM(quantity * unit_cost) AS parts_cost
    FROM maintenance_parts
    GROUP BY maintenance_id
),
asset_costs AS (
    SELECT
        r.asset_id,
        SUM(
            m.labour_cost +
            COALESCE(p.parts_cost, 0)
        ) AS total_cost
    FROM maintenance_records m
    JOIN service_requests r
        ON m.request_id = r.request_id
    LEFT JOIN part_costs p
        ON m.maintenance_id = p.maintenance_id
    GROUP BY r.asset_id
)
SELECT
    a.asset_tag,
    a.asset_name,
    ROUND(ac.total_cost, 2)
        AS maintenance_cost
FROM asset_costs ac
JOIN assets a
    ON ac.asset_id = a.asset_id
WHERE ac.total_cost > (
    SELECT AVG(total_cost)
    FROM asset_costs
)
ORDER BY ac.total_cost DESC
LIMIT 20;

-- =====================================================
-- PART 8: CORRELATED SUBQUERY AND EXISTS
-- ASSETS WHICH HAVE SERVICE HISTORY
-- =====================================================

SELECT
    a.asset_tag,
    a.asset_name,
    (
        SELECT COUNT(*)
        FROM service_requests r2
        WHERE r2.asset_id = a.asset_id
    ) AS total_requests
FROM assets a
WHERE EXISTS (
    SELECT 1
    FROM service_requests r
    WHERE r.asset_id = a.asset_id
)
ORDER BY total_requests DESC
LIMIT 20;

-- =====================================================
-- PART 9: GROUP BY AND HAVING
-- R6 - REPEAT-FAILURE ASSETS
-- =====================================================

-- Assets with at least 3 requests within 12 months.

SELECT
    a.asset_tag,
    a.asset_name,
    COUNT(r.request_id) AS failure_count
FROM assets a
JOIN service_requests r
    ON a.asset_id = r.asset_id
WHERE r.raised_at >=
    DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY
    a.asset_id,
    a.asset_tag,
    a.asset_name
HAVING COUNT(r.request_id) >= 3
ORDER BY failure_count DESC;

-- If no records meet this condition,
-- an empty result is valid.

-- =====================================================
-- PART 10: WINDOW FUNCTION - RANK
-- R7 - TECHNICIAN PERFORMANCE
-- =====================================================

WITH technician_stats AS (
    SELECT
        u.user_id,
        u.full_name,
        SUM(
            CASE
                WHEN s.status_name = 'Closed'
                    THEN 1
                ELSE 0
            END
        ) AS closed_jobs,
        SUM(
            CASE
                WHEN s.status_name IN (
                    'Assigned',
                    'In Progress',
                    'On Hold'
                )
                    THEN 1
                ELSE 0
            END
        ) AS open_jobs,
        ROUND(
            AVG(
                CASE
                    WHEN s.status_name = 'Closed'
                    THEN TIMESTAMPDIFF(
                        HOUR,
                        r.raised_at,
                        r.closed_at
                    )
                END
            ), 2
        ) AS avg_resolution_hours
    FROM users u
    JOIN roles ro
        ON u.role_id = ro.role_id
    LEFT JOIN service_requests r
        ON u.user_id = r.assigned_technician_id
    LEFT JOIN request_statuses s
        ON r.request_status_id =
            s.request_status_id
    WHERE ro.role_name = 'Technician'
    GROUP BY u.user_id, u.full_name
)
SELECT
    full_name,
    closed_jobs,
    open_jobs,
    avg_resolution_hours,
    RANK() OVER (
        ORDER BY closed_jobs DESC
    ) AS performance_rank
FROM technician_stats
ORDER BY performance_rank, full_name;

-- =====================================================
-- PART 11: WARRANTY ANALYSIS
-- R8 - EXPIRING WARRANTIES
-- =====================================================

SELECT
    a.asset_tag,
    a.asset_name,
    w.coverage_type,
    w.end_date,
    DATEDIFF(
        w.end_date, CURDATE()
    ) AS days_remaining
FROM warranties w
JOIN assets a
    ON w.asset_id = a.asset_id
WHERE DATEDIFF(
    w.end_date, CURDATE()
) BETWEEN 0 AND 90
ORDER BY w.end_date
LIMIT 30;

-- Expired warranty assets with paid repairs.

SELECT DISTINCT
    a.asset_tag,
    a.asset_name
FROM assets a
JOIN service_requests r
    ON a.asset_id = r.asset_id
JOIN maintenance_records m
    ON r.request_id = m.request_id
WHERE m.warranty_covered = FALSE
AND EXISTS (
    SELECT 1
    FROM warranties w
    WHERE w.asset_id = a.asset_id
    AND w.end_date < CURDATE()
)
AND NOT EXISTS (
    SELECT 1
    FROM warranties w2
    WHERE w2.asset_id = a.asset_id
    AND w2.end_date >= CURDATE()
)
ORDER BY a.asset_tag
LIMIT 30;

-- =====================================================
-- PART 12: UNION ALL AND HISTORY
-- R9 - ASSET SERVICE HISTORY TIMELINE
-- =====================================================

SELECT
    timeline.asset_tag,
    timeline.event_at,
    timeline.event_type,
    timeline.details
FROM (
    SELECT
        a.asset_tag,
        r.raised_at AS event_at,
        'Request Raised' AS event_type,
        r.title AS details
    FROM service_requests r
    JOIN assets a
        ON r.asset_id = a.asset_id

    UNION ALL

    SELECT
        a.asset_tag,
        u.created_at AS event_at,
        'Timeline Update' AS event_type,
        COALESCE(u.comment, u.update_type)
            AS details
    FROM request_updates u
    JOIN service_requests r
        ON u.request_id = r.request_id
    JOIN assets a
        ON r.asset_id = a.asset_id

    UNION ALL

    SELECT
        a.asset_tag,
        m.end_date AS event_at,
        'Maintenance Completed' AS event_type,
        m.diagnosis AS details
    FROM maintenance_records m
    JOIN service_requests r
        ON m.request_id = r.request_id
    JOIN assets a
        ON r.asset_id = a.asset_id
) AS timeline
ORDER BY timeline.event_at DESC
LIMIT 30;

-- =====================================================
-- PART 13: RUNNING TOTAL AND RANK
-- R10 - DEPARTMENT COST RANKING
-- =====================================================

WITH part_costs AS (
    SELECT
        maintenance_id,
        SUM(quantity * unit_cost) AS parts_cost
    FROM maintenance_parts
    GROUP BY maintenance_id
),
department_costs AS (
    SELECT
        d.department_id,
        d.department_name,
        COALESCE(
            SUM(
                m.labour_cost +
                COALESCE(p.parts_cost, 0)
            ), 0
        ) AS total_cost
    FROM departments d
    LEFT JOIN assets a
        ON d.department_id = a.department_id
    LEFT JOIN service_requests r
        ON a.asset_id = r.asset_id
    LEFT JOIN maintenance_records m
        ON r.request_id = m.request_id
    LEFT JOIN part_costs p
        ON m.maintenance_id = p.maintenance_id
    GROUP BY
        d.department_id,
        d.department_name
)
SELECT
    department_name,
    ROUND(total_cost, 2)
        AS total_maintenance_cost,
    RANK() OVER (
        ORDER BY total_cost DESC
    ) AS cost_rank,
    ROUND(
        SUM(total_cost) OVER (
            ORDER BY total_cost DESC, department_id
            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        ), 2
    ) AS running_total
FROM department_costs
ORDER BY cost_rank, department_name;

-- =====================================================
-- PART 14: ASSET DEPRECIATION
-- R11 - CURRENT ESTIMATED BOOK VALUE
-- =====================================================

-- Straight-line depreciation.
-- A stored function will be added later.

SELECT
    a.asset_tag,
    a.asset_name,
    a.purchase_cost,
    a.salvage_value,
    a.purchase_date,
    COALESCE(
        a.useful_life_years,
        c.default_useful_life_years,
        5
    ) AS useful_life_years,
    CASE
        WHEN a.purchase_date IS NULL
            THEN NULL
        ELSE ROUND(
            GREATEST(
                a.salvage_value,
                a.purchase_cost -
                (
                    a.purchase_cost -
                    a.salvage_value
                ) *
                LEAST(
                    1,
                    GREATEST(
                        0,
                        TIMESTAMPDIFF(
                            MONTH,
                            a.purchase_date,
                            CURDATE()
                        )
                    ) /
                    (
                        12.0 * COALESCE(
                            a.useful_life_years,
                            c.default_useful_life_years,
                            5
                        )
                    )
                )
            ), 2
        )
    END AS estimated_book_value
FROM assets a
JOIN asset_categories c
    ON a.category_id = c.category_id
ORDER BY a.asset_id
LIMIT 20;

-- =====================================================
-- PART 15: RECURSIVE CTE
-- R12 - ASSET COMPONENT HIERARCHY
-- =====================================================

WITH RECURSIVE asset_hierarchy AS (
    SELECT
        a.asset_id,
        a.parent_asset_id,
        a.asset_tag,
        0 AS depth,
        CAST(a.asset_tag AS CHAR(1000))
            AS asset_path
    FROM assets a
    WHERE a.parent_asset_id IS NULL
    AND a.serial_number LIKE 'CASMS-DEMO-%'

    UNION ALL

    SELECT
        child.asset_id,
        child.parent_asset_id,
        child.asset_tag,
        h.depth + 1,
        CONCAT(
            h.asset_path,
            ' > ',
            child.asset_tag
        )
    FROM assets child
    JOIN asset_hierarchy h
        ON child.parent_asset_id = h.asset_id
    WHERE h.depth < 5
)
SELECT
    asset_tag,
    depth,
    asset_path
FROM asset_hierarchy
WHERE depth > 0
ORDER BY asset_path
LIMIT 20;

-- =====================================================
-- PART 16: CONDITIONAL AGGREGATION
-- R13 - WARRANTY COVERAGE AND COST SAVINGS
-- =====================================================

WITH part_costs AS (
    SELECT
        maintenance_id,
        SUM(quantity * unit_cost) AS parts_cost
    FROM maintenance_parts
    GROUP BY maintenance_id
),
repair_costs AS (
    SELECT
        m.maintenance_id,
        m.warranty_covered,
        m.labour_cost +
            COALESCE(p.parts_cost, 0)
            AS total_cost
    FROM maintenance_records m
    LEFT JOIN part_costs p
        ON m.maintenance_id = p.maintenance_id
)
SELECT
    COUNT(*) AS total_repairs,
    ROUND(
        SUM(
            CASE
                WHEN warranty_covered = TRUE
                    THEN total_cost
                ELSE 0
            END
        ), 2
    ) AS vendor_covered_cost,
    ROUND(
        SUM(
            CASE
                WHEN warranty_covered = FALSE
                    THEN total_cost
                ELSE 0
            END
        ), 2
    ) AS college_borne_cost,
    ROUND(SUM(total_cost), 2)
        AS total_repair_cost
FROM repair_costs;

-- =====================================================
-- PART 17: AUDIT REPORT
-- R14 - AUDIT TRAIL
-- =====================================================

-- Audit triggers will be implemented later.
-- The result may currently be empty.

SELECT
    a.audit_id,
    a.table_name,
    a.record_id,
    a.action,
    u.full_name AS changed_by,
    a.changed_at,
    a.old_values,
    a.new_values
FROM audit_log a
LEFT JOIN users u
    ON a.changed_by_user_id = u.user_id
ORDER BY a.changed_at DESC
LIMIT 30;

-- =====================================================
-- PART 18: DASHBOARD SUMMARY
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM assets) AS total_assets,

    (SELECT COUNT(*)
     FROM users
     WHERE is_active = TRUE)
        AS active_users,

    (SELECT COUNT(*)
     FROM service_requests r
     JOIN request_statuses s
       ON r.request_status_id = s.request_status_id
     WHERE s.status_name NOT IN (
         'Closed', 'Cancelled'
     )) AS pending_requests,

    (SELECT COUNT(*)
     FROM service_requests r
     JOIN request_statuses s
       ON r.request_status_id = s.request_status_id
     WHERE s.status_name NOT IN (
         'Closed', 'Cancelled'
     )
     AND r.due_at < NOW())
        AS overdue_requests,

    (SELECT COUNT(*)
     FROM warranties
     WHERE end_date BETWEEN
       CURDATE()
       AND DATE_ADD(
           CURDATE(), INTERVAL 30 DAY
       )) AS expiring_warranties;

-- =====================================================
-- PART 19: FINAL ANALYTICS VALIDATION
-- =====================================================

SELECT
    'Assets' AS metric,
    COUNT(*) AS total
FROM assets

UNION ALL

SELECT
    'Service Requests',
    COUNT(*)
FROM service_requests

UNION ALL

SELECT
    'Maintenance Records',
    COUNT(*)
FROM maintenance_records

UNION ALL

SELECT
    'Maintenance Parts',
    COUNT(*)
FROM maintenance_parts;

-- R15: Preventive maintenance due list
-- is deferred (Could-have feature).
-- Its optional table has not been created.

-- =====================================================
-- END OF 04_analytics.sql
-- =====================================================
