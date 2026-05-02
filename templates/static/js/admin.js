// ── ADMIN SIDEBAR + ACTION MODALS ─────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

// ── Sidebar collapse/expand ───────────────────────────────────────────────────
// ── Sidebar collapse/expand ───────────────────────────────────────────────
const sidebarToggle=$('sidebarToggle'),bodyEl=document.querySelector('.body');
let _sidebarCollapsed = false;
sidebarToggle.addEventListener('click', ()=>{
  _sidebarCollapsed = !_sidebarCollapsed;
  bodyEl.classList.toggle('sidebar-collapsed', _sidebarCollapsed);
  sidebarToggle.innerHTML = _sidebarCollapsed ? '&#9654;' : '&#9664;';
});

// ── Terraform/AWS collapsible section ─────────────────────────────────────
const tfSecHdr=$('tfSecHdr'),tfChevron=$('tfChevron'),tfMenuRows=$('tfMenuRows');
let tfOpen = false;
tfSecHdr.addEventListener('click', ()=>{
  tfOpen = !tfOpen;
  tfMenuRows.classList.toggle('open', tfOpen);
  tfChevron.classList.toggle('open', tfOpen);
});

const adminSecHdr   = $('adminSecHdr');
const adminChevron  = $('adminChevron');
const adminMenuRows = $('adminMenuRows');
let adminOpen = false;

adminSecHdr.addEventListener('click', ()=>{
  adminOpen = !adminOpen;
  adminMenuRows.classList.toggle('open', adminOpen);
  adminChevron.classList.toggle('open', adminOpen);
  if(adminOpen) refreshAdminBadges();
});

function refreshAdminBadges(){
  fetch('/admin/api-key/status').then(r=>r.json()).then(d=>{
    $('apiKeyBadge').style.display = d.configured ? '' : 'none';
  }).catch(()=>{});
  fetch('/admin/aws-keys/status').then(r=>r.json()).then(d=>{
    $('awsKeyBadge').style.display = d.configured ? '' : 'none';
    if(d.configured) $('awsRegionInput').value = d.region||'us-east-1';
  }).catch(()=>{});
}

// ── Generic overlay helpers ───────────────────────────────────────────────────
function openOverlay(id){ $(id).classList.add('show'); }
function closeOverlay(id){ $(id).classList.remove('show'); }

['apiKeyOverlay','awsKeysOverlay','historyOverlay'].forEach(id=>{
  $(id).addEventListener('click', e=>{ if(e.target===$(id)) closeOverlay(id); });
});
document.addEventListener('keydown', e=>{
  if(e.key==='Escape'){
    ['apiKeyOverlay','awsKeysOverlay','historyOverlay'].forEach(id=>{
      if($(id).classList.contains('show')) closeOverlay(id);
    });
  }
});

$('apiKeyClose').addEventListener('click',  ()=>closeOverlay('apiKeyOverlay'));
$('awsKeysClose').addEventListener('click', ()=>closeOverlay('awsKeysOverlay'));
$('historyClose').addEventListener('click', ()=>closeOverlay('historyOverlay'));

// ── Row click handlers ────────────────────────────────────────────────────────
$('rowApiKey').addEventListener('click', ()=>{
  $('apiKeyStatus').className='adm-status';
  $('apiKeyStatus').textContent='';
  $('apiKeyInput').value='';
  openOverlay('apiKeyOverlay');
});

$('rowAwsKeys').addEventListener('click', ()=>{
  $('awsKeyStatus').className='adm-status';
  $('awsKeyStatus').textContent='';
  openOverlay('awsKeysOverlay');
});

$('rowHistory').addEventListener('click', async ()=>{
  openOverlay('historyOverlay');
  await loadHistoricalPipelines();
});

// rowDestroyAll is .disabled — no click handler

// ── Configure API Key ─────────────────────────────────────────────────────────
$('saveApiKeyBtn').addEventListener('click', async ()=>{
  const key = $('apiKeyInput').value.trim();
  const st  = $('apiKeyStatus');
  if(!key){ st.className='adm-status err'; st.textContent='Please enter a key.'; return; }
  const btn = $('saveApiKeyBtn');
  btn.disabled=true; btn.textContent='Saving…';
  try{
    const r = await fetch('/admin/api-key',{
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({api_key: key}),
    });
    const d = await r.json();
    if(r.ok){
      st.className='adm-status ok';
      st.textContent=`✓ Saved (${d.masked})`;
      $('apiKeyBadge').style.display='';
      $('apiKeyInput').value='';
    } else {
      st.className='adm-status err';
      st.textContent='Error: '+(d.detail||'Unknown');
    }
  }catch(e){
    st.className='adm-status err'; st.textContent='Network error.';
  }finally{
    btn.disabled=false; btn.textContent='Save Key';
  }
});

