'use strict';
// Small visual datasets for dashboard. Every query is scoped to the signed-in user.
const express=require('express');
const {pool}=require('../config/db');
const {assetScope,requestScope}=require('../middleware/auth');
const router=express.Router();
router.get('/',async(req,res,next)=>{
  try{
    const a=assetScope(req.user,'a');
    const r=requestScope(req.user,'r');
    const [categories]=await pool.execute(`SELECT c.category_name AS label,COUNT(*) AS value FROM assets a
      JOIN asset_categories c ON c.category_id=a.category_id
      WHERE ${a.sql} GROUP BY c.category_id,c.category_name ORDER BY value DESC LIMIT 8`,a.params);
    const [monthlyRequests]=await pool.execute(`SELECT DATE_FORMAT(r.raised_at,'%Y-%m') AS label,COUNT(*) AS value
      FROM service_requests r WHERE ${r.sql} AND r.raised_at>=DATE_SUB(CURDATE(),INTERVAL 12 MONTH)
      GROUP BY DATE_FORMAT(r.raised_at,'%Y-%m') ORDER BY label ASC`,r.params);
    let costs=[],warrantyExpiring=null;
    if(req.user.role==='Admin'){
      const [rows]=await pool.query(`SELECT DATE_FORMAT(end_date,'%Y-%m') AS label,SUM(total_cost) AS value
        FROM vw_service_history WHERE end_date>=DATE_SUB(CURDATE(),INTERVAL 12 MONTH)
        GROUP BY DATE_FORMAT(end_date,'%Y-%m') ORDER BY label`);costs=rows;
      const [[count]]=await pool.query('SELECT COUNT(*) AS total FROM vw_warranty_status WHERE days_remaining BETWEEN 0 AND 30');
      warrantyExpiring=count.total;
    }
    res.json({categories,monthlyRequests,monthlyCosts:costs,warrantyExpiring});
  }catch(e){next(e);}
});
module.exports=router;
