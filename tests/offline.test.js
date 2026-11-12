'use strict';
// CASMS Phase 6: zero-dependency, read-only source and security-contract tests.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root,p),'utf8');
const exists = p => fs.existsSync(path.join(root,p));
function collect(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(x => x.isDirectory()?collect(path.join(dir,x.name)) : x.name.endsWith('.js')?[path.join(dir,x.name)]:[]);}

test('All application and test JavaScript files have valid syntax', () => {
  const files=[...collect(path.join(root,'server')),...collect(path.join(root,'public','js')),...collect(path.join(root,'tests'))];
  assert.ok(files.length >= 30, `Expected application source, found ${files.length} JS files`);
  for(const f of files){const r=cp.spawnSync(process.execPath,['--check',f],{encoding:'utf8'}); assert.equal(r.status,0,`${path.relative(root,f)}\n${r.stderr}`);}
});
test('Required web pages and modules are included', () => {
  const files=['public/login.html','public/change-password.html','public/dashboard.html','public/assets.html','public/asset-new.html','public/asset.html','public/requests.html','public/request-new.html','public/request.html','public/master.html','public/users.html','public/reports.html','public/notifications.html','public/audit.html','public/css/styles.css','public/css/analytics.css','server/app.js','server/config/db.js'];
  for(const f of files) assert.ok(exists(f),`Missing: ${f}`);
});
test('API has authentication, password-change gating and request validation',()=>{
  const app=read('server/app.js');
  assert.match(app,/SESSION_SECRET/);
  assert.match(app,/requireAuth,\s*requireReady/);
  assert.match(app,/X-CASMS-Request/);
  assert.match(app,/httpOnly:\s*true/);
  assert.match(app,/sameSite:\s*'lax'/);
  const auth=read('server/routes/auth.js');
  assert.match(auth,/\.regenerate\(/);
  assert.match(auth,/bcrypt\.compare/);
  assert.match(auth,/bcrypt\.hash/);
  assert.match(auth,/rateLimit\(/);
});
test('Every required router is mounted behind session middleware',()=>{
  const app=read('server/app.js');
  for(const route of ['dashboard','assets','requests','request-actions','master','users','asset-actions','reports','notifications','audit','insights']) {
    assert.ok(app.includes(`require('./routes/${route}')`),`Missing route: ${route}`);
  }
  assert.match(read('server/routes/users.js'),/router\.use\(roles\('Admin'\)\)/);
  assert.match(read('server/routes/audit.js'),/router\.use\(roles\('Admin'\)\)/);
});
test('SQL injection safety and scoped query helpers exist',()=>{
  const auth=read('server/middleware/auth.js');
  assert.match(auth,/function assetScope/);
  assert.match(auth,/function requestScope/);
  assert.match(auth,/assigned_technician_id=\?/);
  const assets=read('server/routes/assets.js');
  const requests=read('server/routes/requests.js');
  assert.match(assets,/assetScope\(req\.user/);
  assert.match(requests,/requestScope\(req\.user/);
  assert.match(read('server/routes/master.js'),/const tables\s*=\s*\{/);
});
test('Service closure delegates to stored procedure',()=>{
  const work=read('server/routes/request-actions.js');
  assert.match(work,/sp_assign_technician/);
  assert.match(work,/sp_close_service_request/);
  assert.match(work,/sp_reopen_request/);
  assert.match(work,/beginTransaction\(/);
  assert.match(work,/rollback\(/);
});
test('Asset transfer and assignment use database transactions',()=>{
  const src=read('server/routes/asset-actions.js');
  for(const name of ['sp_register_asset','sp_assign_asset','sp_retire_asset'])assert.ok(src.includes(name));
  assert.match(src,/router\.post\('\/:id\/transfer'/);
  assert.match(src,/beginTransaction\(/);
  assert.match(src,/commit\(/);
  assert.match(src,/rollback\(/);
});
test('Reports have role restrictions, bound searches, and CSV formula escape',()=>{
  const src=read('server/routes/reports.js');
  assert.match(src,/\.audience\.includes\(req\.user\.role\)/);
  assert.match(src,/csvValue\(/);
  assert.match(src,/MAX_EXPORT/);
  assert.match(src,/\[\.\.\.params/);
  assert.match(src,/\[=\+\\-@\]/);
});
test('Notification API scopes record mutation by signed-in user',()=>{
  const src=read('server/routes/notifications.js');
  assert.match(src,/WHERE notification_id=\? AND user_id=\?/);
  assert.match(src,/WHERE user_id=\?/);
});
test('No .env or private keys appear in submitted overlay',()=>{
  assert.ok(!exists('.env.example.secret') && !exists('tests/.env'));
  assert.ok(!exists('private.key') && !exists('.env.production'));
});
