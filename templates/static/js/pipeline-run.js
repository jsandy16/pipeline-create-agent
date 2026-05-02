// ── PIPELINE RUN PREVIEW (LOG AGGREGATOR) ─────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

// ── Console tab switching ──────────────────────────────────────────────────
let _activeTab = 'build';

tabBuild.addEventListener('click', () => switchConsoleTab('build'));
tabRun.addEventListener('click', () => switchConsoleTab('run'));
tabConfig.addEventListener('click', () => switchConsoleTab('config'));

function switchConsoleTab(tab) {
  _activeTab = tab;
  tabBuild.classList.toggle('active', tab === 'build');
  tabRun.classList.toggle('active', tab === 'run');
  tabConfig.classList.toggle('active', tab === 'config');
  consoleEl.style.display = tab === 'build' ? '' : 'none';
  runConsole.style.display = tab === 'run' ? '' : 'none';
  cfgChat.classList.toggle('active', tab === 'config');
  runFilterBar.classList.toggle('show', tab === 'run' && runFilterBar.children.length > 0);
}

// ── Monitor button handler ─────────────────────────────────────────────────
monitorBtn.addEventListener('click', async () => {
  if (monitorBtn.disabled) return;

  // If already monitoring, stop
  if (activePreviewId) {
    await stopRunPreview();
    return;
  }

  const jobId = monitorBtn._monitorJobId;
  const pipeName = monitorBtn._monitorPipelineName;
  if (!jobId && !pipeName) return;

  monitorBtn.disabled = true;
  monitorBtn.textContent = '⏳\u00a0 Starting monitor…';

  try {
    // Use job_id route for current-session deploys, name route for historical
    const url = jobId
      ? `/pipeline/run-preview/${jobId}/start`
      : `/pipeline/run-preview/by-name/${encodeURIComponent(pipeName)}/start`;
    const resp = await fetch(url, { method: 'POST' });
    const data = await resp.json();

    if (!resp.ok) {
      log('WARNING', now(), 'monitor', data.detail || 'Failed to start monitoring');
      resetMonitorBtn();
      return;
    }

    activePreviewId = data.preview_id;

    // Build filter chips for monitored services (CW Logs + CloudTrail)
    const allMonitored = [...(data.monitored || []), ...(data.cloudtrail_monitored || [])];
    buildRunFilters(allMonitored);

    // Log init info
    const cwCount = (data.monitored||[]).length;
    const ctCount = (data.cloudtrail_monitored||[]).length;
    const parts = [];
    if (cwCount) parts.push(`${cwCount} via CloudWatch Logs`);
    if (ctCount) parts.push(`${ctCount} via CloudTrail`);
    runLog('INFO', now(), 'monitor', `Monitoring ${parts.join(' + ')}…`);
    if (ctCount > 0) {
      runLog('INFO', now(), 'monitor',
        `CloudTrail sources (5-15 min delay): ${(data.cloudtrail_monitored||[]).map(s=>s.service_name).join(', ')}`);
    }
    if (data.services_without_logs && data.services_without_logs.length > 0) {
      runLog('INFO', now(), 'monitor',
        `No logs for: ${data.services_without_logs.join(', ')} (governance/metadata-only services)`);
    }

    // Show auto-fix toggle if inspector is available
    if (data.has_inspector) {
      autofixToggle.style.display = '';
      autofixCheck.checked = false;
    }

    // Switch to run tab
    switchConsoleTab('run');

    // Update button to "stop" mode
    monitorBtn.disabled = false;
    monitorBtn.classList.remove('enabled');
    monitorBtn.classList.add('active');
    monitorBtn.textContent = '⏹\u00a0 Stop Monitoring';

    // Start live dot
    runDot.classList.add('live');

    // Connect WebSocket
    connectPreviewWs(activePreviewId);

  } catch (err) {
    log('ERROR', now(), 'monitor', `Failed to start monitoring: ${err.message}`);
    resetMonitorBtn();
  }
});

function resetMonitorBtn() {
  monitorBtn.classList.remove('active');
  if (monitorBtn._monitorJobId || monitorBtn._monitorPipelineName) {
    monitorBtn.disabled = false;
    monitorBtn.classList.add('enabled');
  } else {
    monitorBtn.disabled = true;
    monitorBtn.classList.remove('enabled');
  }
  monitorBtn.textContent = '📡\u00a0 Monitor Pipeline Run';
  activePreviewId = null;
  runDot.classList.remove('live');
  autofixToggle.style.display = 'none';
  autofixCheck.checked = false;
}

async function stopRunPreview() {
  if (previewWs) {
    try { previewWs.close(); } catch (_) {}
    previewWs = null;
  }
  if (activePreviewId) {
    try {
      await fetch(`/pipeline/run-preview/${activePreviewId}/stop`, { method: 'DELETE' });
    } catch (_) {}
  }
  runLog('INFO', now(), 'monitor', 'Monitoring stopped.');
  resetMonitorBtn();
}

