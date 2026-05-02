// ── Shared element refs (designer + modal builder) ───────────────────────────
const pbOverlay=$('pbOverlay'),pbChat=$('pbChat'),pbEmpty=$('pbEmpty'),
      pbInput=$('pbInput'),pbSend=$('pbSend'),pbStatus=$('pbStatus'),
      pbPreviewCol=$('pbPreviewCol'),pbYaml=$('pbYaml'),pbPipeName=$('pbPipeName'),
      pbBuildBtn=$('pbBuildBtn'),pbClose=$('pbClose'),pipeBuilderBtn=$('pipeBuilderBtn'),
      pbImgBtn=$('pbImgBtn'),pbImageInput=$('pbImageInput'),
      pbImgPreview=$('pbImgPreview'),pbImgName=$('pbImgName'),pbImgClear=$('pbImgClear');

// ── Pipeline Designer (main-screen chat) ─────────────────────────────────────
const dcMessages=$('dcMessages'),dcInput=$('dcInput'),dcSend=$('dcSend'),
      dcStatus=$('dcStatus'),dcBuildBtn=$('dcBuildBtn'),dcEmpty=$('dcEmpty'),
      designerChat=$('designerChat'),dcToggle=$('dcToggle'),dcHeader=$('dcHeader');

let _dcChatId = null;
let _dcBusy = false;
let _dcServices = null;
let _dcIntegrations = null;
let _dcYaml = '';          // latest YAML from design phase
let _dcPipelineName = '';

// ── Collapse / Expand ────────────────────────────────────────────────────────
let _dcCollapsed = false;
let _dcSavedFr = null; // saved grid fractions before collapse

function dcCollapse() {
  if (_dcCollapsed) return;
  _dcCollapsed = true;
  _dcSavedFr = [..._splitFr];
  designerChat.classList.add('collapsed');
  // Redistribute chat space to console
  _splitFr[2] += _splitFr[1];
  _splitFr[1] = 0;
  _applyGridRows();
}
function dcExpand() {
  if (!_dcCollapsed) return;
  _dcCollapsed = false;
  designerChat.classList.remove('collapsed');
  if (_dcSavedFr) {
    _splitFr = [..._dcSavedFr];
  } else {
    _splitFr = [5, 2, 3];
  }
  _applyGridRows();
}
function dcToggleCollapse() {
  if (_dcCollapsed) dcExpand(); else dcCollapse();
}
dcHeader.addEventListener('click', e => {
  // Don't toggle if clicking the build button
  if (e.target.closest('.dc-build-btn')) return;
  dcToggleCollapse();
});

// ── Shared message helpers ───────────────────────────────────────────────────
function dcAddMsg(role, html) {
  if (dcEmpty) dcEmpty.style.display = 'none';
  const div = document.createElement('div');
  div.className = `dc-msg ${role}`;
  div.innerHTML = html;
  dcMessages.appendChild(div);
  dcMessages.scrollTop = dcMessages.scrollHeight;
  return div;
}

function dcShowThinking() {
  const div = document.createElement('div');
  div.className = 'dc-thinking';
  div.id = 'dcThinking';
  div.innerHTML = 'Designing pipeline <div class="dots"><span></span><span></span><span></span></div>';
  dcMessages.appendChild(div);
  dcMessages.scrollTop = dcMessages.scrollHeight;
}
function dcHideThinking() {
  const el = document.getElementById('dcThinking');
  if (el) el.remove();
}

function dcUseExample(el) {
  dcInput.value = el.textContent.trim();
  dcInput.focus();
}

// ── Build agent response HTML (shared by main chat + modal) ──────────────────
function _buildAgentResponseHtml(d) {
  let html = `Pipeline <b>${escHtml(d.pipeline_name)}</b> designed with ${d.services.length} service(s).`;
  html += '<div class="dc-svc-list">';
  for (const s of d.services) {
    const icon = SVC_ICONS[s.type] || '\u2601\uFE0F';
    html += `<span class="dc-svc-chip">${icon} ${escHtml(s.name)}</span>`;
  }
  html += '</div>';
  if (d.integrations && d.integrations.length) {
    html += '<div style="margin-top:6px;display:flex;flex-wrap:wrap;gap:4px">';
    for (const i of d.integrations) {
      html += `<span style="display:inline-flex;align-items:center;gap:3px;padding:2px 7px;border-radius:4px;background:var(--bg);border:1px solid var(--border);font-size:10px;color:var(--muted);font-family:var(--mono)">${escHtml(i.source)} \u2192 ${escHtml(i.target)}</span>`;
    }
    html += '</div>';
  }
  html += '<div style="margin-top:6px;font-size:11px;color:var(--muted)">Modify the design by typing changes, or click <b>Build Terraform</b> when ready.</div>';
  return html;
}

