-- CASMS Phase 3 | 06_functions_procedures.sql | MySQL 8.0.46
USE casms;
DELIMITER $$

DROP FUNCTION IF EXISTS fn_warranty_days_remaining$$
CREATE FUNCTION fn_warranty_days_remaining(p_warranty_id INT UNSIGNED)
RETURNS INT NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_end DATE DEFAULT NULL;
    SELECT MAX(end_date) INTO v_end FROM warranties
    WHERE warranty_id=p_warranty_id;
    RETURN IF(v_end IS NULL,NULL,DATEDIFF(v_end,CURDATE()));
END$$

DROP FUNCTION IF EXISTS fn_asset_total_maintenance_cost$$
CREATE FUNCTION fn_asset_total_maintenance_cost(p_asset_id INT UNSIGNED)
RETURNS DECIMAL(12,2) NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(h.total_cost),0.00) INTO v_total
    FROM vw_service_history h WHERE h.asset_id=p_asset_id;
    RETURN v_total;
END$$

DROP FUNCTION IF EXISTS fn_asset_book_value$$
CREATE FUNCTION fn_asset_book_value(p_asset_id INT UNSIGNED)
RETURNS DECIMAL(12,2) NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_cost DECIMAL(12,2);
    DECLARE v_salvage DECIMAL(12,2);
    DECLARE v_date DATE;
    DECLARE v_life INT;
    SELECT a.purchase_cost,a.salvage_value,a.purchase_date,
           COALESCE(a.useful_life_years,c.default_useful_life_years,5)
      INTO v_cost,v_salvage,v_date,v_life
    FROM assets a JOIN asset_categories c ON c.category_id=a.category_id
    WHERE a.asset_id=p_asset_id;
    IF v_date IS NULL OR v_life IS NULL OR v_life<=0 THEN RETURN NULL; END IF;
    RETURN ROUND(GREATEST(v_salvage, v_cost -
       (v_cost-v_salvage)*LEAST(1,
        GREATEST(0,TIMESTAMPDIFF(MONTH,v_date,CURDATE()))/(12.0*v_life))),2);
END$$

-- This function FORMATS a tag. sp_register_asset locks and increments
-- the counter so generating a tag is concurrency-safe.
DROP FUNCTION IF EXISTS fn_generate_asset_tag$$
CREATE FUNCTION fn_generate_asset_tag(
    p_department_id INT UNSIGNED, p_category_id INT UNSIGNED,
    p_sequence INT UNSIGNED)
RETURNS VARCHAR(50) NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_dept VARCHAR(20);
    DECLARE v_cat VARCHAR(20);
    SELECT MAX(department_code) INTO v_dept FROM departments
      WHERE department_id=p_department_id;
    SELECT MAX(category_code) INTO v_cat FROM asset_categories
      WHERE category_id=p_category_id;
    IF v_dept IS NULL OR v_cat IS NULL OR p_sequence IS NULL THEN RETURN NULL; END IF;
    RETURN CONCAT(v_dept,'-',v_cat,'-',LPAD(p_sequence,4,'0'));
END$$

