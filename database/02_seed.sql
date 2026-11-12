
-- CASMS | database/02_seed.sql
-- Phase 2: DML and sample data
-- MySQL 8.0.46
-- Run after 01_schema.sql.
-- This script preserves existing permanent tables.

USE casms;

-- Undo any unfinished seed transaction.
ROLLBACK;

-- Temporarily disable Safe Update Mode for
-- controlled JOIN-based sample data updates.
SET @casms_prior_safe_updates :=
    @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;

-- ============================================
-- TEMPORARY NUMBER GENERATOR (1 TO 1000)
-- ============================================

DROP TEMPORARY TABLE IF EXISTS seed_numbers;

CREATE TEMPORARY TABLE seed_numbers (
    n INT UNSIGNED PRIMARY KEY
) ENGINE=MEMORY;

INSERT IGNORE INTO seed_numbers (n)
SELECT 1 + a.d + 10 * b.d + 100 * c.d
FROM (
    SELECT 0 AS d UNION ALL SELECT 1
    UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9
) AS a
CROSS JOIN (
    SELECT 0 AS d UNION ALL SELECT 1
    UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9
) AS b
CROSS JOIN (
    SELECT 0 AS d UNION ALL SELECT 1
    UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9
) AS c;

START TRANSACTION;

-- ============================================
-- 1. ROLES
-- ============================================

INSERT IGNORE INTO roles (role_name)
VALUES
('Admin'),
('Staff'),
('Technician');

-- ============================================
-- 2. DEPARTMENTS
-- ============================================

INSERT IGNORE INTO departments
(department_code, department_name)
VALUES
('MCA','Master of Computer Applications'),
('CSE','Computer Science'),
('ECE','Electronics and Communication'),
('MECH','Mechanical Engineering'),
('CIVIL','Civil Engineering'),
('MBA','Business Administration'),
('ADMIN','Administration'),
('LIB','Library');

-- ============================================
-- 3. BUILDINGS
-- ============================================

INSERT IGNORE INTO buildings
(building_code, building_name)
VALUES
('B1','Main Academic Block'),
('B2','Computer Science Block'),
('B3','Engineering Block'),
('B4','Administrative Block'),
('B5','Library and Learning Centre');

-- ============================================
-- 4. ROOMS
-- ============================================

INSERT INTO rooms
(building_id, department_id, room_number,
 floor_number, room_type)
SELECT
    b.building_id,
    d.department_id,
    CONCAT('R', LPAD(s.n,3,'0')),
    MOD(FLOOR((s.n-1)/4),3),
    CASE
        WHEN MOD(s.n,12)=0 THEN 'Server Room'
        WHEN MOD(s.n,5)=0 THEN 'Office'
        WHEN MOD(s.n,3)=0 THEN 'Laboratory'
        ELSE 'Classroom'
    END
FROM seed_numbers s
JOIN buildings b
ON b.building_code =
    CONCAT('B',1+FLOOR((s.n-1)/12))
JOIN departments d
ON d.department_code =
    ELT(1+MOD(s.n-1,8),
    'MCA','CSE','ECE','MECH',
    'CIVIL','MBA','ADMIN','LIB')
WHERE s.n BETWEEN 1 AND 60
AND NOT EXISTS (
    SELECT 1 FROM rooms r
    WHERE r.building_id=b.building_id
    AND r.room_number =
        CONCAT('R',LPAD(s.n,3,'0'))
);

-- ============================================
-- 5. ASSET CATEGORIES
-- ============================================

INSERT IGNORE INTO asset_categories
(category_code, category_name,
 default_useful_life_years)
VALUES
('COM','Desktop Computer',5),
('LAP','Laptop',4),
('MON','Monitor',5),
('PRJ','Projector',5),
('PRN','Printer',5),
('NET','Networking Device',6),
('SRV','Server',6),
('UPS','UPS System',5),
('AC','Air Conditioner',8),
('CCTV','CCTV Camera',6),
('FUR','Furniture',10),
('LAB','Laboratory Equipment',7);

-- ============================================
-- 6. VENDORS
-- ============================================