// ── Handle a successful design response (shared logic) ───────────────────────
function _handleDesignResponse(d) {
  _dcChatId = d.chat_id;
  _dcServices = d.services;
  _dcIntegrations = d.integrations;
  _dcYaml = d.yaml || '';
  _dcPipelineName = d.pipeline_name || '';

  // Render proper dagre diagram in the architect panel
  if (d.services && d.services.length) {
    _lastRenderedPipelineName = d.pipeline_name || '';
    initServices(d.services);
    buildDagram(d.services, d.integrations || []);
    dgmLabel.textContent = 'Pipeline Design';
  }

  // Enable build buttons on both UIs
  dcBuildBtn.classList.add('show');
  dcBuildBtn.disabled = false;

  // Sync modal builder YAML preview
  pbPreviewCol.classList.remove('empty');
  pbPipeName.textContent = d.pipeline_name;
  pbYaml.textContent = d.yaml || '';
  pbBuildBtn.disabled = false;
}

// ── Send message from main-screen chat ───────────────────────────────────────
async function dcSendMessage() {
  const msg = dcInput.value.trim();
  if (!msg || _dcBusy) return;

  // Intercept "create @service" / "add @service" — handle locally
  if (/^(?:create|add)\s+@/i.test(msg)) {
    dcInput.value = '';
    dcAddMsg('user', escHtml(msg));
    pbAddMsg('user', escHtml(msg));
    _pbHandleCreateCommand(msg);
    return;
  }

  dcInput.value = '';
  _dcBusy = true;
  dcSend.disabled = true;
  dcStatus.textContent = 'Designing...';

  dcAddMsg('user', escHtml(msg));
  // Mirror in modal
  pbAddMsg('user', escHtml(msg));
  dcShowThinking();

  try {
    const r = await fetch('/pipeline-designer/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ message: msg, chat_id: _dcChatId }),
    });
    dcHideThinking();
    const d = await r.json();

    if (!r.ok) {
      const errHtml = `<span style="color:var(--red)">${escHtml(d.detail || 'Design failed')}</span>`;
      dcAddMsg('agent', errHtml);
      pbAddMsg('agent', errHtml);
      dcStatus.textContent = 'Error';
      pbStatus.textContent = 'Error';
    } else {
      _handleDesignResponse(d);
      dcStatus.textContent = 'Design ready';
      pbStatus.textContent = 'Ready';

      const html = _buildAgentResponseHtml(d);
      dcAddMsg('agent', html);
      pbAddMsg('agent', html);
    }
  } catch(e) {
    dcHideThinking();
    const errHtml = `<span style="color:var(--red)">Error: ${escHtml(e.message)}</span>`;
    dcAddMsg('agent', errHtml);
    pbAddMsg('agent', errHtml);
    dcStatus.textContent = 'Error';
  }

  _dcBusy = false;
  dcSend.disabled = false;
}

dcSend.addEventListener('click', dcSendMessage);

// ── DC @mention autocomplete for service types ───────────────────────────────
const dcMentionDrop = $('dcMentionDrop');
let _dcMentionActive = false;
let _dcMentionSelIdx = -1;
let _dcMentionJustInserted = false;

function _dcGetMentionQuery() {
  const val = dcInput.value;
  const caret = dcInput.selectionStart;
  const before = val.slice(0, caret);
  const at = before.lastIndexOf('@');
  if (at === -1) return null;
  const query = before.slice(at + 1);
  if (/\s/.test(query)) return null;
  return { query, atPos: at };
}

