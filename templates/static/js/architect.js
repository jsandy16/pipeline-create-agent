// ── PIPELINE ARCHITECT CANVAS ─────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

// All known service types for the palette
const ALL_SVC_TYPES = [
  's3','lambda','sqs','dynamodb','cloudwatch','sns','eventbridge','glue','athena',
  'kinesis_streams','kinesis_firehose','kinesis_analytics','stepfunctions','ec2',
  'msk','dms','redshift','lake_formation','aurora','glue_databrew','emr',
  'glue_data_catalog','iam','emr_serverless','sagemaker','quicksight'
];

// ── Canvas state ──────────────────────────────────────────────────────────────
let archNodes  = [];  // [{id, name, type, x, y}]
let archEdges  = [];  // [{id, srcId, tgtId, event}]
let archSel    = null; // selected node/edge id
let archNextId = 1;

// ── Architect canvas pan/zoom ─────────────────────────────────────────────────
let _aPan = {x:40, y:40, scale:1};

// ── Interaction state ─────────────────────────────────────────────────────────
let _aDrag    = null;  // {nodeId, ox, oy} — node being dragged
let _aDrawing = null;  // {srcId, x0, y0} — edge being drawn
let _aPanDrag = null;  // {ox, oy} — canvas being panned

const archCanvas  = $('archCanvas');
const archEmpty   = $('archEmpty');
const archToolbar = $('archToolbar');

// ── Palette ────────────────────────────────────────────────────────────────────
function buildPalette(filter=''){
  const grid = $('palGrid');
  grid.innerHTML='';
  const q = filter.toLowerCase().trim();
  for(const t of ALL_SVC_TYPES){
    if(q && !t.includes(q) && !(ABBREV[t]||'').toLowerCase().includes(q)) continue;
    const tile = document.createElement('div');
    tile.className='pal-tile';
    tile.draggable=true;
    tile.dataset.svcType=t;
    tile.innerHTML=`<span class="pal-icon">${SVC_ICONS[t]||'☁️'}</span><span class="pal-name">${ABBREV[t]||t}</span>`;
    tile.title=t;
    tile.addEventListener('dragstart', e=>{
      e.dataTransfer.setData('svc-type', t);
      e.dataTransfer.effectAllowed='copy';
    });
    grid.appendChild(tile);
  }
}
$('palSearch').addEventListener('input', e=>buildPalette(e.target.value));

// ── Tab switching ──────────────────────────────────────────────────────────────
let _archMode = false;

function setArchMode(on){
  _archMode = on;
  $('tabUpload').classList.toggle('active', !on);
  $('tabArchitect').classList.toggle('active', on);
  $('uploadSection').style.display = on ? 'none' : '';
  $('archSection').classList.toggle('show', on);
  // Canvas visibility
  archCanvas.classList.toggle('active', on);
  archToolbar.classList.toggle('show', on);
  archEmpty.style.display = on ? (archNodes.length===0?'flex':'none') : 'none';
  // Hide other diagram layers when architect is active
  if(on){
    rawImg.style.display='none';
    diagramSvg.style.display='none';
    dgmEmpty.style.display='none';
    dgmLabel.textContent='Pipeline Architect';
    archRender();
  } else {
    // Restore dagre diagram if it has content
    if(diagramSvg.innerHTML.trim()){
      diagramSvg.style.display='block';
      rawImg.style.display='none';
      dgmLabel.textContent='Pipeline Architecture';
    } else if(objUrl){
      rawImg.src=objUrl; rawImg.style.display='block';
      dgmLabel.textContent='Input Diagram';
    } else {
      dgmLabel.textContent='Input Diagram';
    }
  }
}

$('tabUpload').addEventListener('click', ()=>setArchMode(false));
$('tabArchitect').addEventListener('click', ()=>{
  setArchMode(true);
  buildPalette();
});

// ── Canvas rendering ──────────────────────────────────────────────────────────
const ANW=200, ANH=66; // node width/height (same as dagre)

function svgA(tag, a={}){
  const el=document.createElementNS('http://www.w3.org/2000/svg',tag);
  for(const[k,v] of Object.entries(a)) el.setAttribute(k,v);
  return el;
}

