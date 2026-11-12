import {api,getUser,shell,el,head} from './common.js';
import {button,field,formBox,formValues,table,td,toast,opt} from './forms.js';
const user=await getUser();
if(user){
  if(user.role!=='Admin'){location.replace('/dashboard.html');}
  else {
    const root=shell(user,'master');root.append(head('Campus master data','Manage the departments, locations, categories and vendors used throughout CASMS.'));
    const defs={
      departments:{title:'Departments',pk:'department_id',columns:['department_code','department_name'],fields:[['Department code','department_code',true],['Department name','department_name',true]]},
      buildings:{title:'Buildings',pk:'building_id',columns:['building_code','building_name'],fields:[['Building code','building_code',true],['Building name','building_name',true],['Notes','notes',false]]},
      rooms:{title:'Rooms',pk:'room_id',columns:['room_number','room_type','floor_number'],fields:[['Building','building_id',true,'buildings'],['Department','department_id',false,'departments'],['Room number','room_number',true],['Floor','floor_number',false,'number'],['Room type','room_type',true]]},
      asset_categories:{title:'Categories',pk:'category_id',columns:['category_code','category_name','default_useful_life_years'],fields:[['Category code','category_code',true],['Category name','category_name',true],['Useful life in years','default_useful_life_years',false,'number']]},
      vendors:{title:'Vendors',pk:'vendor_id',columns:['vendor_name','contact_number','email','vendor_type'],fields:[['Vendor name','vendor_name',true],['Phone','contact_number',false],['Email','email',false,'email'],['Vendor type','vendor_type',true,'vendorTypes']]}
    };
    const tabs=el('div',null,'control-tabs');const section=el('div');root.append(tabs,section);
    let resource='departments', editing=null, serial=0;
    async function load(){const seq=++serial;const def=defs[resource];tabs.replaceChildren();
      for(const [key,val] of Object.entries(defs)){const b=button(val.title,()=>{resource=key;editing=null;load();},'btn'+(resource===key?' selected':''));tabs.append(b);}
      section.replaceChildren(el('p','Loading…','loading'));
      try{
        const requests=[api('/master/'+resource)];
        if(resource==='rooms')requests.push(api('/master/buildings'),api('/master/departments'));
        const results=await Promise.all(requests);if(seq!==serial)return;
        const rows=results[0].rows;const sources={buildings:results[1]?.rows||[],departments:results[2]?.rows||[]};
        section.replaceChildren();const grid=el('div',null,'editor-grid');
        const left=el('div');const right=el('section',null,'panel');const hd=el('div',null,'panel-top');hd.append(el('h2',`${def.title} (${rows.length})`,'panel-title'));right.append(hd);
        const cols=[...def.columns,'is_active','Actions'];
        right.append(table(cols.map(c=>c.replaceAll('_',' ')),rows,(tr,r)=>{
          for(const c of def.columns)td(tr,r[c]);td(tr,r.is_active?'Active':'Inactive');
          const action=el('td');const buttons=el('div',null,'action-line');
          buttons.append(button('Edit',()=>{editing=r;load();},'btn subtle sm'));
          buttons.append(button(r.is_active?'Deactivate':'Activate',async()=>{
            if(!confirm(`${r.is_active?'Deactivate':'Activate'} this record?`))return;
            try{await api(`/master/${resource}/${r[def.pk]}/status`,{method:'PATCH',data:{is_active:!r.is_active}});editing=null;await load();toast(root,'Record updated.');}catch(e){alert(e.message);}
          },'btn subtle sm'));
          action.append(buttons);tr.append(action);
        }));
        const fields=def.fields.map(([label,key,required,type])=>{
          const value=editing?.[key]??'';
          if(type==='vendorTypes')return field(label,key,{value,required,options:opt(['Supplier','Service Provider','Both'].map(v=>({id:v,name:v})))});
          if(type==='buildings'||type==='departments'){
            const fk=type==='buildings'?'building_id':'department_id';
            const labelKey=type==='buildings'?'building_name':'department_name';
            return field(label,key,{value,required,options:opt(sources[type].filter(x=>x.is_active||x[fk]===value).map(x=>({id:x[fk],name:x[labelKey]})))});
          }
          return field(label,key,{value,required,type:type||'text',min:type==='number'?0:null});
        });
        const editor=formBox(editing?`Edit ${def.title.toLowerCase()}`:`Add ${def.title.toLowerCase()}`,editing?'Save changes':'Create record',async(values)=>{
          const currentResource=resource;const id=editing?.[def.pk];
          await api(`/master/${currentResource}${id?'/'+id:''}`,{method:id?'PUT':'POST',data:values});editing=null;await load();toast(root,'Saved successfully.');
        },fields);
        if(editing)editor.querySelector('.editor-actions').append(button('Cancel',()=>{editing=null;load();},'btn subtle'));
        left.append(editor);grid.append(left,right);section.append(grid);
      }catch(e){if(seq===serial)section.replaceChildren(el('p',e.message,'error-inline'));}
    }
    load();
  }
}
