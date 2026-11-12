'use strict';
// CASMS Phase 5 Batch 3: role-controlled service workflow.
// All SQL uses bound parameters, and multi-step changes share one connection.
const express = require('express');
const crypto = require('crypto');
const { pool } = require('../config/db');
const { roles, requestScope, assetScope } = require('../middleware/auth');
const router = express.Router();

function reject(message, status = 400) { const e = new Error(message); e.status = status; throw e; }
function positive(value, label='ID') {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) reject(`Invalid ${label}.`);
  return n;
}
function string(value, label, maximum, required=true) {
  if (typeof value !== 'string') { if (!required && (value == null || value === '')) return null; reject(`${label} is required.`); }
  const v = value.trim();
  if (v.length > maximum || (required && !v)) reject(`Enter a valid ${label.toLowerCase()} (maximum ${maximum} characters).`);
  return v || null;
}
function money(value, label='Cost') {
  const s = String(value ?? '');
  if (!/^\d{1,10}(\.\d{1,2})?$/.test(s)) reject(`${label} must be a non-negative amount with at most two decimal places.`);
  const n = Number(s);
  if (n > 9999999999.99) reject(`${label} is too large.`);
  return n;
}
function mysqlDateTime(value, label) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?$/.test(value)) reject(`Enter a valid ${label}.`);
  const v = value.replace('T', ' ');
  const d = new Date(v.replace(' ', 'T'));
  if (Number.isNaN(d.getTime())) reject(`Enter a valid ${label}.`);
  return v.length === 16 ? v + ':00' : v;
}
async function requestFor(id, user, db=pool, lock=false) {
  const scope = requestScope(user,'r');
  // Lock only the request row; avoid locking nullable LEFT JOIN tables.
  if(lock){
    const [locked]=await db.execute(`SELECT r.request_id FROM service_requests r WHERE r.request_id=? AND ${scope.sql} FOR UPDATE`,[id,...scope.params]);
    if(!locked.length)return null;
  }
  const [rows] = await db.execute(`SELECT r.request_id AS id, r.request_number AS number,
      r.asset_id AS assetId, a.asset_tag AS assetTag, a.asset_name AS assetName,
      a.department_id AS assetDepartmentId, ast.status_name AS assetStatus,
      r.title, r.description, r.raised_by_user_id AS requesterId,
      requester.full_name AS requester, r.assigned_technician_id AS technicianId,
      t.full_name AS technician, st.status_name AS status, r.priority_id AS priorityId,
      pr.priority_name AS priority, r.raised_at AS raisedAt, r.due_at AS dueAt,
      r.assigned_at AS assignedAt, r.started_at AS startedAt,
      r.closed_at AS closedAt, r.resolution_summary AS resolution,
      r.cancellation_reason AS cancellationReason, r.reopen_count AS reopenCount,
      r.feedback_rating AS feedbackRating, r.feedback_comment AS feedbackComment
    FROM service_requests r
    JOIN assets a ON a.asset_id=r.asset_id
    JOIN asset_statuses ast ON ast.asset_status_id=a.asset_status_id
    JOIN users requester ON requester.user_id=r.raised_by_user_id
    JOIN request_statuses st ON st.request_status_id=r.request_status_id
    JOIN priorities pr ON pr.priority_id=r.priority_id
    LEFT JOIN users t ON t.user_id=r.assigned_technician_id
    WHERE r.request_id=? AND ${scope.sql} LIMIT 1`,
  [id, ...scope.params]);
  return rows[0] || null;
}
async function withTransaction(actor, fn) {
  const c = await pool.getConnection();
  try {
    await c.beginTransaction();
    await c.query('SET @casms_actor_id=?', [actor]);
    const result = await fn(c);
    await c.commit();
    return result;
  } catch (e) {
    try { await c.rollback(); } catch (_) { /* preserve original failure */ }
    throw e;
  } finally {
    try { await c.query('SET @casms_actor_id=NULL'); } finally { c.release(); }
  }
}
async function withProcedure(fn) {
  const c = await pool.getConnection();
  try { return await fn(c); }
  finally { try { await c.query('SET @casms_actor_id=NULL'); } finally { c.release(); } }
}

