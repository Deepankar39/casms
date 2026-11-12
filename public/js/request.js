import {api,getUser,shell,el,head,date,statusChip,money} from './common.js';
import {field,formBox,opt,toast,table,td,button} from './forms.js';
const user=await getUser();
if(user){
  const root=shell(user,'requests');
  const id=new URLSearchParams(location.search).get('id');
  const alert=el('p','', 'error-inline');root.append(alert);
  const content=el('div');root.append(content);
  if(!/^\d+$/.test(id||'')){alert.textContent='Select a valid request from the queue.';}
  else {
    let technicians=[];
    if(user.role==='Admin'){
      try{const lookups=await api('/requests/lookups');technicians=lookups.technicians;}catch(e){alert.textContent=e.message;}
    }
    const showError=e=>{alert.textContent=e.message||String(e);window.scrollTo({top:0,behavior:'smooth'});};
    async function apply(path,payload){try{alert.textContent='';await api('/requests/'+id+path,{method:'POST',data:payload});await render();toast(content,'Saved successfully.');}catch(e){showError(e);}}
    async function render(){
      try{
        const {request:r,timeline,maintenance}=await api('/requests/'+id);
        content.replaceChildren();
        const header=head(r.number+' · '+r.title,`${r.assetTag} · ${r.assetName}`);
        const back=el('a','← All service requests','btn subtle');back.href='/requests.html';header.append(back);content.append(header);
        const summary=el('section',null,'panel');summary.append(el('h2','Request overview','panel-title'));
        const grid=el('div',null,'request-facts');
        for(const [key,value] of [
          ['Status',r.status],['Priority',r.priority],['Requester',r.requester],['Assigned technician',r.technician||'Not assigned'],
          ['Raised',date(r.raisedAt)],['Due',date(r.dueAt)],['Started',date(r.startedAt)],['Closed',date(r.closedAt)]
        ]){const item=el('div',null,'request-fact');item.append(el('span',key,'fact-label'),el('strong',value));grid.append(item);}
        summary.append(grid,el('p',r.description,'request-description'));
        if(r.resolution)summary.append(el('p','Resolution: '+r.resolution,'request-description'));
        if(r.cancellationReason)summary.append(el('p','Cancellation: '+r.cancellationReason,'request-description'));
        content.append(summary);
        const actionGroup=el('div',null,'request-actions');content.append(actionGroup);
        const authorizedTech=user.role==='Technician'&&Number(r.technicianId)===Number(user.id);
        const operator=user.role==='Admin'||authorizedTech;
        if(user.role==='Admin'&&['Open','Assigned'].includes(r.status)){
          const box=formBox('Assign technician','Assign',v=>apply('/assign',{technicianId:v.technicianId}),[
            field('Available technician','technicianId',{options:opt(technicians,t=>t.name),required:true})
          ]);actionGroup.append(box);
        }
        if(operator&&['Assigned','In Progress','On Hold'].includes(r.status)){
          const card=el('section',null,'panel');card.append(el('h2','Repair progress','panel-title'));
          const actions=el('div',null,'request-button-row');
          if(r.status==='Assigned')actions.append(button('Start repair',()=>apply('/status',{status:'In Progress'}),'btn'));
          if(r.status==='In Progress')actions.append(button('Place on hold',()=>apply('/status',{status:'On Hold'}),'btn subtle'));
          if(r.status==='On Hold')actions.append(button('Resume repair',()=>apply('/status',{status:'In Progress'}),'btn'));
          card.append(actions);actionGroup.append(card);
        }
        if(operator&&r.status==='In Progress'){
          const now=new Date();const local=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}T${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
          const started=r.startedAt?local(new Date(r.startedAt)):local(now);
          const parts=el('div',null,'request-parts');let partRows=[];
          const partsCaption=el('div',null,'request-part-head');partsCaption.append(el('h3','Replacement parts (optional)','panel-title'));
          const addPart=button('+ Add part',()=>addPartRow(), 'btn subtle');partsCaption.append(addPart);
          parts.append(partsCaption);const list=el('div');parts.append(list);
          function addPartRow(){
            const row=el('div',null,'part-row');
            const name=field('Part','partName',{required:true,placeholder:'Cable, adapter, etc.'});
            const qty=field('Quantity','qty',{type:'number',required:true,min:1,value:1});
            const cost=field('Unit cost','unitCost',{type:'number',required:true,min:0,step:'0.01',value:'0.00'});
            const remove=button('Remove',()=>{row.remove();partRows=partRows.filter(x=>x.row!==row);},'btn subtle');
            row.append(name,qty,cost,remove);list.append(row);partRows.push({row,name:name.querySelector('input'),quantity:qty.querySelector('input'),unitCost:cost.querySelector('input')});
          }
          const form=formBox('Close with maintenance record','Close request',async values=>{
            if(!window.confirm('Close this request and save the maintenance record?'))return;
            const payload={diagnosis:values.diagnosis,workPerformed:values.workPerformed,startAt:values.startAt,endAt:values.endAt,
              labourCost:values.labourCost,outcome:values.outcome,warrantyCovered:values.warrantyCovered==='yes',
              parts:partRows.map(p=>({name:p.name.value,quantity:p.quantity.value,unitCost:p.unitCost.value}))};
            await apply('/close',payload);
          },[
            field('Diagnosis','diagnosis',{type:'textarea',required:true,placeholder:'What was wrong?'}),
            field('Work performed','workPerformed',{type:'textarea',required:true,placeholder:'What was done to resolve it?'}),
            field('Work started','startAt',{type:'datetime-local',required:true,value:started}),
            field('Work completed','endAt',{type:'datetime-local',required:true,value:local(now)}),
            field('Labour cost','labourCost',{type:'number',required:true,min:0,step:'0.01',value:'0.00'}),
            field('Outcome','outcome',{required:true,options:[{value:'Repaired',label:'Repaired'},{value:'Replaced',label:'Replaced'},{value:'Beyond Repair',label:'Beyond Repair'}]}),
            field('Covered by warranty','warrantyCovered',{required:true,options:[{value:'no',label:'No'},{value:'yes',label:'Yes'}]})
          ]);
          const target=form.querySelector('form');target.insertBefore(parts,target.querySelector('.editor-actions'));
          actionGroup.append(form);
        }
        if((user.role==='Admin'&&['Open','Assigned'].includes(r.status))||(user.role==='Staff'&&r.status==='Open')){
          actionGroup.append(formBox('Cancel request','Cancel request',async values=>{
            if(window.confirm('Cancel this service request?'))await apply('/cancel',{reason:values.reason});
          },[field('Reason','reason',{required:true,type:'textarea'})]));
        }
        if(user.role==='Admin'&&r.status==='Closed'){
          const card=el('section',null,'panel');card.append(el('h2','Reopen request','panel-title'));
          card.append(el('p','Admin may reopen a request within seven days of its closure.','page-desc'));
          card.append(button('Reopen this request',()=>{if(window.confirm('Reopen this request?'))apply('/reopen',{});},'btn subtle'));actionGroup.append(card);
        }
        if(user.role==='Staff'&&r.status==='Closed'&&r.feedbackRating==null){
          actionGroup.append(formBox('Rate the repair','Submit feedback',v=>apply('/feedback',{rating:v.rating,comment:v.comment}),[
            field('Rating','rating',{required:true,options:[1,2,3,4,5].map(n=>({value:n,label:`${n} / 5`}))}),
            field('Comment (optional)','comment',{type:'textarea'})
          ]));
        }
        if(r.feedbackRating!=null)content.append(el('p',`Staff feedback: ${r.feedbackRating}/5 — ${r.feedbackComment||'No comment'}`,'notice'));
        if(!['Cancelled','Closed'].includes(r.status)){
          actionGroup.append(formBox('Add a timeline comment','Post comment',v=>apply('/comments',{comment:v.comment}),[
            field('Comment','comment',{type:'textarea',required:true,placeholder:'Share an update or question.'})
          ]));
        }
        const history=el('section',null,'panel');history.append(el('h2','Activity timeline','panel-title'));
        const events=el('div',null,'timeline');
        for(const u of timeline){const item=el('div',null,'timeline-event');item.append(el('strong',u.type+' · '+u.author),el('small',date(u.createdAt)),el('p',u.comment||`${u.oldValue||'—'} → ${u.newValue||'—'}`));events.append(item);}
        if(!timeline.length)events.append(el('p','No timeline entries yet.','page-desc'));
        history.append(events);content.append(history);
        const repairs=el('section',null,'panel');repairs.append(el('h2','Maintenance history','panel-title'));
        if(!maintenance.length)repairs.append(el('p','No completed maintenance records yet.','page-desc'));
        for(const m of maintenance){const card=el('div',null,'repair-history');card.append(el('strong',m.outcome+' · '+m.technician),el('p','Diagnosis: '+m.diagnosis),el('p','Work: '+m.workPerformed),el('p',`Labour: ${money(m.labourCost)} · Warranty: ${m.warrantyCovered?'Yes':'No'}`));
          if(m.parts.length){card.append(table(['Part','Quantity','Unit cost'],m.parts,(tr,p)=>{td(tr,p.name);td(tr,p.quantity);td(tr,money(p.unitCost));}));}repairs.append(card);}
        content.append(repairs);
      }catch(e){content.replaceChildren();showError(e);}
    }
    render();
  }
}
