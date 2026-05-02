// ── Config Chat ──────────────────────────────────────────────────────────────
let _cfgChatId = null;
let _cfgServices = [];        // [{name, type, config}] from pipeline
let _cfgSelectedSvc = null;   // current selected service name
let _cfgSelectedType = null;

// Populate service dropdown when services_init arrives
function cfgPopulateServices(services) {
  _cfgServices = services.map(s => ({name: s.name, type: s.type, config: {}}));
  cfgSvcSelect.innerHTML = '<option value="">-- select service --</option>';
  for (const s of _cfgServices) {
    const opt = document.createElement('option');
    opt.value = s.name;
    opt.textContent = `${s.name} (${s.type})`;
    cfgSvcSelect.appendChild(opt);
  }
}

// Load pipeline.yaml config for services after build completes
async function cfgLoadServiceConfigs(jobId) {
  // Load supported keys + config from pipeline.yaml via job details
  for (const svc of _cfgServices) {
    try {
      const r = await fetch(`/config/templates/${svc.type}`);
      if (r.ok) {
        const d = await r.json();
        svc.templates = d.templates || [];
        svc.supported_keys = d.supported_keys || [];
      }
    } catch(e) {}
  }
}

cfgSvcSelect.addEventListener('change', () => {
  const name = cfgSvcSelect.value;
  if (!name) {
    _cfgSelectedSvc = null;
    _cfgSelectedType = null;
    cfgInput.disabled = true;
    cfgSendBtn.disabled = true;
    cfgTplBar.innerHTML = '';
    return;
  }
  const svc = _cfgServices.find(s => s.name === name);
  _cfgSelectedSvc = name;
  _cfgSelectedType = svc ? svc.type : null;
  cfgInput.disabled = false;
  cfgSendBtn.disabled = false;
  cfgInput.focus();

  // Populate template chips
  cfgTplBar.innerHTML = '';
  if (svc && svc.templates && svc.templates.length) {
    for (const t of svc.templates) {
      const chip = document.createElement('span');
      chip.className = 'cfg-tpl-chip';
      chip.textContent = t.display_name;
      chip.title = t.description;
      chip.addEventListener('click', () => cfgApplyTemplate(t));
      cfgTplBar.appendChild(chip);
    }
  }

  // Show supported keys info
  if (svc && svc.supported_keys && svc.supported_keys.length) {
    // If msgs area is empty, show a hint about supported keys
    if (cfgMsgs.children.length <= 1 && cfgEmpty.style.display !== 'none') {
      const keys = svc.supported_keys.map(k => `${k.key} (${k.description})`).join(', ');
      cfgEmpty.innerHTML = `Configurable keys for <b>${svc.type}</b>: ${escHtml(keys)}<br><br>` +
        'Type a request like "enable versioning" or "set memory to 1GB", or click a template above.';
    }
  }
});

function cfgAddMsg(role, html) {
  if (cfgEmpty) cfgEmpty.style.display = 'none';
  const div = document.createElement('div');
  div.className = `cfg-msg ${role}`;
  div.innerHTML = html;
  cfgMsgs.appendChild(div);
  cfgMsgs.scrollTop = cfgMsgs.scrollHeight;
  return div;
}

async function cfgSendMessage() {
  const msg = cfgInput.value.trim();
  if (!msg || !_cfgSelectedSvc || !_deployJobId) return;
  cfgInput.value = '';
  cfgSendBtn.disabled = true;

  cfgAddMsg('user', escHtml(msg));

  try {
    const r = await fetch('/config/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        message: msg,
        job_id: _deployJobId,
        service_name: _cfgSelectedSvc,
        chat_id: _cfgChatId,
      }),
    });
    const d = await r.json();
    if (!r.ok) {
      cfgAddMsg('system', `<span style="color:var(--red)">Error: ${escHtml(d.detail || 'Request failed')}</span>`);
      cfgSendBtn.disabled = false;
      return;
    }

    _cfgChatId = d.chat_id;

    if (d.error) {
      cfgAddMsg('system', escHtml(d.error));
      cfgSendBtn.disabled = false;
      return;
    }

    if (d.resolution) {
      cfgShowResolution(d.resolution, d.tier);
    } else {
      cfgAddMsg('system', 'Could not resolve your request. Try being more specific.');
    }
  } catch(e) {
    cfgAddMsg('system', `<span style="color:var(--red)">Error: ${escHtml(e.message)}</span>`);
  }
  cfgSendBtn.disabled = false;
}

