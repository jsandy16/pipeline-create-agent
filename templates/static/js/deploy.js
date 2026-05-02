// ── Auto-fix UI ──────────────────────────────────────────────────────────────
const autofixBanner     = $('autofixBanner');
const autofixTitle      = $('autofixTitle');
const autofixSummary    = $('autofixSummary');
const autofixDetails    = $('autofixDetails');
const autofixUserAction = $('autofixUserAction');
const autofixConfirmBtn = $('autofixConfirmBtn');
const autofixRejectBtn  = $('autofixRejectBtn');
const autofixRegenerateBtn = $('autofixRegenerateBtn');

function hideAutofixBanner(){ autofixBanner.style.display='none'; }

function showAutofixBanner(proposal, errors){
  autofixBanner.style.display='block';
  if(proposal.fixable){
    autofixTitle.textContent='🔧 Auto-Fix Available';
    autofixTitle.style.color='#00d26a';
    autofixConfirmBtn.style.display='';
  } else {
    autofixTitle.textContent='⚠️ Manual Action Required';
    autofixTitle.style.color='#f85149';
    autofixConfirmBtn.style.display='none';
  }
  autofixSummary.textContent=proposal.summary||'';
  autofixDetails.textContent=proposal.fix_description||'';
  if(proposal.user_action_required){
    autofixUserAction.textContent=proposal.user_action_required;
    autofixUserAction.style.display='block';
  } else {
    autofixUserAction.style.display='none';
  }
  autofixRegenerateBtn.style.display = proposal.requires_regeneration ? '' : 'none';
}

autofixRejectBtn.addEventListener('click', ()=>{
  hideAutofixBanner();
  log('INFO', now(), 'terraform', 'Auto-fix dismissed by user.');
  planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
});

autofixConfirmBtn.addEventListener('click', async ()=>{
  if(!_deployJobId) return;
  autofixConfirmBtn.disabled=true; autofixConfirmBtn.textContent='Applying…';
  log('INFO', now(), 'terraform', '🔧 Applying auto-fix…');

  try{
    const r = await fetch(`/deploy/autofix/confirm/${_deployJobId}`, {method:'POST'});
    const d = await r.json();
    if(!r.ok){
      log('ERROR', now(), 'terraform', 'Fix failed: '+(d.detail||'unknown'));
      autofixConfirmBtn.disabled=false; autofixConfirmBtn.textContent='✓ Apply Fix';
      return;
    }
    log('SUCCESS', now(), 'terraform', '🔧 Fix applied: '+d.message);
    hideAutofixBanner();

    if(d.requires_regeneration){
      log('WARNING', now(), 'terraform', 'Pipeline needs to be regenerated with the fixed configuration.');
      log('INFO', now(), 'terraform', 'Click "🔄 Regenerate Pipeline" to rebuild.');
      autofixRegenerateBtn.style.display='';
      autofixBanner.style.display='block';
      autofixTitle.textContent='🔄 Regeneration Required';
      autofixTitle.style.color='#f85149';
      autofixSummary.textContent='The fix modified pipeline.yaml or specs. The pipeline must be regenerated.';
      autofixDetails.textContent='';
      autofixConfirmBtn.style.display='none';
      return;
    }

    // HCL fix succeeded — show plan if available
    if(d.plan){
      _cachedPlanText = d.plan;
      d.plan.split('\n').forEach(l=>{
        if(!l.trim()) return;
        const lvl = l.startsWith('Error')?'ERROR':l.includes('Plan:')?'SUCCESS':'INFO';
        log(lvl, now(), 'terraform', l);
      });
      const summary = d.plan.split('\n').find(l=>l.includes('Plan:')) || 'Plan complete.';
      log('SUCCESS', now(), 'terraform', '─── '+summary.trim()+' ───');
      applyBtn.disabled=false; applyBtn.classList.add('enabled');
      dlPlanBtn.disabled=false; dlPlanBtn.classList.add('enabled');
    }
    planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
  }catch(e){
    log('ERROR', now(), 'terraform', 'Error: '+e.message);
  }
  autofixConfirmBtn.disabled=false; autofixConfirmBtn.textContent='✓ Apply Fix';
});

