'use strict';
const express=require('express');
const {pool}=require('../config/db');
const {roles,assetScope,requestScope}=require('../middleware/auth');
const router=express.Router();
const pos=v=>Number.isSafeInteger(Number(v))&&Number(v)>0;
function invalid(message){const e=new Error(message);e.status=400;throw e;}
function num(v,{optional=false,zero=false}={}){
  if(v===undefined||v===null||v===''){if(optional)return null;invalid('A required ID or number is missing.');}
  const n=Number(v);if(!Number.isFinite(n)||(zero?n<0:n<=0)||(Number.isInteger(n)===false))invalid('Invalid number.');return n;
}
function cash(v){if(v===undefined||v===null||v==='')invalid('Cost is required.'); const raw=String(v);const n=Number(raw);if(!/^\d+(\.\d{1,2})?$/.test(raw)||!Number.isFinite(n)||n<0||n>9999999999.99)invalid('Enter a valid amount with up to two decimals.');return n;}
function idParam(req){if(!pos(req.params.id))invalid('Invalid asset ID.');return Number(req.params.id);}
function text(v,limit,{required=false}={}){if(v===undefined||v===null||v===''){if(required)invalid('Required text is missing.');return null;}if(typeof v!=='string')invalid('Invalid text.');const s=v.trim();if(required&&!s)invalid('Required text is missing.');if(s.length>limit)invalid('Text too long.');return s||null;}
async function visibleAsset(id,user,connection=pool){
  const scope=assetScope(user,'a');
  const [rows]=await connection.execute(`SELECT a.asset_id,a.asset_tag,a.asset_name,a.serial_number,a.brand,a.model,a.purchase_date,a.purchase_cost,a.salvage_value,a.useful_life_years,
    a.category_id,a.department_id,a.room_id,a.vendor_id,a.parent_asset_id,a.needs_retirement_review,a.retirement_date,a.retirement_reason,
    c.category_name,d.department_name,d.department_code, rm.room_number,st.status_name AS status
    FROM assets a JOIN asset_categories c ON c.category_id=a.category_id JOIN departments d ON d.department_id=a.department_id
    JOIN asset_statuses st ON st.asset_status_id=a.asset_status_id LEFT JOIN rooms rm ON a.room_id=rm.room_id
    WHERE a.asset_id=? AND ${scope.sql} LIMIT 1`,[id,...scope.params]);
  return rows[0]||null;
}
router.get('/lookups',async(req,res,next)=>{
  try{
    const [departments]=await pool.query('SELECT department_id AS id,department_code AS code,department_name AS name FROM departments WHERE is_active=1 ORDER BY department_name');
    const [categories]=await pool.query('SELECT category_id AS id,category_code AS code,category_name AS name FROM asset_categories WHERE is_active=1 ORDER BY category_name');
    const [rooms]=await pool.query('SELECT room_id AS id,room_number AS name,building_id,department_id FROM rooms WHERE is_active=1 ORDER BY room_number');
    const [vendors]=await pool.query('SELECT vendor_id AS id,vendor_name AS name FROM vendors WHERE is_active=1 ORDER BY vendor_name');
    const [users]=req.user.role==='Admin'?await pool.query('SELECT user_id AS id,full_name AS name,department_id FROM users WHERE is_active=1 ORDER BY full_name'): [[]];
    res.json({departments,categories,rooms,vendors,users});
  }catch(e){next(e);}
});
router.get('/:id',async(req,res,next)=>{
  try{const asset=await visibleAsset(idParam(req),req.user);if(!asset)return res.status(404).json({error:'Asset not found or not permitted.'});res.json({asset});}catch(e){next(e);}
});
router.get('/:id/history',async(req,res,next)=>{
  try{
    const id=idParam(req);if(!await visibleAsset(id,req.user))return res.status(404).json({error:'Asset not found or not permitted.'});
    const [assignments]=await pool.execute(`SELECT aa.assignment_id,aa.assigned_from,aa.assigned_to,aa.remarks,u.full_name AS assigned_user,d.department_code AS department,rm.room_number AS room
      FROM asset_assignments aa LEFT JOIN users u ON aa.assigned_user_id=u.user_id LEFT JOIN departments d ON aa.assigned_department_id=d.department_id
      LEFT JOIN rooms rm ON aa.assigned_room_id=rm.room_id WHERE aa.asset_id=? ORDER BY aa.assigned_from DESC,aa.assignment_id DESC LIMIT 100`,[id]);
    const [transfers]=await pool.execute(`SELECT t.transfer_id,t.transferred_at,t.reason,fd.department_code AS from_department,td.department_code AS to_department,fr.room_number AS from_room,tr.room_number AS to_room
      FROM asset_transfers t JOIN departments fd ON fd.department_id=t.from_department_id JOIN departments td ON td.department_id=t.to_department_id
      LEFT JOIN rooms fr ON t.from_room_id=fr.room_id LEFT JOIN rooms tr ON t.to_room_id=tr.room_id
      WHERE t.asset_id=? ORDER BY t.transferred_at DESC LIMIT 100`,[id]);
    const [warranties]=await pool.execute('SELECT warranty_id,coverage_type,start_date,end_date FROM warranties WHERE asset_id=? ORDER BY end_date DESC LIMIT 100',[id]);
    const requestFilter=requestScope(req.user,'r');
    const [requests]=await pool.execute(`SELECT r.request_number,r.title,r.raised_at,s.status_name FROM service_requests r
      JOIN request_statuses s ON r.request_status_id=s.request_status_id WHERE r.asset_id=? AND ${requestFilter.sql}
      ORDER BY r.raised_at DESC LIMIT 40`,[id,...requestFilter.params]);
    res.json({assignments,transfers,warranties,requests});
  }catch(e){next(e);}
});
router.post('/',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const name=text(req.body?.name,150,{required:true});const dept=num(req.body?.departmentId);const cat=num(req.body?.categoryId);
    const room=num(req.body?.roomId,{optional:true});const cost=cash(req.body?.purchaseCost);
    const [[allowed]]=await pool.execute(`SELECT d.department_id,c.category_id FROM departments d JOIN asset_categories c
      ON c.category_id=? AND c.is_active=1 WHERE d.department_id=? AND d.is_active=1`,[cat,dept]);
    if(!allowed)invalid('Select an active department and asset category.');
    if(room){const [[r]]=await pool.execute('SELECT room_id FROM rooms WHERE room_id=? AND is_active=1',[room]);if(!r)invalid('Select an active room.');}
    c=await pool.getConnection();
    await c.query('CALL sp_register_asset(?,?,?,?,?,?,@casms_new_asset_id,@casms_new_asset_tag)',[req.user.id,dept,cat,name,room,cost]);
    const [[result]]=await c.query('SELECT @casms_new_asset_id AS id,@casms_new_asset_tag AS tag');
    if(!result?.id)throw new Error('Asset registration did not return an ID.');
    res.status(201).json({ok:true,id:result.id,tag:result.tag});
  }catch(e){next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL, @casms_new_asset_id=NULL,@casms_new_asset_tag=NULL');}finally{c.release();}}}
});
router.put('/:id',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const id=idParam(req);const body=req.body||{};
    const fields={};
    if('name' in body)fields.asset_name=text(body.name,150,{required:true});
    if('serialNumber' in body)fields.serial_number=text(body.serialNumber,100);
    if('brand' in body)fields.brand=text(body.brand,100);
    if('model' in body)fields.model=text(body.model,100);
    if('vendorId' in body)fields.vendor_id=num(body.vendorId,{optional:true});
    if('parentAssetId' in body)fields.parent_asset_id=num(body.parentAssetId,{optional:true});
    if('purchaseCost' in body)fields.purchase_cost=cash(body.purchaseCost);
    if('salvageValue' in body)fields.salvage_value=cash(body.salvageValue);
    if('usefulLifeYears' in body)fields.useful_life_years=num(body.usefulLifeYears,{optional:true});
    if('purchaseDate' in body){const s=body.purchaseDate;if(s && (!/^\d{4}-\d{2}-\d{2}$/.test(s)||Number.isNaN(Date.parse(s))))invalid('Invalid purchase date.');fields.purchase_date=s||null;}
    if(!Object.keys(fields).length)invalid('No changes submitted.');
    c=await pool.getConnection();await c.beginTransaction();await c.query('SET @casms_actor_id=?',[req.user.id]);
    const keys=Object.keys(fields);
    const [result]=await c.execute(`UPDATE assets SET ${keys.map(k=>k+'=?').join(',')} WHERE asset_id=?`,[...keys.map(k=>fields[k]),id]);
    if(!result.affectedRows){await c.rollback();return res.status(404).json({error:'Asset not found.'});}
    await c.commit();res.json({ok:true});
  }catch(e){if(c)await c.rollback();next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL');}finally{c.release();}}}
});
router.post('/:id/assign',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const id=idParam(req);const userId=num(req.body?.userId,{optional:true});const dept=num(req.body?.departmentId,{optional:true});const room=num(req.body?.roomId,{optional:true});
    if(!userId&&!dept)invalid('Choose a user or department.');
    if(userId){const [[u]]=await pool.execute('SELECT user_id FROM users WHERE user_id=? AND is_active=1',[userId]);if(!u)invalid('Assigned user must be active.');}
    c=await pool.getConnection();await c.query('CALL sp_assign_asset(?,?,?,?,?)',[id,userId,dept,room,req.user.id]);res.json({ok:true});
  }catch(e){next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL');}finally{c.release();}}}
});
router.post('/:id/end-assignment',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const id=idParam(req);c=await pool.getConnection();await c.beginTransaction();await c.query('SET @casms_actor_id=?',[req.user.id]);
    const [[asset]]=await c.execute('SELECT asset_id FROM assets WHERE asset_id=? FOR UPDATE',[id]);if(!asset)invalid('Asset not found.');
    const [result]=await c.execute('UPDATE asset_assignments SET assigned_to=CURDATE() WHERE asset_id=? AND assigned_to IS NULL',[id]);
    if(!result.affectedRows)invalid('Asset has no current assignment.');
    await c.commit();res.json({ok:true});
  }catch(e){if(c)await c.rollback();next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL');}finally{c.release();}}}
});
router.post('/:id/transfer',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const id=idParam(req);const departmentId=num(req.body?.departmentId);const roomId=num(req.body?.roomId,{optional:true});
    const reason=text(req.body?.reason,1000,{required:true});
    c=await pool.getConnection();await c.beginTransaction();await c.query('SET @casms_actor_id=?',[req.user.id]);
    const [[a]]=await c.execute(`SELECT a.department_id,a.room_id,st.status_name AS status FROM assets a
      JOIN asset_statuses st ON a.asset_status_id=st.asset_status_id WHERE a.asset_id=? FOR UPDATE`,[id]);
    if(!a)invalid('Asset not found.');
    if(!['Active','In Stock'].includes(a.status))invalid('Only active or in-stock assets may be transferred.');
    const [[d]]=await c.execute('SELECT department_id FROM departments WHERE department_id=? AND is_active=1',[departmentId]);
    if(!d)invalid('Choose an active department.');
    if(roomId){const [[room]]=await c.execute('SELECT room_id FROM rooms WHERE room_id=? AND is_active=1',[roomId]);if(!room)invalid('Choose an active room.');}
    if(a.department_id===departmentId&&a.room_id===roomId)invalid('Choose a different room or department.');
    await c.execute(`INSERT INTO asset_transfers (asset_id,from_room_id,to_room_id,from_department_id,to_department_id,transferred_by_user_id,reason)
      VALUES(?,?,?,?,?,?,?)`,[id,a.room_id,roomId,a.department_id,departmentId,req.user.id,reason]);
    await c.execute('UPDATE assets SET department_id=?,room_id=? WHERE asset_id=?',[departmentId,roomId,id]);
    // Preserve assignment history and move any CURRENT assignment to the new location.
    const [[current]]=await c.execute('SELECT assignment_id,assigned_user_id FROM asset_assignments WHERE asset_id=? AND assigned_to IS NULL FOR UPDATE',[id]);
    if(current){
      await c.execute('UPDATE asset_assignments SET assigned_to=CURDATE() WHERE assignment_id=?',[current.assignment_id]);
      await c.execute(`INSERT INTO asset_assignments (asset_id,assigned_user_id,assigned_department_id,assigned_room_id,assigned_by_user_id,assigned_from,remarks)
        VALUES(?,?,?,?,?,CURDATE(),?)`,[id,current.assigned_user_id,departmentId,roomId,req.user.id,'Continued assignment after transfer']);
    }
    await c.commit();res.json({ok:true});
  }catch(e){if(c)await c.rollback();next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL');}finally{c.release();}}}
});
router.post('/:id/activate',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const id=idParam(req);c=await pool.getConnection();await c.beginTransaction();await c.query('SET @casms_actor_id=?',[req.user.id]);
    const [[record]]=await c.execute(`SELECT st.status_name FROM assets a JOIN asset_statuses st ON st.asset_status_id=a.asset_status_id WHERE a.asset_id=? FOR UPDATE`,[id]);
    if(!record || record.status_name!=='In Stock')invalid('Only in-stock assets can be activated.');
    await c.execute(`UPDATE assets SET asset_status_id=(SELECT asset_status_id FROM asset_statuses WHERE status_name='Active') WHERE asset_id=?`,[id]);
    await c.commit();res.json({ok:true});
  }catch(e){if(c)await c.rollback();next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL');}finally{c.release();}}}
});
router.post('/:id/retire',roles('Admin'),async(req,res,next)=>{
  let c;
  try{
    const id=idParam(req);const reason=text(req.body?.reason,1000,{required:true});
    c=await pool.getConnection();await c.query('CALL sp_retire_asset(?,?,?)',[id,reason,req.user.id]);res.json({ok:true});
  }catch(e){next(e);}finally{if(c){try{await c.query('SET @casms_actor_id=NULL');}finally{c.release();}}}
});
module.exports=router;