function archRenderDefs(){
  let defs=archCanvas.querySelector('defs');
  if(defs) defs.remove();
  defs=svgA('defs');
  // Arrow marker for edges
  const mk=svgA('marker',{id:'a-arr',markerWidth:'10',markerHeight:'7',
    refX:'9',refY:'3.5',orient:'auto',markerUnits:'userSpaceOnUse'});
  mk.appendChild(svgA('path',{d:'M0,0 L10,3.5 L0,7 Z',fill:'#4a5568'}));
  defs.appendChild(mk);
  // Arrow marker for selected edges
  const mkS=svgA('marker',{id:'a-arr-sel',markerWidth:'10',markerHeight:'7',
    refX:'9',refY:'3.5',orient:'auto',markerUnits:'userSpaceOnUse'});
  mkS.appendChild(svgA('path',{d:'M0,0 L10,3.5 L0,7 Z',fill:'#7c5cfc'}));
  defs.appendChild(mkS);
  // Grid pattern
  const pat=svgA('pattern',{id:'a-grid',width:'40',height:'40',patternUnits:'userSpaceOnUse'});
  const c1=svgA('circle',{cx:'20',cy:'20',r:'1',fill:'#1c2333'});
  pat.appendChild(c1);
  defs.appendChild(pat);
  // Clip paths for each node
  for(const n of archNodes){
    const cp=svgA('clipPath',{id:'acp_'+n.id});
    cp.appendChild(svgA('rect',{width:ANW,height:ANH,rx:'10',ry:'10'}));
    defs.appendChild(cp);
  }
  archCanvas.insertBefore(defs, archCanvas.firstChild);
}

function archRender(){
  archCanvas.innerHTML='';
  archRenderDefs();

  // Root group for pan/zoom
  const root=svgA('g',{id:'_aroot'});

  // Grid background (large rect filled with pattern)
  root.appendChild(svgA('rect',{x:'-5000',y:'-5000',width:'10000',height:'10000',fill:'url(#a-grid)'}));

  // Edges group (below nodes)
  const eg=svgA('g',{id:'_aedges'});
  for(const edge of archEdges) eg.appendChild(buildArchEdge(edge));
  root.appendChild(eg);

  // Preview edge
  const prev=svgA('path',{id:'archPreview',d:'',stroke:'#7c5cfc','stroke-width':'1.5',
    'stroke-dasharray':'5 4',fill:'none','pointer-events':'none'});
  root.appendChild(prev);

  // Nodes group
  const ng=svgA('g',{id:'_anodes'});
  for(const node of archNodes) ng.appendChild(buildArchNode(node));
  root.appendChild(ng);

  archCanvas.appendChild(root);
  applyArchPan();

  // Empty state
  if(archEmpty) archEmpty.style.display = archNodes.length===0 ? 'flex' : 'none';
}

function applyArchPan(){
  const root=archCanvas.querySelector('#_aroot');
  if(root) root.setAttribute('transform',`translate(${_aPan.x.toFixed(1)},${_aPan.y.toFixed(1)}) scale(${_aPan.scale.toFixed(4)})`);
}

