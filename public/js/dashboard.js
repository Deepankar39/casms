import {bars} from './charts.js';
import {api,getUser,shell,el,head,statusChip,date,money,error} from './common.js';
const user=await getUser();
if(user){
  const root=shell(user,'dashboard');root.append(head(`Good to see you, ${user.name.split(' ')[0]}.`,'Here is what is happening across your CASMS workspace.'));
  const welcome=el('div',null,'callout'); welcome.innerHTML='<span class="callout-symbol">✦</span><div><strong>Campus service operations at a glance</strong><p>Live information from your MySQL database, filtered by your role.</p></div>';root.append(welcome);
  try {
    const data=await api('/dashboard');const {stats,statuses,recent}=data;
    const cards=[['Assets in scope',stats.assets,'▤','Your permitted asset register'],['Total requests',stats.requests,'☷','Requests visible to your role'],['Pending requests',stats.pending,'◷','Open, assigned or in progress'],['Overdue requests',stats.overdue,'!','Need attention']];
    const grid=el('div',null,'grid-stats');
    for(const [name,value,icon,sub] of cards){const card=el('div',null,'stat');card.innerHTML='<div class="stat-top"><span></span><span class="stat-icon"></span></div><div class="stat-number"></div><div class="stat-foot"></div>';card.querySelector('.stat-top span').textContent=name;card.querySelector('.stat-icon').textContent=icon;card.querySelector('.stat-number').textContent=Number(value).toLocaleString('en-IN');card.querySelector('.stat-foot').textContent=sub;grid.append(card);}root.append(grid);
    const panels=el('div',null,'panels');const chart=el('section',null,'panel');chart.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Request overview</h2><p class="panel-sub">Service requests by status</p></div></div><div class="bars" id="bars"></div>';
    const max=Math.max(1,...statuses.map(x=>x.total));
    for(const s of statuses){const line=el('div');const label=el('div',null,'bar-label');label.append(el('span',s.name),el('span',s.total));const track=el('div',null,'track');const fill=el('div',null,'fill');fill.style.width=`${Math.max(2,s.total/max*100)}%`;track.append(fill);line.append(label,track);chart.querySelector('#bars').append(line);}if(!statuses.length)chart.querySelector('#bars').append(el('p','No request data yet.','empty'));
    const side=el('section',null,'panel');side.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Snapshot</h2><p class="panel-sub">Key operational indicators</p></div></div>';
    const summary=el('div',null,'bars');for(const [label,val] of [['Closed requests',stats.closed],['Completion rate',stats.requests?Math.round(stats.closed/stats.requests*100)+'%':'0%'],['Total maintenance cost',user.role==='Admin'?money(stats.spend):'Role-restricted']]){const bar=el('div',null,'bar-label');bar.append(el('span',label),el('strong',val));summary.append(bar);}side.append(summary);panels.append(chart,side);root.append(panels);
    const recentPanel=el('section',null,'panel');recentPanel.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Recent service requests</h2><p class="panel-sub">Latest activities from your visible queue</p></div><a class="link" href="/requests.html">View all →</a></div><div class="table-wrap"><table class="table"><thead><tr><th>Ticket</th><th>Summary</th><th>Priority</th><th>Status</th><th>Raised</th></tr></thead><tbody id="recent-body"></tbody></table></div>';const tbody=recentPanel.querySelector('#recent-body');for(const r of recent){const tr=el('tr');for(const value of [r.number,r.title,r.priority])tr.append(el('td',value));const td=el('td');td.append(statusChip(r.status));tr.append(td,el('td',date(r.raisedAt)));tbody.append(tr);}if(!recent.length)tbody.append(el('tr','No service requests yet.'));root.append(recentPanel);
    // Live role-scoped trend and equipment insights from the Batch 4 API.
    try{
      const insights=await api('/insights');
      const heading=el('div',null,'section-head');heading.append(el('div','Operational analytics','panel-title'));root.append(heading);
      if(user.role==='Admin'&&insights.warrantyExpiring!=null){
        const exp=el('div',null,'highlight-kpi');exp.append(el('span','WARRANTIES EXPIRING WITHIN 30 DAYS'),el('strong',Number(insights.warrantyExpiring).toLocaleString('en-IN')),el('span','Use Reports → Warranty register to review coverage dates.'));root.append(exp);
      }
      const grid=el('div',null,'insight-grid');
      for(const [title,sub,data,formatter] of [
        ['Asset distribution','Assets by category',insights.categories,null],
        ['Service demand','New requests over the last 12 months',insights.monthlyRequests,null],
        ...(user.role==='Admin'?[['Maintenance spending','Last 12 months of recorded repairs',insights.monthlyCosts,money]]:[])
      ]){
        const panel=el('section',null,'panel');const top=el('div',null,'panel-top');const labels=el('div');labels.append(el('h2',title,'panel-title'),el('p',sub,'panel-sub'));top.append(labels);const chart=el('div',null,'report-bars');bars(chart,data,{valueText:formatter||undefined});panel.append(top,chart);grid.append(panel);
      }root.append(grid);
    }catch(_){root.append(el('p','Live analytics are temporarily unavailable; other dashboard features remain accessible.','footnote'));}

  } catch(err){error(root,err.message);}
}
