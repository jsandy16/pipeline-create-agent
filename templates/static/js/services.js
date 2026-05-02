// Also hide the panel when a new run starts
runBtn.addEventListener('click', ()=>{
  resPanel.classList.remove('show');
  resTableBody.innerHTML='';
}, true);

async function rerenderFromPipelineYaml(name){
  // Re-render the Pipeline Architecture panel from the saved pipeline.yaml so that
  // auto-generated resources (e.g. EventBridge rules added for S3 fan-out) are shown.
  try{
    const r = await fetch(`/admin/pipeline/${encodeURIComponent(name)}`);
    if(!r.ok) return;
    const d = await r.json();
    dgmLabel.textContent = 'Pipeline Architecture — ' + d.name + ' (deployed)';
    buildDagram(d.services, d.integrations||[]);
    log('INFO', now(), 'app', 'Pipeline architecture refreshed from generated YAML.');
  }catch(e){
    log('WARNING', now(), 'app', 'Could not refresh architecture: '+e.message);
  }
}

async function loadDeployedResources(jobId){
  try{
    const r = await fetch(`/deploy/resources/${jobId}`);
    if(!r.ok){
      log('WARNING', now(), 'app', 'Could not load resource table: '+(await r.json()).detail);
      return;
    }
    const d = await r.json();
    // Only show resources that have a console deep-link (i.e. have an ARN + known URL pattern)
    const rows = (d.resources || []).filter(r => r.url);
    if(!rows.length){ return; }

    // Re-number after filtering
    rows.forEach((r, i) => r.idx = i + 1);

    resTableBody.innerHTML = '';
    for(const row of rows){
      const tr = document.createElement('tr');

      // ARN / link cell
      let arnCell;
      if(row.url){
        // Has a console deep-link — make the ARN clickable
        arnCell = `<a class="res-arn-link" href="${row.url}" target="_blank" rel="noopener"
                      title="Open in AWS Console">${row.arn||'Open Console ↗'}</a>`;
      } else if(row.arn){
        // Has ARN but no console URL — show it as plain text
        arnCell = `<span class="res-arn-text">${row.arn}</span>`;
      } else {
        // No ARN (e.g. EventBridge Target, S3 notifications) — show resource name/id
        arnCell = `<span class="res-name">${row.name||'—'}</span>`;
      }

      tr.innerHTML=`
        <td class="res-num">${row.idx}</td>
        <td><div class="res-comp">${row.component}</div><div class="res-type">${row.type}</div></td>
        <td class="res-name">${row.name||'—'}</td>
        <td>${arnCell}</td>`;
      resTableBody.appendChild(tr);
    }

    resPanel.classList.add('show');
    log('INFO', now(), 'app', `☁️ ${rows.length} deployed resources listed in Architecture panel.`);
  }catch(e){
    log('WARNING', now(), 'app', 'Resource table error: '+e.message);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── SERVICE CONFIG POPUP + DEVELOPER AGENT ──────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

const svcCfgOverlay = $('svcCfgOverlay');
const svcCfgBody    = $('svcCfgBody');
const svcCfgTitle   = $('svcCfgTitle');
const svcCfgIcon    = $('svcCfgIcon');
const svcCfgType    = $('svcCfgType');
const svcCfgNote    = $('svcCfgNote');
const svcCfgClose   = $('svcCfgClose');
const devAgentBtn   = $('devAgentBtn');

const devagOverlay    = $('devagOverlay');
const devagChat       = $('devagChat');
const devagInput      = $('devagInput');
const devagSend       = $('devagSend');
const devagClose      = $('devagClose');
const devagSvcLabel   = $('devagSvcLabel');
const devagMentionDrop = $('devagMentionDrop');

// Current service context for developer agent
let _svcCtx = null;
let _devChatId = null;

// All services in the current pipeline (populated by initServices)
let _pipelineServices = [];

// ── Click handler for diagram nodes ────────────────────────────────────────
// Attach click listeners after diagram is built
const _origBuildDagram = buildDagram;
buildDagram = function(services, integrations) {
  _origBuildDagram(services, integrations);
  // Attach click handlers to all nodes
  document.querySelectorAll('.dgm-node').forEach(grp => {
    grp.addEventListener('click', e => {
      // Don't trigger during drag
      if(_svgDrag) return;
      const name = grp.getAttribute('data-name');
      if(name && _deployJobId) openServiceConfig(name);
    });
  });
};

async function openServiceConfig(serviceName){
  if(!_deployJobId) return;
  svcCfgOverlay.classList.add('show');
  svcCfgBody.innerHTML='<div style="text-align:center;padding:40px;color:var(--muted)">Loading configuration…</div>';
  svcCfgTitle.textContent = serviceName;
  svcCfgIcon.textContent = '';
  svcCfgType.textContent = '';
  svcCfgNote.textContent = '';
  devAgentBtn.disabled = true;

  try {
    const r = await fetch(`/pipeline/${_deployJobId}/service/${encodeURIComponent(serviceName)}/config`);
    if(!r.ok){
      const d = await r.json();
      svcCfgBody.innerHTML=`<div style="text-align:center;padding:40px;color:var(--red)">${d.detail||'Failed to load'}</div>`;
      return;
    }
    const d = await r.json();
    const svc = d.service || {};
    const bp = d.blueprint || {};
    const live = d.live_attrs || {};

    svcCfgIcon.textContent = SVC_ICONS[svc.type] || '☁️';
    svcCfgTitle.textContent = svc.name;
    svcCfgType.textContent = svc.type;

    // Store context for developer agent
    _svcCtx = {
      service_name: svc.name,
      service_type: svc.type,
      config: bp.required_configuration || {},
      iam_permissions: bp.iam_permissions || [],
      env_vars: bp.env_vars || {},
      region: d.region,
      resource_name: bp.resource_name || '',
      resource_arn: live.arn || '',
    };

    // Build config sections
    let html = '';

    // Resource info
    html += `<div class="svc-cfg-section">
      <div class="svc-cfg-section-title">Resource Identity</div>
      <div class="svc-cfg-row"><span class="k">Resource Name</span><span class="v">${bp.resource_name||'—'}</span></div>
      <div class="svc-cfg-row"><span class="k">Terraform Label</span><span class="v">${bp.resource_label||'—'}</span></div>
      <div class="svc-cfg-row"><span class="k">Region</span><span class="v">${d.region}</span></div>
      <div class="svc-cfg-row"><span class="k">Has IAM Role</span><span class="v ${bp.is_principal?'bool-true':'bool-false'}">${bp.is_principal?'Yes':'No'}</span></div>
      <div class="svc-cfg-row"><span class="k">VPC Required</span><span class="v ${bp.vpc_required?'bool-true':'bool-false'}">${bp.vpc_required?'Yes':'No'}</span></div>
    </div>`;

    // Configuration
    const cfg = bp.required_configuration || {};
    if(Object.keys(cfg).length){
      html += `<div class="svc-cfg-section"><div class="svc-cfg-section-title">Configuration</div>`;
      for(const [k,v] of Object.entries(cfg)){
        html += `<div class="svc-cfg-row"><span class="k">${k}</span><span class="v">${typeof v === 'object' ? JSON.stringify(v) : v}</span></div>`;
      }
      html += `</div>`;
    }

    // IAM permissions
    const perms = bp.iam_permissions || [];
    if(perms.length){
      html += `<div class="svc-cfg-section"><div class="svc-cfg-section-title">IAM Permissions (${perms.length})</div>
        <div class="svc-cfg-tags">${perms.map(p=>`<span class="svc-cfg-tag">${p}</span>`).join('')}</div></div>`;
    }

    // Env vars
    const envs = bp.env_vars || {};
    if(Object.keys(envs).length){
      html += `<div class="svc-cfg-section"><div class="svc-cfg-section-title">Environment Variables</div>`;
      for(const [k,v] of Object.entries(envs)){
        html += `<div class="svc-cfg-row"><span class="k">${k}</span><span class="v">${v}</span></div>`;
      }
      html += `</div>`;
    }

    // Tags
    const tags = bp.tags || {};
    if(Object.keys(tags).length){
      html += `<div class="svc-cfg-section"><div class="svc-cfg-section-title">Tags</div>`;
      for(const [k,v] of Object.entries(tags)){
        html += `<div class="svc-cfg-row"><span class="k">${k}</span><span class="v">${v}</span></div>`;
      }
      html += `</div>`;
    }

    // Integrations
    const srcI = bp.integrations_as_source || [];
    const tgtI = bp.integrations_as_target || [];
    if(srcI.length || tgtI.length){
      html += `<div class="svc-cfg-section"><div class="svc-cfg-section-title">Integrations</div>`;
      for(const i of tgtI){
        html += `<div class="svc-cfg-row"><span class="k">← Receives from</span><span class="v">${i.source} (${i.event})</span></div>`;
      }
      for(const i of srcI){
        html += `<div class="svc-cfg-row"><span class="k">→ Sends to</span><span class="v">${i.target} (${i.event})</span></div>`;
      }
      html += `</div>`;
    }

    // Live attributes (from tfstate)
    if(Object.keys(live).length){
      html += `<div class="svc-cfg-section"><div class="svc-cfg-section-title">Live Resource Attributes</div>`;
      const showKeys = ['arn','id','bucket','function_name','name','url','endpoint','status',
        'instance_type','runtime','handler','memory_size','timeout','engine','cluster_identifier'];
      for(const k of showKeys){
        if(live[k] !== undefined && live[k] !== null && live[k] !== ''){
          html += `<div class="svc-cfg-row"><span class="k">${k}</span><span class="v">${live[k]}</span></div>`;
        }
      }
      html += `</div>`;
    }

    svcCfgBody.innerHTML = html;

    // Enable Developer Agent if API reference exists
    if(d.has_developer_api){
      devAgentBtn.disabled = false;
      svcCfgNote.textContent = `${Object.keys(cfg).length} config keys · ${perms.length} IAM permissions`;
    } else {
      devAgentBtn.disabled = true;
      svcCfgNote.textContent = 'Developer Agent not available for this service type';
    }

  } catch(e) {
    svcCfgBody.innerHTML=`<div style="text-align:center;padding:40px;color:var(--red)">Error: ${e.message}</div>`;
  }
}

// Close service config
svcCfgClose.addEventListener('click', ()=> svcCfgOverlay.classList.remove('show'));
svcCfgOverlay.addEventListener('click', e=>{ if(e.target===svcCfgOverlay) svcCfgOverlay.classList.remove('show'); });

// ── Developer Agent ────────────────────────────────────────────────────────

devAgentBtn.addEventListener('click', ()=>{
  if(!_svcCtx || devAgentBtn.disabled) return;
  svcCfgOverlay.classList.remove('show');
  _devChatId = null;
  // Reset chat
  devagChat.innerHTML=`<div class="devag-msg agent">
    <div style="font-weight:600;margin-bottom:4px;color:#c4b5fd">🤖 Developer Agent — ${_svcCtx.service_name}</div>
    I have access to the <strong>${_svcCtx.service_type}</strong> service configuration and API reference.
    The resource <code>${_svcCtx.resource_name}</code> is in <strong>${_svcCtx.region}</strong>.
    <br><br>What would you like to create or configure?
  </div>`;
  devagSvcLabel.textContent = `${_svcCtx.service_type} : ${_svcCtx.service_name}`;
  devagInput.value = '';
  devagOverlay.classList.add('show');
  devagInput.focus();
});

// Close developer agent
devagClose.addEventListener('click', ()=> devagOverlay.classList.remove('show'));
devagOverlay.addEventListener('click', e=>{ if(e.target===devagOverlay) devagOverlay.classList.remove('show'); });

// Send message
devagSend.addEventListener('click', sendDevAgentMsg);
devagInput.addEventListener('keydown', e=>{
  // @mention navigation takes priority over send
  if(_mentionActive){
    const items = devagMentionDrop.querySelectorAll('.devag-mention-item');
    if(e.key==='ArrowDown'){
      e.preventDefault();
      _mentionSelIdx = Math.min(_mentionSelIdx+1, items.length-1);
      items.forEach((el,i)=>el.classList.toggle('active',i===_mentionSelIdx));
      return;
    }
    if(e.key==='ArrowUp'){
      e.preventDefault();
      _mentionSelIdx = Math.max(_mentionSelIdx-1, 0);
      items.forEach((el,i)=>el.classList.toggle('active',i===_mentionSelIdx));
      return;
    }
    if(e.key==='Enter' && _mentionSelIdx>=0){
      e.preventDefault();
      const r=_getMentionQuery();
      if(r){
        const q=r.query.toLowerCase();
        const matched=_pipelineServices.filter(s=>s.name.toLowerCase().includes(q)||s.type.toLowerCase().includes(q));
        if(matched[_mentionSelIdx]) _insertMention(matched[_mentionSelIdx], r.atPos);
      }
      return;
    }
    if(e.key==='Escape'){ e.preventDefault(); _hideMentionDrop(); return; }
    if(e.key===' '){ _hideMentionDrop(); }
  }
  if(e.key==='Enter' && !e.shiftKey){ e.preventDefault(); sendDevAgentMsg(); }
});

async function sendDevAgentMsg(){
  const msg = devagInput.value.trim();
  if(!msg || !_svcCtx) return;
  devagInput.value = '';

  // Add user message
  const userDiv = document.createElement('div');
  userDiv.className = 'devag-msg user';
  userDiv.textContent = msg;
  devagChat.appendChild(userDiv);

  // Add thinking indicator
  const thinking = document.createElement('div');
  thinking.className = 'devag-thinking';
  thinking.innerHTML = '<div class="dots"><span></span><span></span><span></span></div> Generating code…';
  devagChat.appendChild(thinking);
  devagChat.scrollTop = devagChat.scrollHeight;

  devagSend.disabled = true;

  try {
    const r = await fetch('/developer-agent/chat', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({
        message: msg,
        chat_id: _devChatId || '',
        ..._svcCtx,
      }),
    });
    thinking.remove();

    if(!r.ok){
      const d = await r.json();
      const errDiv = document.createElement('div');
      errDiv.className = 'devag-msg agent';
      errDiv.innerHTML = `<span style="color:var(--red)">Error: ${d.detail||'Request failed'}</span>`;
      devagChat.appendChild(errDiv);
      devagChat.scrollTop = devagChat.scrollHeight;
      devagSend.disabled = false;
      return;
    }

    const d = await r.json();
    _devChatId = d.chat_id;

    // Build agent response
    const agentDiv = document.createElement('div');
    agentDiv.className = 'devag-msg agent';

    let inner = '';
    if(d.explanation){
      inner += `<div class="msg-explain">${escHtml(d.explanation)}</div>`;
    }
    if(d.operations_used && d.operations_used.length){
      inner += `<div class="msg-ops">${d.operations_used.map(o=>`<span>${o}</span>`).join('')}</div>`;
    }
    if(d.code){
      const codeId = 'code_' + Date.now();
      const resultId = 'result_' + Date.now();
      inner += `<div class="devag-code-wrap">
        <div class="devag-code-hdr">
          <span>Python (boto3) — deploys to ${escHtml(_svcCtx?.service_type||'service')}</span>
          <button class="devag-code-copy" onclick="copyCode('${codeId}')">Copy</button>
        </div>
        <pre class="devag-code" id="${codeId}">${escHtml(d.code)}</pre>
        <div class="devag-exec-bar">
          <span class="devag-exec-status" id="es_${resultId}">Ready to deploy</span>
          <button class="devag-exec-btn" onclick="executeCode('${codeId}','${resultId}',this)">▶ Deploy</button>
        </div>
      </div>
      <div id="${resultId}"></div>`;
    }

    agentDiv.innerHTML = inner;
    devagChat.appendChild(agentDiv);
    devagChat.scrollTop = devagChat.scrollHeight;

  } catch(e) {
    thinking.remove();
    const errDiv = document.createElement('div');
    errDiv.className = 'devag-msg agent';
    errDiv.innerHTML = `<span style="color:var(--red)">Network error: ${e.message}</span>`;
    devagChat.appendChild(errDiv);
  }

  devagSend.disabled = false;
  devagChat.scrollTop = devagChat.scrollHeight;
}

function escHtml(s){
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

// ── @mention autocomplete ──────────────────────────────────────────────────
let _mentionActive  = false;
let _mentionSelIdx  = -1;

function _getMentionQuery(){
  const val   = devagInput.value;
  const caret = devagInput.selectionStart;
  const before = val.slice(0, caret);
  const at = before.lastIndexOf('@');
  if(at === -1) return null;
  const query = before.slice(at + 1);
  // Cancel if there's a space between @ and caret (mention ended)
  if(/\s/.test(query)) return null;
  return { query, atPos: at };
}

function _showMentionDrop(items, atPos){
  _mentionActive  = true;
  _mentionSelIdx  = -1;
  devagMentionDrop.innerHTML =
    `<div class="devag-mention-hint">Pipeline services — ↑↓ navigate · Enter select · Esc dismiss</div>`;
  items.forEach(svc => {
    const el = document.createElement('div');
    el.className = 'devag-mention-item';
    el.innerHTML =
      `<span class="devag-mention-ico">${SVC_ICONS[svc.type]||'☁️'}</span>` +
      `<span class="devag-mention-name">${escHtml(svc.name)}</span>` +
      `<span class="devag-mention-badge">${escHtml(svc.type)}</span>`;
    el.addEventListener('mousedown', e => {
      e.preventDefault();           // keep textarea focused
      _insertMention(svc, atPos);
    });
    devagMentionDrop.appendChild(el);
  });
  devagMentionDrop.style.display = 'block';
}

function _hideMentionDrop(){
  _mentionActive = false;
  _mentionSelIdx = -1;
  devagMentionDrop.style.display = 'none';
}

function _insertMention(svc, atPos){
  const val   = devagInput.value;
  const caret = devagInput.selectionStart;
  // Insert "@name[type]" — gives the developer agent a clear cross-service reference
  const token = `@${svc.name}[${svc.type}]`;
  devagInput.value = val.slice(0, atPos) + token + ' ' + val.slice(caret);
  const newPos = atPos + token.length + 1;
  devagInput.setSelectionRange(newPos, newPos);
  devagInput.focus();
  _hideMentionDrop();
}

devagInput.addEventListener('input', () => {
  const r = _getMentionQuery();
  if(!r){ _hideMentionDrop(); return; }
  const q = r.query.toLowerCase();
  const matches = _pipelineServices.filter(s =>
    s.name.toLowerCase().includes(q) || s.type.toLowerCase().includes(q)
  );
  if(!matches.length){ _hideMentionDrop(); return; }
  _showMentionDrop(matches, r.atPos);
});

// Hide when clicking outside the mention dropdown
document.addEventListener('mousedown', e => {
  if(_mentionActive && !devagMentionDrop.contains(e.target) && e.target !== devagInput){
    _hideMentionDrop();
  }
});
// ── end @mention ────────────────────────────────────────────────────────────

function copyCode(codeId){
  const el = document.getElementById(codeId);
  if(!el) return;
  navigator.clipboard.writeText(el.textContent).then(()=>{
    const btn = el.parentElement.querySelector('.devag-code-copy');
    if(btn){ btn.textContent='Copied!'; setTimeout(()=>btn.textContent='Copy',1500); }
  });
}

async function executeCode(codeId, resultId, btn){
  const codeEl = document.getElementById(codeId);
  const resultEl = document.getElementById(resultId);
  const statusEl = document.getElementById('es_'+resultId);
  if(!codeEl || !resultEl) return;

  btn.disabled = true;
  btn.textContent = '⏳ Deploying…';
  statusEl.textContent = 'Deploying to AWS…';
  statusEl.style.color = 'var(--muted)';
  resultEl.innerHTML = '';

  try {
    const r = await fetch('/developer-agent/execute', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        code: codeEl.textContent,
        region: _svcCtx?.region || 'us-east-1',
        // Pass service context for auto-fix
        service_name: _svcCtx?.service_name || '',
        service_type: _svcCtx?.service_type || '',
        config: _svcCtx?.config || {},
        iam_permissions: _svcCtx?.iam_permissions || [],
        env_vars: _svcCtx?.env_vars || {},
        resource_name: _svcCtx?.resource_name || '',
        resource_arn: _svcCtx?.resource_arn || '',
      }),
    });
    const text = await r.text();
    let d;
    try { d = JSON.parse(text); } catch(_){
      throw new Error(r.ok ? 'Invalid response from server' : `Server error (${r.status}): ${text.slice(0,200)}`);
    }

    if(d.success){
      // Deployment succeeded
      const lastAttempt = d.attempts[d.attempts.length - 1];
      const attemptCount = d.attempts.length;
      statusEl.textContent = attemptCount > 1
        ? `Deployed successfully (after ${attemptCount} attempts)`
        : 'Deployed successfully';
      statusEl.style.color = 'var(--green)';
      btn.textContent = '✓ Deployed';

      // Update code panel with final (possibly fixed) code
      if(attemptCount > 1 && d.final_code){
        codeEl.textContent = d.final_code;
      }

      // Show attempt log
      let html = renderAttemptLog(d.attempts);
      resultEl.innerHTML = html;
    } else if(d.needs_human){
      // Max retries exhausted — human intervention required
      statusEl.textContent = `Failed after ${d.attempts.length} attempts — human intervention required`;
      statusEl.style.color = 'var(--red)';
      btn.textContent = '▶ Deploy';
      btn.disabled = false;

      // Update code panel with last attempted code
      if(d.final_code){
        codeEl.textContent = d.final_code;
      }

      let html = renderAttemptLog(d.attempts);
      html += `<div class="devag-result">
        <div class="devag-result-hdr error" style="padding:8px 10px;font-size:11px">
          ⚠ Auto-fix exhausted after 6 attempts. Please review the errors above and modify the code manually, or describe the issue to the Developer Agent for a new approach.
        </div>
      </div>`;
      resultEl.innerHTML = html;
    } else {
      // Generic failure
      statusEl.textContent = 'Deployment failed';
      statusEl.style.color = 'var(--red)';
      btn.textContent = '▶ Deploy';
      btn.disabled = false;
      resultEl.innerHTML = renderAttemptLog(d.attempts || []);
    }

    devagChat.scrollTop = devagChat.scrollHeight;
  } catch(e) {
    statusEl.textContent = 'Network error: ' + e.message;
    statusEl.style.color = 'var(--red)';
    btn.textContent = '▶ Deploy';
    btn.disabled = false;
  }
}

