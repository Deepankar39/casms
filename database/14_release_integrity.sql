-- CASMS Phase 6 | 14_release_integrity.sql
-- READ-ONLY acceptance queries. Run in MySQL Workbench as a DB administrator.
-- Designed for existing application database; do not reset or reseed.
USE casms;

-- Release object inventory (22 academic tables + 1 web session table expected).
SELECT 'Base tables' AS object_type, COUNT(*) AS total
FROM information_schema.tables WHERE table_schema='casms' AND table_type='BASE TABLE'
UNION ALL SELECT 'Views',COUNT(*) FROM information_schema.views WHERE table_schema='casms'
UNION ALL SELECT 'Functions',COUNT(*) FROM information_schema.routines WHERE routine_schema='casms' AND routine_type='FUNCTION'
UNION ALL SELECT 'Procedures',COUNT(*) FROM information_schema.routines WHERE routine_schema='casms' AND routine_type='PROCEDURE'
UNION ALL SELECT 'Triggers',COUNT(*) FROM information_schema.triggers WHERE trigger_schema='casms';
-- Expected if no optional tables added: 23 base tables, 7 views, 4 functions, 6 procedures, 14 triggers.

SELECT 'Users' AS entity, COUNT(*) AS total FROM users
UNION ALL SELECT 'Assets', COUNT(*) FROM assets
UNION ALL SELECT 'Service requests', COUNT(*) FROM service_requests
UNION ALL SELECT 'Maintenance jobs', COUNT(*) FROM maintenance_records
UNION ALL SELECT 'Maintenance parts', COUNT(*) FROM maintenance_parts
UNION ALL SELECT 'Audit events', COUNT(*) FROM audit_log
UNION ALL SELECT 'Session rows', COUNT(*) FROM sessions;
-- Counts may be greater than original seed: Phase 4 fixtures and web activity create data.

-- All of the following counts must be ZERO.
SELECT
  (SELECT COUNT(*) FROM service_requests r LEFT JOIN assets a ON a.asset_id=r.asset_id WHERE a.asset_id IS NULL) AS orphan_requests,
  (SELECT COUNT(*) FROM maintenance_records m LEFT JOIN service_requests r ON r.request_id=m.request_id WHERE r.request_id IS NULL) AS orphan_maintenance,
  (SELECT COUNT(*) FROM maintenance_parts p LEFT JOIN maintenance_records m ON m.maintenance_id=p.maintenance_id WHERE m.maintenance_id IS NULL) AS orphan_parts,
  (SELECT COUNT(*) FROM asset_assignments aa LEFT JOIN assets a ON a.asset_id=aa.asset_id WHERE a.asset_id IS NULL) AS orphan_assignments,
  (SELECT COUNT(*) FROM assets a WHERE a.purchase_cost<0 OR a.salvage_value<0) AS negative_asset_costs,
  (SELECT COUNT(*) FROM maintenance_parts p WHERE p.quantity<1 OR p.unit_cost<0) AS invalid_part_values,
  (SELECT COUNT(*) FROM warranties w WHERE w.end_date<w.start_date) AS invalid_warranty_dates,
  (SELECT COUNT(*) FROM service_requests r WHERE r.due_at<r.raised_at) AS invalid_request_due_dates;

-- Duplicate active assignments: should return no rows.
SELECT asset_id, COUNT(*) AS open_assignments
FROM asset_assignments WHERE assigned_to IS NULL
GROUP BY asset_id HAVING COUNT(*)>1;

-- Duplicate asset tags: should return no rows.
SELECT asset_tag,COUNT(*) AS duplicates
FROM assets GROUP BY asset_tag HAVING COUNT(*)>1;

-- Inconsistent closed_at timestamps: should return no rows.
SELECT r.request_id, r.request_number, st.status_name, r.closed_at
FROM service_requests r
JOIN request_statuses st ON st.request_status_id=r.request_status_id
WHERE (st.status_name='Closed' AND r.closed_at IS NULL)
   OR (st.status_name NOT IN ('Closed') AND r.closed_at IS NOT NULL);
-- If historical reopen behavior legitimately preserves closed_at, document and investigate any rows.

-- Previously executed Phase 4 controlled fixtures; if they exist, check expected outcomes.
SELECT r.request_number,st.status_name,COUNT(DISTINCT m.maintenance_id) AS maintenance_rows,
       COUNT(mp.part_id) AS part_rows
FROM service_requests r JOIN request_statuses st ON st.request_status_id=r.request_status_id
LEFT JOIN maintenance_records m ON m.request_id=r.request_id
LEFT JOIN maintenance_parts mp ON mp.maintenance_id=m.maintenance_id
WHERE r.request_number IN ('P4-CLOSE-OK','P4-CLOSE-FAIL')
GROUP BY r.request_id,r.request_number,st.status_name;

-- A representative dashboard report and reporting views.
SELECT * FROM vw_technician_workload ORDER BY open_jobs DESC LIMIT 10;
SELECT * FROM vw_department_cost_summary ORDER BY total_maintenance_cost DESC LIMIT 10;
SELECT table_name,action,COUNT(*) AS events FROM audit_log GROUP BY table_name,action ORDER BY events DESC;
