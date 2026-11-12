'use strict';
const express = require('express');
const { pool } = require('../config/db');
const { roles } = require('../middleware/auth');
const router = express.Router();

// Only these trusted identifiers may be inserted into SQL statements.
// All data values are passed separately as mysql2 query parameters.
const tables = {
  departments: { pk:'department_id', columns:['department_code','department_name','is_active'], required:['department_code','department_name'], lengths:{department_code:20,department_name:100}, codes:['department_code'] },
  buildings: { pk:'building_id', columns:['building_code','building_name','notes','is_active'], required:['building_code','building_name'], lengths:{building_code:20,building_name:100,notes:1000}, codes:['building_code'] },
  rooms: { pk:'room_id', columns:['building_id','department_id','room_number','floor_number','room_type','is_active'], required:['building_id','room_number','room_type'], lengths:{room_number:20,room_type:40}, fks:['building_id','department_id'] },
  asset_categories: { pk:'category_id', columns:['category_code','category_name','default_useful_life_years','is_active'], required:['category_code','category_name'], lengths:{category_code:20,category_name:100}, codes:['category_code'] },
  vendors: { pk:'vendor_id', columns:['vendor_name','contact_number','email','vendor_type','is_active'], required:['vendor_name','vendor_type'], lengths:{vendor_name:150,contact_number:20,email:150,vendor_type:30} }
};
const bool = v => v === true || v === 1 || v === '1';
function fail(message){const e=new Error(message); e.status=400; throw e;}
function numeric(v, optional=false) {
  if (v === undefined || v === null || v === '') { if(optional)return null; fail('A required numeric value is missing.'); }
  const n=Number(v); if (!Number.isSafeInteger(n)||n<0) fail('Enter a valid non-negative whole number.');return n;
}
function validated(cfg, body, isNew) {
  if (!body || typeof body!=='object'||Array.isArray(body)) fail('Invalid request body.');
  const row={};
  for(const key of cfg.columns){
    if(!Object.prototype.hasOwnProperty.call(body,key)){if(isNew&&cfg.required.includes(key))fail(`${key} is required.`); continue;}
    let v=body[key];
    if(key==='is_active'){row[key]=bool(v)?1:0; continue;}
    if(cfg.fks?.includes(key)) {row[key]=numeric(v,key==='department_id');if(row[key]===0)fail(`${key} must be positive.`);continue;}
    if(['floor_number','default_useful_life_years'].includes(key)) {row[key]=numeric(v,true); if(key==='default_useful_life_years'&&row[key]===0)fail('Useful life must be positive.');continue;}
    if(v===null||v===''){if(cfg.required.includes(key))fail(`${key} is required.`);row[key]=null;continue;}
    if(typeof v!=='string')fail(`${key} must be text.`);
    v=v.trim();if(!v&&cfg.required.includes(key))fail(`${key} is required.`);
    if(v.length>(cfg.lengths?.[key]||255))fail(`${key} is too long.`);
    row[key]=cfg.codes?.includes(key)?v.toUpperCase():(v||null);
  }
  if(row.vendor_type&&!['Supplier','Service Provider','Both'].includes(row.vendor_type))fail('Choose a valid vendor type.');
  if(row.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(row.email))fail('Enter a valid email address.');
  return row;
}
function cfgFor(req,res,next){const cfg=tables[req.params.resource];if(!cfg)return res.status(404).json({error:'Unknown master-data resource.'});req.cfg=cfg;next();}
router.get('/:resource',cfgFor,async(req,res,next)=>{
  try{
    const name=req.params.resource;const c=req.cfg;
    const [rows]=await pool.query(`SELECT * FROM \`${name}\` ORDER BY \`${c.pk}\` DESC LIMIT 1000`);
    res.json({rows});
  }catch(e){next(e);}
});
router.post('/:resource',roles('Admin'),cfgFor,async(req,res,next)=>{
  try{
    const data=validated(req.cfg,req.body,true);
    const keys=Object.keys(data);if(!keys.length)fail('No values supplied.');
    const [result]=await pool.execute(`INSERT INTO \`${req.params.resource}\` (${keys.map(k=>'`'+k+'`').join(',')}) VALUES (${keys.map(()=>'?').join(',')})`,keys.map(k=>data[k]));
    res.status(201).json({ok:true,id:result.insertId});
  }catch(e){next(e);}
});
router.put('/:resource/:id',roles('Admin'),cfgFor,async(req,res,next)=>{
  try{
    const id=numeric(req.params.id);if(!id)fail('Invalid record ID.');
    const data=validated(req.cfg,req.body,false);const keys=Object.keys(data);
    if(!keys.length)fail('No changes provided.');
    const [result]=await pool.execute(`UPDATE \`${req.params.resource}\` SET ${keys.map(k=>'`'+k+'`=?').join(',')} WHERE \`${req.cfg.pk}\`=?`,[...keys.map(k=>data[k]),id]);
    if(!result.affectedRows)return res.status(404).json({error:'Record not found.'});
    res.json({ok:true});
  }catch(e){next(e);}
});
router.patch('/:resource/:id/status',roles('Admin'),cfgFor,async(req,res,next)=>{
  try{
    const id=numeric(req.params.id);if(!id)fail('Invalid record ID.');
    const [result]=await pool.execute(`UPDATE \`${req.params.resource}\` SET is_active=? WHERE \`${req.cfg.pk}\`=?`,[bool(req.body?.is_active)?1:0,id]);
    if(!result.affectedRows)return res.status(404).json({error:'Record not found.'});
    res.json({ok:true});
  }catch(e){next(e);}
});
module.exports=router;
