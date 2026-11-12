'use strict';
const { pool } = require('../config/db');

async function requireAuth(req, res, next) {
  const id = req.session?.userId;
  if (!id) return res.status(401).json({ error: 'Please sign in to continue.' });
  try {
    const [rows] = await pool.execute(
      `SELECT u.user_id AS id, u.full_name AS name, u.email,
              u.department_id AS departmentId, u.must_change_password AS mustChangePassword,
              ro.role_name AS role
       FROM users u JOIN roles ro ON ro.role_id=u.role_id
       WHERE u.user_id=? AND u.is_active=TRUE LIMIT 1`, [id]
    );
    if (!rows.length) {
      return req.session.destroy(() => res.status(401).json({ error: 'Session expired.' }));
    }
    req.user = rows[0];
    next();
  } catch (err) { next(err); }
}
function requireReady(req, res, next) {
  if (req.user.mustChangePassword) {
    return res.status(403).json({ error: 'Change your temporary password first.', code: 'PASSWORD_CHANGE_REQUIRED' });
  }
  next();
}
function roles(...allowed) {
  return (req, res, next) => allowed.includes(req.user.role) ? next() :
    res.status(403).json({ error: 'Not permitted for this role.' });
}
// Literal SQL fragments chosen only from authenticated server-side role.
// Parameters are always bound with mysql2, never assembled from user input.
function assetScope(user, alias='a') {
  if (user.role === 'Admin') return { sql: '1=1', params: [] };
  if (user.role === 'Staff') return {
    sql: `(${alias}.department_id=? OR EXISTS
      (SELECT 1 FROM asset_assignments aa WHERE aa.asset_id=${alias}.asset_id
       AND aa.assigned_user_id=? AND aa.assigned_to IS NULL))`,
    params: [user.departmentId, user.id]
  };
  return {
    sql: `EXISTS (SELECT 1 FROM service_requests q
      WHERE q.asset_id=${alias}.asset_id AND q.assigned_technician_id=?)`,
    params: [user.id]
  };
}
function requestScope(user, alias='r') {
  if (user.role === 'Admin') return { sql: '1=1', params: [] };
  return user.role === 'Staff'
    ? { sql: `${alias}.raised_by_user_id=?`, params: [user.id] }
    : { sql: `${alias}.assigned_technician_id=?`, params: [user.id] };
}
module.exports = { requireAuth, requireReady, roles, assetScope, requestScope };