// ── Run log rendering ──────────────────────────────────────────────────────
function runLog(level, time, source, msg, svcType) {
  const empty = runConsole.querySelector('.con-empty');
  if (empty) empty.remove();

  const ln = document.createElement('div');
  ln.className = 'log-line ' + level;
  if (source && source !== 'monitor') {
    ln.dataset.svc = source;
  }

  const mk = (c, t) => { const s = document.createElement('span'); s.className = c; s.textContent = t; return s; };

  ln.append(mk('lt', time));
  ln.append(mk('ll', level));

  // Service badge for non-system messages
  if (source && source !== 'monitor' && svcType) {
    const badge = document.createElement('span');
    badge.className = 'run-svc-badge';
    badge.style.background = (catColor(svcType) || '#7d8590') + '22';
    badge.style.color = catColor(svcType) || '#7d8590';
    badge.textContent = `${abbrev(svcType)}:${source}`;
    ln.append(badge);
  } else {
    ln.append(mk('lg', '[' + source + ']'));
  }

  ln.append(mk('lm', msg));
  runConsole.appendChild(ln);
  runConsole.scrollTop = runConsole.scrollHeight;

  // Update count badge
  if (source !== 'monitor') {
    runLogCount++;
    runCount.textContent = runLogCount > 999 ? '999+' : runLogCount;
    runCount.classList.add('show');
  }

  // Apply current filters
  if (ln.dataset.svc && _runFilters[ln.dataset.svc] === false) {
    ln.style.display = 'none';
  }
}

// ── WebSocket for run preview ──────────────────────────────────────────────
function connectPreviewWs(previewId) {
  const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const ws = new WebSocket(`${proto}//${location.host}/ws/pipeline-run/${previewId}`);
  previewWs = ws;

  ws.onmessage = (evt) => {
    const m = JSON.parse(evt.data);

    if (m.type === 'run_log') {
      runLog(m.level, m.time, m.service_name, m.message, m.service_type);
    }

    if (m.type === 'run_log_status') {
      if (m.status === 'polling') {
        runLog('INFO', now(), 'monitor', m.message);
      } else if (m.status === 'group_found') {
        runLog('INFO', now(), 'monitor', m.message);
      } else if (m.status === 'error') {
        runLog('ERROR', now(), 'monitor', m.message);
      } else if (m.status === 'stopped') {
        runLog('INFO', now(), 'monitor', m.message);
        resetMonitorBtn();
      }
    }

    if (m.type === 'inspector_event') {
      renderInspectorEvent(m);
    }
  };

  ws.onclose = () => {
    previewWs = null;
  };

  ws.onerror = () => {
    runLog('ERROR', now(), 'monitor', 'WebSocket connection error');
    resetMonitorBtn();
  };
}

// ── Service filter chips ───────────────────────────────────────────────────
function buildRunFilters(monitored) {
  runFilterBar.innerHTML = '';
  _runFilters = {};

  for (const svc of monitored) {
    _runFilters[svc.service_name] = true;

    const chip = document.createElement('div');
    chip.className = 'run-filter-chip';
    chip.dataset.svc = svc.service_name;

    const dot = document.createElement('span');
    dot.className = 'chip-dot';
    dot.style.background = catColor(svc.service_type) || '#7d8590';
    chip.appendChild(dot);

    const label = document.createElement('span');
    label.textContent = `${abbrev(svc.service_type)}:${svc.service_name}`;
    chip.appendChild(label);

    chip.addEventListener('click', () => {
      const on = !_runFilters[svc.service_name];
      _runFilters[svc.service_name] = on;
      chip.classList.toggle('off', !on);

      // Show/hide matching log lines
      runConsole.querySelectorAll(`.log-line[data-svc="${svc.service_name}"]`).forEach(el => {
        el.style.display = on ? '' : 'none';
      });
    });

    runFilterBar.appendChild(chip);
  }

  if (_activeTab === 'run') runFilterBar.classList.add('show');
}

// ── Auto-fix toggle handler ────────────────────────────────────────────────
autofixCheck.addEventListener('change', async () => {
  if (!activePreviewId) return;
  try {
    const resp = await fetch(`/pipeline/run-preview/${activePreviewId}/auto-fix`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({enabled: autofixCheck.checked}),
    });
    const data = await resp.json();
    if (!resp.ok) {
      runLog('WARNING', now(), 'monitor', data.detail || 'Failed to toggle auto-fix');
      autofixCheck.checked = false;
      return;
    }
    if (data.auto_fix_enabled) {
      runLog('INFO', now(), 'monitor', 'Auto-fix enabled — Inspector will diagnose and fix runtime errors automatically.');
    } else {
      runLog('INFO', now(), 'monitor', 'Auto-fix disabled.');
    }
  } catch (err) {
    runLog('ERROR', now(), 'monitor', `Toggle error: ${err.message}`);
    autofixCheck.checked = false;
  }
});

