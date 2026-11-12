import {api,getUser,shell,el,head,statusChip,money,date} from './common.js';
import {button,field,formBox,table,td,opt,toast} from './forms.js';
const user=await getUser();
if(user){
  const id=Number(new URLSearchParams(location.search).get('id'));
  const root=shell(user,'asset');
  if(!Number.isSafeInteger(id)||id<=0)root.append(el('p','Invalid asset ID.','error-inline'));
  else {
    let currentAction='edit';const actionNames={edit:'Edit asset',assign:'Assign asset',end:'End assignment',transfer:'Transfer asset',retire:'Retire asset'};
    async function render(){root.replaceChildren(el('p','Loading asset details…','loading'));
      try{
        const [detail,history,lookups]=await Promise.all([
          api('/assets/'+id),api('/assets/'+id+'/history'),user.role==='Admin'?api('/assets/lookups'):Promise.resolve(null)
        ]);
        root.replaceChildren();const a=detail.asset;
        const hdr=head(a.asset_tag,`${a.asset_name} · ${a.category_name}`);
        if(user.role==='Admin'){
          const actions=el('div',null,'action-line');
          actions.append(button('＋ New asset',()=>location.assign('/asset-new.html'),'btn subtle'));
          if(a.status==='In Stock')actions.append(button('Activate asset',async()=>{
            try{await api('/assets/'+id+'/activate',{method:'POST',data:{}});await render();toast(root,'Asset activated.');}catch(e){alert(e.message);}
          }));hdr.append(actions);
        }root.append(hdr);
        const facts=el('div',null,'record-facts');
        for(const [label,value] of [['Status',a.status],['Department',a.department_name],['Room',a.room_number||'In stock / unassigned'],['Purchase value',money(a.purchase_cost)]]){
          const fact=el('div',null,'fact');fact.append(el('div',label,'k'),el('div',value,'v'));facts.append(fact);
        }root.append(facts);
        const overview=el('section',null,'panel');overview.append(el('h2','Asset information','panel-title'));
        const keyvalues=el('div',null,'key-values');
        for(const [label,value] of [['Serial number',a.serial_number],['Brand',a.brand],['Model',a.model],['Purchase date',date(a.purchase_date)],['Useful life',a.useful_life_years&&a.useful_life_years+' years'],['Salvage value',money(a.salvage_value)],['Retirement review',a.needs_retirement_review?'Required':'No'],['Retirement reason',a.retirement_reason]]){
          const row=el('p');row.append(el('strong',label),el('span',value||'—'));keyvalues.append(row);
        }overview.append(keyvalues);root.append(overview);
        if(user.role==='Admin'&&a.status!=='Retired'){
          const controls=el('section',null,'panel');controls.append(el('h2','Asset management','panel-title'));
          const tabs=el('div',null,'control-tabs');const editor=el('div');controls.append(tabs,editor);root.append(controls);
          const opList=['edit','assign','end','transfer','retire'];
          const active=history.assignments.some(x=>x.assigned_to===null);
          if(!active&&currentAction==='end')currentAction='assign';
          function show(){tabs.replaceChildren();editor.replaceChildren();
            for(const op of opList){if(op==='end'&&!active)continue;
              tabs.append(button(actionNames[op],()=>{currentAction=op;show();},'btn'+(currentAction===op?' selected':'')));
            }
            const save=async(path,data,method='POST')=>{await api('/assets/'+id+path,{method,data});await render();toast(root,'Asset updated successfully.');};
            if(currentAction==='edit'){
              editor.append(formBox('Update asset details','Save changes',data=>save('',data,'PUT'),[
                field('Asset name','name',{required:true,value:a.asset_name}),
                field('Serial number','serialNumber',{value:a.serial_number||''}),
                field('Brand','brand',{value:a.brand||''}),
                field('Model','model',{value:a.model||''}),
                field('Vendor','vendorId',{value:a.vendor_id||'',options:opt(lookups.vendors)}),
                field('Parent asset ID (optional)','parentAssetId',{value:a.parent_asset_id||'',type:'number',min:1}),
                field('Purchase date','purchaseDate',{value:a.purchase_date?String(a.purchase_date).slice(0,10):'',type:'date'}),
                field('Purchase cost','purchaseCost',{value:a.purchase_cost,type:'number',required:true,min:0,step:'0.01'}),
                field('Salvage value','salvageValue',{value:a.salvage_value,type:'number',required:true,min:0,step:'0.01'}),
                field('Useful life (years)','usefulLifeYears',{value:a.useful_life_years||'',type:'number',min:1})
              ]));
            } else if(currentAction==='assign'){
              editor.append(formBox('Assign responsibility','Create assignment',data=>save('/assign',data),[
                field('User (optional)','userId',{options:opt(lookups.users)}),
                field('Department','departmentId',{value:a.department_id,options:opt(lookups.departments,x=>x.code+' · '+x.name)}),
                field('Assigned room','roomId',{value:a.room_id||'',options:opt(lookups.rooms)})
              ]));
              if(active)editor.append(el('p','There is already a current assignment. End it before creating another.','footnote'));
            } else if(currentAction==='end'){
              editor.append(el('p','Close the current assignment while preserving assignment history.','page-desc'));
              editor.append(button('End current assignment',async()=>{if(!confirm('End current assignment?'))return;
                try{await save('/end-assignment',{});}catch(e){alert(e.message);}},'btn danger'));
            } else if(currentAction==='transfer'){
              editor.append(formBox('Move asset to another location','Record transfer',data=>save('/transfer',data),[
                field('Department','departmentId',{required:true,value:a.department_id,options:opt(lookups.departments,x=>x.code+' · '+x.name)}),
                field('Destination room','roomId',{value:a.room_id||'',options:opt(lookups.rooms)}),
                field('Reason','reason',{required:true,type:'textarea',placeholder:'Why is the asset moving?'})
              ]));
            } else if(currentAction==='retire'){
              editor.append(formBox('Retire this asset','Retire permanently',async data=>{
                if(!confirm('Retirement is permanent. Continue?'))throw new Error('Retirement cancelled.');
                await save('/retire',data);
              },[field('Retirement reason','reason',{required:true,type:'textarea'})]));
            }
          }show();
        }
        const hist=el('div',null,'history-grid');
        const assignments=el('section',null,'panel');assignments.append(el('h2','Assignment history','panel-title'));
        assignments.append(table(['Assigned','Ended','User','Department'],history.assignments,(tr,r)=>{
          for(const v of [date(r.assigned_from),date(r.assigned_to),r.assigned_user||'Department',r.department])td(tr,v);
        }));hist.append(assignments);
        const moves=el('section',null,'panel');moves.append(el('h2','Transfers','panel-title'));
        moves.append(table(['Date','From','To'],history.transfers,(tr,r)=>{
          td(tr,date(r.transferred_at));td(tr,`${r.from_department} / ${r.from_room||'—'}`);td(tr,`${r.to_department} / ${r.to_room||'—'}`);
        }));hist.append(moves);
        const guarantees=el('section',null,'panel');guarantees.append(el('h2','Warranty history','panel-title'));
        guarantees.append(table(['Type','From','Until'],history.warranties,(tr,r)=>{
          td(tr,r.coverage_type);td(tr,date(r.start_date));td(tr,date(r.end_date));
        }));hist.append(guarantees);
        const requests=el('section',null,'panel');requests.append(el('h2','Service history','panel-title'));
        requests.append(table(['Ticket','Issue','Status'],history.requests,(tr,r)=>{td(tr,r.request_number);td(tr,r.title);td(tr,r.status_name);}));hist.append(requests);
        root.append(hist);
      }catch(e){root.replaceChildren(el('p',e.message,'error-inline'));}
    }render();
  }
}
