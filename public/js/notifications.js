import {api,getUser,shell,el,head,paginator,date,refreshNotificationBadge} from './common.js';
const user=await getUser();
if(user){
  const root=shell(user,'notifications');root.append(head('Notifications','Updates from service requests assigned to you or raised by you.'));
  const panel=el('section',null,'panel');
  panel.innerHTML='<div class="panel-top"><div><h2 class="panel-title">Notification inbox</h2><p class="panel-sub">Read or unread activity, newest first</p></div><button type="button" class="btn subtle" id="read-all">Mark all read</button></div><div class="toolbar"><label class="check-inline"><input type="checkbox" id="unread-only"> Unread only</label></div><p id="notify-error" class="error-inline"></p><div id="notification-list" class="inbox-list"></div><div id="pages" class="pagination"></div>';
  root.append(panel);let page=1;
  async function load(){const list=panel.querySelector('#notification-list');list.replaceChildren(el('p','Loading…','loading'));panel.querySelector('#notify-error').textContent='';
    try{
      const q=new URLSearchParams({page:String(page),unreadOnly:panel.querySelector('#unread-only').checked?'1':'0'});
      const data=await api('/notifications?'+q);list.replaceChildren();
      for(const n of data.rows){
        const row=el('article',null,'inbox-item'+(Number(n.isRead)===0?' unread':''));
        const icon=el('span','♧','inbox-icon');const body=el('div',null,'inbox-text');
        body.append(el('strong',n.type||'Update'),el('p',n.message),el('small',date(n.createdAt)));
        if(n.requestId){const link=el('a','View request →','link');link.href='/request.html?id='+encodeURIComponent(n.requestId);body.append(link);}
        row.append(icon,body);
        if(!Number(n.isRead)){
          const b=el('button','Mark read','btn subtle inbox-action');b.type='button';b.addEventListener('click',async()=>{try{b.disabled=true;await api(`/notifications/${n.id}/read`,{method:'POST'});await load();await refreshNotificationBadge();}catch(e){panel.querySelector('#notify-error').textContent=e.message;b.disabled=false;}});row.append(b);
        }else row.append(el('span','Read','muted inbox-read'));
        list.append(row);
      }
      if(!data.rows.length)list.append(el('p','No notifications match this filter.','empty'));
      paginator(panel.querySelector('#pages'),data.page,data.total,data.limit,n=>{page=n;load();});
      panel.querySelector('#read-all').disabled=data.total===0;
    }catch(e){panel.querySelector('#notify-error').textContent=e.message;list.replaceChildren();}
  }
  panel.querySelector('#unread-only').addEventListener('change',()=>{page=1;load();});
  panel.querySelector('#read-all').addEventListener('click',async()=>{try{await api('/notifications/read-all',{method:'POST'});page=1;await load();await refreshNotificationBadge();}catch(e){panel.querySelector('#notify-error').textContent=e.message;}});
  load();
}
