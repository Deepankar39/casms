'use strict';
const express = require('express');
const { pool } = require('../config/db');
const { requestScope } = require('../middleware/auth');
const router = express.Router();
router.get('/', async (req, res, next) => {
  try {
    const scope = requestScope(req.user, 'r');
    let where = scope.sql;
    const params = [...scope.params];
    const status = String(req.query.status || '').trim().slice(0, 30);
    if (status) { where += ' AND st.status_name=?'; params.push(status); }
    const page = Math.max(1, Math.min(100000, Number.parseInt(req.query.page,10) || 1));
    const limit = 12;
    const from = `FROM service_requests r JOIN assets a ON a.asset_id=r.asset_id
      JOIN priorities p ON p.priority_id=r.priority_id
      JOIN request_statuses st ON st.request_status_id=r.request_status_id
      LEFT JOIN users t ON t.user_id=r.assigned_technician_id
      WHERE ${where}`;
    const [counts] = await pool.execute(`SELECT COUNT(*) AS total ${from}`, params);
    const [rows] = await pool.query(
      `SELECT r.request_id AS id, r.request_number AS number, r.title,
       a.asset_tag AS assetTag, st.status_name AS status,
       p.priority_name AS priority, t.full_name AS technician,
       r.raised_at AS raisedAt, r.due_at AS dueAt
       ${from} ORDER BY r.raised_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, (page-1)*limit]);
    res.json({ rows, total: counts[0].total, page, limit });
  } catch (err) { next(err); }
});
module.exports = router;
