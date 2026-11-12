import {api,getUser,shell,el,head,statusChip,money,paginator} from './common.js';
import {button} from './forms.js';
const user=await getUser();
if(user){
 const root=shell(user,'assets');const header=head('Asset register','Explore, track and manage campus equipment.');
 if(user.role==='Admin')header.append(button('＋ Register asset',()=>location.assign('/asset-new.html')));
 root.append(header);
 const panel=el('section',null,'panel');panel.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Campus assets</h2><p class="panel-sub">Click an asset to view history and management actions</p></div></div><div class="toolbar"><input class="search" id="search" placeholder="Search tags, names and categories" aria-label="Search assets"><select id="status" aria-label="Filter asset status"><option value="">All statuses</option><option>In Stock</option><option>Active</option><option>Under Repair</option><option>Retired</option></select></div><p class="error-inline" id="load-error"></p><div class="table-wrap"><table class="table"><thead><tr><th>Tag</th><th>Name</th><th>Category</th><th>Department</th><th>Room</th><th>Status</th><th>Value</th></tr></thead><tbody id="list"></tbody></table></div><div class="pagination" id="pages"></div>';
 root.append(panel);let page=1,timer,serial=0;
 async function load(){const current=++serial;const tbody=panel.querySelector('#list');tbody.replaceChildren();panel.querySelector('#load-error').textContent='';
  try{const qs=new URLSearchParams({page:String(page),search:panel.querySelector('#search').value,status:panel.querySelector('#status').value});const data=await api('/assets?'+qs);if(current!==serial)return;
   for(const a of data.rows){const tr=el('tr');const link=el('a',a.tag,'mini-link');link.href='/asset.html?id='+encodeURIComponent(a.id);const first=el('td');first.append(link);tr.append(first);
     for(const value of [a.name,a.category,a.department,a.room||'—'])tr.append(el('td',value));const s=el('td');s.append(statusChip(a.status));tr.append(s,el('td',money(a.purchaseCost)));tbody.append(tr);}
   if(!data.rows.length){const tr=el('tr');const td=el('td','No matching assets.','empty');td.colSpan=7;tr.append(td);tbody.append(tr);}
   paginator(panel.querySelector('#pages'),data.page,data.total,data.limit,n=>{page=n;load();});
  }catch(err){panel.querySelector('#load-error').textContent=err.message;}
 }
 panel.querySelector('#search').addEventListener('input',()=>{page=1;clearTimeout(timer);timer=setTimeout(load,300);});
 panel.querySelector('#status').addEventListener('change',()=>{page=1;load();});load();
}