INSERT INTO vendors
(vendor_name,contact_number,email,vendor_type)
SELECT
    CONCAT('Demo Supplier ',LPAD(s.n,2,'0')),
    CONCAT('000000',LPAD(s.n,4,'0')),
    CONCAT('supplier',LPAD(s.n,2,'0'),
           '@example.test'),
    CASE
        WHEN MOD(s.n,3)=0
            THEN 'Service Provider'
        WHEN MOD(s.n,3)=1
            THEN 'Supplier'
        ELSE 'Both'
    END
FROM seed_numbers s
WHERE s.n<=10
AND NOT EXISTS (
    SELECT 1 FROM vendors v
    WHERE v.vendor_name =
        CONCAT('Demo Supplier ',LPAD(s.n,2,'0'))
);

-- ============================================
-- 7. STATUS AND PRIORITY LOOKUPS
-- ============================================

INSERT IGNORE INTO asset_statuses (status_name)
VALUES
('In Stock'),
('Active'),
('Under Repair'),
('Retired');

INSERT IGNORE INTO request_statuses (status_name)
VALUES
('Open'),
('Assigned'),
('In Progress'),
('On Hold'),
('Closed'),
('Cancelled');

INSERT IGNORE INTO priorities
(priority_name,target_hours)
VALUES
('Critical',4),
('High',24),
('Medium',72),
('Low',168);

-- ============================================
-- 8. USERS
-- ============================================

-- 2 Admins, 8 Technicians, 30 Staff.
-- Bcrypt password hash for local demo accounts.
-- Change temporary passwords before deployment.

INSERT INTO users
(employee_code,full_name,email,password_hash,
 role_id,department_id,must_change_password)
SELECT
    CONCAT('EMP',LPAD(s.n,3,'0')),
    CASE
        WHEN s.n<=2
            THEN CONCAT('Demo Administrator ',s.n)
        WHEN s.n<=10
            THEN CONCAT('Demo Technician ',s.n-2)
        ELSE CONCAT('Demo Staff ',s.n-10)
    END,
    CONCAT('emp',LPAD(s.n,3,'0'),
           '@casms.example.test'),
    '$2b$12$8kb.d3gSL062TyoxVeGt9uYR99gzC21K2bWv7jwbo3fLxaOrbFOFu',
    ro.role_id,
    d.department_id,
    TRUE
FROM seed_numbers s
JOIN roles ro
ON ro.role_name =
    CASE
        WHEN s.n<=2 THEN 'Admin'
        WHEN s.n<=10 THEN 'Technician'
        ELSE 'Staff'
    END
JOIN departments d
ON d.department_code =
    CASE
        WHEN s.n<=10 THEN 'ADMIN'
        ELSE ELT(1+MOD(s.n-11,8),
            'MCA','CSE','ECE','MECH',
            'CIVIL','MBA','ADMIN','LIB')
    END
WHERE s.n BETWEEN 1 AND 40
AND NOT EXISTS (
    SELECT 1 FROM users u
    WHERE u.employee_code =
        CONCAT('EMP',LPAD(s.n,3,'0'))
);

-- ============================================
-- 9. TECHNICIAN PROFILES
-- ============================================

INSERT INTO technician_profiles
(user_id,specialization,max_open_requests)
SELECT
    u.user_id,
    ELT(1+MOD(s.n,4),
        'Computers','Networking',
        'Electrical','Projectors'),
    20
FROM seed_numbers s
JOIN users u
ON u.employee_code =
    CONCAT('EMP',LPAD(s.n,3,'0'))
WHERE s.n BETWEEN 3 AND 10
AND NOT EXISTS (
    SELECT 1 FROM technician_profiles t
    WHERE t.user_id=u.user_id
);

-- ============================================
-- 10. ASSETS
-- ============================================

INSERT INTO assets
(asset_tag,serial_number,asset_name,
 category_id,department_id,room_id,
 vendor_id,asset_status_id,brand,model,
 purchase_date,purchase_cost,
 useful_life_years,salvage_value,
 retirement_date,retirement_reason)