autofixRegenerateBtn.addEventListener('click', async ()=>{
  if(!_deployJobId) return;
  autofixRegenerateBtn.disabled=true; autofixRegenerateBtn.textContent='Regenerating…';
  log('INFO', now(), 'terraform', '🔄 Regenerating pipeline from fixed YAML…');

  try{
    const r = await fetch(`/deploy/autofix/regenerate/${_deployJobId}`, {method:'POST'});
    const d = await r.json();
    if(!r.ok){
      log('ERROR', now(), 'terraform', 'Regeneration failed: '+(d.detail||'unknown'));
      autofixRegenerateBtn.disabled=false; autofixRegenerateBtn.textContent='🔄 Regenerate Pipeline';
      return;
    }
    log('SUCCESS', now(), 'terraform', 'Pipeline regeneration started: '+d.message);
    hideAutofixBanner();

    // Switch to tracking the new job
    _deployJobId = d.new_job_id;
    planBtn.disabled=true; planBtn.classList.remove('enabled');
    applyBtn.disabled=true; applyBtn.classList.remove('enabled');

    log('INFO', now(), 'terraform', 'New job ID: '+d.new_job_id+' — waiting for generation to complete…');
    log('INFO', now(), 'terraform', 'Once complete, click Plan to run terraform plan on the fixed pipeline.');

    // Poll for job completion
    const pollInterval = setInterval(async ()=>{
      try{
        const jr = await fetch(`/details/${d.new_job_id}`);
        if(jr.ok){
          clearInterval(pollInterval);
          log('SUCCESS', now(), 'terraform', '✓ Pipeline regenerated successfully!');
          planBtn.disabled=false; planBtn.classList.add('enabled');
          planBtn.textContent='📋 Deploy to AWS: Plan';
        }
      }catch(e){}
    }, 3000);

  }catch(e){
    log('ERROR', now(), 'terraform', 'Error: '+e.message);
  }
  autofixRegenerateBtn.disabled=false; autofixRegenerateBtn.textContent='🔄 Regenerate Pipeline';
});

// ── Plan ─────────────────────────────────────────────────────────────────────
planBtn.addEventListener('click', async () => {
  if(!_deployJobId || planBtn.disabled) return;
  planBtn.disabled=true; planBtn.textContent='📋 Running plan…';
  applyBtn.disabled=true; applyBtn.classList.remove('enabled');
  dlPlanBtn.disabled=true; dlPlanBtn.classList.remove('enabled');
  hideAutofixBanner();

  log('INFO', now(), 'terraform', '─── terraform init + plan ───────────────────');

  try{
    const r = await fetch(`/deploy/plan/${_deployJobId}`, {method:'POST'});
    const d = await r.json();

    if(!r.ok){
      // Check if autofix is available
      if(d.autofix_available && d.autofix_proposal){
        log('WARNING', now(), 'terraform', '⚠️ Plan failed — auto-fix available:');
        log('WARNING', now(), 'terraform', '  '+d.autofix_proposal.summary);
        showAutofixBanner(d.autofix_proposal, d.detail);
        planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
        return;
      }

      // Check for non-fixable proposal with user guidance
      if(d.autofix_proposal && !d.autofix_proposal.fixable){
        const p = d.autofix_proposal;
        log('ERROR', now(), 'terraform', '⚠️ '+p.summary);
        if(p.user_action_required){
          p.user_action_required.split('\n').forEach(l=>
            log('WARNING', now(), 'terraform', l));
        }
        showAutofixBanner(p, d.detail);
        planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
        return;
      }

      const humanReview = d.human_review;
      log('ERROR', now(), 'terraform', humanReview
        ? '⚠️  HUMAN REVIEW REQUIRED — errors cannot be auto-fixed:'
        : '✗ terraform plan failed:');
      (d.detail||'Plan failed').split('\n').filter(l=>l.trim()).forEach(l=>
        log('ERROR', now(), 'terraform', l));
      planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
      return;
    }

    if(d.autofix_note){
      log('WARNING', now(), 'terraform', '🔧 Auto-fix applied: '+d.autofix_note);
    }

    const planText = d.plan || '';
    _cachedPlanText = planText;

    // Stream every non-empty line to console
    planText.split('\n').forEach(l => {
      if(!l.trim()) return;
      const lvl = l.startsWith('Error') ? 'ERROR'
                : l.includes('Plan:')   ? 'SUCCESS'
                : l.startsWith('  +')   ? 'INFO'
                : 'INFO';
      log(lvl, now(), 'terraform', l);
    });

    const summary = planText.split('\n').find(l=>l.includes('Plan:')) || 'Plan complete.';
    log('SUCCESS', now(), 'terraform', '─── '+summary.trim()+' ───');

    planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
    applyBtn.disabled=false; applyBtn.classList.add('enabled');
    dlPlanBtn.disabled=false; dlPlanBtn.classList.add('enabled');

  }catch(e){
    log('ERROR', now(), 'terraform', 'Plan error: '+e.message);
    planBtn.disabled=false; planBtn.textContent='📋 Deploy to AWS: Plan';
  }
});

