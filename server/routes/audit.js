'use strict';
// Admin-only, read-only audit log: never return authentication secrets.
const express=require('express');
const {pool}=require('../config/db');
const {roles}=require('../middleware/auth');
const router=express.Router();
router.use(roles('Admin'));
router.get('/tables',async(req,res,next)=>{
  try{
    const [rows]=await pool.query('SELECT DISTINCT table_name AS name FROM audit_log ORDER BY table_name');
    res.json({rows});
  }catch(e){next(e);}
});
router.get('/',async(req,res,next)=>{
  try{
    const page=Math.min(100000,Math.max(1,Number.parseInt(req.query.page,10)||1));
    const limit=15, where=['1=1'],params=[];
    const table=String(req.query.table||'').trim().slice(0,64);
    const action=String(req.query.action||'').trim();
    if(table){where.push('a.table_name=?');params.push(table);}
    if(action){if(!['INSERT','UPDATE','DELETE'].includes(action))return res.status(400).json({error:'Unknown action filter.'});where.push('a.action=?');params.push(action);}
    for(const [key,operator] of [['from','>='],['to','<']]){
      const value=String(req.query[key]||'');if(!value)continue;
      if(!/^\d{4}-\d{2}-\d{2}$/.test(value)||Number.isNaN(Date.parse(value)))return res.status(400).json({error:'Enter dates as YYYY-MM-DD.'});
      where.push(`a.changed_at ${operator} ${key==='to'?'DATE_ADD(?, INTERVAL 1 DAY)':'?'}`);
      params.push(key==='to'?value:value+' 00:00:00');
    }
    const q=`FROM audit_log a LEFT JOIN users u ON u.user_id=a.changed_by_user_id WHERE ${where.join(' AND ')}`;
    const [[{total}]]=await pool.query(`SELECT COUNT(*) AS total ${q}`,params);
    const [rows]=await pool.query(`SELECT a.audit_id AS id,a.table_name AS tableName,a.record_id AS recordId,a.action,
      a.changed_at AS changedAt,u.full_name AS actor,a.old_values AS beforeValues,a.new_values AS afterValues
      ${q} ORDER BY a.audit_id DESC LIMIT ? OFFSET ?`,[...params,limit,(page-1)*limit]);
    res.json({rows,total,page,limit});
  }catch(e){next(e);}
});
module.exports=router;
