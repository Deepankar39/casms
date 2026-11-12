'use strict';
const express = require('express');
const { pool } = require('../config/db');
const { assetScope, requestScope } = require('../middleware/auth');
const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const a = assetScope(req.user);
    const r = requestScope(req.user);
    const [assetRows] = await pool.execute(
      `SELECT COUNT(*) AS total FROM assets a WHERE ${a.sql}`, a.params);
    const [requestRows] = await pool.execute(
      `SELECT COUNT(*) AS total,
         COALESCE(SUM(st.status_name NOT IN ('Closed','Cancelled')),0) AS pending,
         COALESCE(SUM(st.status_name='Closed'),0) AS closed,
         COALESCE(SUM(st.status_name NOT IN ('Closed','Cancelled') AND sr.due_at<NOW()),0) AS overdue
       FROM service_requests sr JOIN request_statuses st ON st.request_status_id=sr.request_status_id
       WHERE ${r.sql.replaceAll('r.', 'sr.')}`, r.params);
    const [statusRows] = await pool.execute(
      `SELECT st.status_name AS name, COUNT(*) AS total
       FROM service_requests sr JOIN request_statuses st ON st.request_status_id=sr.request_status_id
       WHERE ${r.sql.replaceAll('r.', 'sr.')}
       GROUP BY st.request_status_id, st.status_name ORDER BY total DESC`, r.params);
    const [recentRows] = await pool.execute(
      `SELECT sr.request_id AS id, sr.request_number AS number, sr.title,
              st.status_name AS status, p.priority_name AS priority, sr.raised_at AS raisedAt
       FROM service_requests sr
       JOIN request_statuses st ON sr.request_status_id=st.request_status_id
       JOIN priorities p ON sr.priority_id=p.priority_id
       WHERE ${r.sql.replaceAll('r.', 'sr.')}
       ORDER BY sr.raised_at DESC LIMIT 6`, r.params);
    let spend = null;
    if (req.user.role === 'Admin') {
      const [rows] = await pool.execute('SELECT COALESCE(SUM(total_maintenance_cost),0) AS total FROM vw_department_cost_summary');
      spend = rows[0].total;
    }
    res.json({
      stats: { assets: assetRows[0].total, requests: requestRows[0].total,
        pending: Number(requestRows[0].pending), closed: Number(requestRows[0].closed),
        overdue: Number(requestRows[0].overdue), spend },
      statuses: statusRows.map(x => ({ name: x.name, total: x.total })),
      recent: recentRows
    });
  } catch (err) { next(err); }
});
module.exports = router;
