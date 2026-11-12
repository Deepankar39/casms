import {api,getUser,shell,el,head,paginator,date} from './common.js';
const user=await getUser();
if(user){
  const root=shell(user,'audit');root.append(head('Audit trail','Read-only records of database changes captured by MySQL triggers.'));
  if(user.role!=='Admin')root.append(el('p','Audit history is only available to administrators.','error-inline'));
  else{
    const panel=el('section',null,'panel');panel.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Change history</h2><p class="panel-sub">Inspect old and new values of recorded changes</p></div><span class="report-tag">APPEND ONLY</span></div><div class="report-controls"><label>Table<select id="table"><option value="">All tables</option></select></label><label>Action<select id="action"><option value="">All actions</option><option>INSERT</option><option>UPDATE</option><option>DELETE</option></select></label><label>From<input id="from" type="date"></label><label>To<input id="to" type="date"></label></div><div class="report-actions"><button type="button" id="filter" class="btn">Apply filters</button></div><p class="error-inline" id="audit-error"></p><div class="table-wrap"><table class="table"><thead><tr><th>ID</th><th>Table</th><th>Record</th><th>Action</th><th>Changed by</th><th>When</th><th>Details</th></tr></thead><tbody id="audit-list"></tbody></table></div><div class="pagination" id="pages"></div>';
    root.append(panel);
    const detail=el('dialog',null,'audit-dialog');detail.innerHTML='<div class="panel-top"><h2 class="panel-title">Recorded changes</h2><button id="close" type="button" class="btn subtle">Close</button></div><div class="audit-compare"><div><h3>Before</h3><pre id="before"></pre></div><div><h3>After</h3><pre id="after"></pre></div></div>';
    root.append(detail);detail.querySelector('#close').addEventListener('click',()=>detail.close());
    let page=1;
    const params=()=>{const q=new URLSearchParams({page:String(page)});for(const id of ['table','action','from','to']){const v=panel.querySelector('#'+id).value;if(v)q.set(id,v);}return q;};
    function pretty(v){if(v==null)return 'No recorded values';try{return JSON.stringify(typeof v==='string'?JSON.parse(v):v,null,2);}catch{return String(v);}}
    async function load(){
      const body=panel.querySelector('#audit-list');body.replaceChildren(el('tr','Loading history…'));panel.querySelector('#audit-error').textContent='';
      try{const data=await api('/audit?'+params());body.replaceChildren();
        for(const record of data.rows){const row=el('tr');for(const val of [record.id,record.tableName,record.recordId,record.action,record.actor||'Database operation',date(record.changedAt)])row.append(el('td',val));
          const td=el('td');const btn=el('button','Inspect','btn subtle');btn.type='button';btn.addEventListener('click',()=>{detail.querySelector('#before').textContent=pretty(record.beforeValues);detail.querySelector('#after').textContent=pretty(record.afterValues);detail.showModal();});td.append(btn);row.append(td);body.append(row);}
        if(!data.rows.length){const tr=el('tr');const td=el('td','No audit events match the selected filters.','empty');td.colSpan=7;tr.append(td);body.append(tr);}
        paginator(panel.querySelector('#pages'),data.page,data.total,data.limit,n=>{page=n;load();});
      }catch(e){panel.querySelector('#audit-error').textContent=e.message;body.replaceChildren();}
    }
    panel.querySelector('#filter').addEventListener('click',()=>{page=1;load();});
    try{const {rows}=await api('/audit/tables');for(const r of rows){const opt=el('option',r.name);opt.value=r.name;panel.querySelector('#table').append(opt);}load();}catch(e){panel.querySelector('#audit-error').textContent=e.message;}
  }
}
