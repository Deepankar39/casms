import {api,getUser,shell,el,head} from './common.js';
import {field,formBox,opt,toast} from './forms.js';
const user=await getUser();
if(user){
  if(user.role==='Technician')location.replace('/requests.html');
  else {
    const root=shell(user,'requests');root.append(head('Raise a service request','Report a campus asset issue and track it through repair and closure.'));
    const message=el('p','', 'error-inline');root.append(message);
    try{
      const data=await api('/requests/lookups');
      const assetOptions=opt(data.assets,a=>`${a.tag} — ${a.name}`);
      const priorityOptions=opt(data.priorities,p=>`${p.name} · target ${p.targetHours}h`);
      const form=formBox('New request','Submit request',async values=>{
        const payload={assetId:values.assetId,priorityId:values.priorityId,title:values.title,description:values.description};
        let result;
        try{result=await api('/requests',{method:'POST',data:payload});}
        catch(err){
          if(err.message.includes('Active request') && window.confirm(err.message+'\n\nCreate another request anyway?')){
            result=await api('/requests',{method:'POST',data:{...payload,allowDuplicate:true}});
          } else throw err;
        }
        location.assign('/request.html?id='+encodeURIComponent(result.id));
      },[
        field('Asset','assetId',{options:assetOptions,required:true}),
        field('Priority','priorityId',{options:priorityOptions,required:true}),
        field('Issue title','title',{required:true,placeholder:'e.g. Classroom projector will not switch on'}),
        field('Detailed description','description',{type:'textarea',required:true,placeholder:'Describe the problem, location and symptoms.'})
      ]);
      root.append(form);
      if(!data.assets.length)root.append(el('p','No eligible assets are available for your account. Ask your administrator to check asset ownership.','notice'));
    }catch(e){message.textContent=e.message;}
  }
}
