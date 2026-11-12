-- CASMS Phase 4 | 08_transactions.sql | MySQL 8.0.46
-- Requires: 01, 02, 05, 06, 07 from prior phases.
-- Repeatable controlled lab. Creates one labeled asset + three requests,
-- plus a separate concurrency demo table in casms_perf.
USE casms;
ROLLBACK;
SET @casms_actor_id = NULL;

-- PART A: SAVEPOINT / ROLLBACK / COMMIT with TEMPORARY lab data.
DROP TEMPORARY TABLE IF EXISTS p4_transaction_demo;
CREATE TEMPORARY TABLE p4_transaction_demo (
  id INT PRIMARY KEY, note VARCHAR(100) NOT NULL
) ENGINE=InnoDB;
START TRANSACTION;
INSERT INTO p4_transaction_demo VALUES (1, 'Keep this first change');
SAVEPOINT p4_after_first_insert;
INSERT INTO p4_transaction_demo VALUES (2, 'Undo this second change');
ROLLBACK TO SAVEPOINT p4_after_first_insert;
COMMIT;
SELECT 'SAVEPOINT expected 1 row' AS test, COUNT(*) AS actual_rows
FROM p4_transaction_demo;
START TRANSACTION;
INSERT INTO p4_transaction_demo VALUES (3, 'This whole transaction rolls back');
ROLLBACK;
SELECT 'ROLLBACK expected 1 row' AS test, COUNT(*) AS actual_rows
FROM p4_transaction_demo;
DROP TEMPORARY TABLE p4_transaction_demo;

-- PART B: controlled fixtures for atomic closure, failures, and concurrency.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_p4_prepare_fixture$$
CREATE PROCEDURE sp_p4_prepare_fixture()
BEGIN
  DECLARE v_admin INT UNSIGNED;
  DECLARE v_tech INT UNSIGNED;
  DECLARE v_dept INT UNSIGNED;
  DECLARE v_cat INT UNSIGNED;
  DECLARE v_asset INT UNSIGNED;
  DECLARE v_stock INT UNSIGNED;
  DECLARE v_active INT UNSIGNED;
  DECLARE v_open INT UNSIGNED;
  DECLARE v_assigned INT UNSIGNED;
  DECLARE v_progress INT UNSIGNED;
  DECLARE v_priority INT UNSIGNED;
  DECLARE v_tag VARCHAR(50);
  DECLARE v_req INT UNSIGNED;
  DECLARE v_number VARCHAR(50);
  DECLARE v_counter INT DEFAULT 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;

  SELECT MIN(u.user_id) INTO v_admin FROM users u JOIN roles ro
    ON ro.role_id=u.role_id WHERE ro.role_name='Admin' AND u.is_active=1;
  SELECT MIN(u.user_id) INTO v_tech FROM users u JOIN roles ro
    ON ro.role_id=u.role_id WHERE ro.role_name='Technician' AND u.is_active=1;
  SELECT MIN(department_id) INTO v_dept FROM departments WHERE is_active=1;
  SELECT MIN(category_id) INTO v_cat FROM asset_categories WHERE is_active=1;
  SELECT asset_status_id INTO v_stock FROM asset_statuses WHERE status_name='In Stock';
  SELECT asset_status_id INTO v_active FROM asset_statuses WHERE status_name='Active';
  SELECT request_status_id INTO v_open FROM request_statuses WHERE status_name='Open';
  SELECT request_status_id INTO v_assigned FROM request_statuses WHERE status_name='Assigned';
  SELECT request_status_id INTO v_progress FROM request_statuses WHERE status_name='In Progress';
  SELECT priority_id INTO v_priority FROM priorities WHERE priority_name='High';
  IF v_admin IS NULL OR v_tech IS NULL OR v_dept IS NULL OR v_cat IS NULL
     OR v_stock IS NULL OR v_active IS NULL OR v_priority IS NULL
     OR v_open IS NULL OR v_assigned IS NULL OR v_progress IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Seed data missing; rerun 02_seed.sql';
  END IF;

  SELECT MIN(asset_id) INTO v_asset FROM assets
    WHERE asset_name='CASMS PHASE4 CONTROLLED TEST ASSET';
  IF v_asset IS NULL THEN
    -- Calls the real concurrency-safe automatic asset-tag routine.
    CALL sp_register_asset(v_admin,v_dept,v_cat,
      'CASMS PHASE4 CONTROLLED TEST ASSET',NULL,1000.00,v_asset,v_tag);
  END IF;
  -- On first run move the fixture from In Stock -> Active (valid lifecycle).
  SET @casms_actor_id=v_admin;
  UPDATE assets SET asset_status_id=v_active
    WHERE asset_id=v_asset AND asset_status_id=v_stock;
  SET @casms_actor_id=NULL;

  -- Re-run safe: only insert missing requests and do not reopen closed ones.
  WHILE v_counter<=3 DO
    SET v_number=CASE v_counter
      WHEN 1 THEN 'P4-CLOSE-OK'
      WHEN 2 THEN 'P4-CLOSE-FAIL'
      ELSE 'P4-CONCURRENCY'
    END;
    SELECT MIN(request_id) INTO v_req FROM service_requests
      WHERE request_number=v_number;
    IF v_req IS NULL THEN
      SET @casms_actor_id=v_admin;
      START TRANSACTION;
      INSERT INTO service_requests(
        request_number,asset_id,raised_by_user_id,request_status_id,
        priority_id,title,description,raised_at,due_at)
      VALUES(v_number,v_asset,v_admin,v_open,v_priority,
        CONCAT('Phase 4 lab: ',v_number),
        'Synthetic request for controlled transaction testing',
        DATE_SUB(NOW(),INTERVAL 2 HOUR),DATE_ADD(NOW(),INTERVAL 22 HOUR));
      SET v_req=LAST_INSERT_ID();
      UPDATE service_requests
        SET request_status_id=v_assigned,assigned_technician_id=v_tech,
            assigned_at=DATE_SUB(NOW(),INTERVAL 90 MINUTE)
        WHERE request_id=v_req;
      UPDATE service_requests
        SET request_status_id=v_progress,
            started_at=DATE_SUB(NOW(),INTERVAL 1 HOUR)
        WHERE request_id=v_req;
      COMMIT;
      SET @casms_actor_id=NULL;
    END IF;
    SET v_counter=v_counter+1;
  END WHILE;