function buildArchNode(n){
  const cat=catColor(n.type), ab=abbrev(n.type);
  const isSel = archSel===n.id;
  const grp=svgA('g',{
    id:'an_'+n.id,
    class:'arch-node'+(isSel?' selected':''),
    transform:`translate(${n.x.toFixed(1)},${n.y.toFixed(1)})`,
    'data-nid':n.id
  });

  // Shadow
  grp.appendChild(svgA('rect',{x:'1',y:'4',width:ANW,height:ANH,rx:'10',ry:'10',fill:'rgba(0,0,0,.45)','pointer-events':'none'}));

  // Clipped bg
  const cg=svgA('g',{'clip-path':`url(#acp_${n.id})`});
  cg.appendChild(svgA('rect',{class:'an-bg',width:ANW,height:ANH,fill:'#131720'}));
  cg.appendChild(svgA('rect',{x:'0',y:'0',width:'5',height:ANH,fill:cat}));
  grp.appendChild(cg);

  // Border
  grp.appendChild(svgA('rect',{
    class:'an-border',width:ANW,height:ANH,rx:'10',ry:'10',fill:'none',
    stroke:isSel?'#7c5cfc':'#252d3d',
    'stroke-width':isSel?'2':'1'
  }));

  // Badge
  const BX=10,BY=9,BS=48, TX=BX+BS+12;
  grp.appendChild(svgA('rect',{x:BX,y:BY,width:BS,height:BS,rx:'8',ry:'8',fill:cat}));
  grp.appendChild(svgA('rect',{x:BX,y:BY,width:BS,height:BS/2,rx:'8',ry:'8',fill:'rgba(255,255,255,.1)','pointer-events':'none'}));
  grp.appendChild(svgA('rect',{x:BX,y:BY+BS/2,width:BS,height:BS/2,fill:cat,'pointer-events':'none'}));
  grp.appendChild(svgA('rect',{x:BX,y:BY,width:BS,height:BS,rx:'8',ry:'8',fill:'none',stroke:'rgba(255,255,255,.12)','stroke-width':'1','pointer-events':'none'}));

  const aLen=ab.length, aSize=aLen<=2?'18':aLen===3?'13.5':'11';
  const abEl=svgA('text',{x:BX+BS/2,y:BY+BS/2,'text-anchor':'middle','dominant-baseline':'central',
    'font-size':aSize,'font-weight':'700',fill:'rgba(255,255,255,.95)',
    'font-family':"'JetBrains Mono',monospace",'pointer-events':'none'});
  abEl.textContent=ab;
  grp.appendChild(abEl);

  // Separator
  grp.appendChild(svgA('line',{x1:TX-5,y1:'11',x2:TX-5,y2:ANH-11,stroke:'#1e2535','stroke-width':'1','pointer-events':'none'}));

  // Name
  const dispName=n.name.length>15?n.name.slice(0,14)+'…':n.name;
  const nmEl=svgA('text',{x:TX,y:'26','font-size':'11.5','font-weight':'600',fill:'#dde4ed',
    'dominant-baseline':'middle','pointer-events':'none'});
  nmEl.textContent=dispName;
  grp.appendChild(nmEl);

  // Type
  const tpEl=svgA('text',{x:TX,y:'45','font-size':'9',fill:'#4d5a70',
    'dominant-baseline':'middle','font-family':"'JetBrains Mono',monospace",'pointer-events':'none'});
  tpEl.textContent=n.type;
  grp.appendChild(tpEl);

  // Input port (left, middle)
  grp.appendChild(svgA('circle',{class:'arch-port arch-port-in',
    cx:'0',cy:String(ANH/2),r:'6','data-port':'in','data-nid':n.id}));

  // Output port (right, middle)
  grp.appendChild(svgA('circle',{class:'arch-port arch-port-out',
    cx:String(ANW),cy:String(ANH/2),r:'6','data-port':'out','data-nid':n.id}));

  return grp;
}

function buildArchEdge(edge){
  const src=archNodes.find(n=>n.id===edge.srcId);
  const tgt=archNodes.find(n=>n.id===edge.tgtId);
  if(!src||!tgt) return svgA('g',{});

  const isSel=archSel===edge.id;
  const d=archEdgePath(src, tgt);
  const mid=archEdgeMid(src,tgt);

  const g=svgA('g',{id:'ae_'+edge.id, class:'arch-edge'+(isSel?' selected':''), 'data-eid':edge.id});

  // Invisible wider hit area (for clicking)
  const hit=svgA('path',{d,class:'arch-edge-hit'});
  g.appendChild(hit);

  // Visual background line
  g.appendChild(svgA('path',{d,class:'arch-edge-bg',stroke:isSel?'#7c5cfc':'#1e2535','stroke-width':'2',fill:'none'}));
  // Animated dashed line
  g.appendChild(svgA('path',{d,class:'arch-edge-line edge-flow',
    stroke:isSel?'#7c5cfc':'#3a4558','stroke-width':'1.5','stroke-dasharray':'6 5',fill:'none',
    'marker-end':`url(#a-arr${isSel?'-sel':''})`}));

  // Event label at midpoint
  if(edge.event && edge.event!=='*'){
    const lbl=svgA('text',{x:mid.x,y:mid.y-8,class:'arch-edge-label'});
    lbl.textContent=edge.event.length>18?edge.event.slice(0,17)+'…':edge.event;
    g.appendChild(lbl);
  }
  return g;
}

function archEdgePath(src, tgt){
  const x1=src.x+ANW, y1=src.y+ANH/2;
  const x2=tgt.x,     y2=tgt.y+ANH/2;
  const cx=(x2-x1)/2;
  return `M${x1},${y1} C${x1+cx},${y1} ${x2-cx},${y2} ${x2},${y2}`;
}

function archEdgeMid(src, tgt){
  const x1=src.x+ANW, y1=src.y+ANH/2;
  const x2=tgt.x,     y2=tgt.y+ANH/2;
  return {x:(x1+x2)/2, y:(y1+y2)/2};
}

// ── Client → SVG coordinate conversion ────────────────────────────────────────
function clientToArch(cx, cy){
  const r=archCanvas.getBoundingClientRect();
  return {
    x:(cx-r.left-_aPan.x)/_aPan.scale,
    y:(cy-r.top -_aPan.y)/_aPan.scale
  };
}