-- ADMIN REGISTERS AN ASSET: counter lock + asset INSERT in one transaction.
DROP PROCEDURE IF EXISTS sp_register_asset$$
CREATE PROCEDURE sp_register_asset(
    IN p_actor_id INT UNSIGNED, IN p_department_id INT UNSIGNED,
    IN p_category_id INT UNSIGNED, IN p_asset_name VARCHAR(150),
    IN p_room_id INT UNSIGNED, IN p_purchase_cost DECIMAL(12,2),
    OUT p_new_asset_id INT UNSIGNED, OUT p_new_asset_tag VARCHAR(50))
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_counter INT UNSIGNED;
    DECLARE v_stock INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;
    SELECT MAX(ro.role_name) INTO v_role FROM users u
      JOIN roles ro ON ro.role_id=u.role_id
      WHERE u.user_id=p_actor_id AND u.is_active=TRUE;
    IF COALESCE(v_role,'')<>'Admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only Admin can register assets';
    END IF;
    IF TRIM(COALESCE(p_asset_name,''))='' OR p_purchase_cost IS NULL
       OR p_purchase_cost<0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid asset name or purchase cost';
    END IF;
    SET @casms_actor_id=p_actor_id;
    START TRANSACTION;
    SELECT asset_status_id INTO v_stock FROM asset_statuses
       WHERE status_name='In Stock';
    INSERT INTO asset_tag_counters(department_id,category_id,last_number)
      VALUES(p_department_id,p_category_id,0)
      ON DUPLICATE KEY UPDATE counter_id=counter_id;
    SELECT last_number INTO v_counter FROM asset_tag_counters
      WHERE department_id=p_department_id AND category_id=p_category_id
      FOR UPDATE;
    SET v_counter=v_counter+1;
    UPDATE asset_tag_counters SET last_number=v_counter
      WHERE department_id=p_department_id AND category_id=p_category_id;
    SET p_new_asset_tag=fn_generate_asset_tag(
        p_department_id,p_category_id,v_counter);
    IF p_new_asset_tag IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid department or category';
    END IF;
    INSERT INTO assets(asset_tag,asset_name,department_id,category_id,
                       room_id,asset_status_id,purchase_cost)
    VALUES(p_new_asset_tag,TRIM(p_asset_name),p_department_id,p_category_id,
           p_room_id,v_stock,p_purchase_cost);
    SET p_new_asset_id=LAST_INSERT_ID();
    COMMIT;
    SET @casms_actor_id=NULL;
END$$

-- ADMIN ASSIGNS A SERVICE REQUEST TO AN ACTIVE TECHNICIAN.
DROP PROCEDURE IF EXISTS sp_assign_technician$$
CREATE PROCEDURE sp_assign_technician(
    IN p_request_id INT UNSIGNED, IN p_technician_id INT UNSIGNED,
    IN p_actor_id INT UNSIGNED)
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_status VARCHAR(30);
    DECLARE v_max INT;
    DECLARE v_work INT;
    DECLARE v_tech_ok INT DEFAULT 0;
    DECLARE v_request_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;
    SELECT MAX(ro.role_name) INTO v_role FROM users u
      JOIN roles ro ON ro.role_id=u.role_id
      WHERE u.user_id=p_actor_id AND u.is_active=TRUE;
    IF COALESCE(v_role,'')<>'Admin' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only Admin can assign technicians';
    END IF;
    SET @casms_actor_id=p_actor_id;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_request_exists FROM service_requests
      WHERE request_id=p_request_id;
    IF v_request_exists=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Service request not found';
    END IF;
    SELECT st.status_name INTO v_status FROM service_requests r
      JOIN request_statuses st ON st.request_status_id=r.request_status_id
      WHERE r.request_id=p_request_id FOR UPDATE;
    IF v_status NOT IN ('Open','Assigned') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Request cannot be assigned now';
    END IF;
    SELECT COUNT(*) INTO v_tech_ok FROM users u JOIN roles ro
      ON ro.role_id=u.role_id JOIN technician_profiles tp
      ON tp.user_id=u.user_id WHERE u.user_id=p_technician_id
      AND u.is_active=TRUE AND tp.is_available=TRUE
      AND ro.role_name='Technician';
    IF v_tech_ok=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Technician unavailable or inactive';
    END IF;
    SELECT tp.max_open_requests INTO v_max FROM technician_profiles tp
      WHERE tp.user_id=p_technician_id FOR UPDATE;
    SELECT COUNT(*) INTO v_work FROM service_requests r
      JOIN request_statuses st ON st.request_status_id=r.request_status_id
      WHERE r.assigned_technician_id=p_technician_id
        AND st.status_name IN ('Assigned','In Progress','On Hold')
        AND r.request_id<>p_request_id;
    IF v_work>=v_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Technician workload limit reached';
    END IF;
    UPDATE service_requests SET assigned_technician_id=p_technician_id,
       request_status_id=(SELECT request_status_id FROM request_statuses
                          WHERE status_name='Assigned'),
       assigned_at=NOW() WHERE request_id=p_request_id;
    INSERT INTO request_updates(request_id,author_user_id,update_type,comment)
      VALUES(p_request_id,p_actor_id,'Assignment','Technician assigned by Admin');
    INSERT INTO notifications(user_id,request_id,notification_type,message)
      VALUES(p_technician_id,p_request_id,'Technician Assigned','New service request assigned');
    COMMIT;
    SET @casms_actor_id=NULL;