function _dcShowMentionDrop(items, atPos) {
  _dcMentionActive = true;
  _dcMentionSelIdx = -1;
  dcMentionDrop.innerHTML =
    `<div class="pb-mention-hint">AWS Services — ↑↓ navigate · Enter select · Esc dismiss</div>`;
  items.forEach(t => {
    const el = document.createElement('div');
    el.className = 'pb-mention-item';
    el.innerHTML =
      `<span class="pb-mention-ico">${SVC_ICONS[t] || '☁️'}</span>` +
      `<span class="pb-mention-name">${t}</span>` +
      `<span class="pb-mention-badge">${ABBREV[t] || t}</span>`;
    el.addEventListener('mousedown', e => {
      e.preventDefault();
      _dcInsertMention(t, atPos);
    });
    dcMentionDrop.appendChild(el);
  });
  const rect = dcInput.getBoundingClientRect();
  dcMentionDrop.style.left = rect.left + 'px';
  dcMentionDrop.style.width = rect.width + 'px';
  dcMentionDrop.style.display = 'block';
  const dropH = dcMentionDrop.offsetHeight;
  dcMentionDrop.style.top = (rect.top - dropH - 6) + 'px';
}

function _dcHideMentionDrop() {
  _dcMentionActive = false;
  _dcMentionSelIdx = -1;
  dcMentionDrop.style.display = 'none';
}

function _dcInsertMention(type, atPos) {
  const val = dcInput.value;
  const caret = dcInput.selectionStart;
  const token = `@${type}`;
  dcInput.value = val.slice(0, atPos) + token + ' ' + val.slice(caret);
  const newPos = atPos + token.length + 1;
  dcInput.setSelectionRange(newPos, newPos);
  dcInput.focus();
  _dcHideMentionDrop();
}

dcInput.addEventListener('input', () => {
  const r = _dcGetMentionQuery();
  if (!r) { _dcHideMentionDrop(); return; }
  const q = r.query.toLowerCase();
  const matches = ALL_SVC_TYPES.filter(t =>
    t.includes(q) || (ABBREV[t] || '').toLowerCase().includes(q)
  );
  if (!matches.length) { _dcHideMentionDrop(); return; }
  _dcShowMentionDrop(matches, r.atPos);
});

dcInput.addEventListener('keydown', e => {
  if (_dcMentionActive) {
    const items = dcMentionDrop.querySelectorAll('.pb-mention-item');
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      _dcMentionSelIdx = Math.min(_dcMentionSelIdx + 1, items.length - 1);
      items.forEach((el, i) => el.classList.toggle('active', i === _dcMentionSelIdx));
      if (items[_dcMentionSelIdx]) items[_dcMentionSelIdx].scrollIntoView({ block: 'nearest' });
      return;
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      _dcMentionSelIdx = Math.max(_dcMentionSelIdx - 1, 0);
      items.forEach((el, i) => el.classList.toggle('active', i === _dcMentionSelIdx));
      if (items[_dcMentionSelIdx]) items[_dcMentionSelIdx].scrollIntoView({ block: 'nearest' });
      return;
    } else if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      if (_dcMentionSelIdx >= 0) {
        const r = _dcGetMentionQuery();
        if (r) {
          const q = r.query.toLowerCase();
          const matches = ALL_SVC_TYPES.filter(t =>
            t.includes(q) || (ABBREV[t] || '').toLowerCase().includes(q)
          );
          if (matches[_dcMentionSelIdx]) _dcInsertMention(matches[_dcMentionSelIdx], r.atPos);
        }
        _dcMentionJustInserted = true;
      } else {
        _dcHideMentionDrop();
        dcSendMessage();
      }
      _dcHideMentionDrop();
      return;
    } else if (e.key === 'Escape') {
      e.preventDefault();
      _dcHideMentionDrop();
      return;
    }
  }
  // Normal keydown — send on Enter
  if (_dcMentionJustInserted) { _dcMentionJustInserted = false; return; }
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    dcSendMessage();
  }
});

dcInput.addEventListener('blur', () => {
  setTimeout(_dcHideMentionDrop, 150);
});