// Only assets the current user can report are offered as choices.
router.get('/lookups', async (req,res,next) => {
  try {
    const [priorities] = await pool.query('SELECT priority_id AS id,priority_name AS name,target_hours AS targetHours FROM priorities ORDER BY target_hours');
    const aScope = assetScope(req.user,'a');
    let assets=[];
    if (req.user.role !== 'Technician') {
      const [rows] = await pool.execute(`SELECT a.asset_id AS id,a.asset_tag AS tag,a.asset_name AS name
        FROM assets a JOIN asset_statuses st ON a.asset_status_id=st.asset_status_id
        WHERE ${aScope.sql} AND st.status_name <> 'Retired' ORDER BY a.asset_tag LIMIT 1000`,aScope.params);
      assets=rows;
    }
    let technicians=[];
    if(req.user.role === 'Admin') {
      const [rows]=await pool.query(`SELECT u.user_id AS id,u.full_name AS name,tp.max_open_requests AS maxOpen
        FROM users u JOIN roles r ON r.role_id=u.role_id
        JOIN technician_profiles tp ON tp.user_id=u.user_id
        WHERE u.is_active=1 AND tp.is_available=1 AND r.role_name='Technician' ORDER BY u.full_name`);
      technicians=rows;
    }
    res.json({priorities,assets,technicians});
  } catch(e) { next(e); }
});

router.post('/', roles('Admin','Staff'), async (req,res,next) => {
  try {
    const assetId=positive(req.body?.assetId, 'asset');
    const priorityId=positive(req.body?.priorityId, 'priority');
    const title=string(req.body?.title,'Title',200);
    const description=string(req.body?.description,'Description',5000);
    const allowDuplicate=req.body?.allowDuplicate === true;
    const created=await withTransaction(req.user.id, async c=>{
      const aScope=assetScope(req.user,'a');
      const [assets]=await c.execute(`SELECT a.asset_id,st.status_name AS status
        FROM assets a JOIN asset_statuses st ON st.asset_status_id=a.asset_status_id
        WHERE a.asset_id=? AND ${aScope.sql} FOR UPDATE`,[assetId,...aScope.params]);
      if(!assets.length || assets[0].status==='Retired')reject('This asset cannot receive a request.',403);
      const [ps]=await c.execute('SELECT target_hours FROM priorities WHERE priority_id=?',[priorityId]);
      if(!ps.length)reject('Select a valid priority.');
      const [existing]=await c.execute(`SELECT r.request_number FROM service_requests r
        JOIN request_statuses st ON st.request_status_id=r.request_status_id
        WHERE r.asset_id=? AND st.status_name NOT IN ('Closed','Cancelled') LIMIT 1`,[assetId]);
      if(existing.length && !allowDuplicate)reject(`Active request ${existing[0].request_number} already exists for this asset. Confirm to continue.`,409);
      const number='WEB-'+crypto.randomUUID().replaceAll('-','').slice(0,24).toUpperCase();
      const [result]=await c.execute(`INSERT INTO service_requests
        (request_number,asset_id,raised_by_user_id,request_status_id,priority_id,title,description,due_at)
        VALUES (?,?,?,(SELECT request_status_id FROM request_statuses WHERE status_name='Open'),
          ?,?,?, DATE_ADD(NOW(), INTERVAL ? HOUR))`,
        [number,assetId,req.user.id,priorityId,title,description,ps[0].target_hours]);
      await c.execute(`INSERT INTO request_updates (request_id,author_user_id,update_type,comment)
        VALUES(?,?,'Created','Service request raised')`,[result.insertId,req.user.id]);
      return {id:result.insertId,number};
    });
    res.status(201).json({ok:true,...created});
  } catch(e) {next(e);}
});

router.get('/:id', async (req,res,next) => {
  try {
    const id=positive(req.params.id,'request ID');
    const request=await requestFor(id,req.user);
    if(!request)return res.status(404).json({error:'Request not found or not permitted.'});
    const [timeline]=await pool.execute(`SELECT u.update_id AS id,u.update_type AS type,u.comment,
      u.old_value AS oldValue,u.new_value AS newValue,u.created_at AS createdAt,
      writer.full_name AS author
      FROM request_updates u JOIN users writer ON writer.user_id=u.author_user_id
      WHERE u.request_id=? ORDER BY u.created_at DESC,u.update_id DESC`,[id]);
    const [maintenance]=await pool.execute(`SELECT m.maintenance_id AS id,m.maintenance_type AS type,m.diagnosis,
      m.work_performed AS workPerformed,m.start_date AS startAt,m.end_date AS endAt,
      m.labour_cost AS labourCost,m.outcome,m.warranty_covered AS warrantyCovered,
      t.full_name AS technician
      FROM maintenance_records m JOIN users t ON m.technician_id=t.user_id
      WHERE m.request_id=? ORDER BY m.maintenance_id DESC`,[id]);
    const [parts]=await pool.execute(`SELECT p.maintenance_id AS maintenanceId,p.part_name AS name,
      p.quantity,p.unit_cost AS unitCost FROM maintenance_parts p
      JOIN maintenance_records m ON m.maintenance_id=p.maintenance_id WHERE m.request_id=? ORDER BY p.part_id`,[id]);
    res.json({request,timeline,maintenance:maintenance.map(m=>({...m,parts:parts.filter(p=>p.maintenanceId===m.id)}))});
  } catch(e) {next(e);}
});