END$$

DROP PROCEDURE IF EXISTS sp_assign_asset$$
CREATE PROCEDURE sp_assign_asset(
    IN p_asset_id INT UNSIGNED, IN p_user_id INT UNSIGNED,
    IN p_department_id INT UNSIGNED, IN p_room_id INT UNSIGNED,
    IN p_actor_id INT UNSIGNED)
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_asset_status VARCHAR(30);
    DECLARE v_current INT DEFAULT 0;
    DECLARE v_dept INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;
    SELECT MAX(ro.role_name) INTO v_role FROM users u
      JOIN roles ro ON ro.role_id=u.role_id
      WHERE u.user_id=p_actor_id AND u.is_active=TRUE;
    IF COALESCE(v_role,'')<>'Admin' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only Admin can assign assets';
    END IF;
    IF p_user_id IS NULL AND p_department_id IS NULL THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='User or department required';
    END IF;
    SET @casms_actor_id=p_actor_id;
    START TRANSACTION;
    SELECT s.status_name,a.department_id INTO v_asset_status,v_dept
      FROM assets a JOIN asset_statuses s
      ON s.asset_status_id=a.asset_status_id
      WHERE a.asset_id=p_asset_id FOR UPDATE;
    IF v_asset_status IS NULL OR v_asset_status='Retired' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid or retired asset';
    END IF;
    SELECT COUNT(*) INTO v_current FROM asset_assignments
      WHERE asset_id=p_asset_id AND assigned_to IS NULL;
    IF v_current>0 THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Asset already has current assignment';
    END IF;
    INSERT INTO asset_assignments(asset_id,assigned_user_id,
      assigned_department_id,assigned_room_id,assigned_by_user_id,
      assigned_from,remarks)
    VALUES(p_asset_id,p_user_id,COALESCE(p_department_id,v_dept),
      p_room_id,p_actor_id,CURDATE(),'Assigned by Admin');
    COMMIT;
    SET @casms_actor_id=NULL;
END$$