// ── Shared build function (used by both main chat and modal) ─────────────────
async function dcStartBuild() {
  // If in architect mode (user edited the pipeline), use the architect build path
  if (_archMode && archNodes.length > 0) {
    pbOverlay.classList.remove('show');
    archGenerate();
    return;
  }
  if (!_dcChatId) return;
  if (!validateProjectFields()) return;

  dcBuildBtn.disabled = true;
  dcBuildBtn.textContent = 'Building...';
  pbBuildBtn.disabled = true;
  pbBuildBtn.textContent = 'Building...';
  dcStatus.textContent = 'Building Terraform...';
  pbStatus.textContent = 'Building Terraform...';

  try {
    const r = await fetch('/pipeline-designer/build', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        chat_id: _dcChatId,
        business_unit: getBusinessUnit() || getProject(),
        cost_center: getCostCenter(),
      }),
    });
    const d = await r.json();
    if (!r.ok) {
      const errHtml = `<span style="color:var(--red)">Build failed: ${escHtml(d.detail || '')}</span>`;
      dcAddMsg('agent', errHtml);
      pbAddMsg('agent', errHtml);
      dcBuildBtn.disabled = false;
      dcBuildBtn.textContent = 'Build Terraform';
      pbBuildBtn.disabled = false;
      pbBuildBtn.textContent = 'Build Terraform';
      dcStatus.textContent = 'Build failed';
      pbStatus.textContent = 'Build failed';
      return;
    }

    const buildMsg = `Building Terraform for <b>${escHtml(d.pipeline_name)}</b>... Check the Pipeline Build console.`;
    dcAddMsg('agent', buildMsg);
    pbAddMsg('agent', buildMsg);
    dcStatus.textContent = 'Build started';
    pbStatus.textContent = 'Build started';

    // Close modal, collapse designer chat, show build console
    pbOverlay.classList.remove('show');
    dcCollapse();
    _deployJobId = d.job_id;
    switchConsoleTab('build');

    const wsUrl = `${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/${d.job_id}`;
    setBusy(true);
    setProg(0, 'Generating Terraform...', '');
    setStatus('running', 'Building pipeline...');
    consoleEl.innerHTML = '';
    activeWs = makeWs(wsUrl, function({data}) {
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
          setStatus('ok', 'Pipeline built successfully');
          setProg(100, 'Complete', 'done');
          log('SUCCESS', now(), 'pipeline', 'Terraform generated successfully.');
          _pipelineName = m.result?.pipeline_name || '';
          planBtn.disabled = false; planBtn.classList.add('enabled');
          matrixBtn.disabled = false; matrixBtn.classList.add('enabled');
          cfgLoadServiceConfigs(d.job_id);
          // Auto-expand Terraform/AWS section so buttons are visible
          if (!tfOpen) {
            tfOpen = true;
            tfMenuRows.classList.add('open');
            tfChevron.classList.add('open');
          }
        } else {
          setStatus('fail', 'Build failed');
          log('ERROR', now(), 'pipeline', 'Build failed.');
        }
        if (!m.cancelled) showResult(m.exit_code, m.result);
        dcBuildBtn.textContent = 'Build Terraform';
        dcBuildBtn.disabled = false;
        pbBuildBtn.textContent = 'Build Terraform';
        pbBuildBtn.disabled = false;
      }
    }, {
      onGiveUp() { log('ERROR', now(), 'ws', 'Connection lost during build.'); setStatus('fail', 'Connection error'); setBusy(false); }
    });

  } catch(e) {
    const errHtml = `<span style="color:var(--red)">Build error: ${escHtml(e.message)}</span>`;
    dcAddMsg('agent', errHtml);
    pbAddMsg('agent', errHtml);
    dcBuildBtn.disabled = false;
    dcBuildBtn.textContent = 'Build Terraform';
    pbBuildBtn.disabled = false;
    pbBuildBtn.textContent = 'Build Terraform';
    dcStatus.textContent = 'Error';
    pbStatus.textContent = 'Error';
  }
}

dcBuildBtn.addEventListener('click', dcStartBuild);

// ── Pipeline Builder Agent (modal — synced with main-screen designer) ────────
let _pbBusy = false;
let _pbImageFile = null;

pipeBuilderBtn.addEventListener('click', () => { pbOverlay.classList.add('show'); pbInput.focus(); });
pbClose.addEventListener('click', () => pbOverlay.classList.remove('show'));
pbOverlay.addEventListener('click', e => { if (e.target === pbOverlay) pbOverlay.classList.remove('show'); });

// Image upload wiring
pbImgBtn.addEventListener('click', () => pbImageInput.click());
pbImageInput.addEventListener('change', () => {
  const file = pbImageInput.files[0];
  if (!file) return;
  _pbImageFile = file;
  pbImgName.textContent = file.name;
  pbImgPreview.style.display = 'flex';
  pbInput.placeholder = 'Add a note about this diagram (optional)...';
  pbImageInput.value = '';
});
pbImgClear.addEventListener('click', () => {
  _pbImageFile = null;
  pbImgPreview.style.display = 'none';
  pbInput.placeholder = 'Describe your pipeline or upload a diagram...';
});