router.post('/:id/assign', roles('Admin'), async (req,res,next) => {
  try {
    const id=positive(req.params.id,'request ID'), techId=positive(req.body?.technicianId,'technician');
    if(!await requestFor(id,req.user))reject('Request not found.',404);
    await withProcedure(c=>c.query('CALL sp_assign_technician(?,?,?)',[id,techId,req.user.id]));
    res.json({ok:true});
  } catch(e) {next(e);}
});

router.post('/:id/status', roles('Admin','Technician'), async (req,res,next) => {
  try {
    const id=positive(req.params.id,'request ID');
    const nextStatus=string(req.body?.status,'Status',30);
    if(!['In Progress','On Hold'].includes(nextStatus))reject('This status cannot be set manually.');
    await withTransaction(req.user.id,async c=>{
      const r=await requestFor(id,req.user,c,true);
      if(!r)reject('Request not found or not assigned to you.',404);
      if(!r.technicianId)reject('Assign a technician first.');
      const allowed=(r.status==='Assigned'&&nextStatus==='In Progress') ||
        (r.status==='In Progress'&&nextStatus==='On Hold') ||
        (r.status==='On Hold'&&nextStatus==='In Progress');
      if(!allowed)reject(`Cannot change ${r.status} to ${nextStatus}.`);
      if(nextStatus==='In Progress'){
        const [busy]=await c.execute(`SELECT request_id FROM service_requests WHERE asset_id=? AND request_id<>?
          AND request_status_id IN (SELECT request_status_id FROM request_statuses
          WHERE status_name IN ('In Progress','On Hold')) LIMIT 1`,[r.assetId,id]);
        if(busy.length)reject('Another active repair is already underway for this asset.');
        const [[asset]]=await c.execute('SELECT a.asset_id, st.status_name AS status FROM assets a JOIN asset_statuses st ON st.asset_status_id=a.asset_status_id WHERE a.asset_id=? FOR UPDATE',[r.assetId]);
        if(!['Active','Under Repair'].includes(asset.status))reject('Activate the asset before beginning repair.');
        if(asset.status==='Active')await c.execute(`UPDATE assets SET asset_status_id=(SELECT asset_status_id FROM asset_statuses WHERE status_name='Under Repair') WHERE asset_id=?`,[r.assetId]);
      }
      await c.execute(`UPDATE service_requests SET request_status_id=
        (SELECT request_status_id FROM request_statuses WHERE status_name=?),
        started_at=IF(?='In Progress',COALESCE(started_at,NOW()),started_at)
        WHERE request_id=?`,[nextStatus,nextStatus,id]);
      await c.execute(`INSERT INTO request_updates (request_id,author_user_id,update_type,old_value,new_value,comment)
        VALUES(?,?,'Status Change',?,?,?)`,[id,req.user.id,r.status,nextStatus,`Status changed to ${nextStatus}`]);
      await c.execute(`INSERT INTO notifications(user_id,request_id,notification_type,message)
        VALUES(?,?,'Status Changed',?)`,[r.requesterId,id,`Request ${r.number}: ${nextStatus}`]);
    });
    res.json({ok:true});
  } catch(e) {next(e);}
});

router.post('/:id/comments',async(req,res,next)=>{
  try {
    const id=positive(req.params.id,'request ID');
    const comment=string(req.body?.comment,'Comment',2000);
    await withTransaction(req.user.id, async c=>{
      const r=await requestFor(id,req.user,c,true);
      if(!r)reject('Request not found or not permitted.',404);
      if(['Cancelled','Closed'].includes(r.status))reject('This request no longer accepts comments.');
      await c.execute(`INSERT INTO request_updates(request_id,author_user_id,update_type,comment)
        VALUES(?,?,'Comment',?)`,[id,req.user.id,comment]);
      if(req.user.id!==r.requesterId){
        await c.execute(`INSERT INTO notifications(user_id,request_id,notification_type,message)
          VALUES(?,?,'Comment Added',?)`,[r.requesterId,id,`New comment on ${r.number}`]);
      }
    });
    res.json({ok:true});
  }catch(e){next(e);}
});