function renderAttemptLog(attempts){
  if(!attempts || !attempts.length) return '';
  let html = '';
  for(const a of attempts){
    const isLast = a === attempts[attempts.length - 1];
    const ok = a.exit_code === 0;
    const attemptLabel = attempts.length > 1 ? `Attempt ${a.attempt}/${attempts.length}` : 'Execution';
    const hdrClass = ok ? 'success' : (isLast && !ok ? 'error' : '');

    html += `<div class="devag-result" style="margin-top:6px">`;
    html += `<div class="devag-result-hdr ${hdrClass}">${ok ? '✓' : '✗'} ${attemptLabel}${a.fix_explanation ? ' — ' + escHtml(a.fix_explanation) : ''}</div>`;

    if(a.stdout){
      html += `<pre>${escHtml(a.stdout)}</pre>`;
    }
    if(a.stderr && !ok){
      html += `<pre style="color:var(--red)">${escHtml(a.stderr)}</pre>`;
    }
    // Show auto-fix status between attempts
    if(!ok && !isLast){
      html += `<div style="padding:4px 10px;font-size:9px;color:#8b5cf6;background:rgba(139,92,246,.08);border-top:1px solid var(--border)">🔄 Sending error to Developer Agent for auto-fix…</div>`;
    }
    html += `</div>`;
  }
  return html;
}

// ── Escape handling for all new overlays ─────────────────────────────────
document.addEventListener('keydown', e=>{
  if(e.key==='Escape'){
    if(devagOverlay.classList.contains('show')){ devagOverlay.classList.remove('show'); return; }
    if(svcCfgOverlay.classList.contains('show')){ svcCfgOverlay.classList.remove('show'); return; }
  }
});

// ══════════════════════════════════════════════════════════════════════════════