SELECT
    CONCAT(
        d.department_code,'-',
        c.category_code,'-',
        LPAD(1+FLOOR((s.n-1)/96),4,'0')
    ),
    CONCAT('CASMS-DEMO-',LPAD(s.n,4,'0')),
    CONCAT(c.category_name,' #',LPAD(s.n,3,'0')),
    c.category_id,
    d.department_id,
    CASE
        WHEN s.n BETWEEN 241 AND 255
            THEN NULL
        ELSE r.room_id
    END,
    v.vendor_id,
    st.asset_status_id,
    ELT(1+MOD(s.n,4),
        'Dell','HP','Lenovo','Generic'),
    CONCAT('Campus Series ',1+MOD(s.n,20)),
    DATE_ADD(
        '2023-01-01',
        INTERVAL MOD(s.n*7,1100) DAY
    ),
    3000.00+s.n*145.00,
    5,
    500.00,
    CASE
        WHEN s.n>280
            THEN DATE_ADD(
                '2026-01-01',
                INTERVAL MOD(s.n,100) DAY
            )
        ELSE NULL
    END,
    CASE
        WHEN s.n>280 THEN 'End of useful life'
        ELSE NULL
    END
FROM seed_numbers s
JOIN departments d
ON d.department_code =
    ELT(1+MOD(s.n-1,8),
        'MCA','CSE','ECE','MECH',
        'CIVIL','MBA','ADMIN','LIB')
JOIN asset_categories c
ON c.category_code =
    ELT(1+MOD(FLOOR((s.n-1)/8),12),
        'COM','LAP','MON','PRJ',
        'PRN','NET','SRV','UPS',
        'AC','CCTV','FUR','LAB')
JOIN rooms r
ON r.room_number =
    CONCAT('R',LPAD(1+MOD(s.n-1,60),3,'0'))
JOIN vendors v
ON v.vendor_name =
    CONCAT('Demo Supplier ',
           LPAD(1+MOD(s.n-1,10),2,'0'))
JOIN asset_statuses st
ON st.status_name =
    CASE
        WHEN s.n<=240 THEN 'Active'
        WHEN s.n<=255 THEN 'In Stock'
        WHEN s.n<=280 THEN 'Under Repair'
        ELSE 'Retired'
    END
WHERE s.n BETWEEN 1 AND 300
AND NOT EXISTS (
    SELECT 1 FROM assets a
    WHERE a.serial_number =
        CONCAT('CASMS-DEMO-',LPAD(s.n,4,'0'))
);

-- ============================================
-- 11. PARENT-CHILD ASSETS
-- ============================================

-- Safe Update Mode is temporarily disabled.
-- Only matching demo component assets are updated.

UPDATE assets child
JOIN assets parent
ON parent.serial_number =
    CONCAT(
        'CASMS-DEMO-',
        LPAD(
            CAST(
                RIGHT(child.serial_number,4)
                AS UNSIGNED
            )-1,
            4,'0'
        )
    )
SET child.parent_asset_id = parent.asset_id
WHERE child.serial_number LIKE 'CASMS-DEMO-%'
AND MOD(
    CAST(
        RIGHT(child.serial_number,4)
        AS UNSIGNED
    ),10
)=0
AND child.parent_asset_id IS NULL;

-- ============================================
-- 12. ASSET TAG COUNTERS
-- ============================================

INSERT INTO asset_tag_counters
(department_id,category_id,last_number)
SELECT
    a.department_id,
    a.category_id,
    MAX(
        CAST(
            SUBSTRING_INDEX(a.asset_tag,'-',-1)
            AS UNSIGNED
        )
    )
FROM assets a
WHERE a.serial_number LIKE 'CASMS-DEMO-%'
AND NOT EXISTS (
    SELECT 1 FROM asset_tag_counters t
    WHERE t.department_id=a.department_id
    AND t.category_id=a.category_id
)
GROUP BY a.department_id,a.category_id;

-- ============================================
-- 13. WARRANTIES
-- ============================================

INSERT INTO warranties
(asset_id,vendor_id,coverage_type,
 start_date,end_date,terms)
