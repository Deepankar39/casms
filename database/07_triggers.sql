-- CASMS Phase 3 | 07_triggers.sql | MySQL 8.0.46
-- Create AFTER 05_views.sql and 06_functions_procedures.sql.
USE casms;
DELIMITER $$

-- ASSETS: valid lifecycle and no parent-child cycles.
DROP TRIGGER IF EXISTS trg_assets_before_update$$
CREATE TRIGGER trg_assets_before_update BEFORE UPDATE ON assets
FOR EACH ROW
BEGIN
    DECLARE v_old VARCHAR(30);
    DECLARE v_new VARCHAR(30);
    DECLARE v_parent INT UNSIGNED;
    DECLARE v_next INT UNSIGNED;
    DECLARE v_depth INT DEFAULT 0;
    SELECT status_name INTO v_old FROM asset_statuses
      WHERE asset_status_id=OLD.asset_status_id;
    SELECT status_name INTO v_new FROM asset_statuses
      WHERE asset_status_id=NEW.asset_status_id;
    IF v_old='Retired' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Retired assets cannot be modified';
    END IF;
    IF v_old<>v_new AND NOT (
       (v_old='In Stock' AND v_new IN ('Active','Retired')) OR
       (v_old='Active' AND v_new IN ('Under Repair','Retired')) OR
       (v_old='Under Repair' AND v_new IN ('Active','Retired'))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid asset status transition';
    END IF;
    SET v_parent=NEW.parent_asset_id;
    WHILE v_parent IS NOT NULL DO
        IF v_parent=NEW.asset_id THEN
           SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cyclic asset hierarchy';
        END IF;
        SET v_depth=v_depth+1;
        IF v_depth>100 THEN
           SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Asset hierarchy too deep';
        END IF;
        SET v_next=NULL;
        SELECT MAX(parent_asset_id) INTO v_next FROM assets
          WHERE asset_id=v_parent;
        SET v_parent=v_next;
    END WHILE;
END$$

DROP TRIGGER IF EXISTS trg_assets_before_insert$$
CREATE TRIGGER trg_assets_before_insert BEFORE INSERT ON assets
FOR EACH ROW
BEGIN
    IF NEW.parent_asset_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='Set parent only after registering the asset';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_assets_after_insert$$
CREATE TRIGGER trg_assets_after_insert AFTER INSERT ON assets
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by_user_id)
    VALUES('assets',CAST(NEW.asset_id AS CHAR),'INSERT',
       JSON_OBJECT('tag',NEW.asset_tag,'status_id',NEW.asset_status_id,
                   'department_id',NEW.department_id),@casms_actor_id);
END$$

DROP TRIGGER IF EXISTS trg_assets_after_update$$
CREATE TRIGGER trg_assets_after_update AFTER UPDATE ON assets
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name,record_id,action,old_values,new_values,changed_by_user_id)
    VALUES('assets',CAST(NEW.asset_id AS CHAR),'UPDATE',
       JSON_OBJECT('status_id',OLD.asset_status_id,'room_id',OLD.room_id,
                   'department_id',OLD.department_id,'parent_id',OLD.parent_asset_id),
       JSON_OBJECT('status_id',NEW.asset_status_id,'room_id',NEW.room_id,
                   'department_id',NEW.department_id,'parent_id',NEW.parent_asset_id),
       @casms_actor_id);
END$$

-- ASSIGNMENTS: no retired assets and preserve historical closures.
DROP TRIGGER IF EXISTS trg_assignments_before_insert$$
CREATE TRIGGER trg_assignments_before_insert BEFORE INSERT ON asset_assignments
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM assets a JOIN asset_statuses s
        ON s.asset_status_id=a.asset_status_id
        WHERE a.asset_id=NEW.asset_id AND s.status_name='Retired') THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot assign a retired asset';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_assignments_before_update$$
CREATE TRIGGER trg_assignments_before_update BEFORE UPDATE ON asset_assignments
FOR EACH ROW
BEGIN
    IF OLD.assigned_to IS NOT NULL AND NOT (NEW.assigned_to <=> OLD.assigned_to) THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot change closed assignment';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_assignments_after_insert$$
CREATE TRIGGER trg_assignments_after_insert AFTER INSERT ON asset_assignments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by_user_id)
    VALUES('asset_assignments',CAST(NEW.assignment_id AS CHAR),'INSERT',
       JSON_OBJECT('asset_id',NEW.asset_id,'user_id',NEW.assigned_user_id,
                   'assigned_from',NEW.assigned_from),
       COALESCE(@casms_actor_id,NEW.assigned_by_user_id));
END$$

DROP TRIGGER IF EXISTS trg_assignments_after_update$$
CREATE TRIGGER trg_assignments_after_update AFTER UPDATE ON asset_assignments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name,record_id,action,old_values,new_values,changed_by_user_id)
    VALUES('asset_assignments',CAST(NEW.assignment_id AS CHAR),'UPDATE',
       JSON_OBJECT('assigned_to',OLD.assigned_to),
       JSON_OBJECT('assigned_to',NEW.assigned_to),@casms_actor_id);
END$$

