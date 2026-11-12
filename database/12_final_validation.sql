-- CASMS Phase 4 | 12_final_validation.sql | MySQL 8.0.46
-- Read-only final checks. Run after 08, 09, 11.
USE casms;

-- 1. Database totals and required objects.
SELECT 'CASMS base tables' AS metric, COUNT(*) AS total
 FROM information_schema.tables
 WHERE table_schema='casms' AND table_type='BASE TABLE'
UNION ALL SELECT 'Views',COUNT(*) FROM information_schema.views
 WHERE table_schema='casms'
UNION ALL SELECT 'Functions',COUNT(*) FROM information_schema.routines
 WHERE routine_schema='casms' AND routine_type='FUNCTION'
UNION ALL SELECT 'Procedures',COUNT(*) FROM information_schema.routines
 WHERE routine_schema='casms' AND routine_type='PROCEDURE'
UNION ALL SELECT 'Triggers',COUNT(*) FROM information_schema.triggers
 WHERE trigger_schema='casms'
UNION ALL SELECT 'Performance rows',COUNT(*) FROM casms_perf.performance_requests;
-- Expected: 22 tables, 7 views, 4 functions, 6 procedures, 14 triggers,
-- and 50,000 performance rows.

-- 2. Business data (extra controlled fixtures from Phase 4 are labeled).
SELECT 'Departments' AS metric,COUNT(*) AS total FROM departments
UNION ALL SELECT 'Users',COUNT(*) FROM users
UNION ALL SELECT 'Assets (including P4 fixture)',COUNT(*) FROM assets
UNION ALL SELECT 'Service Requests (including P4 fixtures)',COUNT(*) FROM service_requests
UNION ALL SELECT 'Maintenance Records (including P4 success)',COUNT(*) FROM maintenance_records
UNION ALL SELECT 'Maintenance Parts (including P4 success)',COUNT(*) FROM maintenance_parts
UNION ALL SELECT 'Audit entries',COUNT(*) FROM audit_log;

-- 3. Successful vs failed closure prove atomicity.
SELECT r.request_number, st.status_name,
       COUNT(DISTINCT m.maintenance_id) AS repair_rows,
       COUNT(mp.part_id) AS part_rows,
       r.closed_at
FROM service_requests r
JOIN request_statuses st ON st.request_status_id=r.request_status_id
LEFT JOIN maintenance_records m ON m.request_id=r.request_id
LEFT JOIN maintenance_parts mp ON mp.maintenance_id=m.maintenance_id
WHERE r.request_number IN ('P4-CLOSE-OK','P4-CLOSE-FAIL')
GROUP BY r.request_id,r.request_number,st.status_name,r.closed_at
ORDER BY r.request_number;
-- Expected: P4-CLOSE-OK Closed/1 repair/1 part;
--           P4-CLOSE-FAIL In Progress/0 repair/0 parts.

-- 4. Referential integrity: no orphaned maintenance requests or parts.
SELECT
  (SELECT COUNT(*) FROM maintenance_records m
    LEFT JOIN service_requests r ON r.request_id=m.request_id
    WHERE r.request_id IS NULL) AS orphan_maintenance,
  (SELECT COUNT(*) FROM maintenance_parts p
    LEFT JOIN maintenance_records m ON m.maintenance_id=p.maintenance_id
    WHERE m.maintenance_id IS NULL) AS orphan_parts,
  (SELECT COUNT(*) FROM service_requests r
    LEFT JOIN assets a ON a.asset_id=r.asset_id
    WHERE a.asset_id IS NULL) AS orphan_requests;
-- Expected: 0, 0, 0.

-- 5. No asset has more than one current assignment.
SELECT asset_id,COUNT(*) AS current_assignments
FROM asset_assignments
WHERE assigned_to IS NULL
GROUP BY asset_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows.

-- 6. No negative prices / invalid dates.
SELECT
 (SELECT COUNT(*) FROM assets WHERE purchase_cost<0 OR salvage_value<0)
   AS invalid_asset_costs,
 (SELECT COUNT(*) FROM maintenance_parts WHERE quantity<1 OR unit_cost<0)
   AS invalid_parts,
 (SELECT COUNT(*) FROM maintenance_records WHERE end_date<start_date
   OR labour_cost<0) AS invalid_maintenance,
 (SELECT COUNT(*) FROM warranties WHERE end_date<start_date)
   AS invalid_warranties;
-- Expected: 0,0,0,0.

-- 7. Dashboard and audit views are usable.
SELECT * FROM vw_technician_workload ORDER BY open_jobs DESC LIMIT 8;
SELECT * FROM vw_department_cost_summary
  ORDER BY total_maintenance_cost DESC LIMIT 8;
SELECT table_name,action,COUNT(*) AS events FROM audit_log
  GROUP BY table_name,action ORDER BY table_name,action;

-- 8. Security: both users should exist (privileges checked separately).
SELECT user,host FROM mysql.user
WHERE user IN ('casms_app','casms_report');
-- This last query requires root/administrator privileges.
