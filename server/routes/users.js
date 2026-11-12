'use strict';
const express=require('express');
const crypto=require('crypto');
const bcrypt=require('bcryptjs');
const {pool}=require('../config/db');
const {roles}=require('../middleware/auth');
const router=express.Router();
router.use(roles('Admin'));
function invalid(msg){const e=new Error(msg);e.status=400;throw e;}
const positive=v=>Number.isSafeInteger(Number(v))&&Number(v)>0;
function profile(body){
  if(!body||typeof body!=='object')invalid('Invalid data.');
  const employee_code=String(body.employee_code||'').trim().toUpperCase();
  const full_name=String(body.full_name||'').trim();
  const email=String(body.email||'').trim().toLowerCase();
  if(!/^[A-Z0-9_-]{3,30}$/.test(employee_code))invalid('Employee code must be 3–30 letters/numbers.');
  if(full_name.length<2||full_name.length>100)invalid('Name must contain 2–100 characters.');
  if(email.length>150||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))invalid('Enter a valid email.');
  if(!positive(body.role_id)||!positive(body.department_id))invalid('Choose a role and department.');
  return {employee_code,full_name,email,role_id:Number(body.role_id),department_id:Number(body.department_id)};
}
async function checkRefs(c, data){
  const [[role]]=await c.execute('SELECT role_name FROM roles WHERE role_id=?',[data.role_id]);
  const [[dept]]=await c.execute('SELECT department_id FROM departments WHERE department_id=? AND is_active=1',[data.department_id]);
  if(!role||!dept)invalid('Role or active department is invalid.');
  return role.role_name;
}
router.get('/roles',async(req,res,next)=>{try{const [rows]=await pool.query('SELECT role_id,role_name FROM roles ORDER BY role_id');res.json({rows});}catch(e){next(e);}});
router.get('/',async(req,res,next)=>{
  try{const [rows]=await pool.query(`SELECT u.user_id AS id,u.employee_code,u.full_name,u.email,u.role_id,u.department_id,u.is_active,u.must_change_password,r.role_name,d.department_code
    FROM users u JOIN roles r ON r.role_id=u.role_id JOIN departments d ON d.department_id=u.department_id
    ORDER BY u.user_id DESC LIMIT 1000`);res.json({rows});}catch(e){next(e);}
});
router.post('/',async(req,res,next)=>{
  let c;
  try{
    const data=profile(req.body);c=await pool.getConnection();await c.beginTransaction();
    const role=await checkRefs(c,data);
    const temporaryPassword=crypto.randomBytes(18).toString('base64url');
    const hash=await bcrypt.hash(temporaryPassword,12);
    const [result]=await c.execute(`INSERT INTO users (employee_code,full_name,email,password_hash,role_id,department_id,is_active,must_change_password)
      VALUES(?,?,?,?,?,?,1,1)`,[data.employee_code,data.full_name,data.email,hash,data.role_id,data.department_id]);
    if(role==='Technician')await c.execute('INSERT INTO technician_profiles (user_id,max_open_requests,is_available) VALUES(?,5,1)',[result.insertId]);
    await c.commit();res.status(201).json({ok:true,id:result.insertId,temporaryPassword});
  }catch(e){if(c)await c.rollback();next(e);}finally{if(c)c.release();}
});
router.put('/:id',async(req,res,next)=>{
  let c;
  try{
    const id=Number(req.params.id);if(!positive(id))invalid('Invalid user.');
    const data=profile(req.body);c=await pool.getConnection();await c.beginTransaction();
    const role=await checkRefs(c,data);
    const [[old]]=await c.execute('SELECT u.role_id,r.role_name FROM users u JOIN roles r ON u.role_id=r.role_id WHERE u.user_id=? FOR UPDATE',[id]);
    if(!old){await c.rollback();return res.status(404).json({error:'User not found.'});}
    if(id===req.user.id&&role!=='Admin')invalid('Cannot remove your own Admin role.');
    await c.execute('UPDATE users SET employee_code=?,full_name=?,email=?,role_id=?,department_id=? WHERE user_id=?',
      [data.employee_code,data.full_name,data.email,data.role_id,data.department_id,id]);
    if(role==='Technician')await c.execute('INSERT INTO technician_profiles(user_id,max_open_requests) VALUES(?,5) ON DUPLICATE KEY UPDATE user_id=user_id',[id]);
    await c.commit();res.json({ok:true});
  }catch(e){if(c)await c.rollback();next(e);}finally{if(c)c.release();}
});
router.patch('/:id/status',async(req,res,next)=>{
  try{
    const id=Number(req.params.id);if(!positive(id))invalid('Invalid user.');
    const active=req.body?.is_active===true||req.body?.is_active===1;
    if(id===req.user.id&&!active)invalid('You cannot deactivate your own account.');
    const [result]=await pool.execute('UPDATE users SET is_active=? WHERE user_id=?',[active?1:0,id]);
    if(!result.affectedRows)return res.status(404).json({error:'User not found.'});
    res.json({ok:true});
  }catch(e){next(e);}
});
module.exports=router;