// ── Node count per type (for auto-naming) ─────────────────────────────────────
function nextNodeName(type){
  let n=1;
  const existing=archNodes.filter(nd=>nd.type===type).map(nd=>{
    const m=nd.name.match(/_(\d+)$/);
    return m?parseInt(m[1]):0;
  });
  while(existing.includes(n)) n++;
  return type+'_'+n;
}

// ── Create node ───────────────────────────────────────────────────────────────
function archAddNode(type, cx, cy){
  const pt=clientToArch(cx, cy);
  const id='n'+archNextId++;
  archNodes.push({id, name:nextNodeName(type), type, x:pt.x-ANW/2, y:pt.y-ANH/2});
  archRender();
  $('archRunBtn').disabled = archNodes.length===0;
}

// ── Drag-and-drop from palette ─────────────────────────────────────────────────
archCanvas.addEventListener('dragover', e=>{e.preventDefault(); e.dataTransfer.dropEffect='copy';});
archCanvas.addEventListener('drop', e=>{
  e.preventDefault();
  const type=e.dataTransfer.getData('svc-type');
  if(type) archAddNode(type, e.clientX, e.clientY);
});

// ── Canvas mouse interactions ──────────────────────────────────────────────────
archCanvas.addEventListener('mousedown', e=>{
  if(e.button!==0) return;
  const tgt=e.target;

  // Output port → start drawing edge
  if(tgt.classList.contains('arch-port-out')){
    const nid=tgt.dataset.nid||tgt.closest('[data-nid]')?.dataset.nid;
    if(!nid) return;
    const node=archNodes.find(n=>n.id===nid);
    if(!node) return;
    const startX=node.x+ANW, startY=node.y+ANH/2;
    _aDrawing={srcId:nid, x0:startX, y0:startY};
    archCanvas.classList.add('drawing-edge');
    // Highlight the source node's output port so user knows drag started
    const srcGrp=archCanvas.querySelector('#an_'+nid);
    if(srcGrp) srcGrp.classList.add('connecting-src');
    // Show preview line
    const prev=archCanvas.querySelector('#archPreview');
    if(prev) prev.style.display='block';
    e.preventDefault(); e.stopPropagation(); return;
  }

  // Node → select + start drag (but not on ports)
  if(tgt.classList.contains('arch-port-in')) { e.preventDefault(); return; }
  const nodeGrp=tgt.closest('[data-nid]');
  if(nodeGrp){
    const nid=nodeGrp.dataset.nid;
    archSelect(nid);
    const pt=clientToArch(e.clientX, e.clientY);
    const node=archNodes.find(n=>n.id===nid);
    _aDrag={nodeId:nid, ox:pt.x-node.x, oy:pt.y-node.y};
    e.preventDefault(); return;
  }

  // Edge hit area → select edge
  const edgeGrp=tgt.closest('[data-eid]');
  if(edgeGrp){
    archSelect(edgeGrp.dataset.eid);
    e.preventDefault(); return;
  }

  // Canvas background → pan or deselect
  if(tgt===archCanvas || tgt.id==='_aroot' || (tgt.tagName==='rect' && tgt.getAttribute('fill')==='url(#a-grid)')){
    archSelect(null);
    _aPanDrag={ox:e.clientX-_aPan.x, oy:e.clientY-_aPan.y};
    e.preventDefault();
  }
});

document.addEventListener('mousemove', e=>{
  // Node drag
  if(_aDrag){
    const pt=clientToArch(e.clientX, e.clientY);
    const node=archNodes.find(n=>n.id===_aDrag.nodeId);
    if(node){ node.x=pt.x-_aDrag.ox; node.y=pt.y-_aDrag.oy; archRenderFast(); }
    return;
  }
  // Edge drawing
  if(_aDrawing){
    const pt=clientToArch(e.clientX, e.clientY);
    const x1=_aDrawing.x0, y1=_aDrawing.y0;
    const x2=pt.x, y2=pt.y;
    const cx=(x2-x1)/2;
    const d=`M${x1},${y1} C${x1+cx},${y1} ${x2-cx},${y2} ${x2},${y2}`;
    const prev=archCanvas.querySelector('#archPreview');
    if(prev) prev.setAttribute('d',d);
    return;
  }
  // Canvas pan
  if(_aPanDrag){
    _aPan.x=e.clientX-_aPanDrag.ox;
    _aPan.y=e.clientY-_aPanDrag.oy;
    applyArchPan();
  }
});

