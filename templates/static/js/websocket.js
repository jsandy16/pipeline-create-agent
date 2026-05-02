// ── WebSocket with auto-reconnect ─────────────────────────────────────────────
// Returns a handle with .close() that prevents reconnection.
// onGiveUp() is called when all retries are exhausted.
function makeWs(url, onMessage, { onGiveUp, retries = 4 } = {}) {
  let attempt = 0, ws, abandoned = false;
  function open() {
    ws = new WebSocket(url);
    ws.onmessage = onMessage;
    ws.onerror   = () => {}; // onclose handles it
    ws.onclose   = evt => {
      if (abandoned || evt.wasClean) return;       // clean server-side close → done
      if (attempt >= retries) { if (onGiveUp) onGiveUp(); return; }
      attempt++;
      const delay = attempt * 1000;                // 1 s, 2 s, 3 s, 4 s
      log('WARNING', now(), 'ws',
          `Connection lost — reconnecting (${attempt}/${retries}) in ${delay/1000}s…`);
      setTimeout(open, delay);
    };
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

