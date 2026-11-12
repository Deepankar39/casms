-- CASMS Phase 3 | 10_indexes_explain.sql | MySQL 8.0.46
-- Run after 05_views.sql, 06_functions_procedures.sql, 07_triggers.sql.
-- Uses a SEPARATE performance database; casms retains its 22 base tables.
USE casms;
CREATE DATABASE IF NOT EXISTS casms_perf
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE TABLE IF NOT EXISTS casms_perf.performance_requests (
    perf_id INT UNSIGNED PRIMARY KEY,
    asset_id INT UNSIGNED NOT NULL,
    status_id INT UNSIGNED NOT NULL,
    priority_id INT UNSIGNED NOT NULL,
    raised_at DATETIME NOT NULL,
    due_at DATETIME NOT NULL
) ENGINE=InnoDB;

-- 50,000 synthetic rows using ordinary derived sets, not repeated temp tables.
INSERT IGNORE INTO casms_perf.performance_requests
   (perf_id,asset_id,status_id,priority_id,raised_at,due_at)
SELECT n,1+MOD(n-1,300),1+MOD(n-1,6),1+MOD(n-1,4),
       DATE_ADD('2025-01-01',INTERVAL MOD(n,550) DAY),
       DATE_ADD('2025-01-04',INTERVAL MOD(n,550) DAY)
FROM (
  SELECT 1+a.d+10*b.d+100*c.d+1000*d.d+10000*e.d AS n
  FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
  CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) e
) sequence_50k;

SELECT COUNT(*) AS performance_rows FROM casms_perf.performance_requests;
-- Expected: 50000

-- BEFORE: note EXPLAIN.type, possible_keys, key, rows, Extra.
EXPLAIN SELECT perf_id,asset_id,raised_at
FROM casms_perf.performance_requests
WHERE status_id=2 AND priority_id=2
ORDER BY raised_at LIMIT 20;

-- MySQL lacks CREATE INDEX IF NOT EXISTS, so use a short helper
-- that checks information_schema before each CREATE INDEX.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_phase3_add_index$$
CREATE PROCEDURE sp_phase3_add_index(
    IN p_schema VARCHAR(64), IN p_table VARCHAR(64),
    IN p_index VARCHAR(64), IN p_columns VARCHAR(255))
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count FROM information_schema.statistics
      WHERE table_schema=p_schema AND table_name=p_table
        AND index_name=p_index;
    IF v_count=0 THEN
       SET @casms_index_sql=CONCAT(
         'CREATE INDEX `',p_index,'` ON `',p_schema,'`.`',p_table,
         '` (`',REPLACE(p_columns,',','`,`'),'`)');
       PREPARE casms_index_stmt FROM @casms_index_sql;
       EXECUTE casms_index_stmt;
       DEALLOCATE PREPARE casms_index_stmt;
    END IF;
END$$
DELIMITER ;

CALL sp_phase3_add_index('casms','assets',
  'idx_assets_dept_status','department_id,asset_status_id');
CALL sp_phase3_add_index('casms','service_requests',
  'idx_requests_status_priority','request_status_id,priority_id');
CALL sp_phase3_add_index('casms','service_requests',
  'idx_requests_asset_raised','asset_id,raised_at');
CALL sp_phase3_add_index('casms','service_requests',
  'idx_requests_technician_status','assigned_technician_id,request_status_id');
CALL sp_phase3_add_index('casms','maintenance_records',
  'idx_maintenance_request_end','request_id,end_date');
CALL sp_phase3_add_index('casms','warranties',
  'idx_warranties_end','end_date');
CALL sp_phase3_add_index('casms','notifications',
  'idx_notifications_user_read','user_id,is_read');
CALL sp_phase3_add_index('casms','audit_log',
  'idx_audit_table_record','table_name,record_id');
CALL sp_phase3_add_index('casms_perf','performance_requests',
  'idx_perf_status_priority_date','status_id,priority_id,raised_at');
CALL sp_phase3_add_index('casms_perf','performance_requests',
  'idx_perf_asset_raised','asset_id,raised_at');

DROP PROCEDURE IF EXISTS sp_phase3_add_index;
ANALYZE TABLE casms_perf.performance_requests;

-- AFTER: compare key and estimated rows with the earlier EXPLAIN.
EXPLAIN SELECT perf_id,asset_id,raised_at
FROM casms_perf.performance_requests
WHERE status_id=2 AND priority_id=2
ORDER BY raised_at LIMIT 20;

-- Additional explain using the real application schema.
EXPLAIN SELECT request_number,asset_id,raised_at
FROM casms.service_requests
WHERE asset_id=1
ORDER BY raised_at DESC LIMIT 20;

-- Verification: 4 functions, 6 procedures, 7 views, 14 triggers.
SELECT routine_type,COUNT(*) AS objects
FROM information_schema.routines WHERE routine_schema='casms'
GROUP BY routine_type;
SELECT COUNT(*) AS views FROM information_schema.views
WHERE table_schema='casms';
SELECT COUNT(*) AS triggers FROM information_schema.triggers
WHERE trigger_schema='casms';
SELECT COUNT(*) AS base_tables FROM information_schema.tables
WHERE table_schema='casms' AND table_type='BASE TABLE';
-- Expected base_tables = 22. casms_perf is separate.
