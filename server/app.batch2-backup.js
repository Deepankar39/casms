'use strict';
require('dotenv').config();
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const session = require('express-session');
const MySQLStore = require('express-mysql-session')(session);
const { pool } = require('./config/db');
const { requireAuth, requireReady } = require('./middleware/auth');
const { errorHandler } = require('./middleware/error');
const PORT = Number(process.env.PORT || 3000);
const SECRET = process.env.SESSION_SECRET;
if (!SECRET || SECRET.length < 32) throw new Error('SESSION_SECRET must be at least 32 characters in .env');

const app = express();
app.disable('x-powered-by');
app.use(helmet());
app.use(express.json({ limit: '64kb' }));
// Only JavaScript requests with our custom header can change state.
app.use('/api', (req, res, next) => {
  if (['POST','PUT','PATCH','DELETE'].includes(req.method) &&
      req.get('X-CASMS-Request') !== '1') {
    return res.status(403).json({ error: 'Request validation failed.' });
  }
  next();
});
const store = new MySQLStore({
  createDatabaseTable: false,
  endConnectionOnClose: false,
  clearExpired: true,
  checkExpirationInterval: 900000,
  expiration: 8 * 60 * 60 * 1000
}, pool);
app.use(session({
  name: 'casms.sid', secret: SECRET, store,
  resave: false, saveUninitialized: false, rolling: true,
  cookie: { httpOnly: true, sameSite: 'lax', secure: false, maxAge: 8*60*60*1000 }
}));
// Do not cache API containing user-specific data.
app.use('/api', (req,res,next) => { res.setHeader('Cache-Control','no-store'); next(); });
app.get('/api/health', async (req, res, next) => {
  try { const [rows] = await pool.execute('SELECT DATABASE() AS databaseName');
    res.json({ ok: true, service: 'CASMS API', database: rows[0].databaseName });
  } catch (err) { next(err); }
});
app.use('/api/auth', require('./routes/auth'));
app.use('/api/dashboard', requireAuth, requireReady, require('./routes/dashboard'));
app.use('/api/assets', requireAuth, requireReady, require('./routes/assets'));
app.use('/api/requests', requireAuth, requireReady, require('./routes/requests'));
app.use('/api/master', requireAuth, requireReady, require('./routes/master'));
app.use('/api/users', requireAuth, requireReady, require('./routes/users'));
app.use('/api/assets', requireAuth, requireReady, require('./routes/asset-actions'));
app.use(express.static(path.join(__dirname, '../public'), { index: false }));
app.get('/', (req,res) => res.redirect('/login.html'));
app.use('/api', (req,res) => res.status(404).json({ error: 'API endpoint not found.' }));
app.use(errorHandler);
(async () => {
  try {
    await pool.query('SELECT 1');
    if (typeof store.onReady === 'function') await store.onReady();
    app.listen(PORT, '127.0.0.1', () => {
      console.log(`CASMS running: http://localhost:${PORT}`);
      console.log('Database connection and session store initialized.');
    });
  } catch (err) {
    console.error('Startup failed:', err.message);
    process.exit(1);
  }
})();