function pbClearImage() {
  _pbImageFile = null;
  pbImgPreview.style.display = 'none';
  pbInput.placeholder = 'Describe your pipeline or upload a diagram...';
}

// ── PB @mention autocomplete for service types ──────────────────────────────
const pbMentionDrop = $('pbMentionDrop');
let _pbMentionActive = false;
let _pbMentionSelIdx = -1;

function _pbGetMentionQuery() {
  const val = pbInput.value;
  const caret = pbInput.selectionStart;
  const before = val.slice(0, caret);
  const at = before.lastIndexOf('@');
  if (at === -1) return null;
  const query = before.slice(at + 1);
  if (/\s/.test(query)) return null;
  return { query, atPos: at };
}

function _pbShowMentionDrop(items, atPos) {
  _pbMentionActive = true;
  _pbMentionSelIdx = -1;
  pbMentionDrop.innerHTML =
    `<div class="pb-mention-hint">AWS Services — ↑↓ navigate · Enter select · Esc dismiss</div>`;
  items.forEach(t => {
    const el = document.createElement('div');
    el.className = 'pb-mention-item';
    el.innerHTML =
      `<span class="pb-mention-ico">${SVC_ICONS[t] || '☁️'}</span>` +
      `<span class="pb-mention-name">${t}</span>` +
      `<span class="pb-mention-badge">${ABBREV[t] || t}</span>`;
    el.addEventListener('mousedown', e => {
      e.preventDefault();
      _pbInsertMention(t, atPos);
    });
    pbMentionDrop.appendChild(el);
  });
  // Position fixed dropdown above the textarea
  const rect = pbInput.getBoundingClientRect();
  pbMentionDrop.style.left = rect.left + 'px';
  pbMentionDrop.style.width = rect.width + 'px';
  pbMentionDrop.style.display = 'block';
  // Measure dropdown height, then position above textarea
  const dropH = pbMentionDrop.offsetHeight;
  pbMentionDrop.style.top = (rect.top - dropH - 6) + 'px';
}

function _pbHideMentionDrop() {
  _pbMentionActive = false;
  _pbMentionSelIdx = -1;
  pbMentionDrop.style.display = 'none';
}

function _pbInsertMention(type, atPos) {
  const val = pbInput.value;
  const caret = pbInput.selectionStart;
  const token = `@${type}`;
  pbInput.value = val.slice(0, atPos) + token + ' ' + val.slice(caret);
  const newPos = atPos + token.length + 1;
  pbInput.setSelectionRange(newPos, newPos);
  pbInput.focus();
  _pbHideMentionDrop();
}

pbInput.addEventListener('input', () => {
  const r = _pbGetMentionQuery();
  if (!r) { _pbHideMentionDrop(); return; }
  const q = r.query.toLowerCase();
  const matches = ALL_SVC_TYPES.filter(t =>
    t.includes(q) || (ABBREV[t] || '').toLowerCase().includes(q)
  );
  if (!matches.length) { _pbHideMentionDrop(); return; }
  _pbShowMentionDrop(matches, r.atPos);
});

let _pbMentionJustInserted = false;

pbInput.addEventListener('keydown', e => {
  if (!_pbMentionActive) return;
  const items = pbMentionDrop.querySelectorAll('.pb-mention-item');
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    _pbMentionSelIdx = Math.min(_pbMentionSelIdx + 1, items.length - 1);
    items.forEach((el, i) => el.classList.toggle('active', i === _pbMentionSelIdx));
    if (items[_pbMentionSelIdx]) items[_pbMentionSelIdx].scrollIntoView({ block: 'nearest' });
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    _pbMentionSelIdx = Math.max(_pbMentionSelIdx - 1, 0);
    items.forEach((el, i) => el.classList.toggle('active', i === _pbMentionSelIdx));
    if (items[_pbMentionSelIdx]) items[_pbMentionSelIdx].scrollIntoView({ block: 'nearest' });
  } else if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    if (_pbMentionSelIdx >= 0) {
      const r = _pbGetMentionQuery();
      if (r) {
        const q = r.query.toLowerCase();
        const matches = ALL_SVC_TYPES.filter(t =>
          t.includes(q) || (ABBREV[t] || '').toLowerCase().includes(q)
        );
        if (matches[_pbMentionSelIdx]) _pbInsertMention(matches[_pbMentionSelIdx], r.atPos);
      }
      _pbMentionJustInserted = true;
    } else {
      _pbHideMentionDrop();
      pbSendMessage();
    }
    _pbHideMentionDrop();
  } else if (e.key === 'Escape') {
    e.preventDefault();
    _pbHideMentionDrop();
  }
});