// ── Apply ────────────────────────────────────────────────────────────────────
applyBtn.addEventListener('click', async () => {
  if(!_deployJobId || applyBtn.disabled) return;
  applyBtn.disabled=true; applyBtn.textContent='🚀 Deploying…';
  planBtn.disabled=true;

  log('INFO', now(), 'terraform', '─── terraform apply ─────────────────────────');

  let deployId;
  try{
    const r=await fetch(`/deploy/apply/${_deployJobId}`,{method:'POST'});
    const d=await r.json();
    if(!r.ok){
      log('ERROR', now(), 'terraform', 'Apply failed: '+(d.detail||'unknown error'));
      applyBtn.disabled=false; applyBtn.textContent='🚀 Deploy to AWS: Deploy';
      planBtn.disabled=false;
      return;
    }
    deployId=d.deploy_id;
  }catch(e){
    log('ERROR', now(), 'terraform', 'Network error: '+e.message);
    applyBtn.disabled=false; applyBtn.textContent='🚀 Deploy to AWS: Deploy';
    planBtn.disabled=false;
    return;
  }

  _deployWs=makeWs(
    `${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/deploy/${deployId}`,
    ({data})=>{
      const m=JSON.parse(data);
      if(m.type==='log'){
        const lvl=m.level==='SUCCESS'?'SUCCESS':m.level==='ERROR'?'ERROR':'INFO';
        log(lvl, m.time||now(), 'terraform', m.message);
      }
      if(m.type==='done'){
        _deployWs=null;
        planBtn.disabled=false;
        if(m.exit_code===0){
          log('SUCCESS', now(), 'terraform', '─── ✓ Deployment complete! ──────────────────');
          applyBtn.textContent='✅ Deployed'; applyBtn.disabled=true; applyBtn.classList.remove('enabled');
          _destroyJobId=_deployJobId;
          destroyBtn.disabled=false; destroyBtn.classList.add('enabled');
          // Enable pipeline run monitor
          monitorBtn.disabled=false; monitorBtn.classList.add('enabled');
          monitorBtn._monitorJobId=_deployJobId;
          // Re-render architecture from generated pipeline YAML (reflects auto-added
          // resources like EventBridge that may not appear in the original diagram)
          if(_pipelineName) rerenderFromPipelineYaml(_pipelineName);
          // Fetch and render deployed resources table
          loadDeployedResources(_deployJobId);
        }else{
          log('ERROR', now(), 'terraform', '─── ✗ Deployment failed ─────────────────────');
          applyBtn.disabled=false; applyBtn.textContent='🚀 Deploy to AWS: Deploy';
        }
      }
    },
    { onGiveUp(){ log('ERROR',now(),'terraform','Connection lost — could not reconnect during apply. Check AWS Console for deployment status.'); applyBtn.disabled=false; applyBtn.textContent='🚀 Deploy to AWS: Deploy'; planBtn.disabled=false; } }
  );
});

// ══════════════════════════════════════════════════════════════════════════════
// ── DESTROY RESOURCES ────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

const destroyBtn        = $('destroyBtn');
const destroyOverlay    = $('destroyOverlay');
const destroyClose      = $('destroyClose');
const destroyCancelBtn  = $('destroyCancelBtn');
const destroyConfirmBtn = $('destroyConfirmBtn');
const destroyConfirmView= $('destroyConfirmView');
const destroyLog        = $('destroyLog');
const destroyNote       = $('destroyNote');
const destroyModalTitle = $('destroyModalTitle');
const destroyWarnBody   = $('destroyWarnBody');

let _destroyJobId = null;
let _destroyWs    = null;

// Open destroy modal
destroyBtn.addEventListener('click', () => {
  if(!_destroyJobId || destroyBtn.disabled) return;
  // Reset modal state
  destroyConfirmView.style.display='flex';
  destroyLog.classList.remove('show'); destroyLog.innerHTML='';
  destroyConfirmBtn.disabled=false;
  destroyNote.textContent='This will permanently delete all pipeline resources.';
  destroyModalTitle.textContent='🗑️ Destroy AWS Resources';
  destroyOverlay.classList.add('show');
});

