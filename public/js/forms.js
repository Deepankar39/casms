// DOM-only form helpers: user-controlled data is always rendered as text/value.
import {el} from './common.js';
export function button(title,fn,klass='btn') {const b=el('button',title,klass);b.type='button';b.addEventListener('click',fn);return b;}
export function field(label,name,{value='',type='text',required=false,options=null,placeholder='',min=null,step=null}={}) {
  const wrap=el('label',null,'field');const labelEl=el('span',label);let control;
  if(options){control=el('select');for(const {value:val,label:caption} of options){const o=el('option',caption);o.value=String(val);control.append(o);}}
  else if(type==='textarea'){control=el('textarea');control.rows=3;}
  else {control=el('input');control.type=type;if(min!==null)control.min=String(min);if(step!==null)control.step=String(step);}
  control.name=name;control.placeholder=placeholder;control.required=required;
  if(value!==undefined&&value!==null)control.value=String(value);
  wrap.append(labelEl,control);return wrap;
}
export function formValues(form){return Object.fromEntries(new FormData(form).entries());}
export function formBox(title,submitLabel,onSubmit,items){
  const pane=el('section',null,'panel');const h=el('h2',title,'panel-title');const form=el('form',null,'editor-form');
  for(const item of items)form.append(item);
  const actions=el('div',null,'editor-actions');const submit=el('button',submitLabel,'btn');submit.type='submit';actions.append(submit);form.append(actions);
  const feedback=el('p','', 'error-inline');pane.append(h,feedback,form);
  form.addEventListener('submit',async e=>{e.preventDefault();submit.disabled=true;feedback.textContent='';
    try{await onSubmit(formValues(form),form); }catch(err){feedback.textContent=err.message;}finally{submit.disabled=false;}});
  return pane;
}
export function toast(parent,message){const p=el('div',message,'notice');parent.prepend(p);setTimeout(()=>p.remove(),6000);}
export function table(headers,rows,display){
  const holder=el('div',null,'table-wrap');const t=el('table',null,'table');const thead=el('thead');const hrow=el('tr');headers.forEach(h=>hrow.append(el('th',h)));thead.append(hrow);t.append(thead);const tb=el('tbody');
  if(!rows.length){const tr=el('tr');const cell=el('td','No records yet.','empty');cell.colSpan=headers.length;tr.append(cell);tb.append(tr);}
  for(const row of rows){const tr=el('tr');display(tr,row);tb.append(tr);}t.append(tb);holder.append(t);return holder;
}
export function td(tr,value){tr.append(el('td',value==null?'—':String(value)));}
export const opt=(items,labelFn=x=>x.name)=>[{value:'',label:'Select…'},...items.map(x=>({value:x.id,label:labelFn(x)}))];