-- REQUESTS: reject retired assets and unauthorized staff submissions.
DROP TRIGGER IF EXISTS trg_requests_before_insert$$
CREATE TRIGGER trg_requests_before_insert BEFORE INSERT ON service_requests
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(30);
    DECLARE v_dept INT UNSIGNED;
    IF NOT EXISTS (SELECT 1 FROM assets a JOIN asset_statuses s
       ON s.asset_status_id=a.asset_status_id
       WHERE a.asset_id=NEW.asset_id AND s.status_name<>'Retired') THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid or retired asset';
    END IF;
    SELECT MAX(ro.role_name),MAX(u.department_id)
       INTO v_role,v_dept FROM users u JOIN roles ro
       ON ro.role_id=u.role_id WHERE u.user_id=NEW.raised_by_user_id
       AND u.is_active=TRUE;
    IF v_role IS NULL OR v_role='Technician' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='User cannot raise requests';
    END IF;
    IF v_role='Staff' AND NOT EXISTS (
       SELECT 1 FROM assets a WHERE a.asset_id=NEW.asset_id AND
       (a.department_id=v_dept OR EXISTS (
           SELECT 1 FROM asset_assignments aa
           WHERE aa.asset_id=a.asset_id
             AND aa.assigned_user_id=NEW.raised_by_user_id
             AND aa.assigned_to IS NULL))
    ) THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Staff cannot request another department asset';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_requests_before_update$$
CREATE TRIGGER trg_requests_before_update BEFORE UPDATE ON service_requests
FOR EACH ROW
BEGIN
    DECLARE v_old VARCHAR(30);
    DECLARE v_new VARCHAR(30);
    DECLARE v_actor_role VARCHAR(30);
    SELECT status_name INTO v_old FROM request_statuses
      WHERE request_status_id=OLD.request_status_id;
    SELECT status_name INTO v_new FROM request_statuses
      WHERE request_status_id=NEW.request_status_id;
    IF v_old='Cancelled' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cancelled request is final';
    END IF;
    IF v_old<>v_new AND NOT (
       (v_old='Open' AND v_new IN ('Assigned','Cancelled')) OR
       (v_old='Assigned' AND v_new IN ('In Progress','Cancelled')) OR
       (v_old='In Progress' AND v_new IN ('On Hold','Closed')) OR
       (v_old='On Hold' AND v_new='In Progress') OR
       (v_old='Closed' AND v_new='Assigned')
    ) THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid request status transition';
    END IF;
    IF v_old='Closed' THEN
        IF v_new='Assigned' THEN
            SELECT MAX(ro.role_name) INTO v_actor_role FROM users u
              JOIN roles ro ON ro.role_id=u.role_id
              WHERE u.user_id=@casms_actor_id AND u.is_active=TRUE;
            IF COALESCE(v_actor_role,'')<>'Admin' OR OLD.closed_at IS NULL OR
               OLD.closed_at<DATE_SUB(NOW(),INTERVAL 7 DAY) OR
               NEW.reopen_count<>OLD.reopen_count+1 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Admin can reopen within 7 days only';
            END IF;
        ELSEIF NOT (
           NEW.asset_id<=>OLD.asset_id AND
           NEW.raised_by_user_id<=>OLD.raised_by_user_id AND
           NEW.assigned_technician_id<=>OLD.assigned_technician_id AND
           NEW.priority_id<=>OLD.priority_id AND
           NEW.title<=>OLD.title AND NEW.description<=>OLD.description AND
           NEW.closed_at<=>OLD.closed_at AND
           NEW.resolution_summary<=>OLD.resolution_summary AND
           NEW.reopen_count<=>OLD.reopen_count
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Closed request is read-only except feedback';
        END IF;
    END IF;
    IF v_new IN ('Assigned','In Progress','On Hold','Closed')
       AND NEW.assigned_technician_id IS NULL THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned technician required';
    END IF;
    IF NOT (NEW.assigned_technician_id <=> OLD.assigned_technician_id)
      AND NEW.assigned_technician_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM users u JOIN roles ro ON ro.role_id=u.role_id
        JOIN technician_profiles tp ON tp.user_id=u.user_id
        WHERE u.user_id=NEW.assigned_technician_id
          AND u.is_active=TRUE AND tp.is_available=TRUE
          AND ro.role_name='Technician') THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid technician assignment';
    END IF;
    IF v_new='Closed' AND v_old<>'Closed' AND NOT EXISTS (
       SELECT 1 FROM maintenance_records m WHERE m.request_id=OLD.request_id
    ) THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Maintenance required before closure';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_requests_after_insert$$
CREATE TRIGGER trg_requests_after_insert AFTER INSERT ON service_requests
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by_user_id)
    VALUES('service_requests',CAST(NEW.request_id AS CHAR),'INSERT',
       JSON_OBJECT('asset_id',NEW.asset_id,'status_id',NEW.request_status_id),
       COALESCE(@casms_actor_id,NEW.raised_by_user_id));
END$$

DROP TRIGGER IF EXISTS trg_requests_after_update$$
CREATE TRIGGER trg_requests_after_update AFTER UPDATE ON service_requests
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(table_name,record_id,action,old_values,new_values,changed_by_user_id)
    VALUES('service_requests',CAST(NEW.request_id AS CHAR),'UPDATE',
       JSON_OBJECT('status_id',OLD.request_status_id,
          'technician_id',OLD.assigned_technician_id),
       JSON_OBJECT('status_id',NEW.request_status_id,
          'technician_id',NEW.assigned_technician_id),@casms_actor_id);
END$$

DROP TRIGGER IF EXISTS trg_audit_before_update$$
CREATE TRIGGER trg_audit_before_update BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Audit history is append-only';
END$$

DROP TRIGGER IF EXISTS trg_audit_before_delete$$
CREATE TRIGGER trg_audit_before_delete BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Audit history cannot be deleted';
END$$

DELIMITER ;

SELECT COUNT(*) AS casms_triggers
FROM information_schema.triggers
WHERE trigger_schema='casms';
-- Expected: 14 triggers. (If modified, check actual count.)