document.addEventListener('mouseup', e=>{
  if(e.button!==0) return;

  if(_aDrag){ _aDrag=null; return; }

  if(_aDrawing){
    const prev=archCanvas.querySelector('#archPreview');
    if(prev){ prev.setAttribute('d',''); prev.style.display='none'; }
    archCanvas.classList.remove('drawing-edge');

    // Accept mouseup on ANY part of a target node (not just the exact port pixel).
    // We walk up from the element under the cursor to find the nearest node group.
    const tgt=document.elementFromPoint(e.clientX, e.clientY);
    const nodeGrp=tgt&&(tgt.closest('[data-nid]'));
    const tgtNid=nodeGrp?.dataset.nid;

    // Clear source highlight regardless of outcome
    archCanvas.querySelectorAll('.connecting-src').forEach(el=>el.classList.remove('connecting-src'));

    if(tgtNid && tgtNid!==_aDrawing.srcId){
      // Don't create a duplicate edge for the same source→target pair
      const alreadyExists=archEdges.some(ed=>ed.srcId===_aDrawing.srcId&&ed.tgtId===tgtNid);
      if(!alreadyExists){
        const drawing=_aDrawing;
        _aDrawing=null;
        showEdgeLabelPopup(drawing.srcId, tgtNid, e.clientX, e.clientY);
      } else {
        _aDrawing=null;
      }
    } else {
      _aDrawing=null;
    }
    return;
  }

  if(_aPanDrag){ _aPanDrag=null; return; }
});

// ── Double-click to rename ─────────────────────────────────────────────────────
archCanvas.addEventListener('dblclick', e=>{
  const nodeGrp=e.target.closest('[data-nid]');
  if(!nodeGrp) return;
  const nid=nodeGrp.dataset.nid;
  const node=archNodes.find(n=>n.id===nid);
  if(!node) return;
  showRenamePopup(nid, node.name, e.clientX, e.clientY);
  e.preventDefault();
});

// ── Wheel zoom ─────────────────────────────────────────────────────────────────
archCanvas.addEventListener('wheel', e=>{
  e.preventDefault();
  const r=archCanvas.getBoundingClientRect();
  const mx=e.clientX-r.left, my=e.clientY-r.top;
  const d=e.deltaY<0?1.12:0.89;
  _aPan.x=mx+(_aPan.x-mx)*d;
  _aPan.y=my+(_aPan.y-my)*d;
  _aPan.scale=Math.max(0.08,Math.min(12,_aPan.scale*d));
  applyArchPan();
},{passive:false});

// ── Toolbar buttons ────────────────────────────────────────────────────────────
$('archZoomIn') .addEventListener('click',()=>{ _aPan.scale=Math.min(12,_aPan.scale*1.25); applyArchPan(); });
$('archZoomOut').addEventListener('click',()=>{ _aPan.scale=Math.max(0.08,_aPan.scale*0.8); applyArchPan(); });
$('archFit')    .addEventListener('click',()=>{
  if(archNodes.length===0) return;
  const w=archCanvas.clientWidth, h=archCanvas.clientHeight;
  const xs=archNodes.map(n=>n.x), ys=archNodes.map(n=>n.y);
  const x0=Math.min(...xs), y0=Math.min(...ys);
  const x1=Math.max(...xs)+ANW, y1=Math.max(...ys)+ANH;
  const gW=x1-x0+80, gH=y1-y0+80;
  const s=Math.min(w/gW, h/gH)*0.9;
  _aPan={x:(w-gW*s)/2-x0*s+40*s, y:(h-gH*s)/2-y0*s+40*s, scale:s};
  applyArchPan();
});
$('archDeleteBtn').addEventListener('click', archDeleteSelected);
$('archClearBtn') .addEventListener('click',()=>{
  if(archNodes.length===0) return;
  if(!confirm('Clear all nodes and connections?')) return;
  archNodes=[]; archEdges=[]; archSel=null; archRender();
  $('archRunBtn').disabled=true;
  $('archDeleteBtn').disabled=true;
});

// ── Delete key ─────────────────────────────────────────────────────────────────
document.addEventListener('keydown', e=>{
  if(!_archMode) return;
  if(e.key==='Delete'||e.key==='Backspace'){
    // Don't interfere with text inputs
    if(document.activeElement.tagName==='INPUT'||document.activeElement.tagName==='TEXTAREA') return;
    archDeleteSelected();
  }
});

