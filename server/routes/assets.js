'use strict';
const express = require('express');
const { pool } = require('../config/db');
const { assetScope } = require('../middleware/auth');
const router = express.Router();
function paging(query) {
  return {
    page: Math.max(1, Math.min(100000, parseInt(query.page,10) || 1)),
    limit: 12
  };
}
router.get('/', async (req, res, next) => {
  try {
    const { page, limit } = paging(req.query);
    const scope = assetScope(req.user, 'a');
    let sql = scope.sql;
    const params = [...scope.params];
    const search = String(req.query.search || '').trim().slice(0, 90);
    const status = String(req.query.status || '').trim().slice(0, 30);
    if (search) {
      sql += ' AND (a.asset_tag LIKE ? OR a.asset_name LIKE ? OR c.category_name LIKE ?)';
      params.push(...Array(3).fill(`%${search}%`));
    }
    if (status) { sql += ' AND st.status_name=?'; params.push(status); }
    const from = `FROM assets a
      JOIN departments d ON a.department_id=d.department_id
      JOIN asset_categories c ON a.category_id=c.category_id
      JOIN asset_statuses st ON a.asset_status_id=st.asset_status_id
      LEFT JOIN rooms rm ON a.room_id=rm.room_id WHERE ${sql}`;
    const [totals] = await pool.execute(`SELECT COUNT(*) AS total ${from}`, params);
    const [rows] = await pool.query(
      `SELECT a.asset_id AS id, a.asset_tag AS tag, a.asset_name AS name,
              d.department_code AS department, c.category_name AS category,
              st.status_name AS status, rm.room_number AS room, a.purchase_cost AS purchaseCost
       ${from} ORDER BY a.asset_id DESC LIMIT ? OFFSET ?`,
      [...params, limit, (page-1)*limit]
    );
    res.json({ rows, total: totals[0].total, page, limit });
  } catch (err) { next(err); }
});
module.exports = router;