SELECT
    a.asset_id,
    a.vendor_id,
    CASE
        WHEN MOD(s.n,6)=0 THEN 'AMC'
        ELSE 'Standard'
    END,
    a.purchase_date,
    DATE_ADD(
        a.purchase_date,
        INTERVAL (365+365*MOD(s.n,3)) DAY
    ),
    'Synthetic campus warranty for academic demonstration'
FROM seed_numbers s
JOIN assets a
ON a.serial_number =
    CONCAT('CASMS-DEMO-',LPAD(s.n,4,'0'))
WHERE s.n<=300
AND NOT EXISTS (
    SELECT 1 FROM warranties w
    WHERE w.asset_id=a.asset_id
    AND w.start_date=a.purchase_date
    AND w.coverage_type =
        CASE
            WHEN MOD(s.n,6)=0 THEN 'AMC'
            ELSE 'Standard'
        END
);

-- Additional extended warranties

INSERT INTO warranties
(asset_id,vendor_id,coverage_type,
 start_date,end_date,terms)
SELECT
    a.asset_id,
    a.vendor_id,
    'Extended',
    DATE_ADD(base.end_date,INTERVAL 1 DAY),
    DATE_ADD(base.end_date,INTERVAL 366 DAY),
    'Optional extended warranty sample'
FROM seed_numbers s
JOIN assets a
ON a.serial_number =
    CONCAT('CASMS-DEMO-',LPAD(s.n,4,'0'))
JOIN warranties base
ON base.asset_id=a.asset_id
AND base.start_date=a.purchase_date
WHERE s.n<=60
AND NOT EXISTS (
    SELECT 1 FROM warranties w
    WHERE w.asset_id=a.asset_id
    AND w.coverage_type='Extended'
);

-- ============================================
-- 14. ASSET ASSIGNMENTS
-- ============================================

INSERT INTO asset_assignments
(asset_id,assigned_user_id,
 assigned_department_id,assigned_room_id,
 assigned_by_user_id,assigned_from,
 assigned_to,remarks)
SELECT
    a.asset_id,
    CASE
        WHEN MOD(s.n,2)=0 THEN NULL
        ELSE recipient.user_id
    END,
    a.department_id,
    a.room_id,
    admin_user.user_id,
    CASE
        WHEN s.n<=265 THEN '2025-12-01'
        ELSE '2024-01-01'
    END,
    CASE
        WHEN s.n<=265 THEN NULL
        ELSE '2025-11-01'
    END,
    CASE
        WHEN s.n<=265 THEN 'Current assignment'
        ELSE 'Historical assignment'
    END
FROM seed_numbers s
JOIN assets a
ON a.serial_number =
    CONCAT(
        'CASMS-DEMO-',
        LPAD(
            CASE
                WHEN s.n<=240 THEN s.n
                WHEN s.n<=265 THEN s.n+15
                WHEN s.n<=365 THEN s.n-265
                WHEN s.n<=385 THEN s.n-85
                ELSE s.n-145
            END,
            4,'0'
        )
    )
JOIN users recipient
ON recipient.employee_code =
    CONCAT(
        'EMP',
        LPAD(
            11+MOD(
                CAST(
                    RIGHT(a.serial_number,4)
                    AS UNSIGNED
                )-1,8
            ),3,'0'
        )
    )
JOIN users admin_user
ON admin_user.employee_code='EMP001'
WHERE s.n<=400
AND NOT EXISTS (
    SELECT 1 FROM asset_assignments aa
    WHERE aa.asset_id=a.asset_id
    AND aa.assigned_from =
        CASE
            WHEN s.n<=265 THEN '2025-12-01'
            ELSE '2024-01-01'
        END
    AND (aa.assigned_to IS NULL)=(s.n<=265)
);

-- ============================================
-- 15. ASSET TRANSFERS
-- ============================================

INSERT INTO asset_transfers
(asset_id,from_room_id,to_room_id,
 from_department_id,to_department_id,
 transferred_by_user_id,transferred_at,reason)
SELECT
    a.asset_id,
    old_room.room_id,
    a.room_id,
    a.department_id,
    a.department_id,
    admin_user.user_id,
    DATE_ADD(
        '2025-11-01 10:00:00',
        INTERVAL s.n DAY
    ),
    'Campus room reallocation - demo'
