// Accessible chart helper using native HTML/CSS: no CDN or package required.
export function bars(container, data, {valueText=v=>Number(v).toLocaleString('en-IN'), empty='No data for this period.'}={}) {
  container.replaceChildren();
  if(!Array.isArray(data)||data.length===0) {
    const p=document.createElement('p');p.className='empty';p.textContent=empty;container.append(p);return;
  }
  const max=Math.max(1,...data.map(d=>Number(d.value)||0));
  container.setAttribute('role','img');
  container.setAttribute('aria-label', data.map(d=>`${d.label}: ${valueText(d.value)}`).join('; '));
  for(const item of data){
    const row=document.createElement('div');row.className='report-bar-row';
    const label=document.createElement('div');label.className='bar-label';
    const name=document.createElement('span');name.textContent=String(item.label);
    const value=document.createElement('strong');value.textContent=valueText(item.value);
    label.append(name,value);
    const track=document.createElement('div');track.className='track';
    const fill=document.createElement('div');fill.className='fill';
    fill.style.width=`${Math.max(0,Math.min(100,100*(Number(item.value)||0)/max))}%`;
    track.append(fill);row.append(label,track);container.append(row);
  }
}