// Confirm destroy
destroyConfirmBtn.addEventListener('click', async () => {
  destroyConfirmBtn.disabled=true;
  destroyConfirmView.style.display='none';
  destroyLog.classList.add('show');
  destroyNote.textContent='Destroying resources…';
  destroyModalTitle.textContent='Destroying…';
  destroyLog.innerHTML='';

  function dlog(msg, cls=''){
    const ln=document.createElement('div');
    ln.style.cssText=`color:${cls==='ok'?'var(--green)':cls==='err'?'var(--red)':cls==='warn'?'var(--yellow)':'#c9d5e3'}`;
    ln.textContent=msg; destroyLog.appendChild(ln);
    destroyLog.scrollTop=destroyLog.scrollHeight;
  }

  log('WARNING', now(), 'terraform', '⚠️ terraform destroy started — deleting all pipeline resources…');

  let destroyId;
  try{
    const r=await fetch(`/deploy/destroy/${_destroyJobId}`,{method:'POST'});
    const d=await r.json();
    if(!r.ok){ dlog('ERROR: '+(d.detail||'Destroy failed'),'err'); destroyNote.textContent='Destroy failed.'; return; }
    destroyId=d.destroy_id;
  }catch(e){ dlog('Network error: '+e.message,'err'); return; }

  _destroyWs=makeWs(
    `${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/destroy/${destroyId}`,
    ({data})=>{
      const m=JSON.parse(data);
      if(m.type==='log'){
        const cls=m.level==='SUCCESS'?'ok':m.level==='ERROR'?'err':m.level==='WARNING'?'warn':'';
        dlog(m.message, cls);
        // Mirror to main console
        log(m.level==='SUCCESS'?'SUCCESS':m.level==='ERROR'?'ERROR':m.level==='WARNING'?'WARNING':'INFO',
            m.time||now(), 'terraform', m.message);
      }
      if(m.type==='done'){
        _destroyWs=null;
        if(m.exit_code===0){
          destroyNote.textContent='✅ All resources destroyed.';
          destroyModalTitle.textContent='Destruction Complete';
          destroyBtn.textContent='✓ Destroyed';
          destroyBtn.classList.remove('enabled'); destroyBtn.disabled=true;
          log('SUCCESS', now(), 'terraform', '✓ All AWS resources destroyed.');
        }else{
          destroyNote.textContent='❌ Destroy failed — check log above.';
          destroyModalTitle.textContent='Destroy Failed';
          log('ERROR', now(), 'terraform', '✗ terraform destroy failed.');
        }
      }
    },
    { onGiveUp(){ dlog('WebSocket connection lost — could not reconnect. Check AWS Console for destroy status.','err'); log('ERROR',now(),'terraform','Connection lost during destroy — check AWS Console.'); } }
  );
});

function closeDestroyModal(){
  destroyOverlay.classList.remove('show');
  if(_destroyWs){ try{_destroyWs.close()}catch(_){} _destroyWs=null; }
}
destroyClose.addEventListener('click', closeDestroyModal);
destroyCancelBtn.addEventListener('click', closeDestroyModal);
destroyOverlay.addEventListener('click', e=>{ if(e.target===destroyOverlay) closeDestroyModal(); });
document.addEventListener('keydown', e=>{ if(e.key==='Escape' && destroyOverlay.classList.contains('show')) closeDestroyModal(); });

// ── Download Plan ────────────────────────────────────────────────────────────
dlPlanBtn.addEventListener('click', ()=>{
  if(!_cachedPlanText || dlPlanBtn.disabled) return;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([_cachedPlanText], {type:'text/plain'}));
  const pipelineRow = $('rcRows').querySelector('.v');
  const pipeline = (pipelineRow?.textContent)||'pipeline';
  a.download = pipeline+'_tfplan.txt';
  a.click(); URL.revokeObjectURL(a.href);
});

// ── Download Matrix (CSV from backend) ──────────────────────────────────────
matrixBtn.addEventListener('click', ()=>{
  if(!_deployJobId || matrixBtn.disabled) return;
  const a = document.createElement('a');
  a.href = `/matrix/${_deployJobId}`;
  a.download = '';
  a.click();
});

// Reset all deploy/download state when a new run starts
runBtn.addEventListener('click', ()=>{
  _deployJobId=null; _cachedPlanText=''; _pipelineName='';
  if(_deployWs){ try{_deployWs.close()}catch(_){} _deployWs=null; }
  planBtn.disabled=true; planBtn.classList.remove('enabled'); planBtn.textContent='📋\u00a0 Deploy to AWS: Plan';
  applyBtn.disabled=true; applyBtn.classList.remove('enabled'); applyBtn.textContent='🚀\u00a0 Deploy to AWS: Deploy';
  dlPlanBtn.disabled=true; dlPlanBtn.classList.remove('enabled');
  matrixBtn.disabled=true; matrixBtn.classList.remove('enabled');
  _destroyJobId=null; destroyBtn.disabled=true; destroyBtn.classList.remove('enabled');
  destroyBtn.textContent='🗑️\u00a0 Destroy Resources';
  stopRunPreview(); monitorBtn._monitorJobId=null; monitorBtn._monitorPipelineName=null; resetMonitorBtn();
}, true);
// ══════════════════════════════════════════════════════════════════════════════