function archDeleteSelected(){
  if(!archSel) return;
  // Is it a node?
  if(archNodes.some(n=>n.id===archSel)){
    archEdges=archEdges.filter(e=>e.srcId!==archSel && e.tgtId!==archSel);
    archNodes=archNodes.filter(n=>n.id!==archSel);
  } else {
    archEdges=archEdges.filter(e=>e.id!==archSel);
  }
  archSel=null;
  archRender();
  $('archDeleteBtn').disabled=!archSel;
  $('archRunBtn').disabled=archNodes.length===0;
}

function archSelect(id){
  archSel=id;
  $('archDeleteBtn').disabled=!id;
  archRender();
}

// ── Fast re-render (just update node transforms + edge paths, no full rebuild) ──
function archRenderFast(){
  for(const n of archNodes){
    const g=archCanvas.querySelector('#an_'+n.id);
    if(g) g.setAttribute('transform',`translate(${n.x.toFixed(1)},${n.y.toFixed(1)})`);
  }
  // Rebuild all edge paths
  for(const edge of archEdges){
    const g=archCanvas.querySelector('#ae_'+edge.id);
    if(!g) continue;
    const src=archNodes.find(n=>n.id===edge.srcId);
    const tgt=archNodes.find(n=>n.id===edge.tgtId);
    if(!src||!tgt) continue;
    const d=archEdgePath(src,tgt);
    g.querySelectorAll('path').forEach(p=>p.setAttribute('d',d));
    // Update label position
    const lbl=g.querySelector('text');
    if(lbl){ const m=archEdgeMid(src,tgt); lbl.setAttribute('x',m.x); lbl.setAttribute('y',m.y-8); }
  }
}

// ── Edge label popup ──────────────────────────────────────────────────────────
const edgeLabelPopup = $('edgeLabelPopup');
const edgeLabelInput = $('edgeLabelInput');
let _pendingEdge = null; // {srcId, tgtId}

function showEdgeLabelPopup(srcId, tgtId, px, py){
  _pendingEdge={srcId, tgtId};
  edgeLabelInput.value='*';
  edgeLabelPopup.style.left=px+'px';
  edgeLabelPopup.style.top=(py-10)+'px';
  edgeLabelPopup.classList.add('show');
  setTimeout(()=>{ edgeLabelInput.focus(); edgeLabelInput.select(); }, 50);
}

function commitEdge(){
  if(!_pendingEdge) return;
  const ev=edgeLabelInput.value.trim()||'*';
  const id='e'+archNextId++;
  archEdges.push({id, srcId:_pendingEdge.srcId, tgtId:_pendingEdge.tgtId, event:ev});
  _pendingEdge=null;
  edgeLabelPopup.classList.remove('show');
  archRender();
}

function cancelEdge(){
  _pendingEdge=null;
  edgeLabelPopup.classList.remove('show');
}

$('edgeLabelOk').addEventListener('click', commitEdge);
$('edgeLabelCancel').addEventListener('click', cancelEdge);
edgeLabelInput.addEventListener('keydown', e=>{
  if(e.key==='Enter') commitEdge();
  if(e.key==='Escape') cancelEdge();
});

// ── Rename popup ──────────────────────────────────────────────────────────────
const renamePopup    = $('renamePopup');
const renameInput    = $('renameInput');
let _renameNodeId    = null;

function showRenamePopup(nid, currentName, px, py){
  _renameNodeId=nid;
  renameInput.value=currentName;
  renamePopup.style.left=px+'px';
  renamePopup.style.top=(py-10)+'px';
  renamePopup.classList.add('show');
  setTimeout(()=>{ renameInput.focus(); renameInput.select(); }, 50);
}

function commitRename(){
  if(!_renameNodeId) return;
  const raw=renameInput.value.trim();
  // Sanitize: only letters, digits, underscores; must start with letter
  const name=raw.replace(/[^a-zA-Z0-9_]/g,'_').replace(/^[^a-zA-Z]+/,'n');
  if(!name){ renamePopup.classList.remove('show'); return; }
  // Check uniqueness
  if(archNodes.some(n=>n.id!==_renameNodeId && n.name===name)){
    renameInput.style.borderColor='var(--red)';
    renameInput.title='Name already in use';
    return;
  }
  const node=archNodes.find(n=>n.id===_renameNodeId);
  if(node) node.name=name;
  _renameNodeId=null;
  renamePopup.classList.remove('show');
  renameInput.style.borderColor='';
  archRender();
}

function cancelRename(){
  _renameNodeId=null;
  renamePopup.classList.remove('show');
  renameInput.style.borderColor='';
}

