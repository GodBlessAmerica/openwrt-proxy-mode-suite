'use strict';
'require view';
'require fs';
'require ui';

const PM='/usr/bin/proxy-mode', MGR='/usr/libexec/proxy-mode-ui';
function run(p,a){return fs.exec(p,a||[]).then(r=>({code:r.code,stdout:(r.stdout||'').trim(),stderr:(r.stderr||'').trim()}));}
function val(t,p){for(const l of (t||'').split(/\r?\n/))if(l.indexOf(p)===0)return l.slice(p.length).trim();return '';}
function modes(t){return (t||'').split(/\r?\n/).filter(Boolean).map(l=>{const p=l.split('\t');return{id:p[0],active:p[1]==='1',size:p[2],name:p.slice(3).join('\t')||('Mode '+p[0])};});}
function err(r){ui.addNotification(null,E('p',{},[r.stderr||r.stdout||_('Unknown error')]),'error');}
function has(t,s){return (t||'').indexOf(s)!==-1;}
function chip(text,tone){return E('span',{'class':'pm-chip pm-'+tone},[text]);}
function statusCard(label,value,tone,sub){return E('div',{'class':'pm-status-card'},[
 E('div',{'class':'pm-status-label'},[label]),
 E('div',{'class':'pm-status-value'},[chip(value,tone)]),
 sub?E('div',{'class':'pm-status-sub'},[sub]):''
]);}

