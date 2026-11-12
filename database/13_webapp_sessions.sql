-- Phase 5, step 5.1: session table & scoped permission.
-- RUN IN MYSQL WORKBENCH AS ROOT / YOUR DATABASE ADMIN.
USE casms;

-- express-mysql-session schema, created by administrator (not the app).
CREATE TABLE IF NOT EXISTS sessions (
  session_id VARCHAR(128) COLLATE utf8mb4_bin NOT NULL,
  expires INT UNSIGNED NOT NULL,
  data MEDIUMTEXT COLLATE utf8mb4_bin,
  PRIMARY KEY (session_id)
) ENGINE=InnoDB;

-- casms_app is not granted database DDL permissions.
GRANT SELECT, INSERT, UPDATE, DELETE ON casms.sessions
TO 'casms_app'@'localhost';

SHOW GRANTS FOR 'casms_app'@'localhost';
SELECT COUNT(*) AS session_table_exists
FROM information_schema.tables
WHERE table_schema='casms' AND table_name='sessions';
-- Expected: 1. This increases total base tables from 22 to 23.