-- CORE ADBMS DEMO: request + repair + parts + status + notification,
-- all succeed or all ROLLBACK. Savepoint demonstrates partial undo.
DROP PROCEDURE IF EXISTS sp_close_service_request$$
CREATE PROCEDURE sp_close_service_request(
    IN p_request_id INT UNSIGNED, IN p_actor_id INT UNSIGNED,
    IN p_diagnosis TEXT, IN p_work_performed TEXT,
    IN p_start_date DATETIME, IN p_end_date DATETIME,
    IN p_labour_cost DECIMAL(12,2), IN p_outcome VARCHAR(50),
    IN p_warranty_covered BOOLEAN, IN p_parts_json JSON)
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_request_status VARCHAR(30);
    DECLARE v_asset_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_technician_id INT UNSIGNED;
    DECLARE v_requester INT UNSIGNED;
    DECLARE v_asset_status VARCHAR(30);
    DECLARE v_maintenance_id INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;
    SELECT MAX(ro.role_name) INTO v_role FROM users u
      JOIN roles ro ON ro.role_id=u.role_id
      WHERE u.user_id=p_actor_id AND u.is_active=TRUE;
    IF v_role IS NULL THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Actor must be an active user';
    END IF;
    IF TRIM(COALESCE(p_diagnosis,''))='' OR
       TRIM(COALESCE(p_work_performed,''))='' OR
       p_start_date IS NULL OR p_end_date IS NULL OR
       p_end_date<p_start_date OR p_end_date>NOW() OR
       p_labour_cost IS NULL OR p_labour_cost<0 OR
       TRIM(COALESCE(p_outcome,''))='' OR
       p_parts_json IS NULL OR JSON_TYPE(p_parts_json)<>'ARRAY' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid maintenance details';
    END IF;
    SET @casms_actor_id=p_actor_id;
    START TRANSACTION;
    SELECT r.asset_id,r.assigned_technician_id,r.raised_by_user_id,
           st.status_name INTO v_asset_id,v_technician_id,v_requester,v_request_status
      FROM service_requests r JOIN request_statuses st
      ON st.request_status_id=r.request_status_id
      WHERE r.request_id=p_request_id FOR UPDATE;
    IF v_asset_id IS NULL OR v_request_status<>'In Progress' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Request must be In Progress';
    END IF;
    IF v_role<>'Admin' AND (v_role<>'Technician' OR
       v_technician_id IS NULL OR v_technician_id<>p_actor_id) THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Actor is not assigned technician or Admin';
    END IF;
    SELECT s.status_name INTO v_asset_status FROM assets a
      JOIN asset_statuses s ON s.asset_status_id=a.asset_status_id
      WHERE a.asset_id=v_asset_id FOR UPDATE;
    IF v_asset_status='Retired' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot service retired asset';
    END IF;
    IF v_technician_id IS NULL THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Request has no assigned technician';
    END IF;
    INSERT INTO maintenance_records(request_id,technician_id,
      maintenance_type,diagnosis,work_performed,start_date,end_date,
      labour_cost,outcome,warranty_covered)
    VALUES(p_request_id,v_technician_id,'Corrective',p_diagnosis,
      p_work_performed,p_start_date,p_end_date,p_labour_cost,p_outcome,
      COALESCE(p_warranty_covered,FALSE));
    SET v_maintenance_id=LAST_INSERT_ID();
    SAVEPOINT sp_after_maintenance;
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN ROLLBACK TO SAVEPOINT sp_after_maintenance; RESIGNAL; END;
        INSERT INTO maintenance_parts(maintenance_id,part_name,quantity,unit_cost)
        SELECT v_maintenance_id,j.part_name,j.quantity,j.unit_cost
        FROM JSON_TABLE(p_parts_json,'$[*]' COLUMNS (
           part_name VARCHAR(150) PATH '$.part_name',
           quantity INT PATH '$.quantity',
           unit_cost DECIMAL(12,2) PATH '$.unit_cost'
        )) AS j;
    END;
    UPDATE service_requests SET request_status_id=(
       SELECT request_status_id FROM request_statuses WHERE status_name='Closed'),
       closed_at=NOW(),resolution_summary=p_work_performed
       WHERE request_id=p_request_id;
    UPDATE assets SET
       asset_status_id=(SELECT asset_status_id FROM asset_statuses
                         WHERE status_name='Active'),
       needs_retirement_review=IF(p_outcome='Beyond Repair',TRUE,
                                   needs_retirement_review)
       WHERE asset_id=v_asset_id;
    INSERT INTO request_updates(request_id,author_user_id,update_type,comment)
       VALUES(p_request_id,p_actor_id,'Closed','Repair finished and request closed');
    INSERT INTO notifications(user_id,request_id,notification_type,message)
       VALUES(v_requester,p_request_id,'Request Closed','Your service request was closed');
    COMMIT;
    SET @casms_actor_id=NULL;
END$$

