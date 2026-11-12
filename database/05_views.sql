-- CASMS Phase 3 | 05_views.sql | MySQL 8.0.46
USE casms;

-- One asset, its campus location, category and current status.
CREATE OR REPLACE VIEW vw_asset_overview AS
SELECT a.asset_id, a.asset_tag, a.asset_name,
       d.department_id, d.department_code, d.department_name,
       b.building_name, r.room_number, c.category_name,
       s.status_name AS asset_status, a.purchase_cost,
       a.purchase_date, a.needs_retirement_review
FROM assets a
JOIN departments d ON d.department_id=a.department_id
JOIN asset_categories c ON c.category_id=a.category_id
JOIN asset_statuses s ON s.asset_status_id=a.asset_status_id
LEFT JOIN rooms r ON r.room_id=a.room_id
LEFT JOIN buildings b ON b.building_id=r.building_id;

-- Open workload; used by admin and technician queues.
CREATE OR REPLACE VIEW vw_pending_requests AS
SELECT sr.request_id, sr.request_number, sr.title, sr.asset_id,
       a.asset_tag, sr.raised_by_user_id, sr.assigned_technician_id,
       u.full_name AS technician_name, p.priority_name,
       st.status_name AS request_status, sr.raised_at, sr.due_at,
       TIMESTAMPDIFF(HOUR,sr.raised_at,NOW()) AS age_hours
FROM service_requests sr
JOIN assets a ON a.asset_id=sr.asset_id
JOIN priorities p ON p.priority_id=sr.priority_id
JOIN request_statuses st ON st.request_status_id=sr.request_status_id
LEFT JOIN users u ON u.user_id=sr.assigned_technician_id
WHERE st.status_name NOT IN ('Closed','Cancelled');

CREATE OR REPLACE VIEW vw_overdue_requests AS
SELECT request_id, request_number, title, asset_id, asset_tag,
       assigned_technician_id, technician_name, priority_name,
       request_status, due_at,
       TIMESTAMPDIFF(HOUR,due_at,NOW()) AS overdue_hours
FROM vw_pending_requests
WHERE due_at<NOW();

-- Preaggregate parts BEFORE joining to maintenance to avoid duplicate labour.
CREATE OR REPLACE VIEW vw_service_history AS
SELECT m.maintenance_id, sr.request_id, sr.request_number,
       a.asset_id, a.asset_tag, a.asset_name,
       m.technician_id, u.full_name AS technician_name,
       m.start_date, m.end_date, m.diagnosis, m.work_performed,
       m.outcome, m.warranty_covered, m.labour_cost,
       COALESCE(pc.parts_cost,0.00) AS parts_cost,
       m.labour_cost+COALESCE(pc.parts_cost,0.00) AS total_cost
FROM maintenance_records m
JOIN service_requests sr ON sr.request_id=m.request_id
JOIN assets a ON a.asset_id=sr.asset_id
JOIN users u ON u.user_id=m.technician_id
LEFT JOIN (
    SELECT maintenance_id, SUM(quantity*unit_cost) AS parts_cost
    FROM maintenance_parts GROUP BY maintenance_id
) pc ON pc.maintenance_id=m.maintenance_id;

-- One row per warranty, including expired warranties.
CREATE OR REPLACE VIEW vw_warranty_status AS
SELECT w.warranty_id, a.asset_id, a.asset_tag,
       w.coverage_type, w.start_date, w.end_date,
       DATEDIFF(w.end_date,CURDATE()) AS days_remaining,
       CASE WHEN w.end_date<CURDATE() THEN 'Expired'
            WHEN w.end_date<=DATE_ADD(CURDATE(),INTERVAL 30 DAY)
                THEN 'Expiring in 30 Days'
            ELSE 'Active' END AS warranty_status
FROM warranties w JOIN assets a ON a.asset_id=w.asset_id;

CREATE OR REPLACE VIEW vw_department_cost_summary AS
SELECT d.department_id, d.department_code, d.department_name,
       COUNT(h.maintenance_id) AS total_repairs,
       COALESCE(SUM(h.total_cost),0.00) AS total_maintenance_cost
FROM departments d
LEFT JOIN assets a ON a.department_id=d.department_id
LEFT JOIN vw_service_history h ON h.asset_id=a.asset_id
GROUP BY d.department_id,d.department_code,d.department_name;

CREATE OR REPLACE VIEW vw_technician_workload AS
SELECT u.user_id AS technician_id, u.full_name,
       tp.specialization, tp.max_open_requests, tp.is_available,
       COUNT(v.request_id) AS open_jobs
FROM users u
JOIN roles ro ON ro.role_id=u.role_id AND ro.role_name='Technician'
JOIN technician_profiles tp ON tp.user_id=u.user_id
LEFT JOIN vw_pending_requests v ON v.assigned_technician_id=u.user_id
GROUP BY u.user_id,u.full_name,tp.specialization,
         tp.max_open_requests,tp.is_available;

-- Smoke tests: seven views must be present; sample results.
SELECT COUNT(*) AS casms_views
FROM information_schema.views WHERE table_schema='casms'
  AND table_name IN ('vw_asset_overview','vw_pending_requests',
    'vw_overdue_requests','vw_service_history','vw_warranty_status',
    'vw_department_cost_summary','vw_technician_workload');
SELECT * FROM vw_department_cost_summary ORDER BY total_maintenance_cost DESC;
SELECT * FROM vw_technician_workload ORDER BY open_jobs DESC;
