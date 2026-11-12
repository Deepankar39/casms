'use strict';
// Offline checks only; the user must still test MySQL and the browser locally.
const fs=require('fs');
const path=require('path');
const cp=require('child_process');
const vm=require('vm');
const root=path.resolve(__dirname,'../..');
let issues=0;
const js=[];
function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){
  if(['node_modules','.git'].includes(item.name))continue;
  const p=path.join(dir,item.name);
  if(item.isDirectory())walk(p);else if(p.endsWith('.js'))js.push(p);
}}
walk(path.join(root,'server'));walk(path.join(root,'public','js'));
for(const f of js){const r=cp.spawnSync(process.execPath,['--check',f],{encoding:'utf8'});
  if(r.status!==0){issues++;console.error('SYNTAX',path.relative(root,f),r.stderr);}}
const checks=[
  'server/routes/reports.js','server/routes/notifications.js','server/routes/audit.js',
  'server/routes/insights.js','public/js/charts.js','public/js/reports.js',
  'public/js/audit.js','public/js/notifications.js','public/reports.html',
  'public/audit.html','public/notifications.html','public/css/analytics.css'
];
for(const f of checks)if(!fs.existsSync(path.join(root,f))){issues++;console.error('MISSING',f);}
const app=fs.readFileSync(path.join(root,'server/app.js'),'utf8');
for(const route of ['reports','notifications','audit','insights']){
  if(!app.includes(`require('./routes/${route}')`)){issues++;console.error('ROUTE NOT REGISTERED',route);}
}
// Security contract smoke tests in a mocked router: no running MySQL necessary.
function mockedRouter(file){
  const handlers=new Map();
  const router={get:(p,h)=>handlers.set('GET '+p,h),post:(p,h)=>handlers.set('POST '+p,h),use:()=>{}};
  const seen=[];
  let responseRows=[];
  const pool={query:async(sql,params=[])=>{seen.push({sql,params});
    if(sql.includes('COUNT(*) AS total FROM ('))return [[{total:1}]];
    return [responseRows];
  }};
  const requireMock=name=>{
    if(name==='express')return {Router:()=>router};
    if(name==='../config/db')return {pool};
    if(name==='../middleware/auth')return {assetScope:user=>({sql:user.role==='Admin'?'1=1':'a.department_id=?',params:user.role==='Admin'?[]:[42]}),requestScope:user=>({sql:user.role==='Admin'?'1=1':'r.raised_by_user_id=?',params:user.role==='Admin'?[]:[99]})};
    throw new Error('Unexpected import '+name);
  };
  const sandbox={require:requireMock,module:{exports:{}},console};
  vm.runInNewContext(fs.readFileSync(path.join(root,file),'utf8'),sandbox,{filename:file});
  return {handlers,seen,setRows:rows=>responseRows=rows};
}
(async()=>{
  try{
    const {handlers,seen,setRows}=mockedRouter('server/routes/reports.js');
    function res(){return {statusCode:200,headers:{},status(n){this.statusCode=n;return this;},set(k,v){this.headers[k]=v;return this;},json(v){this.payload=v;return this;},send(v){this.payload=v;return this;}};}
    const staff={role:'Staff',id:99,departmentId:42};
    const catalog=res();await handlers.get('GET /catalog')({user:staff},catalog);
    if(catalog.payload.reports.some(r=>r.audience.length===1&&r.audience[0]==='Admin'))throw new Error('Admin report leaked in staff catalog');
    let nextErr;
    await handlers.get('GET /:id')({params:{id:'department'},query:{},user:staff},res(),e=>{nextErr=e;});
    if(nextErr?.status!==403)throw new Error('Admin-only report did not reject Staff');
    const scoped=res();
    await handlers.get('GET /:id')({params:{id:'assets'},query:{search:"'% OR 1=1 --"},user:staff},scoped,e=>{throw e;});
    if(!scoped.payload.rows||!seen.some(x=>x.sql.includes('a.department_id=?')&&x.params.includes(42)))throw new Error('Missing Staff asset SQL scope');
    if(seen.some(x=>x.sql.includes("'% OR 1=1 --")))throw new Error('Unbound search string in SQL');
    setRows([{tag:'=1+1',asset:'Sample',category:'Laptop',department:'MCA',building:null,room:null,status:'Active',purchaseCost:200}]);
    const out=res();await handlers.get('GET /:id/export')({params:{id:'assets'},query:{},user:staff},out,e=>{throw e;});
    if(!out.payload.includes("\"'=1+1\""))throw new Error('Formula injection not sanitized in CSV');
    console.log('PASS: Mocked role restrictions, bound search, CSV injection safeguard.');
  }catch(err){issues++;console.error('BEHAVIOR CHECK',err.message);}
  if(issues){console.error(`FAIL: ${issues} problems found.`);process.exitCode=1;}
  else{console.log(`PASS: ${js.length} JavaScript files pass syntax checks.`);console.log('PASS: Batch 4 routes and screens present.');console.log('NEXT: Verify logged-in app and MySQL reports in your browser.');}
})();