// ── Configure AWS Keys ────────────────────────────────────────────────────────
$('saveAwsKeysBtn').addEventListener('click', async ()=>{
  const accessKey = $('awsAccessKeyInput').value.trim();
  const secretKey = $('awsSecretKeyInput').value.trim();
  const region    = $('awsRegionInput').value.trim() || 'us-east-1';
  const st = $('awsKeyStatus');
  if(!accessKey||!secretKey){
    st.className='adm-status err'; st.textContent='Access Key ID and Secret Key are required.'; return;
  }
  const btn=$('saveAwsKeysBtn');
  btn.disabled=true; btn.textContent='Saving…';
  try{
    const r = await fetch('/admin/aws-keys',{
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({access_key_id: accessKey, secret_access_key: secretKey, region}),
    });
    const d = await r.json();
    if(r.ok){
      st.className='adm-status ok';
      st.textContent=`✓ Saved (${d.masked_key}, ${d.region})`;
      $('awsKeyBadge').style.display='';
      $('awsSecretKeyInput').value='';
    } else {
      st.className='adm-status err'; st.textContent='Error: '+(d.detail||'Unknown');
    }
  }catch(e){
    st.className='adm-status err'; st.textContent='Network error.';
  }finally{
    btn.disabled=false; btn.textContent='Save Keys';
  }
});

// ── Historical Pipelines ──────────────────────────────────────────────────────
async function loadHistoricalPipelines(){
  const list=$('histList');
  list.innerHTML='<div class="hist-empty">Loading…</div>';
  try{
    const r = await fetch('/admin/pipelines');
    const d = await r.json();
    const pipelines = d.pipelines||[];
    if(!pipelines.length){
      list.innerHTML='<div class="hist-empty">No historical pipelines found.</div>';
      return;
    }
    list.innerHTML='';
    for(const p of pipelines){
      const item=document.createElement('div');
      item.className='hist-item';
      item.innerHTML=`
        <div class="hist-info">
          <div class="hist-name">${escHtml(p.name)}</div>
          <div class="hist-meta">
            <span>${escHtml(p.created)}</span>
            ${p.services ? `<span>${p.services} services</span>` : ''}
            ${p.has_state ? '<span class="hist-badge">Deployed</span>' : ''}
          </div>
        </div>
        <div class="hist-actions">
          <button class="hist-btn" title="View architecture" onclick="event.stopPropagation();viewHistoricalPipeline('${escHtml(p.name)}',${p.has_state})">👁 View</button>
          <button class="hist-btn" title="Modify in Pipeline Builder" onclick="event.stopPropagation();modifyHistoricalPipeline('${escHtml(p.name)}')">✏ Modify</button>
          <button class="hist-btn danger" title="Delete pipeline" onclick="event.stopPropagation();deleteHistoricalPipeline('${escHtml(p.name)}',${p.has_state},this)">🗑 Delete</button>
        </div>`;
      item.querySelector('.hist-info').addEventListener('click', ()=> viewHistoricalPipeline(p.name, p.has_state));
      list.appendChild(item);
    }
  }catch(e){
    list.innerHTML='<div class="hist-empty">Error: '+e.message+'</div>';
  }
}

async function viewHistoricalPipeline(name, hasState){
  try{
    const r = await fetch(`/admin/pipeline/${encodeURIComponent(name)}`);
    if(!r.ok){ log('ERROR',now(),'admin','Failed to load pipeline: '+name); return; }
    const d = await r.json();
    closeOverlay('historyOverlay');
    rawImg.style.display='none';
    dgmEmpty.style.display='none';
    dgmLabel.textContent='Pipeline Architecture — '+d.name+' (historical)';
    buildDagram(d.services, d.integrations||[]);
    log('INFO',now(),'admin',`Historical pipeline '${d.name}' loaded — ${d.services.length} services.`);

    stopRunPreview();
    if(hasState){
      monitorBtn.disabled=false; monitorBtn.classList.add('enabled');
      monitorBtn._monitorJobId=null;
      monitorBtn._monitorPipelineName=name;
      log('INFO',now(),'admin',`Pipeline '${name}' is deployed — run monitoring available.`);
    }else{
      resetMonitorBtn();
    }
  }catch(e){
    log('ERROR',now(),'admin','Error loading pipeline: '+e.message);
  }
}

