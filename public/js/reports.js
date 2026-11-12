import {api,getUser,shell,el,head,paginator,date,money} from './common.js';
import {bars} from './charts.js';
const user=await getUser();
if(user){
  const root=shell(user,'reports');
  root.append(head('Reports & analytics','Explore live campus reports and export the data you are permitted to see.'));
  const form=el('section',null,'panel');
  form.innerHTML=`<div class="panel-top"><div><h2 class="panel-title">Report explorer</h2><p class="panel-sub">Select a report, optionally filter dates or search records</p></div><span class="report-tag">LIVE MYSQL</span></div>
    <div class="report-controls"><label>Report<select id="report-name"></select></label><label>From date<input type="date" id="from"></label><label>To date<input type="date" id="to"></label><label>Search<input id="search" type="search" placeholder="Optional keyword" maxlength="80"></label></div>
    <div class="report-actions"><button type="button" class="btn" id="run">Run report</button><button type="button" class="btn subtle" id="export">↓ Export CSV</button><span id="result-count" class="muted"></span></div><p class="error-inline" id="report-error"></p>`;
  root.append(form);
  const visual=el('section',null,'panel');visual.innerHTML='<div class="panel-top"><div><h2 class="panel-title" id="chart-title">Report distribution</h2><p class="panel-sub" id="chart-description">Distribution across reported records</p></div></div><div id="report-chart" class="report-bars"></div>';
  const table=el('section',null,'panel');table.innerHTML='<div class="panel-top"><div><h2 class="panel-title" id="table-title">Results</h2><p class="panel-sub" id="table-sub">Live database records</p></div></div><div class="table-wrap"><table class="table"><thead id="report-head"></thead><tbody id="report-body"></tbody></table></div><div class="pagination" id="report-pages"></div>';
  root.append(visual,table);
  let page=1,current=null,serial=0,catalog=[];
  function query(withPage=true){const q=new URLSearchParams();for(const id of ['from','to','search']){const v=form.querySelector('#'+id).value.trim();if(v)q.set(id,v);}if(withPage)q.set('page',String(page));return q;}
  const select=form.querySelector('#report-name');
  async function load(){
    const id=select.value;if(!id)return;
    const local=++serial;
    form.querySelector('#report-error').textContent='';table.querySelector('#report-body').replaceChildren(el('tr','Loading report…'));
    try{
      const result=await api('/reports/'+encodeURIComponent(id)+'?'+query());if(local!==serial)return;
      current=result;
      table.querySelector('#table-title').textContent=result.title;
      table.querySelector('#table-sub').textContent=result.description;
      form.querySelector('#result-count').textContent=`${Number(result.total).toLocaleString('en-IN')} records`;
      const tr=el('tr');for(const c of result.columns)tr.append(el('th',c.label));table.querySelector('#report-head').replaceChildren(tr);
      const body=table.querySelector('#report-body');body.replaceChildren();
      for(const item of result.rows){const row=el('tr');for(const c of result.columns){let v=item[c.key];if(c.kind==='money')v=money(v);else if(c.kind==='date')v=date(v);else if(v==null||v==='')v='—';row.append(el('td',v));}body.append(row);}
      if(!result.rows.length){const row=el('tr');const cell=el('td','No records match your selection.','empty');cell.colSpan=result.columns.length;row.append(cell);body.append(row);}
      paginator(table.querySelector('#report-pages'),result.page,result.total,result.limit,n=>{page=n;load();});
      const numeric=result.columns.find(c=>c.kind==='integer'||c.kind==='money');
      const named=result.columns.find(c=>c.kind==='text'&&c.key!==numeric?.key);
      visual.hidden=!numeric||!named||result.rows.length===0;
      if(!visual.hidden){
        visual.querySelector('#chart-title').textContent=result.title+' · preview';
        visual.querySelector('#chart-description').textContent='First-page distribution; use CSV for the full dataset';
        bars(visual.querySelector('#report-chart'),result.rows.slice(0,10).map(r=>({label:String(r[named.key]||'—'),value:Number(r[numeric.key])||0})),{valueText:numeric.kind==='money'?money:undefined});
      }
    }catch(e){if(local===serial){form.querySelector('#report-error').textContent=e.message;table.querySelector('#report-body').replaceChildren();visual.hidden=true;}}
  }
  form.querySelector('#run').addEventListener('click',()=>{page=1;load();});
  select.addEventListener('change',()=>{page=1;load();});
  form.querySelector('#export').addEventListener('click',()=>{
    if(!select.value)return;
    const url='/api/reports/'+encodeURIComponent(select.value)+'/export?'+query(false);
    // Download uses same-origin session cookies; server verifies role and filters.
    const anchor=el('a');anchor.href=url;anchor.download='';document.body.append(anchor);anchor.click();anchor.remove();
  });
  try{
    const response=await api('/reports/catalog');catalog=response.reports;
    for(const r of catalog){const o=el('option',r.label);o.value=r.id;select.append(o);}
    if(catalog.length)load();
    else form.querySelector('#report-error').textContent='No reports available for your role.';
  }catch(e){form.querySelector('#report-error').textContent=e.message;}
}
