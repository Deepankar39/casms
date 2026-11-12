'use strict';
const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const { rateLimit } = require('express-rate-limit');
const { pool } = require('../config/db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
const loginLimit = rateLimit({
  windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: 'draft-7',
  legacyHeaders: false, skipSuccessfulRequests: true,
  message: { error: 'Too many attempts. Please wait 15 minutes.' }
});
const validation = res => {
  const result = validationResult(res);
  return result.isEmpty() ? null : result.array()[0].msg;
};

router.post('/login', loginLimit,
  body('email').isEmail().withMessage('Enter a valid email address.'),
  body('password').isString().notEmpty().withMessage('Password is required.'),
  async (req, res, next) => {
    try {
      const invalid = validation(req);
      if (invalid) return res.status(400).json({ error: invalid });
      const [rows] = await pool.execute(
        `SELECT u.user_id, u.password_hash, u.is_active
         FROM users u WHERE u.email=? LIMIT 1`,
        [req.body.email.trim().toLowerCase()]
      );
      const user = rows[0];
      if (!user || !user.is_active || !(await bcrypt.compare(req.body.password, user.password_hash))) {
        return res.status(401).json({ error: 'Invalid email or password.' });
      }
      req.session.regenerate(err => {
        if (err) return next(err);
        req.session.userId = user.user_id;
        req.session.save(err2 => err2 ? next(err2) : res.json({ ok: true }));
      });
      // Login tracking is intentionally not written here to avoid hiding
      // a successful authentication behind an unrelated database error.
    } catch (err) { next(err); }
  }
);
router.get('/me', requireAuth, (req, res) => res.json({ user: req.user }));
router.post('/change-password', requireAuth,
  body('currentPassword').isString().notEmpty(),
  body('newPassword').isString().isLength({ min: 12, max: 72 })
    .withMessage('New password must have 12–72 characters.'),
  async (req, res, next) => {
    try {
      const invalid = validation(req);
      if (invalid) return res.status(400).json({ error: invalid });
      const [rows] = await pool.execute('SELECT password_hash FROM users WHERE user_id=?', [req.user.id]);
      if (!rows.length || !await bcrypt.compare(req.body.currentPassword, rows[0].password_hash)) {
        return res.status(400).json({ error: 'Current password is incorrect.' });
      }
      if (req.body.newPassword === req.body.currentPassword) {
        return res.status(400).json({ error: 'New password must be different.' });
      }
      const hash = await bcrypt.hash(req.body.newPassword, 12);
      await pool.execute('UPDATE users SET password_hash=?, must_change_password=FALSE WHERE user_id=?', [hash, req.user.id]);
      res.json({ ok: true });
    } catch (err) { next(err); }
  }
);
router.post('/logout', requireAuth, (req, res, next) => {
  req.session.destroy(err => err ? next(err) : res.clearCookie('casms.sid').json({ ok: true }));
});
module.exports = router;
