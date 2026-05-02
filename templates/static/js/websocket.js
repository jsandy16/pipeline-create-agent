// ── WebSocket with auto-reconnect + HTTP polling fallback ─────────────────────
// Returns a handle with .close() that prevents reconnection/polling.
// When WebSocket retries are exhausted, falls back to polling /job/{id}/poll.
// onGiveUp() is only called if polling also fails (e.g. job not found).
function makeWs(url, onMessage, { onGiveUp, retries = 4 } = {}) {
  let attempt = 0, ws, abandoned = false;

  // Extract job_id from ws URL: wss://host/ws/{job_id}
  const jobId = url.split('/ws/').pop();

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

// ══════════════════════════════════════════════════════════════════════════════
// ── DEPLOY TO AWS (plan + apply — all output goes to main console) ────────────
// ══════════════════════════════════════════════════════════════════════════════

const planBtn   = $('planBtn');
const applyBtn  = $('applyBtn');
const dlPlanBtn = $('dlPlanBtn');

let _deployJobId  = null;
let _deployWs     = null;
let _cachedPlanText = '';
let _pipelineName = '';

