'use strict';
const {execFileSync}=require('child_process');
const {resolve}=require('path');
const files=[
 'server/app.js','server/config/db.js','server/middleware/auth.js','server/middleware/error.js',
 'server/routes/auth.js','server/routes/dashboard.js','server/routes/assets.js','server/routes/requests.js',
 'server/routes/master.js','server/routes/users.js','server/routes/asset-actions.js',
 'public/js/common.js','public/js/dashboard.js','public/js/assets.js','public/js/requests.js',
 'public/js/forms.js','public/js/master.js','public/js/users.js','public/js/asset-new.js','public/js/asset.js'
];
try{
  for(const f of files){execFileSync(process.execPath,['--check',resolve(__dirname,'../..',f)],{stdio:'pipe'});}
  console.log(`PASS: ${files.length} JavaScript files passed syntax checks.`);
}catch(err){console.error(String(err.stderr||err.message));process.exitCode=1;}
