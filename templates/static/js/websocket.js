// ── WebSocket with auto-reconnect + HTTP polling fallback ─────────────────────
// Returns a handle with .close() that prevents reconnection/polling.
// When WebSocket retries are exhausted, falls back to polling /job/{id}/poll.
// onGiveUp() is only called if polling also fails (e.g. job not found).
function makeWs(url, onMessage, { onGiveUp, retries = 4 } = {}) {
  let attempt = 0, ws, abandoned = false;

  // Extract job_id from ws URL patterns:
  //   wss://host/ws/{job_id}
  //   wss://host/ws/deploy/{deploy_id}
  //   wss://host/ws/destroy/{destroy_id}
  const wsPath = url.split('/ws/').pop();  // "abc123" or "deploy/abc123"
  const jobId = wsPath.includes('/') ? wsPath.split('/').pop() : wsPath;

  function open() {
    ws = new WebSocket(url);
    ws.onmessage = onMessage;
    ws.onerror   = () => {}; // onclose handles it
    ws.onclose   = evt => {
      if (abandoned || evt.wasClean) return;       // clean server-side close → done
      if (attempt >= retries) {
        // WebSocket failed — fall back to HTTP polling
        log('WARNING', now(), 'ws', 'WebSocket unavailable — switching to HTTP polling…');
        startPolling();
        return;
      }
      attempt++;
      const delay = attempt * 1000;                // 1 s, 2 s, 3 s, 4 s
      log('WARNING', now(), 'ws',
          `Connection lost — reconnecting (${attempt}/${retries}) in ${delay/1000}s…`);
      setTimeout(open, delay);
    };
  }

  function startPolling() {
    if (abandoned) return;
    const poll = async () => {
      if (abandoned) return;
      try {
        const r = await fetch(`/job/${jobId}/poll`);
        if (!r.ok) {
          log('ERROR', now(), 'ws', 'Polling failed — job not found.');
          if (onGiveUp) onGiveUp();
          return;
        }
        const d = await r.json();
        // Replay all queued messages through the same onMessage handler
        for (const msg of (d.messages || [])) {
          if (msg.type === 'ping') continue; // skip keepalives
          onMessage({ data: JSON.stringify(msg) });
        }
        if (!d.done) {
          setTimeout(poll, 2000); // poll every 2s
        }
      } catch (e) {
        if (abandoned) return;
        log('WARNING', now(), 'ws', 'Poll error — retrying…');
        setTimeout(poll, 3000);
      }
    };
    poll();
  }

  open();
  return { close(){ abandoned=true; try{ ws.close() }catch(_){} } };
}

// ── Compatibility shim for div-based "buttons" (tf-row items) ────────────────
// Makes .disabled and .textContent work on div.tf-row elements
// so existing JS (deploy.js, core.js, etc.) doesn't need changes.
function _shimTfRow(el) {
  if (!el || !el.classList.contains('tf-row')) return;
  const label = el.querySelector('.admin-row-label');
  const origText = label ? label.textContent : '';
  Object.defineProperty(el, 'disabled', {
    get() { return el.classList.contains('disabled'); },
    set(v) {
      if (v) { el.classList.add('disabled'); el.classList.remove('enabled'); }
      else   { el.classList.remove('disabled'); el.classList.add('enabled'); }
    },
    configurable: true,
  });
  // .textContent setter updates only the label span, not the icon.
  // Transient states (e.g. "Running plan…", "Deploying…") update the label.
  // Reset values (with emoji prefixes) restore the original label text.
  Object.defineProperty(el, 'textContent', {
    get() { return label ? label.textContent : ''; },
    set(v) {
      if (!label) return;
      // If the value starts with an emoji or matches the old button pattern, restore original
      if (/^[\u{1F4CB}\u{1F680}\u2705\u274C\u23F3\u{1F4E1}\u{1F5D1}\u{1F4E5}\u{1FA84}\u00a0\u2718\u2716✕📋🚀✅📡🗑📥\s]/u.test(v)) {
        label.textContent = origText;
      } else {
        label.textContent = v || origText;
      }
    },
    configurable: true,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// ── DEPLOY TO AWS (plan + apply — all output goes to main console) ────────────
// ══════════════════════════════════════════════════════════════════════════════

const planBtn       = $('planBtn');
const applyBtn      = $('applyBtn');
const dlArtifactsBtn = $('dlArtifactsBtn');
// Back-compat aliases so existing code referencing dlPlanBtn still works
const dlPlanBtn = dlArtifactsBtn;

// Apply shim to all tf-row elements so .disabled/.textContent work
[planBtn, applyBtn, dlArtifactsBtn,
 $('destroyBtn'), $('monitorBtn'), $('cancelBtn')
].forEach(_shimTfRow);

let _deployJobId  = null;
let _deployWs     = null;
let _cachedPlanText = '';
let _pipelineName = '';