FROM seed_numbers s
JOIN assets a
ON a.serial_number =
    CONCAT('CASMS-DEMO-',LPAD(s.n,4,'0'))
JOIN rooms old_room
ON old_room.room_number =
    CONCAT(
        'R',LPAD(1+MOD(s.n,60),3,'0')
    )
JOIN users admin_user
ON admin_user.employee_code='EMP001'
WHERE s.n<=60
AND NOT EXISTS (
    SELECT 1 FROM asset_transfers t
    WHERE t.asset_id=a.asset_id
    AND t.reason='Campus room reallocation - demo'
);

-- ============================================
-- 16. SERVICE REQUESTS
-- ============================================

INSERT INTO service_requests
(request_number,asset_id,raised_by_user_id,
 assigned_technician_id,request_status_id,
 priority_id,title,description,raised_at,
 assigned_at,started_at,due_at,closed_at,
 resolution_summary,cancellation_reason,
 reopen_count,feedback_rating,feedback_comment)
SELECT
    CONCAT('REQ-',LPAD(q.n,5,'0')),
    a.asset_id,
    reporter.user_id,
    technician.user_id,
    st.request_status_id,
    p.priority_id,
    CONCAT('Asset service request #',q.n),
    'Synthetic classroom/lab equipment fault reported by staff',
    q.raised_at,
    CASE
        WHEN q.n<=450
        OR q.n BETWEEN 481 AND 585
        THEN DATE_ADD(
            q.raised_at,INTERVAL 1 HOUR
        )
        ELSE NULL
    END,
    CASE
        WHEN q.n<=450
        OR q.n BETWEEN 511 AND 585
        THEN DATE_ADD(
            q.raised_at,INTERVAL 2 HOUR
        )
        ELSE NULL
    END,
    DATE_ADD(
        q.raised_at,
        INTERVAL p.target_hours HOUR
    ),
    CASE
        WHEN q.n<=450
        THEN DATE_ADD(
            q.raised_at,
            INTERVAL (3+MOD(q.n,90)) HOUR
        )
        ELSE NULL
    END,
    CASE
        WHEN q.n<=450
        THEN 'Fault resolved and tested'
        ELSE NULL
    END,
    CASE
        WHEN q.n>585
        THEN 'Cancelled by requester'
        ELSE NULL
    END,
    CASE
        WHEN q.n<=450 AND MOD(q.n,19)=0
        THEN 1
        ELSE 0
    END,
    CASE
        WHEN q.n<=450 AND MOD(q.n,5)=0
        THEN 3+MOD(FLOOR(q.n/5),3)
        ELSE NULL
    END,
    CASE
        WHEN q.n<=450 AND MOD(q.n,5)=0
        THEN 'Demo feedback: service completed'
        ELSE NULL
    END
FROM (
    SELECT
        s.n,
        DATE_ADD(
            '2025-02-01 09:00:00',
            INTERVAL (s.n-1) DAY
        ) AS raised_at,
        CASE
            WHEN s.n BETWEEN 511 AND 585
            THEN 256+MOD(s.n-511,25)
            ELSE 1+MOD(s.n-1,240)
        END AS asset_number,
        CASE
            WHEN s.n<=450 THEN 'Closed'
            WHEN s.n<=480 THEN 'Open'
            WHEN s.n<=510 THEN 'Assigned'
            WHEN s.n<=565 THEN 'In Progress'
            WHEN s.n<=585 THEN 'On Hold'
            ELSE 'Cancelled'
        END AS status_name
    FROM seed_numbers s
    WHERE s.n<=600
) q
JOIN assets a
ON a.serial_number =
    CONCAT(
        'CASMS-DEMO-',LPAD(q.asset_number,4,'0')
    )
JOIN users reporter
ON reporter.employee_code =
    CONCAT(
        'EMP',
        LPAD(
            11+MOD(q.asset_number-1,8)
            +8*MOD(FLOOR((q.n-1)/8),3),
            3,'0'
        )
    )
LEFT JOIN users technician
ON technician.employee_code =
    CONCAT(
        'EMP',LPAD(3+MOD(q.n-1,8),3,'0')
    )
