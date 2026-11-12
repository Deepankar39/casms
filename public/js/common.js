export async function api(path, { method='GET', data }={}) {
  const options={ method, credentials:'same-origin', headers:{} };
  if (method!=='GET') options.headers['X-CASMS-Request']='1';
  if (data !== undefined) { options.headers['Content-Type']='application/json'; options.body=JSON.stringify(data); }
  let response;
  try { response=await fetch('/api'+path, options); }
  catch { throw new Error('Cannot reach the server. Check that CASMS is running.'); }
  let result;
  try { result=await response.json(); }
  catch { throw new Error('Unexpected server response.'); }
  if (!response.ok) {
    if (response.status===401 && !location.pathname.endsWith('login.html')) location.replace('/login.html');
    if (result.code==='PASSWORD_CHANGE_REQUIRED') location.replace('/change-password.html');
    throw new Error(result.error || 'Request failed.');
  }
  return result;
}
export async function getUser() {
  const {user}=await api('/auth/me');
  if (user.mustChangePassword && !location.pathname.endsWith('change-password.html')) {
    location.replace('/change-password.html'); return null;
  }
  return user;
}
const defaultTabs=[['dashboard','Dashboard','◫'],['assets','Assets','▤'],['requests','Service requests','☷'],['reports','Reports','▥'],['notifications','Notifications','♧']];
export function shell(user,page){
  const tabs=[...defaultTabs];
  if(user.role==='Admin')tabs.push(['master','Master data','▦'],['users','Users','♙'],['audit','Audit trail','◈']);
  const section=['asset','asset-new'].includes(page)?'assets':['request','request-new'].includes(page)?'requests':page;
  const root=document.getElementById('app');
  const nav= tabs.map(([path,label,symbol])=>`<a class="nav-link ${section===path?'active':''}" href="/${path}.html" ${section===path?'aria-current="page"':''}><span class="nav-symbol" aria-hidden="true">${symbol}</span><span>${label}</span>${path==='notifications'?'<span id="nav-unread" class="nav-count" hidden></span>':''}</a>`).join('');
  root.innerHTML=`<div class="app"><button type="button" class="side-scrim" id="scrim" aria-label="Close navigation"></button><aside class="sidebar" id="sidebar" aria-label="Main navigation"><div class="brand"><span class="brand-mark">C</span> CASMS</div><nav><div class="nav-group-label">Workspace</div>${nav}</nav><div class="sidebar-bottom"><span class="mini">CASMS · MCA academic project</span><button class="btn subtle" id="logout" type="button">↗ &nbsp; Sign out</button></div></aside><div class="workspace"><header class="topbar"><div class="top-left"><button type="button" class="mobile-toggle" id="menu" aria-label="Open navigation" aria-expanded="false">☰</button><span class="top-label">Campus Operations &nbsp;/&nbsp; <strong>${tabs.find(t=>t[0]===section)?.[1]||'Workspace'}</strong></span></div><div class="top-right"><a href="/notifications.html" class="top-notifications" aria-label="Notifications">♧ <span id="top-unread" hidden></span></a><span class="role-label" id="role"></span><div class="avatar" id="avatar"></div><div class="profile-mini"><strong id="user-name"></strong><div class="user-sub">My workspace</div></div></div></header><main class="main" id="content"></main></div></div>`;
  document.getElementById('role').textContent=user.role;
  document.getElementById('user-name').textContent=user.name;
  document.getElementById('avatar').textContent=(user.name||'?').split(/\s+/).slice(0,2).map(x=>x[0]).join('').toUpperCase();
  const sidebar=document.getElementById('sidebar'), scrim=document.getElementById('scrim'),menu=document.getElementById('menu');
  function closeMenu(){sidebar.classList.remove('open');scrim.classList.remove('visible');menu.setAttribute('aria-expanded','false');}
  menu.addEventListener('click',()=>{const open=!sidebar.classList.contains('open');sidebar.classList.toggle('open',open);scrim.classList.toggle('visible',open);menu.setAttribute('aria-expanded',String(open));});
  scrim.addEventListener('click',closeMenu);
  document.addEventListener('keydown',event=>{if(event.key==='Escape')closeMenu();});
  document.getElementById('logout').addEventListener('click',async()=>{
    try{await api('/auth/logout',{method:'POST'});location.replace('/login.html');}catch(err){alert(err.message);}
  });
  refreshNotificationBadge();
  return document.getElementById('content');
}
export async function refreshNotificationBadge(){
  try{
    const {unread}=await api('/notifications/summary');
    const amount=Number(unread)||0;
    for(const id of ['nav-unread','top-unread']){
      const node=document.getElementById(id);if(!node)continue;
      node.hidden=amount===0;node.textContent=amount>99?'99+':String(amount);
    }
  }catch(_){/* A badge failure should never block the workspace. */}
}
export function el(tag, value, className) { const n=document.createElement(tag); if(className)n.className=className;if(value!=null)n.textContent=String(value);return n; }
export function statusChip(status) { return el('span',status,'pill '+String(status||'').toLowerCase().replaceAll(' ','-')); }
export function date(value) { return value ? new Date(value).toLocaleDateString('en-IN',{day:'2-digit',month:'short',year:'numeric'}) : '—'; }
export function money(value) { return value==null?'—':new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:0}).format(Number(value)); }
export function head(title,description) { const section=el('div',null,'section-head');const l=el('div');l.append(el('p','CASMS / WORKSPACE','eyebrow'),el('h1',title,'page-title'),el('p',description,'page-desc'));section.append(l);return section; }
export function error(container,message) { const p=el('div',message,'error-inline'); container.prepend(p); }
export function paginator(container,page,total,limit,onPage) {
  container.replaceChildren();const pages=Math.max(1,Math.ceil(total/limit));
  const label=el('span',`Page ${page} of ${pages} · ${total} records`);
  const btns=el('div',null,'pagination-actions');
  for(const [text,target,disabled] of [['Previous',page-1,page<=1],['Next',page+1,page>=pages]]){
    const b=el('button',text);b.type='button';b.disabled=disabled;b.addEventListener('click',()=>onPage(target));btns.append(b);
  }container.append(label,btns);
}
