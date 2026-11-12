'use strict';
// A user can only read/change notifications belonging to their own account.
const express=require('express');
const {pool}=require('../config/db');
const router=express.Router();
router.get('/summary',async(req,res,next)=>{
  try{const [[r]]=await pool.execute('SELECT COUNT(*) AS unread FROM notifications WHERE user_id=? AND is_read=0',[req.user.id]);res.json({unread:r.unread});}catch(e){next(e);}
});
router.get('/',async(req,res,next)=>{
  try{
    const page=Math.min(100000,Math.max(1,Number.parseInt(req.query.page,10)||1));
    const unreadOnly=String(req.query.unreadOnly)==='1';
    const limit=12;
    const where=`n.user_id=? ${unreadOnly?'AND n.is_read=0':''}`;
    const [[{total}]]=await pool.execute(`SELECT COUNT(*) AS total FROM notifications n WHERE ${where}`,[req.user.id]);
    const [rows]=await pool.query(`SELECT n.notification_id AS id,n.notification_type AS type,n.message,n.is_read AS isRead,n.created_at AS createdAt,
      r.request_id AS requestId,r.request_number AS requestNumber FROM notifications n
      LEFT JOIN service_requests r ON n.request_id=r.request_id
      WHERE ${where} ORDER BY n.created_at DESC,n.notification_id DESC LIMIT ? OFFSET ?`,[req.user.id,limit,(page-1)*limit]);
    res.json({rows,total,page,limit});
  }catch(e){next(e);}
});
router.post('/read-all',async(req,res,next)=>{
  try{const [r]=await pool.execute('UPDATE notifications SET is_read=1 WHERE user_id=? AND is_read=0',[req.user.id]);res.json({ok:true,updated:r.affectedRows});}catch(e){next(e);}
});
router.post('/:id/read',async(req,res,next)=>{
  try{
    const id=Number(req.params.id);
    if(!Number.isSafeInteger(id)||id<1)return res.status(400).json({error:'Invalid notification ID.'});
    const [r]=await pool.execute('UPDATE notifications SET is_read=1 WHERE notification_id=? AND user_id=?',[id,req.user.id]);
    if(!r.affectedRows)return res.status(404).json({error:'Notification not found.'});
    res.json({ok:true});
  }catch(e){next(e);}
});
module.exports=router;