AND (
    q.n<=450
    OR q.n BETWEEN 481 AND 585
)
JOIN request_statuses st
ON st.status_name=q.status_name
JOIN priorities p
ON p.priority_name =
    ELT(
        1+MOD(q.n-1,4),
        'Critical','High','Medium','Low'
    )
WHERE NOT EXISTS (
    SELECT 1 FROM service_requests r
    WHERE r.request_number =
        CONCAT('REQ-',LPAD(q.n,5,'0'))
);

-- ============================================
-- 17. MAINTENANCE RECORDS
-- ============================================

INSERT INTO maintenance_records
(request_id,technician_id,vendor_id,
 maintenance_type,diagnosis,work_performed,
 start_date,end_date,labour_cost,
 outcome,warranty_covered)
SELECT
    r.request_id,
    r.assigned_technician_id,
    NULL,
    'Corrective',
    'Equipment component failure',
    'Diagnosed fault, replaced component and tested equipment',
    DATE_ADD(
        r.started_at,INTERVAL 1 HOUR
    ),
    r.closed_at,
    150.00+MOD(s.n*17,1800),
    CASE
        WHEN MOD(s.n,25)=0
        THEN 'Beyond Repair'
        ELSE 'Repaired'
    END,
    MOD(s.n,3)=0
FROM seed_numbers s
JOIN service_requests r
ON r.request_number =
    CONCAT('REQ-',LPAD(s.n,5,'0'))
WHERE s.n<=450
AND NOT EXISTS (
    SELECT 1 FROM maintenance_records m
    WHERE m.request_id=r.request_id
);

-- ============================================
-- 18. RETIREMENT REVIEW FLAGS
-- ============================================

UPDATE assets a
JOIN service_requests r
ON r.asset_id=a.asset_id
JOIN maintenance_records m
ON m.request_id=r.request_id
SET a.needs_retirement_review=TRUE
WHERE m.outcome='Beyond Repair'
AND a.needs_retirement_review=FALSE;

-- ============================================
-- 19. MAINTENANCE PARTS
-- ============================================

INSERT INTO maintenance_parts
(maintenance_id,part_name,quantity,unit_cost)
SELECT
    m.maintenance_id,
    CONCAT(
        'Demo Replacement Part ',
        LPAD(s.n,4,'0')
    ),
    1+MOD(s.n,3),
    50.00+MOD(s.n*13,600)
FROM seed_numbers s
JOIN service_requests r
ON r.request_number =
    CONCAT(
        'REQ-',
        LPAD(1+MOD(s.n-1,450),5,'0')
    )
JOIN maintenance_records m
ON m.request_id=r.request_id
WHERE s.n<=700
AND NOT EXISTS (
    SELECT 1 FROM maintenance_parts mp
    WHERE mp.maintenance_id=m.maintenance_id
    AND mp.part_name =
        CONCAT(
            'Demo Replacement Part ',
            LPAD(s.n,4,'0')
        )
);

-- ============================================
-- 20. REQUEST TIMELINE
-- ============================================

INSERT INTO request_updates
(request_id,author_user_id,update_type,comment)
SELECT
    r.request_id,
    r.raised_by_user_id,
    'Created',
    'Request raised by staff'
FROM service_requests r
WHERE r.request_number LIKE 'REQ-%'
AND NOT EXISTS (
    SELECT 1 FROM request_updates u
    WHERE u.request_id=r.request_id
    AND u.update_type='Created'
);

INSERT INTO request_updates
(request_id,author_user_id,update_type,comment)
SELECT
    r.request_id,
    r.assigned_technician_id,
    'Closed',
    'Repair completed and request closed'
FROM service_requests r
JOIN request_statuses st
ON st.request_status_id=r.request_status_id
WHERE st.status_name='Closed'
AND r.request_number LIKE 'REQ-%'
AND NOT EXISTS (
    SELECT 1 FROM request_updates u
    WHERE u.request_id=r.request_id
    AND u.update_type='Closed'
);

INSERT INTO request_updates
(request_id,author_user_id,update_type,comment)
SELECT
    r.request_id,
    r.assigned_technician_id,
    'Status Change',
    'Work assigned or in progress'