DROP PROCEDURE IF EXISTS sp_retire_asset$$
CREATE PROCEDURE sp_retire_asset(
    IN p_asset_id INT UNSIGNED, IN p_reason TEXT, IN p_actor_id INT UNSIGNED)
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_status VARCHAR(30);
    DECLARE v_pending INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;
    SELECT MAX(ro.role_name) INTO v_role FROM users u JOIN roles ro
      ON ro.role_id=u.role_id WHERE u.user_id=p_actor_id AND u.is_active=TRUE;
    IF COALESCE(v_role,'')<>'Admin' OR TRIM(COALESCE(p_reason,''))='' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Admin and retirement reason required';
    END IF;
    SET @casms_actor_id=p_actor_id;
    START TRANSACTION;
    SELECT st.status_name INTO v_status FROM assets a
      JOIN asset_statuses st ON st.asset_status_id=a.asset_status_id
      WHERE a.asset_id=p_asset_id FOR UPDATE;
    IF v_status IS NULL OR v_status='Retired' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Asset missing or already retired';
    END IF;
    SELECT COUNT(*) INTO v_pending FROM service_requests r
      JOIN request_statuses st ON st.request_status_id=r.request_status_id
      WHERE r.asset_id=p_asset_id
        AND st.status_name NOT IN ('Closed','Cancelled');
    IF v_pending>0 THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Asset has pending requests';
    END IF;
    UPDATE asset_assignments SET assigned_to=CURDATE()
      WHERE asset_id=p_asset_id AND assigned_to IS NULL;
    UPDATE assets SET asset_status_id=(
        SELECT asset_status_id FROM asset_statuses WHERE status_name='Retired'),
        retirement_date=CURDATE(),retirement_reason=p_reason
      WHERE asset_id=p_asset_id;
    COMMIT;
    SET @casms_actor_id=NULL;
END$$

DROP PROCEDURE IF EXISTS sp_reopen_request$$
CREATE PROCEDURE sp_reopen_request(
    IN p_request_id INT UNSIGNED, IN p_actor_id INT UNSIGNED)
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_status VARCHAR(30);
    DECLARE v_closed DATETIME;
    DECLARE v_technician INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET @casms_actor_id=NULL; RESIGNAL; END;
    SELECT MAX(ro.role_name) INTO v_role FROM users u JOIN roles ro
      ON ro.role_id=u.role_id WHERE u.user_id=p_actor_id AND u.is_active=TRUE;
    IF COALESCE(v_role,'')<>'Admin' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only Admin can reopen';
    END IF;
    SET @casms_actor_id=p_actor_id;
    START TRANSACTION;
    SELECT st.status_name,r.closed_at,r.assigned_technician_id
      INTO v_status,v_closed,v_technician
      FROM service_requests r JOIN request_statuses st
      ON st.request_status_id=r.request_status_id
      WHERE r.request_id=p_request_id FOR UPDATE;
    IF v_status IS NULL OR v_status<>'Closed' OR v_closed IS NULL OR
       v_closed<DATE_SUB(NOW(),INTERVAL 7 DAY) OR v_technician IS NULL THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Request cannot be reopened';
    END IF;
    UPDATE service_requests SET request_status_id=(
       SELECT request_status_id FROM request_statuses WHERE status_name='Assigned'),
       closed_at=NULL,resolution_summary=NULL,
       reopen_count=reopen_count+1
      WHERE request_id=p_request_id;
    INSERT INTO request_updates(request_id,author_user_id,update_type,comment)
      VALUES(p_request_id,p_actor_id,'Reopened','Admin reopened request');
    COMMIT;
    SET @casms_actor_id=NULL;
END$$

DELIMITER ;

-- Expected: 4 functions and 6 procedures.
SELECT routine_type,COUNT(*) AS total
FROM information_schema.routines WHERE routine_schema='casms'
GROUP BY routine_type;
-- Tests are read-only. No procedure calls change existing data here.
SELECT fn_asset_total_maintenance_cost(MIN(asset_id)) AS example_asset_cost
FROM assets;