function cfgShowResolution(res, tier) {
  const tierLabels = {0: 'Keyword', 1: 'Haiku', 2: 'Sonnet'};
  const tierClass = `t${tier}`;
  let html = `<span class="cfg-tier ${tierClass}">Tier ${tier}: ${tierLabels[tier] || tier}</span><br>`;
  html += escHtml(res.explanation);

  if (res.config_patch && Object.keys(res.config_patch).length) {
    html += `<div class="cfg-patch">${escHtml(JSON.stringify(res.config_patch, null, 2))}</div>`;
  }

  if (res.warnings && res.warnings.length) {
    for (const w of res.warnings) {
      html += `<div class="cfg-warn">Warning: ${escHtml(w)}</div>`;
    }
  }
  if (res.cost_warning) {
    html += `<div class="cfg-cost">Cost: ${escHtml(res.cost_warning)}</div>`;
  }

  if (res.config_patch && Object.keys(res.config_patch).length) {
    html += '<div class="cfg-actions">';
    html += `<button class="cfg-apply-btn" onclick="cfgApplyPatch('${escHtml(res.service_name)}', ${escHtml(JSON.stringify(JSON.stringify(res.config_patch)))})">Apply Changes</button>`;
    html += '<button class="cfg-dismiss-btn" onclick="this.closest(\'.cfg-msg\').remove()">Dismiss</button>';
    html += '</div>';
  }

  cfgAddMsg('system', html);
}

async function cfgApplyPatch(serviceName, patchJson) {
  const patch = JSON.parse(patchJson);
  try {
    const r = await fetch('/config/apply', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        job_id: _deployJobId,
        service_name: serviceName,
        config_patch: patch,
      }),
    });
    const d = await r.json();
    if (!r.ok) {
      cfgAddMsg('system', `<span style="color:var(--red)">Apply failed: ${escHtml(d.detail || '')}</span>`);
      return;
    }

    cfgAddMsg('system',
      `Config applied to <b>${escHtml(serviceName)}</b>. ` +
      `Pipeline re-rendering... (new job: ${d.new_job_id.substring(0, 8)})`
    );

    // Switch to build tab and connect to the new job
    if (d.new_job_id) {
      _deployJobId = d.new_job_id;
      switchConsoleTab('build');
      cfgConnectRebuildWs(d.new_job_id);
    }
  } catch(e) {
    cfgAddMsg('system', `<span style="color:var(--red)">Apply error: ${escHtml(e.message)}</span>`);
  }
}

async function cfgApplyTemplate(template) {
  if (!_cfgSelectedSvc || !_deployJobId) return;
  cfgAddMsg('user', `Apply template: ${escHtml(template.display_name)}`);

  try {
    const r = await fetch('/config/template/apply', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        job_id: _deployJobId,
        service_name: _cfgSelectedSvc,
        service_type: _cfgSelectedType,
        template_id: template.id,
      }),
    });
    const d = await r.json();
    if (!r.ok) {
      cfgAddMsg('system', `<span style="color:var(--red)">Template apply failed: ${escHtml(d.detail || '')}</span>`);
      return;
    }

    cfgAddMsg('system',
      `Template "<b>${escHtml(template.display_name)}</b>" applied to <b>${escHtml(_cfgSelectedSvc)}</b>. ` +
      `Pipeline re-rendering...`
    );

    if (d.new_job_id) {
      _deployJobId = d.new_job_id;
      switchConsoleTab('build');
      cfgConnectRebuildWs(d.new_job_id);
    }
  } catch(e) {
    cfgAddMsg('system', `<span style="color:var(--red)">Template error: ${escHtml(e.message)}</span>`);
  }
}

// Connect to rebuild WebSocket after config apply/template apply
function cfgConnectRebuildWs(jobId) {
  const url = `${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/${jobId}`;
  setBusy(true);
  setProg(0, 'Re-rendering pipeline...', '');
  setStatus('running', 'Re-rendering...');
  consoleEl.innerHTML = '';
  activeWs = makeWs(url, function({data}) {
    const m = JSON.parse(data);
    if (m.type === 'log') log(m.level, m.time, m.logger, m.message);
    if (m.type === 'progress') { setProg(m.pct, m.stage, m.pct >= 100 ? 'done' : ''); setStatus('running', m.stage || (m.pct + '%')); }
    if (m.type === 'services_init') {
      initServices(m.services);
      buildDagram(m.services, m.integrations || []);
      cfgPopulateServices(m.services);
    }
    if (m.type === 'service_update') updService(m.name, m.status);
    if (m.type === 'done') {
      setBusy(false);
      if (m.exit_code === 0) {
        setStatus('ok', 'Config applied successfully');
        setProg(100, 'Complete', 'done');
        log('SUCCESS', now(), 'pipeline', 'Config applied — Terraform re-rendered.');
        _pipelineName = m.result?.pipeline_name || '';
        planBtn.disabled = false; planBtn.classList.add('enabled');
        matrixBtn.disabled = false; matrixBtn.classList.add('enabled');
        cfgLoadServiceConfigs(jobId);
      } else {
        setStatus('fail', 'Re-render failed');
        log('ERROR', now(), 'pipeline', 'Re-render failed after config change.');
      }
      if (!m.cancelled) showResult(m.exit_code, m.result);
    }
  }, {
    onGiveUp() { log('ERROR', now(), 'ws', 'Connection lost during re-render.'); setStatus('fail', 'Connection error'); setBusy(false); }
  });
}

// Wire up send button and enter key
cfgSendBtn.addEventListener('click', cfgSendMessage);
cfgInput.addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    cfgSendMessage();
  }
});