return view.extend({
 load(){return Promise.all([run(PM,['status']),run(PM,['log']),run(MGR,['list'])]);},
 reload(){return this.load().then(L.bind(function(d){const n=document.querySelector('#proxy-mode-root');if(n)n.replaceWith(this.render(d));},this));},
 action(p,a,title){ui.showModal(title,[E('p',{'class':'spinning'},[_('Applying…')])]);return run(p,a).then(L.bind(function(r){ui.hideModal();if(r.code!==0){err(r);return;}ui.addNotification(null,E('p',{},[r.stdout||_('Done')]),'info');return this.reload();},this));},
 edit(m){ui.showModal(_('Loading Mode ')+m.id,[E('p',{'class':'spinning'},[_('Loading…')])]);return run(MGR,['read',m.id]).then(L.bind(function(r){if(r.code!==0){ui.hideModal();err(r);return;}const name=E('input',{'class':'cbi-input-text','value':m.name,'style':'width:100%'});const ta=E('textarea',{'class':'cbi-input-textarea','style':'width:100%;min-height:480px;font-family:monospace'},[r.stdout]);ui.showModal(_('Edit Mode ')+m.id,[E('p',{},[_('Edit the base mode JSON only. IPv6-block variants are generated automatically.')]),name,ta,E('div',{'class':'right'},[E('button',{'class':'btn','click':ui.hideModal},[_('Cancel')]),' ',E('button',{'class':'btn cbi-button-positive','click':ui.createHandlerFn(this,function(){let obj;try{obj=JSON.parse(ta.value);}catch(e){ui.addNotification(null,E('p',{},[_('Invalid JSON: ')+e.message]),'error');return;}ui.showModal(_('Saving'),[E('p',{'class':'spinning'},[_('Validating…')])]);return run(MGR,['save',m.id,JSON.stringify(obj,null,2)+'\n']).then(L.bind(function(s){if(s.code!==0){ui.hideModal();err(s);return;}return run(MGR,['rename',m.id,(name.value||'').trim()||('Mode '+m.id)]).then(L.bind(function(n){ui.hideModal();if(n.code!==0){err(n);return;}return this.reload();},this));},this));})},[_('Validate & Save')])])]);},this));},
 create(ms){const method=E('select',{'class':'cbi-input-select'},[E('option',{'value':'clone'},[_('Clone existing mode')]),E('option',{'value':'custom'},[_('Custom JSON')])]);const src=E('select',{'class':'cbi-input-select'},ms.map(m=>E('option',{'value':m.id},['Mode '+m.id+' · '+m.name])));const name=E('input',{'class':'cbi-input-text','value':'New Mode'});const ta=E('textarea',{'class':'cbi-input-textarea','style':'width:100%;min-height:360px;font-family:monospace'},['{\n  "log": { "level": "info" },\n  "inbounds": [],\n  "outbounds": []\n}']);ui.showModal(_('Add Mode'),[E('p',{},[_('Clone a working mode, or create one from complete Custom JSON. Protocol-specific templates can be expanded independently without changing the core.')]),method,E('br'),src,E('br'),name,E('br'),ta,E('div',{'class':'right'},[E('button',{'class':'btn','click':ui.hideModal},[_('Cancel')]),' ',E('button',{'class':'btn cbi-button-positive','click':ui.createHandlerFn(this,function(){const nm=(name.value||'').trim()||'New Mode';if(method.value==='clone')return run(MGR,['create',src.value,nm]).then(L.bind(function(r){ui.hideModal();if(r.code!==0){err(r);return;}return this.reload();},this));let obj;try{obj=JSON.parse(ta.value);}catch(e){ui.addNotification(null,E('p',{},[_('Invalid JSON: ')+e.message]),'error');return;}return run(MGR,['create-json',nm,JSON.stringify(obj,null,2)+'\n']).then(L.bind(function(r){ui.hideModal();if(r.code!==0){err(r);return;}return this.reload();},this));})},[_('Create')])])]);},
 render(d){
  const s=d[0].stdout||d[0].stderr||'', ms=modes(d[2].stdout);
  const running=has(s,'运行状态：正常'), ipv6Blocked=has(s,'IPv6 防泄露：已开启'), fwOk=has(s,'IPv6 防火墙：正常'), dnsOk=has(s,'DNS 策略：仅 IPv4'), ruleOk=has(s,'sing-box IPv6 规则：正常');
  const currentMode=val(s,'当前模式：')||_('Unknown');
  const configFile=val(s,'配置文件：')||_('Not set');
  const ipv6State=ipv6Blocked?_('Protected'):_('Allowed');
  const rows=ms.map(L.bind(function(m){return E('tr',{'class':'tr'+(m.active?' pm-current-row':'')},[
   E('td',{'class':'td left'},[E('div',{'class':'pm-mode-title'},['Mode '+m.id,' ',m.active?chip(_('Current'),'good'):''])]),
   E('td',{'class':'td left'},[m.name]),
   E('td',{'class':'td left'},[m.size+' B']),
   E('td',{'class':'td left'},[
    E('button',{'class':'btn '+(m.active?'cbi-button-positive':'cbi-button-action'),'click':ui.createHandlerFn(this,function(){return this.action(PM,[m.id],m.active?_('Restarting'):_('Switching'));})},[m.active?_('Restart'):_('Switch')]),' ',
    E('button',{'class':'btn','click':ui.createHandlerFn(this,function(){return this.edit(m);})},[_('Edit')]),' ',
    E('button',{'class':'btn cbi-button-negative','disabled':m.active?'':null,'click':ui.createHandlerFn(this,function(){return this.action(MGR,['delete',m.id],_('Deleting'));})},[_('Delete')])
   ])
  ]);},this));

  const style=`
   #proxy-mode-root{--pm-good:#16a34a;--pm-bad:#dc2626;--pm-warn:#d97706;--pm-info:#2563eb;--pm-muted:#64748b;--pm-border:rgba(127,127,127,.22)}
   #proxy-mode-root .pm-hero{display:flex;align-items:flex-end;justify-content:space-between;gap:1rem;margin:0 0 1.15rem}
   #proxy-mode-root .pm-hero h2{margin:0}.pm-subtitle{opacity:.68;margin-top:.25rem}
   #proxy-mode-root .pm-status-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:.8rem;margin:.75rem 0 1rem}
   #proxy-mode-root .pm-status-card{border:1px solid var(--pm-border);border-radius:10px;padding:.9rem 1rem;background:rgba(127,127,127,.035);min-width:0}
   #proxy-mode-root .pm-status-label{font-size:.78rem;text-transform:uppercase;letter-spacing:.045em;opacity:.62;margin-bottom:.5rem;font-weight:600}
   #proxy-mode-root .pm-status-value{font-size:1rem;font-weight:700}.pm-status-sub{margin-top:.5rem;font-size:.78rem;opacity:.68;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
   #proxy-mode-root .pm-chip{display:inline-flex;align-items:center;gap:.35rem;padding:.18rem .55rem;border-radius:999px;font-size:.78rem;line-height:1.4;font-weight:700;border:1px solid currentColor;white-space:nowrap}
   #proxy-mode-root .pm-chip:before{content:'';width:.45rem;height:.45rem;border-radius:50%;background:currentColor;box-shadow:0 0 0 2px rgba(127,127,127,.12)}
   #proxy-mode-root .pm-good{color:var(--pm-good);background:rgba(22,163,74,.09)}
   #proxy-mode-root .pm-bad{color:var(--pm-bad);background:rgba(220,38,38,.09)}
   #proxy-mode-root .pm-warn{color:var(--pm-warn);background:rgba(217,119,6,.09)}
   #proxy-mode-root .pm-info{color:var(--pm-info);background:rgba(37,99,235,.09)}
   #proxy-mode-root .pm-muted{color:var(--pm-muted);background:rgba(100,116,139,.09)}
   #proxy-mode-root .pm-section{border:1px solid var(--pm-border);border-radius:10px;padding:1rem;margin:0 0 1rem;background:rgba(127,127,127,.02)}
   #proxy-mode-root .pm-section h3{margin-top:0;display:flex;align-items:center;gap:.5rem}
   #proxy-mode-root .pm-actions{display:flex;flex-wrap:wrap;gap:.45rem;align-items:center}
   #proxy-mode-root .pm-current-row{background:rgba(22,163,74,.055)}
   #proxy-mode-root .pm-mode-title{display:flex;align-items:center;gap:.4rem;font-weight:600}
   #proxy-mode-root .pm-raw-status{margin:.85rem 0 0;padding:.75rem;border-radius:7px;background:rgba(127,127,127,.06);font-size:.78rem;opacity:.78;white-space:pre-wrap}
   #proxy-mode-root .pm-log{max-height:360px;overflow:auto;white-space:pre-wrap;border-radius:7px;padding:.85rem;background:rgba(0,0,0,.16);font-size:.8rem;line-height:1.55}
   #proxy-mode-root .pm-selected-good{box-shadow:0 0 0 2px rgba(22,163,74,.18) inset}
   #proxy-mode-root .pm-selected-warn{box-shadow:0 0 0 2px rgba(217,119,6,.18) inset}
   @media(max-width:640px){#proxy-mode-root .pm-hero{align-items:flex-start;flex-direction:column}.pm-status-grid{grid-template-columns:1fr!important}.table{font-size:.85rem}}
  `;

  return E('div',{'id':'proxy-mode-root'},[
   E('style',{},[style]),
   E('div',{'class':'pm-hero'},[E('div',{},[E('h2',{},[_('Proxy Mode')]),E('div',{'class':'pm-subtitle'},[_('sing-box routing, leak protection and mode management')])]),running?chip(_('Online'),'good'):chip(_('Offline'),'bad')]),
   E('div',{'class':'pm-status-grid'},[
    statusCard(_('Service'),running?_('Running'):_('Stopped'),running?'good':'bad',running?_('sing-box process is active'):_('Proxy service is not running')),
    statusCard(_('Current Mode'),currentMode,'info',configFile),
    statusCard(_('IPv6 Leak Protection'),ipv6State,ipv6Blocked?'good':'warn',ipv6Blocked?_('IPv6 egress is blocked'):_('IPv6 traffic is allowed')),
    statusCard(_('IPv6 Firewall'),ipv6Blocked?(fwOk?_('Healthy'):_('Check Required')):_('Not Required'),ipv6Blocked?(fwOk?'good':'bad'):'muted',ipv6Blocked?(fwOk?_('LAN + router IPv6 blocked'):_('Firewall rules missing or abnormal')):_('Protection is currently disabled')),
    statusCard(_('DNS Strategy'),ipv6Blocked?(dnsOk?_('IPv4 Only'):_('Check Required')):_('Automatic'),ipv6Blocked?(dnsOk?'good':'bad'):'muted',ipv6Blocked?_('Prevents AAAA-path leakage'):_('IPv6 protection is disabled')),
    statusCard(_('sing-box IPv6 Rule'),ipv6Blocked?(ruleOk?_('Active'):_('Missing')):_('Not Required'),ipv6Blocked?(ruleOk?'good':'bad'):'muted',ipv6Blocked?_('IPv6 reject rule in active config'):_('No forced IPv6 rejection'))
   ]),
   E('div',{'class':'pm-section'},[E('h3',{},[_('Status'),running?chip(_('Healthy'),'good'):chip(_('Stopped'),'bad')]),E('pre',{'class':'pm-raw-status'},[s])]),
   E('div',{'class':'pm-section'},[E('h3',{},[_('Mode Manager'),chip(ms.length+' '+_('Modes'),'info')]),E('div',{'class':'pm-actions','style':'margin-bottom:.7rem'},[E('button',{'class':'btn cbi-button-positive','click':ui.createHandlerFn(this,function(){return this.create(ms);})},[_('Add Mode')])]),E('table',{'class':'table'},[E('tr',{'class':'tr table-titles'},[E('th',{'class':'th'},[_('Mode')]),E('th',{'class':'th'},[_('Name')]),E('th',{'class':'th'},[_('Size')]),E('th',{'class':'th'},[_('Actions')])])].concat(rows))]),
   E('div',{'class':'pm-section'},[E('h3',{},[_('IPv6 Leak Protection'),' ',ipv6Blocked?chip(_('ON'),'good'):chip(_('OFF'),'warn')]),E('div',{'class':'pm-actions'},[
    E('button',{'class':'btn cbi-button-positive '+(ipv6Blocked?'pm-selected-good':''),'disabled':ipv6Blocked?'':null,'click':ui.createHandlerFn(this,function(){return this.action(PM,['ipv6','block'],_('Blocking IPv6'));})},[ipv6Blocked?'✓ ': '',_('Block IPv6')]),
    E('button',{'class':'btn '+(!ipv6Blocked?'cbi-button-action pm-selected-warn':''),'disabled':!ipv6Blocked?'':null,'click':ui.createHandlerFn(this,function(){return this.action(PM,['ipv6','allow'],_('Allowing IPv6'));})},[!ipv6Blocked?'✓ ': '',_('Allow IPv6')])
   ])]),
   E('div',{'class':'pm-section'},[E('h3',{},[_('Service'),' ',running?chip(_('RUNNING'),'good'):chip(_('STOPPED'),'bad')]),E('div',{'class':'pm-actions'},[
    E('button',{'class':'btn cbi-button-positive','disabled':running?'':null,'click':ui.createHandlerFn(this,function(){return this.action(PM,['start'],_('Starting'));})},[_('Start')]),
    E('button',{'class':'btn cbi-button-action','click':ui.createHandlerFn(this,function(){return this.action(PM,['restart'],_('Restarting'));})},[_('Restart')]),
    E('button',{'class':'btn cbi-button-negative','disabled':!running?'':null,'click':ui.createHandlerFn(this,function(){return this.action(PM,['stop'],_('Stopping'));})},[_('Stop')])
   ])]),
   E('div',{'class':'pm-section'},[E('h3',{},[_('Recent log')]),E('pre',{'class':'pm-log'},[d[1].stdout||d[1].stderr||_('No log output')])])
  ]);
 },
 handleSaveApply:null,handleSave:null,handleReset:null
});
