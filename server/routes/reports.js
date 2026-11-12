'use strict';
// Batch 4: server-side, role-restricted reporting with safe CSV export.
const express = require('express');
const { pool } = require('../config/db');
const { assetScope, requestScope } = require('../middleware/auth');
const router = express.Router();
const MAX_EXPORT = 5000;

function problem(message, status = 400) { const err = new Error(message); err.status = status; throw err; }
function text(value, size = 100) { return String(value || '').trim().slice(0, size); }
function parseDate(value, label) {
  if (!value) return null;
  const s = String(value);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s) || Number.isNaN(Date.parse(s)) ||
      new Date(s).toISOString().slice(0, 10) !== s) problem(`Invalid ${label} date (YYYY-MM-DD).`);
  return s;
}
const reports = [
  { id: 'assets', label: 'Asset register', description: 'Inventory by location, category and status', audience: ['Admin','Staff','Technician'] },
  { id: 'requests', label: 'Service request queue', description: 'Due dates, priorities and ticket status', audience: ['Admin','Staff','Technician'] },
  { id: 'history', label: 'Maintenance history', description: 'Repair outcomes and labour/parts costs', audience: ['Admin','Staff','Technician'] },
  { id: 'category', label: 'Assets by category', description: 'Equipment distribution and purchase value', audience: ['Admin','Staff','Technician'] },
  { id: 'department', label: 'Department repair costs', description: 'Aggregate maintenance expense by department', audience: ['Admin'] },
  { id: 'monthly', label: 'Monthly repair costs', description: 'Maintenance spending trend by month', audience: ['Admin'] },
  { id: 'technicians', label: 'Technician workload', description: 'Open jobs and technician availability', audience: ['Admin'] },
  { id: 'warranties', label: 'Warranty register', description: 'Expired, active and expiring coverage', audience: ['Admin'] },
  { id: 'repeat', label: 'Repeat-failure assets', description: 'Assets with three or more tickets in 12 months', audience: ['Admin'] },
  { id: 'savings', label: 'Warranty cost allocation', description: 'Repairs covered by vendors versus college', audience: ['Admin'] }
];
const col = (key, label, kind = 'text') => ({ key, label, kind });
function buildReport(id, user, query) {
  const scopeA = assetScope(user, 'a');
  const scopeR = requestScope(user, 'r');
  const search = text(query.search, 80);
  const start = parseDate(query.from, 'From');
  const end = parseDate(query.to, 'To');
  if (start && end && start > end) problem('From date must not be after To date.');
  const filter = (where, params, expr) => {
    if (start) { where.push(`${expr} >= ?`); params.push(start + ' 00:00:00'); }
    if (end) { where.push(`${expr} < DATE_ADD(?, INTERVAL 1 DAY)`); params.push(end); }
  };
  switch (id) {
    case 'assets': {
      const w = [scopeA.sql], p = [...scopeA.params];
      if (search) { w.push('(a.asset_tag LIKE ? OR a.asset_name LIKE ?)'); p.push(`%${search}%`, `%${search}%`); }
      return { params:p, columns:[col('tag','Asset tag'),col('asset','Asset name'),col('category','Category'),col('department','Department'),col('building','Building'),col('room','Room'),col('status','Status'),col('purchaseCost','Purchase value','money')],
        sql:`SELECT a.asset_tag AS tag,a.asset_name AS asset,c.category_name AS category,d.department_code AS department,
          b.building_name AS building,rm.room_number AS room,st.status_name AS status,a.purchase_cost AS purchaseCost
          FROM assets a JOIN departments d ON d.department_id=a.department_id JOIN asset_categories c ON c.category_id=a.category_id
          JOIN asset_statuses st ON st.asset_status_id=a.asset_status_id LEFT JOIN rooms rm ON rm.room_id=a.room_id
          LEFT JOIN buildings b ON b.building_id=rm.building_id WHERE ${w.join(' AND ')} ORDER BY a.asset_id DESC` };
    }
    case 'requests': {
      const w=[scopeR.sql],p=[...scopeR.params];
      filter(w,p,'r.raised_at');
      if (search) { w.push('(r.request_number LIKE ? OR r.title LIKE ?)');p.push(`%${search}%`,`%${search}%`); }
      return {params:p,columns:[col('number','Ticket'),col('title','Issue'),col('asset','Asset'),col('priority','Priority'),col('status','Status'),col('technician','Technician'),col('raised','Raised','date'),col('due','Due','date')],
        sql:`SELECT r.request_number AS number,r.title,a.asset_tag AS asset,p.priority_name AS priority,
          s.status_name AS status,t.full_name AS technician,r.raised_at AS raised,r.due_at AS due
          FROM service_requests r JOIN assets a ON a.asset_id=r.asset_id
          JOIN request_statuses s ON s.request_status_id=r.request_status_id
          JOIN priorities p ON p.priority_id=r.priority_id LEFT JOIN users t ON t.user_id=r.assigned_technician_id
          WHERE ${w.join(' AND ')} ORDER BY r.raised_at DESC,r.request_id DESC`};
    }
    case 'history': {
      const w=[scopeR.sql],p=[...scopeR.params];filter(w,p,'h.end_date');
      if (search) {w.push('(h.asset_tag LIKE ? OR h.request_number LIKE ?)');p.push(`%${search}%`,`%${search}%`);}
      return {params:p,columns:[col('number','Ticket'),col('asset','Asset'),col('technician','Technician'),col('date','Completed','date'),col('outcome','Outcome'),col('labour','Labour','money'),col('parts','Parts','money'),col('total','Total','money')],
        sql:`SELECT h.request_number AS number,h.asset_tag AS asset,h.technician_name AS technician,h.end_date AS date,
        h.outcome,h.labour_cost AS labour,h.parts_cost AS parts,h.total_cost AS total
        FROM vw_service_history h JOIN service_requests r ON r.request_id=h.request_id
        WHERE ${w.join(' AND ')} ORDER BY h.end_date DESC,h.maintenance_id DESC`};
    }
    case 'category': {
      const w=[scopeA.sql],p=[...scopeA.params];
      return {params:p,columns:[col('category','Category'),col('assets','Assets','integer'),col('value','Purchase value','money')],
        sql:`SELECT c.category_name AS category,COUNT(*) AS assets,SUM(a.purchase_cost) AS value
        FROM assets a JOIN asset_categories c ON c.category_id=a.category_id
        WHERE ${w.join(' AND ')} GROUP BY c.category_id,c.category_name ORDER BY assets DESC,c.category_name`};
    }
    case 'department': return {params:[],columns:[col('department','Department'),col('repairs','Repairs','integer'),col('total','Total cost','money')],
      sql:'SELECT department_name AS department,total_repairs AS repairs,total_maintenance_cost AS total FROM vw_department_cost_summary ORDER BY total DESC,department'};
    case 'monthly': {
      const w=['h.end_date IS NOT NULL'],p=[];filter(w,p,'h.end_date');
      return {params:p,columns:[col('month','Month'),col('repairs','Repairs','integer'),col('total','Maintenance cost','money')],
        sql:`SELECT DATE_FORMAT(h.end_date,'%Y-%m') AS month,COUNT(*) AS repairs,SUM(h.total_cost) AS total
        FROM vw_service_history h WHERE ${w.join(' AND ')} GROUP BY DATE_FORMAT(h.end_date,'%Y-%m') ORDER BY month DESC`};
    }
    case 'technicians': return {params:[],columns:[col('name','Technician'),col('specialization','Specialization'),col('available','Available'),col('capacity','Capacity','integer'),col('openJobs','Open jobs','integer')],
      sql:'SELECT full_name AS name,specialization,IF(is_available=1,\'Yes\',\'No\') AS available,max_open_requests AS capacity,open_jobs AS openJobs FROM vw_technician_workload ORDER BY open DESC,name'};
    case 'warranties': return {params:[],columns:[col('asset','Asset'),col('coverage','Coverage'),col('expires','Expiry date','date'),col('remaining','Days remaining','integer'),col('status','Status')],
      sql:'SELECT asset_tag AS asset,coverage_type AS coverage,end_date AS expires,days_remaining AS remaining,warranty_status AS status FROM vw_warranty_status ORDER BY end_date ASC,warranty_id'};
    case 'repeat': return {params:[],columns:[col('asset','Asset'),col('name','Name'),col('failures','Requests (12 months)','integer')],
      sql:`SELECT a.asset_tag AS asset,a.asset_name AS name,COUNT(*) AS failures FROM assets a
      JOIN service_requests r ON r.asset_id=a.asset_id WHERE r.raised_at>=DATE_SUB(NOW(),INTERVAL 12 MONTH)
      GROUP BY a.asset_id,a.asset_tag,a.asset_name HAVING COUNT(*)>=3 ORDER BY failures DESC,asset`};
    case 'savings': return {params:[],columns:[col('coverage','Cost responsibility'),col('repairs','Repairs','integer'),col('total','Amount','money')],
      sql:`SELECT IF(h.warranty_covered=1,'Warranty covered','College paid') AS coverage,
      COUNT(*) AS repairs,SUM(h.total_cost) AS total FROM vw_service_history h
      GROUP BY h.warranty_covered ORDER BY coverage`};
    default: problem('Unknown report.',404);
  }
}
function csvValue(value) {
  if (value == null) return '""';
  let s = value instanceof Date ? value.toISOString().slice(0,19).replace('T',' ') : String(value);
  // Quoting alone does NOT neutralize spreadsheet formulas.
  if (/^[\s\x00-\x1f]*[=+\-@]/.test(s)) s = "'" + s;
  return '"' + s.replace(/"/g,'""') + '"';
}
async function execute(req,res,next,exportCsv=false) {
  try {
    const entry=reports.find(r=>r.id===req.params.id);
    if (!entry) problem('Unknown report.',404);
    if (!entry.audience.includes(req.user.role)) problem('This report is limited to administrators.',403);
    const {sql,params,columns}=buildReport(entry.id,req.user,req.query);
    if(exportCsv) {
      const [rows] = await pool.query(`${sql} LIMIT ?`,[...params,MAX_EXPORT+1]);
      if(rows.length>MAX_EXPORT) problem(`Export exceeds ${MAX_EXPORT} rows. Narrow your filters.`,413);
      const output='\uFEFF'+columns.map(c=>csvValue(c.label)).join(',')+'\r\n'+
        rows.map(row=>columns.map(c=>csvValue(row[c.key])).join(',')).join('\r\n')+'\r\n';
      res.set('Content-Type','text/csv; charset=utf-8');
      res.set('Content-Disposition',`attachment; filename="casms_${entry.id}.csv"`);
      return res.send(output);
    }
    const page=Math.min(100000,Math.max(1,Number.parseInt(req.query.page,10)||1));
    const limit=15;
    const [[{total}]]=await pool.query(`SELECT COUNT(*) AS total FROM (${sql}) AS report_count`,params);
    const [rows]=await pool.query(`${sql} LIMIT ? OFFSET ?`,[...params,limit,(page-1)*limit]);
    res.json({title:entry.label,description:entry.description,columns,rows,total,page,limit});
  } catch(err) {next(err);}
}
router.get('/catalog',(req,res)=>res.json({reports:reports.filter(r=>r.audience.includes(req.user.role))}));
router.get('/:id/export',(req,res,next)=>execute(req,res,next,true));
router.get('/:id',(req,res,next)=>execute(req,res,next,false));
module.exports=router;