router.post('/:id/cancel',roles('Admin','Staff'),async(req,res,next)=>{
  try {
    const id=positive(req.params.id,'request ID'),reason=string(req.body?.reason,'Cancellation reason',1000);
    await withTransaction(req.user.id,async c=>{
      const r=await requestFor(id,req.user,c,true);
      if(!r)reject('Request not found or not permitted.',404);
      if(!['Open','Assigned'].includes(r.status)||(req.user.role==='Staff'&&r.status!=='Open'))reject('This request cannot be cancelled now.');
      await c.execute(`UPDATE service_requests SET request_status_id=
        (SELECT request_status_id FROM request_statuses WHERE status_name='Cancelled'),cancellation_reason=? WHERE request_id=?`,[reason,id]);
      await c.execute(`INSERT INTO request_updates(request_id,author_user_id,update_type,comment)
        VALUES(?,?,'Cancelled',?)`,[id,req.user.id,reason]);
      if(req.user.id!==r.requesterId)await c.execute(`INSERT INTO notifications(user_id,request_id,notification_type,message)
        VALUES(?,?,'Request Cancelled',?)`,[r.requesterId,id,`Request ${r.number} was cancelled`]);
    });
    res.json({ok:true});
  }catch(e){next(e);}
});

router.post('/:id/close',roles('Admin','Technician'),async(req,res,next)=>{
  try {
    const id=positive(req.params.id,'request ID');
    const diagnosis=string(req.body?.diagnosis,'Diagnosis',5000);
    const work=string(req.body?.workPerformed,'Work performed',5000);
    const start=mysqlDateTime(req.body?.startAt,'start time');
    const end=mysqlDateTime(req.body?.endAt,'end time');
    const cost=money(req.body?.labourCost,'Labour cost');
    const outcome=string(req.body?.outcome,'Outcome',50);
    if(!['Repaired','Beyond Repair','Replaced'].includes(outcome))reject('Choose a valid outcome.');
    if(typeof req.body?.warrantyCovered!=='boolean')reject('Select warranty coverage.');
    const list=req.body?.parts;
    if(!Array.isArray(list)||list.length>30)reject('Parts must be an array of no more than 30 items.');
    const parts=list.map((p,i)=>({
      part_name:string(p?.name,`Part ${i+1} name`,150),
      quantity:positive(p?.quantity,'part quantity'),
      unit_cost:money(p?.unitCost,'Part unit cost')
    }));
    if(!await requestFor(id,req.user))reject('Request not found or not permitted.',404);
    await withProcedure(c=>c.query('CALL sp_close_service_request(?,?,?,?,?,?,?,?,?,?)',
      [id,req.user.id,diagnosis,work,start,end,cost,outcome,req.body.warrantyCovered,JSON.stringify(parts)]));
    res.json({ok:true});
  }catch(e){next(e);}
});

router.post('/:id/reopen',roles('Admin'),async(req,res,next)=>{
  try {
    const id=positive(req.params.id,'request ID');
    if(!await requestFor(id,req.user))reject('Request not found.',404);
    await withProcedure(c=>c.query('CALL sp_reopen_request(?,?)',[id,req.user.id]));
    res.json({ok:true});
  }catch(e){next(e);}
});

router.post('/:id/feedback',roles('Staff'),async(req,res,next)=>{
  try {
    const id=positive(req.params.id,'request ID'), rating=positive(req.body?.rating,'rating');
    if(rating>5)reject('Rating must be from 1 to 5.');
    const comment=string(req.body?.comment ?? '', 'Feedback',1000,false);
    await withTransaction(req.user.id,async c=>{
      const r=await requestFor(id,req.user,c,true);
      if(!r)reject('Request not found or not permitted.',404);
      if(r.status!=='Closed')reject('Feedback is available after closure.');
      if(r.feedbackRating!==null)reject('Feedback has already been submitted.');
      await c.execute('UPDATE service_requests SET feedback_rating=?,feedback_comment=? WHERE request_id=?',[rating,comment,id]);
      await c.execute(`INSERT INTO request_updates(request_id,author_user_id,update_type,comment)
        VALUES(?,?,'Feedback',?)`,[id,req.user.id,`Rating ${rating}/5`]);
    });
    res.json({ok:true});
  }catch(e){next(e);}
});

module.exports=router;