$('renameOkBtn').addEventListener('click', commitRename);
$('renameCancelBtn').addEventListener('click', cancelRename);
renameInput.addEventListener('keydown', e=>{
  if(e.key==='Enter') commitRename();
  if(e.key==='Escape') cancelRename();
});

// ── Canvas → PipelineRequest ──────────────────────────────────────────────────
function sanitizePipeName(s){
  let n=s.trim().replace(/[^a-zA-Z0-9_]/g,'_');
  if(!/^[a-zA-Z]/.test(n)) n='p'+n;
  return n.slice(0,64)||'my_pipeline';
}

async function archGenerate(){
  if(archNodes.length===0){ alert('Add at least one service to the canvas.'); return; }
  if(!validateProjectFields()) return;

  // Validate all node names
  for(const n of archNodes){
    if(!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(n.name)){
      alert(`Invalid service name "${n.name}". Names must start with a letter and contain only letters, digits, underscores. Double-click the node to rename it.`);
      return;
    }
  }

  const rawName=$('archPipeName').value.trim()||'my_pipeline';
  const pipeName=sanitizePipeName(rawName);
  const hint=$('archHint').value.trim();

  const body={
    pipeline_name: pipeName,
    business_unit: getBusinessUnit() || getProject(),
    cost_center: getCostCenter(),
    services: archNodes.map(n=>({name:n.name, type:n.type, config:{}})),
    integrations: archEdges.map(e=>{
      const srcNode=archNodes.find(n=>n.id===e.srcId);
      const tgtNode=archNodes.find(n=>n.id===e.tgtId);
      return {source:srcNode.name, target:tgtNode.name, event:e.event||'*'};
    }),
  };
  if(hint) body.hint=hint;

  // Use the same run pipeline UI flow
  consoleEl.innerHTML='<div class="con-empty">Starting…</div>';
  resetProg(); resetServices();
  resultCard.className='result-card';
  setBusy(true); setStatus('running','Building pipeline…');
  $('archRunBtn').disabled=true;
  $('archRunBtn').textContent='Running…';

  // Reset deploy state
  _deployJobId=null; _cachedPlanText=''; _pipelineName='';
  if(_deployWs){try{_deployWs.close()}catch(_){} _deployWs=null;}
  planBtn.disabled=true; planBtn.classList.remove('enabled'); planBtn.textContent='📋\u00a0 Deploy to AWS: Plan';
  applyBtn.disabled=true; applyBtn.classList.remove('enabled'); applyBtn.textContent='🚀\u00a0 Deploy to AWS: Deploy';
  dlPlanBtn.disabled=true; dlPlanBtn.classList.remove('enabled');
  matrixBtn.disabled=true; matrixBtn.classList.remove('enabled');
  _destroyJobId=null; destroyBtn.disabled=true; destroyBtn.classList.remove('enabled');
  destroyBtn.textContent='🗑️\u00a0 Destroy Resources';
  stopRunPreview(); monitorBtn._monitorJobId=null; monitorBtn._monitorPipelineName=null; resetMonitorBtn();

  let jobId;
  try{
    const r=await fetch('/run-from-diagram',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify(body)
    });
    const d=await r.json();
    if(!r.ok) throw new Error(d.detail||'Failed to start pipeline');
    jobId=d.job_id;
  }catch(err){
    log('ERROR',now(),'app','Failed to start: '+err.message);
    setStatus('fail','Failed');
    setBusy(false);
    $('archRunBtn').disabled=false;
    $('archRunBtn').textContent='Generate Terraform';
    return;
  }

  activeJobId=jobId; setStatus('running','Pipeline starting…');

  function onArchMsg({data}){
    const m=JSON.parse(data);
    if(m.type==='log') log(m.level,m.time,m.logger,m.message);
    if(m.type==='progress'){ setProg(m.pct,m.stage,m.pct>=100?'done':''); setStatus('running',m.stage||(m.pct+'%')); }
    if(m.type==='services_init'){
      initServices(m.services);
      // Switch architect canvas to dagre output diagram
      setArchMode(false);
      buildDagram(m.services, m.integrations||[]);
      cfgPopulateServices(m.services);
    }
    if(m.type==='service_update') updService(m.name,m.status);
    if(m.type==='done'){
      activeJobId=null; activeWs=null;
      cancelBtn.disabled=false; cancelBtn.textContent='✕  Cancel';
      setBusy(false);
      $('archRunBtn').disabled=false;
      $('archRunBtn').textContent='Generate Terraform';
      if(m.cancelled){ setStatus('fail','Cancelled'); setProg(0,'Cancelled','fail'); log('WARNING',now(),'pipeline','⊘ Cancelled.'); }
      else if(m.exit_code===0){ setStatus('ok','Completed successfully'); setProg(100,'Complete','done'); log('SUCCESS',now(),'pipeline','✓ Terraform written successfully.'); }
      else{ setStatus('fail','Failed'); log('ERROR',now(),'pipeline','✗ Pipeline failed.'); }
      if(!m.cancelled) showResult(m.exit_code,m.result);
      if(!m.cancelled && m.exit_code===0){
        _deployJobId=jobId;
        _pipelineName=m.result?.pipeline_name||'';
        planBtn.disabled=false; planBtn.classList.add('enabled');
        matrixBtn.disabled=false; matrixBtn.classList.add('enabled');
        cfgLoadServiceConfigs(jobId);
        if (!tfOpen) { tfOpen=true; tfMenuRows.classList.add('open'); tfChevron.classList.add('open'); }
      }
    }
    if(m.type==='error'){ log('ERROR',now(),'app',m.message); setStatus('fail',m.message); setBusy(false); }
  }

  activeWs=makeWs(
    `${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/${jobId}`,
    onArchMsg,
    { onGiveUp(){ log('ERROR',now(),'ws','Connection lost — could not reconnect.'); setStatus('fail','Connection error'); setBusy(false); $('archRunBtn').disabled=false; $('archRunBtn').textContent='Generate Terraform'; } }
  );
}