// ── Inspector event renderer ───────────────────────────────────────────────
function renderInspectorEvent(m) {
  const empty = runConsole.querySelector('.con-empty');
  if (empty) empty.remove();

  const ev = m.event || '';
  const ln = document.createElement('div');
  ln.className = 'inspector-line ' + ev.replace('inspector_', '');

  const badge = document.createElement('span');
  badge.className = 'inspector-badge';
  badge.textContent = 'INSPECTOR';
  ln.appendChild(badge);

  const content = document.createElement('div');
  content.style.flex = '1';

  const msg = document.createElement('div');
  msg.className = 'inspector-msg';

  if (ev === 'inspector_start') {
    msg.textContent = m.message || `Error detected in ${m.service_name} [${m.category}]`;
  } else if (ev === 'inspector_diagnosing') {
    msg.textContent = m.message || `Analyzing root cause…`;
  } else if (ev === 'inspector_diagnosis') {
    msg.innerHTML = `<strong>Diagnosis:</strong> ${escHtml(m.diagnosis || '')}`;
    if (m.fixable) {
      const detail = document.createElement('div');
      detail.className = 'inspector-detail';
      detail.textContent = `Fix: ${m.fix_description || ''}`;
      content.appendChild(msg);
      content.appendChild(detail);
      ln.appendChild(content);
      runConsole.appendChild(ln);
      runConsole.scrollTop = runConsole.scrollHeight;
      return;
    }
  } else if (ev === 'inspector_fixing') {
    msg.textContent = m.message || 'Applying fix…';
  } else if (ev === 'inspector_fixed') {
    msg.innerHTML = `<strong>Fixed:</strong> ${escHtml(m.message || '')}`;
    if (m.output) {
      const detail = document.createElement('div');
      detail.className = 'inspector-detail';
      detail.textContent = m.output.substring(0, 300);
      content.appendChild(msg);
      content.appendChild(detail);
      ln.appendChild(content);
      runConsole.appendChild(ln);
      runConsole.scrollTop = runConsole.scrollHeight;
      return;
    }
  } else if (ev === 'inspector_fix_failed') {
    msg.innerHTML = `<strong>Fix failed:</strong> ${escHtml(m.message || '')}`;
  } else if (ev === 'inspector_manual') {
    msg.innerHTML = `<strong>Manual action needed (${m.category}):</strong> ${escHtml(m.diagnosis || '')}`;
    if (m.manual_action) {
      const detail = document.createElement('div');
      detail.className = 'inspector-detail';
      detail.textContent = m.manual_action;
      content.appendChild(msg);
      content.appendChild(detail);
      ln.appendChild(content);
      runConsole.appendChild(ln);
      runConsole.scrollTop = runConsole.scrollHeight;
      return;
    }
  } else if (ev === 'inspector_retrigger') {
    msg.textContent = m.message || 'Re-triggering pipeline...';
  } else if (ev === 'inspector_retrigger_ok') {
    msg.innerHTML = `<strong>Pipeline re-triggered:</strong> ${escHtml(m.message || '')}`;
    if (m.output) {
      const detail = document.createElement('div');
      detail.className = 'inspector-detail';
      detail.textContent = m.output.substring(0, 500);
      content.appendChild(msg);
      content.appendChild(detail);
      ln.appendChild(content);
      runConsole.appendChild(ln);
      runConsole.scrollTop = runConsole.scrollHeight;
      return;
    }
  } else if (ev === 'inspector_retrigger_failed') {
    msg.innerHTML = `<strong>Re-trigger failed:</strong> ${escHtml(m.message || '')}`;
  } else if (ev === 'inspector_resolved') {
    msg.innerHTML = `<strong>Pipeline running successfully:</strong> ${escHtml(m.message || '')}`;
  } else if (ev === 'inspector_error_recurred') {
    msg.innerHTML = `<strong>Error recurred:</strong> ${escHtml(m.message || '')}`;
  } else if (ev === 'inspector_budget_exhausted') {
    msg.innerHTML = `<strong>Inspector limit reached:</strong> ${escHtml(m.message || '')}`;
  } else if (ev === 'inspector_error') {
    msg.textContent = m.message || 'Inspector error';
  } else {
    msg.textContent = m.message || JSON.stringify(m);
  }

  content.appendChild(msg);
  ln.appendChild(content);
  runConsole.appendChild(ln);
  runConsole.scrollTop = runConsole.scrollHeight;
}