END$$
DELIMITER ;
CALL sp_p4_prepare_fixture();
DROP PROCEDURE IF EXISTS sp_p4_prepare_fixture;

-- PART C: successful closure + intentionally failed closure.
-- Do NOT wrap calls in an outer transaction: sp_close_service_request
-- explicitly controls the transaction internally.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_p4_test_closure$$
CREATE PROCEDURE sp_p4_test_closure()
BEGIN
  DECLARE v_admin INT UNSIGNED;
  DECLARE v_good INT UNSIGNED;
  DECLARE v_bad INT UNSIGNED;
  DECLARE v_status VARCHAR(30);
  DECLARE v_expected_error BOOLEAN DEFAULT FALSE;
  DECLARE v_error_text TEXT DEFAULT NULL;

  SELECT MIN(u.user_id) INTO v_admin FROM users u JOIN roles ro
    ON ro.role_id=u.role_id WHERE ro.role_name='Admin' AND u.is_active=1;
  SELECT request_id INTO v_good FROM service_requests
    WHERE request_number='P4-CLOSE-OK';
  SELECT request_id INTO v_bad FROM service_requests
    WHERE request_number='P4-CLOSE-FAIL';
  SELECT st.status_name INTO v_status FROM service_requests r
    JOIN request_statuses st ON st.request_status_id=r.request_status_id
    WHERE r.request_id=v_good;
  IF v_status='In Progress' THEN
    CALL sp_close_service_request(v_good,v_admin,
      'Faulty projector cable','Replaced cable and verified output',
      DATE_SUB(NOW(),INTERVAL 45 MINUTE),NOW(),125.00,
      'Repaired',FALSE,
      JSON_ARRAY(JSON_OBJECT('part_name','Lab replacement cable',
                            'quantity',1,'unit_cost',175.00)));
  END IF;

  SELECT st.status_name INTO v_status FROM service_requests r
    JOIN request_statuses st ON st.request_status_id=r.request_status_id
    WHERE r.request_id=v_bad;
  IF v_status='In Progress' THEN
    BEGIN
      DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
      BEGIN
        SET v_expected_error=TRUE;
        GET DIAGNOSTICS CONDITION 1 v_error_text=MESSAGE_TEXT;
      END;
      -- Negative part quantity must fail, rolling back the entire closure.
      CALL sp_close_service_request(v_bad,v_admin,
        'Failed repair for rollback test','This must never be committed',
        DATE_SUB(NOW(),INTERVAL 30 MINUTE),NOW(),250.00,
        'Repaired',FALSE,
        JSON_ARRAY(JSON_OBJECT('part_name','INVALID NEGATIVE QUANTITY',
                              'quantity',-1,'unit_cost',50.00)));
    END;
  END IF;
  SELECT IF(v_expected_error,'PASS: failure rejected',
         IF(v_status<>'In Progress','SKIPPED: not In Progress',
            'FAIL: unexpected successful closure')) AS rollback_test,
         v_error_text AS mysql_message;
END$$
DELIMITER ;
CALL sp_p4_test_closure();
DROP PROCEDURE IF EXISTS sp_p4_test_closure;

-- PART D: status, row-count and audit verification (one row per request).
SELECT r.request_number,st.status_name, r.closed_at,
       (SELECT COUNT(*) FROM maintenance_records m
        WHERE m.request_id=r.request_id) AS maintenance_rows,
       (SELECT COUNT(*) FROM request_updates u
        WHERE u.request_id=r.request_id AND u.update_type='Closed') AS closure_events
FROM service_requests r JOIN request_statuses st
ON st.request_status_id=r.request_status_id
WHERE r.request_number IN ('P4-CLOSE-OK','P4-CLOSE-FAIL','P4-CONCURRENCY')
ORDER BY r.request_number;
-- Expected: P4-CLOSE-OK Closed/1; P4-CLOSE-FAIL In Progress/0;
-- P4-CONCURRENCY In Progress/0 (until optional concurrency exercise).

-- PART E: separate non-business concurrency exercise table.
CREATE DATABASE IF NOT EXISTS casms_perf
 CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE TABLE IF NOT EXISTS casms_perf.phase4_lock_lab (
  row_id INT PRIMARY KEY, amount INT NOT NULL
) ENGINE=InnoDB;
INSERT IGNORE INTO casms_perf.phase4_lock_lab(row_id,amount)
VALUES (1,100),(2,200);
SELECT * FROM casms_perf.phase4_lock_lab ORDER BY row_id;

-- Confirm six original Phase 3 business procedures remain installed.
SELECT COUNT(*) AS business_procedures
FROM information_schema.routines
WHERE routine_schema='casms' AND routine_type='PROCEDURE';
-- Expected: 6
