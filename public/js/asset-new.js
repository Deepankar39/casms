import {api,getUser,shell,el,head} from './common.js';
import {field,formBox,opt} from './forms.js';
const user=await getUser();
if(user){if(user.role!=='Admin')location.replace('/assets.html');else{
  const root=shell(user,'assets');root.append(head('Register new asset','Automatically generate a unique campus asset tag using the MySQL registration procedure.'));
  try{
    const info=await api('/assets/lookups');
    const editor=formBox('Asset registration','Register asset',async values=>{
      const result=await api('/assets',{method:'POST',data:{name:values.name,departmentId:values.departmentId,categoryId:values.categoryId,roomId:values.roomId||null,purchaseCost:values.purchaseCost}});
      location.assign('/asset.html?id='+encodeURIComponent(result.id));
    },[
      field('Asset name','name',{required:true,placeholder:'Example: Dell desktop computer'}),
      field('Department','departmentId',{required:true,options:opt(info.departments,x=>x.code+' · '+x.name)}),
      field('Category','categoryId',{required:true,options:opt(info.categories,x=>x.code+' · '+x.name)}),
      field('Room (optional)','roomId',{options:opt(info.rooms,x=>x.name)}),
      field('Purchase cost (₹)','purchaseCost',{required:true,type:'number',min:0,step:'0.01'})
    ]);
    root.append(editor,el('p','An asset will start as In Stock. Add the serial number, vendor and further details on its detail page.','footnote'));
  }catch(err){root.append(el('p',err.message,'error-inline'));}
}}
