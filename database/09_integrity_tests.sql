-- CASMS Phase 4 | 09_integrity_tests.sql | MySQL 8.0.46
-- Must run AFTER 08_transactions.sql.
-- Expected errors are CAUGHT inside the test procedure: no Workbench stop.
-- Real test transactions are ROLLED BACK. Only TEMPORARY results remain.
USE casms;
ROLLBACK;
DROP TEMPORARY TABLE IF EXISTS phase4_integrity_results;
CREATE TEMPORARY TABLE phase4_integrity_results (
  test_id INT PRIMARY KEY,
  scenario VARCHAR(100) NOT NULL,
  result VARCHAR(8) NOT NULL
) ENGINE=InnoDB;

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_p4_run_integrity_tests$$
CREATE PROCEDURE sp_p4_run_integrity_tests()
BEGIN
  DECLARE v_rejected BOOLEAN DEFAULT FALSE;
  DECLARE v_asset INT UNSIGNED;
  DECLARE v_category INT UNSIGNED;
  DECLARE v_dept INT UNSIGNED;
  DECLARE v_status INT UNSIGNED;
  DECLARE v_admin INT UNSIGNED;
  DECLARE v_active_assignment INT UNSIGNED;
  DECLARE v_audit INT UNSIGNED;
  DECLARE v_request INT UNSIGNED;
  DECLARE v_retired INT UNSIGNED;
  DECLARE v_maintenance INT UNSIGNED;
  DECLARE v_closed_status INT UNSIGNED;
  DECLARE v_open_status INT UNSIGNED;
  DECLARE v_priority INT UNSIGNED;

  SELECT MIN(asset_id) INTO v_asset FROM assets;
  SELECT category_id,department_id,asset_status_id INTO v_category,v_dept,v_status
    FROM assets WHERE asset_id=v_asset;
  SELECT MIN(u.user_id) INTO v_admin FROM users u JOIN roles ro
    ON ro.role_id=u.role_id WHERE ro.role_name='Admin' AND u.is_active=TRUE;
  SELECT MIN(assignment_id) INTO v_active_assignment
    FROM asset_assignments WHERE assigned_to IS NULL;
  SELECT MIN(audit_id) INTO v_audit FROM audit_log;
  SELECT MIN(maintenance_id) INTO v_maintenance FROM maintenance_records;
  SELECT MIN(a.asset_id) INTO v_retired FROM assets a JOIN asset_statuses s
    ON s.asset_status_id=a.asset_status_id WHERE s.status_name='Retired';
  SELECT request_id INTO v_request FROM service_requests
    WHERE request_number='P4-CLOSE-FAIL';
  SELECT request_status_id INTO v_closed_status FROM request_statuses
    WHERE status_name='Closed';
  SELECT request_status_id INTO v_open_status FROM request_statuses
    WHERE status_name='Open';
  SELECT priority_id INTO v_priority FROM priorities
    WHERE priority_name='High';
  IF v_asset IS NULL OR v_admin IS NULL OR v_active_assignment IS NULL
     OR v_audit IS NULL OR v_maintenance IS NULL OR v_retired IS NULL
     OR v_request IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT='Fixtures missing; run 08_transactions.sql first';
  END IF;

  -- Test 1: duplicate asset tag -> UNIQUE rejection.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    INSERT INTO assets(asset_tag,asset_name,category_id,department_id,
                       asset_status_id,purchase_cost)
    SELECT asset_tag,'P4 duplicate tag test',v_category,v_dept,v_status,100
      FROM assets WHERE asset_id=v_asset;
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (1,'Duplicate asset tag (UNIQUE)',IF(v_rejected,'PASS','FAIL'));

  -- Test 2: invalid foreign key -> rejection.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    INSERT INTO maintenance_parts(maintenance_id,part_name,quantity,unit_cost)
    VALUES(4294967294,'P4 invalid FK',1,10.00);
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (2,'Invalid maintenance FK',IF(v_rejected,'PASS','FAIL'));

  -- Test 3: negative cost -> CHECK constraint rejection.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    INSERT INTO maintenance_parts(maintenance_id,part_name,quantity,unit_cost)
    VALUES(v_maintenance,'P4 negative price',1,-1.00);
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (3,'Negative part cost (CHECK)',IF(v_rejected,'PASS','FAIL'));

  -- Test 4: unknown role -> CHECK constraint rejection.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    INSERT INTO roles(role_name) VALUES('P4_Invalid_Role');
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (4,'Invalid role (CHECK)',IF(v_rejected,'PASS','FAIL'));

  -- Test 5: active assignment duplicated -> generated UNIQUE rejection.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    INSERT INTO asset_assignments(asset_id,assigned_department_id,
             assigned_by_user_id,assigned_from,assigned_to)
    SELECT asset_id,assigned_department_id,v_admin,CURDATE(),NULL
    FROM asset_assignments WHERE assignment_id=v_active_assignment;
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (5,'Second current assignment rejected',IF(v_rejected,'PASS','FAIL'));

  -- Test 6: audit is append-only (UPDATE forbidden).
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    UPDATE audit_log SET action=action WHERE audit_id=v_audit;
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (6,'Audit UPDATE blocked',IF(v_rejected,'PASS','FAIL'));

  -- Test 7: audit DELETE forbidden.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    DELETE FROM audit_log WHERE audit_id=v_audit;
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (7,'Audit DELETE blocked',IF(v_rejected,'PASS','FAIL'));

  -- Test 8: new request on retired asset -> trigger rejection.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    INSERT INTO service_requests(request_number,asset_id,raised_by_user_id,
      request_status_id,priority_id,title,description,raised_at,due_at)
    VALUES('P4-INVALID-RETIRED',v_retired,v_admin,v_open_status,
      v_priority,'Should be blocked','Phase 4 test',NOW(),
      DATE_ADD(NOW(),INTERVAL 1 DAY));
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (8,'Retired asset cannot receive requests',IF(v_rejected,'PASS','FAIL'));

  -- Test 9: request cannot close without maintenance.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    UPDATE service_requests SET request_status_id=v_closed_status,
      closed_at=NOW() WHERE request_id=v_request;
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (9,'Direct closure without maintenance blocked',IF(v_rejected,'PASS','FAIL'));

  -- Test 10: invalid lifecycle transition In Progress -> Open.
  SET v_rejected=FALSE;
  START TRANSACTION;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected=TRUE;
    UPDATE service_requests SET request_status_id=v_open_status
      WHERE request_id=v_request;
  END;
  ROLLBACK;
  INSERT INTO phase4_integrity_results VALUES
    (10,'Invalid request status jump blocked',IF(v_rejected,'PASS','FAIL'));
END$$
DELIMITER ;
CALL sp_p4_run_integrity_tests();
DROP PROCEDURE IF EXISTS sp_p4_run_integrity_tests;

SELECT * FROM phase4_integrity_results ORDER BY test_id;
SELECT COUNT(*) AS tests,
       SUM(result='PASS') AS passed,
       SUM(result='FAIL') AS failed
FROM phase4_integrity_results;
-- Expected: 10 tests, 10 passed, 0 failed.
DROP TEMPORARY TABLE IF EXISTS phase4_integrity_results;