pbInput.addEventListener('blur', () => {
  setTimeout(_pbHideMentionDrop, 150);
});

// ── "create @service" command handler ────────────────────────────────────────
function _pbHandleCreateCommand(msg) {
  // Match patterns: "create @type", "create @type name", "add @type", etc.
  const m = msg.match(/^(?:create|add)\s+@(\S+)(?:\s+(\S+))?\s*$/i);
  if (!m) return false;
  const type = m[1].toLowerCase();
  const customName = m[2] || null;

  if (!ALL_SVC_TYPES.includes(type)) {
    pbAddMsg('agent',
      `<span style="color:var(--red)">Unknown service type: <b>${escHtml(type)}</b></span><br>` +
      `<span style="color:var(--muted)">Available: ${ALL_SVC_TYPES.join(', ')}</span>`);
    dcAddMsg('agent', `<span style="color:var(--red)">Unknown service type: ${escHtml(type)}</span>`);
    return true;
  }

  // Switch to architect mode if not already
  if (!_archMode) {
    // If a pipeline is already rendered, load it into the architect canvas first
    if (_lastRenderedServices && _lastRenderedServices.length) {
      loadDesignToArchitect(
        _lastRenderedServices,
        _lastRenderedIntegrations || [],
        _lastRenderedPipelineName
      );
      editPipelineBtn.style.display = 'none';
    } else {
      setArchMode(true);
      buildPalette();
    }
  }

  // Compute placement — stagger nodes in a grid so they don't overlap
  const existingCount = archNodes.length;
  const col = existingCount % 4;
  const row = Math.floor(existingCount / 4);
  const spacingX = 260, spacingY = 100;
  const startX = 60, startY = 40;

  // Add node directly to architect canvas coordinates
  const id = 'n' + archNextId++;
  const name = customName || nextNodeName(type);
  archNodes.push({ id, name, type, x: startX + col * spacingX, y: startY + row * spacingY });
  archRender();
  $('archRunBtn').disabled = archNodes.length === 0;

  // Update architect empty state
  archEmpty.style.display = archNodes.length === 0 ? 'flex' : 'none';

  // Build confirmation message
  const icon = SVC_ICONS[type] || '☁️';
  const confirmHtml =
    `<div style="display:flex;align-items:center;gap:10px;margin-bottom:6px">` +
      `<span style="font-size:20px">${icon}</span>` +
      `<div><b style="color:var(--green)">Service created</b><br>` +
      `<span style="font-family:var(--mono);font-size:12px">${escHtml(name)}</span> ` +
      `<span style="color:var(--muted);font-size:11px">(${escHtml(type)})</span></div>` +
    `</div>` +
    `<span style="color:var(--muted);font-size:12px">Added to the Pipeline Architect canvas. ` +
    `Connect it to other services by dragging from output → input ports, or create more services.</span>`;

  pbAddMsg('agent', confirmHtml);
  dcAddMsg('agent', `${icon} Created <b>${escHtml(name)}</b> (${escHtml(type)}) on the Architect canvas.`);

  return true;
}

function pbAddMsg(role, html) {
  if (pbEmpty) pbEmpty.style.display = 'none';
  const div = document.createElement('div');
  div.className = `pb-msg ${role}`;
  div.innerHTML = html;
  pbChat.appendChild(div);
  pbChat.scrollTop = pbChat.scrollHeight;
  return div;
}

function pbShowThinking() {
  const div = document.createElement('div');
  div.className = 'pb-thinking';
  div.id = 'pbThinking';
  div.innerHTML = 'Designing pipeline <div class="dots"><span></span><span></span><span></span></div>';
  pbChat.appendChild(div);
  pbChat.scrollTop = pbChat.scrollHeight;
}
function pbHideThinking() {
  const el = document.getElementById('pbThinking');
  if (el) el.remove();
}

