'use strict';
/* CASMS Phase 6: live, NON-DESTRUCTIVE HTTP integration verification.
   Run while `npm run dev` is running. Node >=20 required.
   Optional role credentials via CASMS_TEST_{ADMIN,STAFF,TECH}_{EMAIL,PASSWORD}.
   Credentials are used in memory; never printed or written to a file.
   Exit code 1 on failures. Missing credentials => explicitly SKIPPED role tests.
*/
const fs=require('node:fs');
const path=require('node:path');
const ROOT=process.env.CASMS_TEST_URL||'http://127.0.0.1:3000';
const cases=[];
function add(name,result,info=''){cases.push({name,result,info:String(info).slice(0,180)});console.log(`${result.padEnd(5)} ${name}${info?' — '+info:''}`);}
async function req(url,{method='GET',body,cookie,header=true}={}){
 const headers={}; if(body!==undefined)headers['Content-Type']='application/json';
 if(cookie)headers.Cookie=cookie; if(header)headers['X-CASMS-Request']='1';
 const r=await fetch(ROOT+url,{method,headers,body:body===undefined?undefined:JSON.stringify(body),redirect:'manual',signal:AbortSignal.timeout(12000)});
 let parsed;const t=await r.text();try{parsed=JSON.parse(t)}catch{parsed=t};
 return {status:r.status,body:parsed,type:r.headers.get('content-type')||'',cookie:r.headers.get('set-cookie')?.split(';')[0]||'',disposition:r.headers.get('content-disposition')||''};
}
async function verify(name,fn){try{const info=await fn();add(name,'PASS',info||'');}catch(e){add(name,'FAIL',e.message);}}
async function expectStatus(url,status,opts){const r=await req(url,opts);if(r.status!==status)throw Error(`${url}: expected HTTP ${status}, got ${r.status}`);return r;}
async function optionalRole(role, envName, expectation){
 const email=process.env[`CASMS_TEST_${envName}_EMAIL`];const password=process.env[`CASMS_TEST_${envName}_PASSWORD`];
 if(!email||!password){add(`${role} role scenarios`,'SKIP',`Set CASMS_TEST_${envName}_EMAIL and _PASSWORD`);return;}
 let cookie;
 await verify(`${role}: login session`,async()=>{
  const r=await expectStatus('/api/auth/login',200,{method:'POST',body:{email,password}});
  if(!r.cookie)throw Error('No session cookie');cookie=r.cookie;
 });
 if(!cookie){add(`${role}: authenticated scenarios`,'SKIP','login did not succeed');return;}
 await verify(`${role}: /me`,async()=>{
  const r=await expectStatus('/api/auth/me',200,{cookie});
  if(r.body.user?.role!==role)throw Error(`Unexpected role: ${r.body.user?.role}`);
  if(r.body.user.mustChangePassword)throw Error('Change temporary password before final tests');
 });
 for(const [name,url] of [['dashboard','/api/dashboard'],['assets','/api/assets?page=1'],['requests','/api/requests?page=1'],['report catalog','/api/reports/catalog'],['notifications','/api/notifications/summary'],['insights','/api/insights']]){
  await verify(`${role}: ${name}`,async()=>{const r=await expectStatus(url,200,{cookie});if(typeof r.body!=='object')throw Error('Not JSON');});
 }
 if(role==='Admin'){
  for(const url of ['/api/audit?page=1','/api/users?page=1','/api/master/departments','/api/reports/department?page=1']){
   await verify(`Admin: permitted ${url}`,async()=>{await expectStatus(url,200,{cookie});});
  }
  await verify('Admin: CSV export',async()=>{
   const r=await expectStatus('/api/reports/assets/export',200,{cookie});
   if(!r.type.includes('text/csv')||!r.disposition.includes('attachment'))throw Error('Missing CSV download headers');
  });
 }else{
  for(const url of ['/api/audit','/api/users','/api/reports/department','/api/reports/department/export']){
   await verify(`${role}: blocked ${url}`,async()=>{await expectStatus(url,403,{cookie});});
  }
  await verify(`${role}: blocked Admin-only mutation`,async()=>{
   await expectStatus('/api/master/departments',403,{cookie,method:'POST',body:{department_code:'NOCHANGE',department_name:'No Change'}});
  });
 }
 await verify(`${role}: logout invalidates session`,async()=>{
  await expectStatus('/api/auth/logout',200,{method:'POST',cookie});
  await expectStatus('/api/auth/me',401,{cookie});
 });
}
(async()=>{
 try{
  console.log('CASMS Phase 6 HTTP smoke tests: '+ROOT);
  await verify('Health and DB connectivity',async()=>{const r=await expectStatus('/api/health',200);if(r.body.database!=='casms'||r.body.ok!==true)throw Error('Unexpected health response');});
  for(const url of ['/api/auth/me','/api/dashboard','/api/assets','/api/requests','/api/reports/catalog','/api/notifications','/api/audit','/api/users']){
   await verify('Anonymous blocked: '+url,async()=>{await expectStatus(url,401);});
  }
  await verify('Custom request header protection',async()=>{await expectStatus('/api/auth/logout',403,{method:'POST',header:false});});
  await verify('Login invalid input rejected',async()=>{await expectStatus('/api/auth/login',400,{method:'POST',body:{email:'not-an-email',password:''}});});
  await verify('Unknown API is 404',async()=>{await expectStatus('/api/this-does-not-exist',404);});
  await optionalRole('Admin','ADMIN');await optionalRole('Staff','STAFF');await optionalRole('Technician','TECH');
 }catch(e){add('Unexpected test-run error','FAIL',e.message)}
 const results={date:new Date().toISOString(),url:ROOT,results:cases,counts:{pass:cases.filter(c=>c.result==='PASS').length,fail:cases.filter(c=>c.result==='FAIL').length,skip:cases.filter(c=>c.result==='SKIP').length}};
 const file=path.join(__dirname,'phase6-results.json');fs.writeFileSync(file,JSON.stringify(results,null,2)+'\n');
 console.log(`\nRESULTS PASS=${results.counts.pass} FAIL=${results.counts.fail} SKIP=${results.counts.skip}`);
 console.log('Saved '+file+' (no credentials included).');
 if(results.counts.fail)process.exitCode=1;
})();
