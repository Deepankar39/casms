import {api} from './common.js';
const form=document.getElementById('login-form');const msg=document.getElementById('message');
try {const {user}=await api('/auth/me');location.replace(user.mustChangePassword?'/change-password.html':'/dashboard.html');} catch{}
form.addEventListener('submit',async event=>{
  event.preventDefault();msg.textContent='';const btn=document.getElementById('login-btn');btn.disabled=true;btn.textContent='Signing in…';
  try { await api('/auth/login',{method:'POST',data:{email:document.getElementById('email').value,password:document.getElementById('password').value}});location.replace('/dashboard.html'); }
  catch(err){msg.textContent=err.message;btn.disabled=false;btn.textContent='Sign in →';}
});