function pbUseExample(el) {
  pbInput.value = el.textContent.trim();
  pbInput.focus();
}

async function pbSendMessage() {
  const msg = pbInput.value.trim();
  const hasImage = !!_pbImageFile;
  if (!msg && !hasImage) return;
  if (_pbBusy) return;

  // Intercept "create @service" commands — handle locally, no backend call
  if (!hasImage && /^(?:create|add)\s+@/i.test(msg)) {
    pbInput.value = '';
    pbAddMsg('user', escHtml(msg));
    dcAddMsg('user', escHtml(msg));
    _pbHandleCreateCommand(msg);
    return;
  }

  pbInput.value = '';
  _pbBusy = true;
  pbSend.disabled = true;
  pbImgBtn.disabled = true;
  pbStatus.textContent = hasImage ? 'Analyzing diagram...' : 'Designing...';
  dcStatus.textContent = hasImage ? 'Analyzing diagram...' : 'Designing...';

  // Show user message in both UIs
  let userHtml = hasImage
    ? `<span style="color:var(--blue)">\uD83D\uDDBC ${escHtml(_pbImageFile.name)}</span>`
    : '';
  if (msg) userHtml += (userHtml ? '<br>' : '') + escHtml(msg);
  pbAddMsg('user', userHtml);
  dcAddMsg('user', msg ? escHtml(msg) : (hasImage ? '[Uploaded diagram]' : ''));
  pbShowThinking();

  try {
    let r, d;

    if (hasImage) {
      // Image path — multipart form (stays on its own endpoint)
      const form = new FormData();
      form.append('image', _pbImageFile);
      form.append('message', msg);
      if (_dcChatId) form.append('chat_id', _dcChatId);
      r = await fetch('/pipeline-builder/chat-image', { method: 'POST', body: form });
    } else {
      // Text path — use the designer endpoint so state is shared
      r = await fetch('/pipeline-designer/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ message: msg, chat_id: _dcChatId }),
      });
    }

    pbHideThinking();
    d = await r.json();
    pbClearImage();

    if (!r.ok) {
      let errHtml = `<span style="color:var(--red)">${escHtml(d.detail || 'Generation failed')}</span>`;
      if (d.raw_yaml) {
        errHtml += `<div style="background:var(--bg);border:1px solid var(--border);border-radius:6px;padding:8px;margin-top:4px;font-family:var(--mono);font-size:11px;white-space:pre-wrap;max-height:200px;overflow-y:auto">${escHtml(d.raw_yaml)}</div>`;
      }
      pbAddMsg('agent', errHtml);
      dcAddMsg('agent', errHtml);
      pbStatus.textContent = 'Error';
      dcStatus.textContent = 'Error';
    } else {
      // Use shared handler to update diagram, state, and both UIs
      _handleDesignResponse(d);
      pbStatus.textContent = 'Ready';
      dcStatus.textContent = 'Design ready';

      const html = _buildAgentResponseHtml(d);
      pbAddMsg('agent', html);
      dcAddMsg('agent', html);

      // Show warnings from image analysis
      if (d.warnings && d.warnings.length) {
        let warnHtml = '<div style="margin-top:4px">';
        for (const w of d.warnings) {
          warnHtml += `<div style="background:rgba(212,145,31,.12);border:1px solid rgba(212,145,31,.35);border-radius:6px;padding:5px 10px;font-size:11px;color:#d4911f;margin:3px 0">${escHtml(w)}</div>`;
        }
        warnHtml += '</div>';
        pbAddMsg('agent', warnHtml);
      }
    }
  } catch(e) {
    pbHideThinking();
    pbClearImage();
    const errHtml = `<span style="color:var(--red)">Error: ${escHtml(e.message)}</span>`;
    pbAddMsg('agent', errHtml);
    dcAddMsg('agent', errHtml);
    pbStatus.textContent = 'Error';
    dcStatus.textContent = 'Error';
  }

  _pbBusy = false;
  pbSend.disabled = false;
  pbImgBtn.disabled = false;
}

pbSend.addEventListener('click', pbSendMessage);
pbInput.addEventListener('keydown', e => {
  if (_pbMentionActive || _pbMentionJustInserted) {
    _pbMentionJustInserted = false;
    return;
  }
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    pbSendMessage();
  }
});

// Build Terraform — delegate to the shared build function
pbBuildBtn.addEventListener('click', dcStartBuild);