FROM service_requests r
JOIN request_statuses st
ON st.request_status_id=r.request_status_id
WHERE st.status_name IN (
    'Assigned','In Progress','On Hold'
)
AND r.request_number LIKE 'REQ-%'
AND NOT EXISTS (
    SELECT 1 FROM request_updates u
    WHERE u.request_id=r.request_id
    AND u.update_type='Status Change'
);

INSERT INTO request_updates
(request_id,author_user_id,update_type,comment)
SELECT
    r.request_id,
    admin_user.user_id,
    'Reopened',
    'Previously reopened and subsequently closed'
FROM service_requests r
JOIN users admin_user
ON admin_user.employee_code='EMP001'
WHERE r.reopen_count>0
AND r.request_number LIKE 'REQ-%'
AND NOT EXISTS (
    SELECT 1 FROM request_updates u
    WHERE u.request_id=r.request_id
    AND u.update_type='Reopened'
);

-- ============================================
-- 21. NOTIFICATIONS
-- ============================================

INSERT INTO notifications
(user_id,request_id,notification_type,message)
SELECT
    r.raised_by_user_id,
    r.request_id,
    'Request Closed',
    CONCAT(
        'Your request ',
        r.request_number,
        ' was completed'
    )
FROM service_requests r
JOIN request_statuses st
ON st.request_status_id=r.request_status_id
WHERE st.status_name='Closed'
AND r.request_number LIKE 'REQ-%'
AND NOT EXISTS (
    SELECT 1 FROM notifications n
    WHERE n.request_id=r.request_id
    AND n.user_id=r.raised_by_user_id
    AND n.notification_type='Request Closed'
);

INSERT INTO notifications
(user_id,request_id,notification_type,message)
SELECT
    r.assigned_technician_id,
    r.request_id,
    'Technician Assigned',
    CONCAT(
        'You have been assigned request ',
        r.request_number
    )
FROM service_requests r
JOIN request_statuses st
ON st.request_status_id=r.request_status_id
WHERE st.status_name IN (
    'Assigned','In Progress','On Hold'
)
AND r.request_number LIKE 'REQ-%'
AND NOT EXISTS (
    SELECT 1 FROM notifications n
    WHERE n.request_id=r.request_id
    AND n.user_id=r.assigned_technician_id
    AND n.notification_type='Technician Assigned'
);

-- ============================================
-- COMMIT CHANGES
-- ============================================

COMMIT;

-- Restore the original Safe Update Mode.
SET SESSION sql_safe_updates =
    @casms_prior_safe_updates;

DROP TEMPORARY TABLE IF EXISTS seed_numbers;

-- ============================================
-- VERIFY SAMPLE DATA
-- ============================================

SELECT
    'departments' AS table_name,
    COUNT(*) AS row_count FROM departments

UNION ALL SELECT
    'buildings',COUNT(*) FROM buildings

UNION ALL SELECT
    'rooms',COUNT(*) FROM rooms

UNION ALL SELECT
    'asset_categories',COUNT(*) FROM asset_categories

UNION ALL SELECT
    'vendors',COUNT(*) FROM vendors

UNION ALL SELECT
    'users',COUNT(*) FROM users

UNION ALL SELECT
    'assets',COUNT(*) FROM assets

UNION ALL SELECT
    'asset_tag_counters',COUNT(*)
    FROM asset_tag_counters

UNION ALL SELECT
    'warranties',COUNT(*) FROM warranties

UNION ALL SELECT
    'asset_assignments',COUNT(*)
    FROM asset_assignments

UNION ALL SELECT
    'asset_transfers',COUNT(*)
    FROM asset_transfers

UNION ALL SELECT
    'service_requests',COUNT(*)
    FROM service_requests

UNION ALL SELECT
    'maintenance_records',COUNT(*)
    FROM maintenance_records

UNION ALL SELECT
    'maintenance_parts',COUNT(*)
    FROM maintenance_parts

UNION ALL SELECT
    'request_updates',COUNT(*)
    FROM request_updates

UNION ALL SELECT
    'notifications',COUNT(*) FROM notifications;

-- ============================================
-- END OF 02_seed.sql
-- ============================================