$('archRunBtn').addEventListener('click', archGenerate);

// ── Load existing pipeline into Architect canvas for editing ────────────────
function loadDesignToArchitect(services, integrations, pipelineName) {
  // Clear existing canvas state
  archNodes = [];
  archEdges = [];
  archSel = null;
  archNextId = 1;

  // Use dagre layout to compute positions (same as buildDagram)
  const g = new dagre.graphlib.Graph({multigraph: false});
  g.setGraph({rankdir: 'LR', ranksep: 60, nodesep: 22, marginx: 48, marginy: 48});
  g.setDefaultEdgeLabel(() => ({}));
  for (const s of services) g.setNode(s.name, {width: ANW, height: ANH, type: s.type});
  for (const i of (integrations || [])) {
    if (g.hasNode(i.source) && g.hasNode(i.target))
      g.setEdge(i.source, i.target, {event: i.event || ''});
  }
  dagre.layout(g);

  // Create archNodes from dagre positions
  for (const n of g.nodes()) {
    const nd = g.node(n);
    const id = 'n' + archNextId++;
    archNodes.push({id, name: n, type: nd.type, x: nd.x - ANW / 2, y: nd.y - ANH / 2});
  }

  // Create archEdges by mapping source/target names back to node IDs
  const nameToId = {};
  for (const node of archNodes) nameToId[node.name] = node.id;
  let edgeId = 1;
  for (const i of (integrations || [])) {
    const srcId = nameToId[i.source];
    const tgtId = nameToId[i.target];
    if (srcId && tgtId) {
      archEdges.push({id: 'e' + edgeId++, srcId, tgtId, event: i.event || '*'});
    }
  }

  // Set pipeline name
  if (pipelineName) $('archPipeName').value = pipelineName;

  // Switch to architect mode and render
  setArchMode(true);
  buildPalette();
  $('archRunBtn').disabled = archNodes.length === 0;

  // Fit canvas to content
  if (archNodes.length > 0) {
    const xs = archNodes.map(n => n.x);
    const ys = archNodes.map(n => n.y);
    const minX = Math.min(...xs), maxX = Math.max(...xs) + ANW;
    const minY = Math.min(...ys), maxY = Math.max(...ys) + ANH;
    const gW = maxX - minX + 96, gH = maxY - minY + 96;
    const stage = $('dgmStage');
    const sW = stage.clientWidth || 800, sH = stage.clientHeight || 500;
    const scale = Math.min(sW / gW, sH / gH, 1.5);
    _aPan.scale = scale;
    _aPan.x = (sW - gW * scale) / 2 - minX * scale + 48 * scale;
    _aPan.y = (sH - gH * scale) / 2 - minY * scale + 48 * scale;
    applyArchPan();
  }
}

// Pipeline name validation feedback
$('archPipeName').addEventListener('input', e=>{
  const v=e.target.value.trim();
  e.target.style.borderColor = (!v || /^[a-zA-Z][a-zA-Z0-9_]*$/.test(v)) ? '' : 'var(--red)';
});

// Initialize palette when page loads (deferred)
// (palette is built on demand when Architect tab is opened)

// ══════════════════════════════════════════════════════════════════════════════
