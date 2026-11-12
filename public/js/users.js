import {api,getUser,shell,el,head} from './common.js';
import {button,field,formBox,table,td,toast,opt} from './forms.js';
const user=await getUser();
if(user){
  if(user.role!=='Admin')location.replace('/dashboard.html');
  else {
    const root=shell(user,'users');root.append(head('User management','Admin-controlled accounts for faculty, technicians and campus staff.'));
    const view=el('div');root.append(view);let editing=null;
    async function refresh(){view.replaceChildren(el('p','Loading accounts…','loading'));
      try{
        const [users,depts]=await Promise.all([api('/users'),api('/master/departments')]);
        // Roles use the fixed three-role lookup from the existing schema.
        // Read role IDs from account list rather than assuming their numeric order.
        const roleRows=await api('/users/roles');
        const roleOptions=opt(roleRows.rows.map(x=>({id:x.role_id,name:x.role_name})));
        const depOptions=opt(depts.rows.filter(x=>x.is_active).map(x=>({id:x.department_id,name:x.department_name})));
        view.replaceChildren();const grid=el('div',null,'editor-grid');const left=el('div');const right=el('section',null,'panel');right.append(el('h2','Active and inactive accounts','panel-title'));
        const current=editing;
        const make=[field('Employee code','employee_code',{required:true,value:current?.employee_code||''}),field('Full name','full_name',{required:true,value:current?.full_name||''}),field('Email','email',{type:'email',required:true,value:current?.email||''}),field('Role','role_id',{options:roleOptions,required:true,value:current?.role_id||''}),field('Department','department_id',{options:depOptions,required:true,value:current?.department_id||''})];
        const editor=formBox(current?'Edit user':'Create user',current?'Save user':'Create account',async(values)=>{
          const result=await api('/users'+(current?'/'+current.id:''),{method:current?'PUT':'POST',data:values});
          editing=null;await refresh();
          if(result.temporaryPassword){const notice=el('div',null,'notice');notice.append(el('strong','One-time temporary password (copy it now): '),el('code',result.temporaryPassword));
            const copy=button('Copy',()=>navigator.clipboard?.writeText(result.temporaryPassword),'btn subtle sm');notice.append(copy);view.prepend(notice);}
          else toast(root,'User saved.');
        },make);left.append(editor);
        if(current)editor.querySelector('.editor-actions').append(button('Cancel',()=>{editing=null;refresh();},'btn subtle'));
        right.append(table(['Code','Name','Email','Role','Department','State','Actions'],users.rows,(tr,u)=>{
          for(const key of ['employee_code','full_name','email','role_name','department_code'])td(tr,u[key]);td(tr,u.is_active?'Active':'Inactive');
          const actions=el('td');const row=el('div',null,'action-line');
          row.append(button('Edit',()=>{editing=u;refresh();},'btn subtle sm'));
          const state=button(u.is_active?'Deactivate':'Activate',async()=>{
            if(!confirm(`${u.is_active?'Deactivate':'Activate'} ${u.full_name}?`))return;
            try{await api('/users/'+u.id+'/status',{method:'PATCH',data:{is_active:!u.is_active}});editing=null;await refresh();toast(root,'Account status changed.');}catch(e){alert(e.message);}
          },'btn subtle sm');if(user.id===u.id)state.disabled=true;row.append(state);actions.append(row);tr.append(actions);
        }));grid.append(left,right);view.append(grid);
      }catch(err){view.replaceChildren(el('p',err.message,'error-inline'));}
    }
    refresh();
  }
}
