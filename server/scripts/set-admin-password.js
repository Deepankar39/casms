'use strict';
// One-time local development bootstrap: prints temporary password once.
// Does not store or log it anywhere else. Never run on production data.
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');
(async () => {
  try {
    const [rows] = await pool.execute(
      `SELECT u.user_id FROM users u JOIN roles ro ON ro.role_id=u.role_id
       WHERE u.employee_code='EMP001' AND ro.role_name='Admin' AND u.is_active=TRUE LIMIT 1`);
    if (!rows.length) throw new Error('Active demo Admin EMP001 not found; verify 02_seed.sql.');
    const password = crypto.randomBytes(15).toString('base64url');
    const hash = await bcrypt.hash(password, 12);
    await pool.execute(
      'UPDATE users SET password_hash=?, must_change_password=TRUE WHERE user_id=?',
      [hash, rows[0].user_id]);
    console.log('\nAdmin login: emp001@casms.example.test');
    console.log('One-time temporary password:', password);
    console.log('Sign in and change this password immediately. Keep it private.\n');
  } catch (err) {
    console.error('Setup failed:', err.message);
    process.exitCode = 1;
  } finally { await pool.end(); }
})();
