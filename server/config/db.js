'use strict';
const mysql = require('mysql2/promise');
require('dotenv').config();

const config = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'casms',
  waitForConnections: true,
  connectionLimit: 10,
  decimalNumbers: false,
  timezone: 'local'
};
if (!config.user || !config.password) {
  throw new Error('Missing DB_USER or DB_PASSWORD in .env');
}
const pool = mysql.createPool(config);
module.exports = { pool, config };
