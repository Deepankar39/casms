import {api,getUser,shell,el,head,statusChip,date,paginator} from './common.js';
const user=await getUser();
if(user){
  const root=shell(user,'requests');
  const header=head('Service requests',user.role==='Admin'?'Assign and oversee campus repair requests':user.role==='Technician'?'Manage repairs assigned to you':'Raise problems and follow their resolution');
  if(user.role!=='Technician'){
    const create=el('a','+ New service request','btn'); create.href='/request-new.html';header.append(create);
  }
  root.append(header);
  const panel=el('section',null,'panel');
  panel.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Request queue</h2><p class="panel-sub">Select a ticket to view and manage its workflow</p></div></div><div class="toolbar"><select id="status" aria-label="Filter by request status"><option value="">All statuses</option><option>Open</option><option>Assigned</option><option>In Progress</option><option>On Hold</option><option>Closed</option><option>Cancelled</option></select></div><p id="load-error" class="error-inline"></p><div class="table-wrap"><table class="table"><thead><tr><th>Ticket</th><th>Issue</th><th>Asset</th><th>Priority</th><th>Status</th><th>Technician</th><th>Date</th></tr></thead><tbody id="list"></tbody></table></div><div id="pages" class="pagination"></div>';
  root.append(panel); let page=1;
  async function load(){
    const tbody=panel.querySelector('#list');tbody.replaceChildren(el('tr','Loading requests…'));panel.querySelector('#load-error').textContent='';
    try{
      const qs=new URLSearchParams({page:String(page),status:panel.querySelector('#status').value});
      const data=await api('/requests?'+qs);tbody.replaceChildren();
      for(const r of data.rows){
        const tr=el('tr');const idCell=el('td');const link=el('a',r.number,'link');link.href='/request.html?id='+encodeURIComponent(r.id);idCell.append(link);tr.append(idCell);
        for(const value of [r.title,r.assetTag,r.priority])tr.append(el('td',value));
        const status=el('td');status.append(statusChip(r.status));tr.append(status,el('td',r.technician||'Unassigned'),el('td',date(r.raisedAt)));tbody.append(tr);
      }
      if(!data.rows.length){const tr=el('tr');const td=el('td','No requests match this filter.','empty');td.colSpan=7;tr.append(td);tbody.append(tr);}
      paginator(panel.querySelector('#pages'),data.page,data.total,data.limit,n=>{page=n;load();});
    }catch(e){panel.querySelector('#load-error').textContent=e.message;tbody.replaceChildren();}
  }
  panel.querySelector('#status').addEventListener('change',()=>{page=1;load();});load();
  root.append(el('p','Open a request to manage assignment, repair progress, comments, maintenance and closure.','footnote'));
}
