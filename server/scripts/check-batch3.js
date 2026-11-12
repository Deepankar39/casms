'use strict';
// Offline source checks; database/browser behavior must be verified locally.
const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.resolve(__dirname,'../..');
const js=[];
function walk(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
  if(['node_modules','.git'].includes(entry.name))continue;
  const p=path.join(dir,entry.name);
  if(entry.isDirectory())walk(p);else if(entry.name.endsWith('.js'))js.push(p);
}}
walk(path.join(root,'server'));walk(path.join(root,'public','js'));
let failures=0;
for(const file of js){const done=cp.spawnSync(process.execPath,['--check',file],{encoding:'utf8'});
  if(done.status!==0){failures++;console.error('FAIL',path.relative(root,file),done.stderr);}}
for(const f of [
  'server/routes/request-actions.js','public/js/requests.js','public/js/request-new.js',
  'public/js/request.js','public/requests.html','public/request-new.html',
  'public/request.html','public/css/requests-management.css'
]){if(!fs.existsSync(path.join(root,f))){failures++;console.error('MISSING',f);}}
const app=fs.readFileSync(path.join(root,'server/app.js'),'utf8');
if(!app.includes("require('./routes/request-actions')")){failures++;console.error('MISSING registration for request-actions router');}
const actions=fs.readFileSync(path.join(root,'server/routes/request-actions.js'),'utf8');
for(const name of ['sp_assign_technician','sp_close_service_request','sp_reopen_request',"router.post('/:id/feedback'","router.post('/:id/status'","router.post('/:id/comments'"]){
  if(!actions.includes(name)){failures++;console.error('MISSING backend feature',name);}}
if(failures){console.error(`FAIL: ${failures} source checks failed.`);process.exit(1);}
console.log(`PASS: ${js.length} JavaScript files passed syntax checks.`);
console.log('PASS: Batch 3 route registration, pages and procedure calls found.');
console.log('NEXT: Test with your local MySQL and three user roles.');
