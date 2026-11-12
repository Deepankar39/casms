import {api} from './common.js';
const form=document.getElementById('change-form');const msg=document.getElementById('message');
try { const {user}=await api('/auth/me'); if(!user.mustChangePassword)location.replace('/dashboard.html'); } catch {location.replace('/login.html');}
form.addEventListener('submit',async e=>{
  e.preventDefault();msg.textContent='';const currentPassword=document.getElementById('current').value;
  const newPassword=document.getElementById('updated').value;
  if(newPassword!==document.getElementById('confirm').value){msg.textContent='Passwords do not match.';return;}
  const btn=document.getElementById('save-btn');btn.disabled=true;
  try {await api('/auth/change-password',{method:'POST',data:{currentPassword,newPassword}});location.replace('/dashboard.html');}
  catch(err){msg.textContent=err.message;btn.disabled=false;}
});