// Keep old name for any code that calls it
function loadHistoricalPipeline(name, hasState){ return viewHistoricalPipeline(name, hasState); }

async function modifyHistoricalPipeline(name){
  try{
    const r = await fetch(`/pipeline-builder/load/${encodeURIComponent(name)}`);
    if(!r.ok){
      const err=await r.json();
      alert('Could not load pipeline: '+(err.detail||'Unknown error'));
      return;
    }
    const d = await r.json();
    closeOverlay('historyOverlay');

    // Open Pipeline Builder modal pre-populated with the historical YAML
    _dcChatId = d.chat_id;
    pbPreviewCol.classList.remove('empty');
    pbPipeName.textContent = d.pipeline_name;
    pbYaml.textContent = d.yaml;
    pbBuildBtn.disabled = false;

    // Show loaded message in chat
    if(pbEmpty) pbEmpty.style.display='none';
    pbAddMsg('agent',
      `Loaded pipeline <b>${escHtml(d.pipeline_name)}</b> (${d.services.length} services). ` +
      `Type changes to modify it, then click <b>Build Terraform</b>.`
    );

    // Render architecture
    initServices(d.services);
    buildDagram(d.services, d.integrations||[]);

    pbOverlay.classList.add('show');
    pbInput.focus();
    pbStatus.textContent = 'Ready (modify mode)';
  }catch(e){
    alert('Error loading pipeline for modification: '+e.message);
  }
}

async function deleteHistoricalPipeline(name, hasState, btn){
  const msg = hasState
    ? `Pipeline '${name}' has deployed AWS resources.\n\nDestroy AWS resources first, then delete the local files?`
    : `Delete local files for pipeline '${name}'?`;
  if(!confirm(msg)) return;

  btn.disabled = true;
  btn.textContent = '…';

  try{
    if(hasState){
      // Step 1: terraform destroy
      const dr = await fetch(`/admin/pipeline/${encodeURIComponent(name)}/destroy`, {method:'POST'});
      if(!dr.ok){
        const e=await dr.json();
        alert('Destroy failed: '+(e.detail||'Unknown'));
        btn.disabled=false; btn.textContent='🗑 Delete';
        return;
      }
      const dd=await dr.json();
      const destroyId=dd.destroy_id;

      // Stream destroy via WebSocket
      closeOverlay('historyOverlay');
      consoleEl.innerHTML='<div class="con-empty">Destroying resources…</div>';
      setStatus('running',`Destroying ${name}…`);
      await new Promise(resolve=>{
        const wsUrl=`${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/destroy/${destroyId}`;
        const ws=new WebSocket(wsUrl);
        ws.onmessage=({data})=>{
          const m=JSON.parse(data);
          if(m.type==='log') log(m.level,m.time||now(),'destroy',m.message);
          if(m.type==='done'){
            ws.close();
            if(m.exit_code===0){ setStatus('ok','Resources destroyed'); log('SUCCESS',now(),'destroy','✓ Resources destroyed.'); }
            else { setStatus('fail','Destroy failed'); log('ERROR',now(),'destroy','✗ Destroy failed.'); }
            resolve();
          }
        };
        ws.onerror=()=>{ setStatus('fail','WebSocket error'); resolve(); };
      });
    }

    // Step 2: delete local files
    const del=await fetch(`/admin/pipeline/${encodeURIComponent(name)}`,{method:'DELETE'});
    if(del.ok){
      log('INFO',now(),'admin',`Pipeline '${name}' deleted.`);
      loadHistoricalPipelines();
      if(hasState) openOverlay('historyOverlay');
    } else {
      const e=await del.json();
      alert('Delete failed: '+(e.detail||'Unknown'));
    }
  }catch(e){
    alert('Error: '+e.message);
    if(btn){ btn.disabled=false; btn.textContent='🗑 Delete'; }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── DEPLOYED RESOURCES TABLE ──────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

const resPanel      = $('resPanel');
const resTableBody  = $('resTableBody');
const resPanelClose = $('resPanelClose');

resPanelClose.addEventListener('click', ()=> resPanel.classList.remove('show'));

