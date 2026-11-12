-- CASMS Phase 4 | 11_security_users.sql | MySQL 8.0.46
-- RUN AS LOCAL MYSQL ADMINISTRATOR (e.g., root) in Workbench.
-- Creates least-privilege application and report accounts.
-- No plaintext credentials are embedded in this file.
-- Save newly generated credentials PRIVATELY. Do NOT commit to Git.
USE casms;

-- Passwords are generated per execution, and existing accounts are rotated.
SET @p4_app_pw = HEX(RANDOM_BYTES(24));
SET @p4_report_pw = HEX(RANDOM_BYTES(24));

SET @sql = CONCAT(
  "CREATE USER IF NOT EXISTS 'casms_app'@'localhost' IDENTIFIED BY ",
  QUOTE(@p4_app_pw));
PREPARE p4_stmt FROM @sql; EXECUTE p4_stmt; DEALLOCATE PREPARE p4_stmt;
SET @sql = CONCAT(
  "ALTER USER 'casms_app'@'localhost' IDENTIFIED BY ",
  QUOTE(@p4_app_pw));
PREPARE p4_stmt FROM @sql; EXECUTE p4_stmt; DEALLOCATE PREPARE p4_stmt;

SET @sql = CONCAT(
  "CREATE USER IF NOT EXISTS 'casms_report'@'localhost' IDENTIFIED BY ",
  QUOTE(@p4_report_pw));
PREPARE p4_stmt FROM @sql; EXECUTE p4_stmt; DEALLOCATE PREPARE p4_stmt;
SET @sql = CONCAT(
  "ALTER USER 'casms_report'@'localhost' IDENTIFIED BY ",
  QUOTE(@p4_report_pw));
PREPARE p4_stmt FROM @sql; EXECUTE p4_stmt; DEALLOCATE PREPARE p4_stmt;

-- Application: read for authentication + UI; write only operational tables.
-- No CREATE/DROP/ALTER, no audit_log UPDATE/DELETE, no global privileges.
GRANT SELECT ON casms.* TO 'casms_app'@'localhost';
GRANT EXECUTE ON casms.* TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.users TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.departments TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.buildings TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.rooms TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.asset_categories TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.vendors TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.assets TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.warranties TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.asset_assignments TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.asset_transfers TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.asset_tag_counters TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.service_requests TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.request_updates TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.maintenance_records TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.maintenance_parts TO 'casms_app'@'localhost';
GRANT INSERT, UPDATE ON casms.notifications TO 'casms_app'@'localhost';

-- Reporting account only sees seven curated views (NOT users.password_hash).
GRANT SELECT ON casms.vw_asset_overview TO 'casms_report'@'localhost';
GRANT SELECT ON casms.vw_pending_requests TO 'casms_report'@'localhost';
GRANT SELECT ON casms.vw_overdue_requests TO 'casms_report'@'localhost';
GRANT SELECT ON casms.vw_service_history TO 'casms_report'@'localhost';
GRANT SELECT ON casms.vw_warranty_status TO 'casms_report'@'localhost';
GRANT SELECT ON casms.vw_department_cost_summary TO 'casms_report'@'localhost';
GRANT SELECT ON casms.vw_technician_workload TO 'casms_report'@'localhost';

-- GRANT / REVOKE demonstration with a throwaway role (no user access).
CREATE ROLE IF NOT EXISTS 'casms_phase4_dcl_demo';
GRANT SELECT ON casms.vw_asset_overview TO 'casms_phase4_dcl_demo';
REVOKE SELECT ON casms.vw_asset_overview FROM 'casms_phase4_dcl_demo';
DROP ROLE 'casms_phase4_dcl_demo';

-- Inspect effective grants. View the passwords ONCE and store locally.
SHOW GRANTS FOR 'casms_app'@'localhost';
SHOW GRANTS FOR 'casms_report'@'localhost';
SELECT 'casms_app' AS mysql_username, 'localhost' AS mysql_host,
       @p4_app_pw AS generated_temporary_password
UNION ALL
SELECT 'casms_report', 'localhost', @p4_report_pw;

-- Erase passwords from session variables after you have copied them.
SET @p4_app_pw = NULL;
SET @p4_report_pw = NULL;
SET @sql = NULL;

-- Privilege smoke tests: connect SEPARATELY with the new accounts:
-- casms_app: SELECT COUNT(*) FROM casms.assets; (allowed)
-- casms_app: DELETE FROM casms.audit_log WHERE audit_id=0; (denied)
-- casms_app: CREATE TABLE casms.should_fail(id INT); (denied)
-- casms_report: SELECT * FROM casms.vw_asset_overview LIMIT 1; (allowed)
-- casms_report: SELECT * FROM casms.users LIMIT 1; (denied)
-- Security note: Phase 5 session store setup requires an additional,
-- explicitly approved table grant after administrator creates that table.
