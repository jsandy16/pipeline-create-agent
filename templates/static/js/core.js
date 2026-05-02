const $=id=>document.getElementById(id);

// ── Project + Cost Center global fields ──────────────────────────────────────
const projectInput=$('projectInput'), costCenterInput=$('costCenterInput');

const businessUnitInput=$('businessUnitInput');
function getProject(){ return projectInput.value.trim(); }
function getCostCenter(){ return costCenterInput.value.trim(); }
function getBusinessUnit(){ return businessUnitInput.value.trim(); }

/** Returns true if both required fields are filled. Highlights empty ones. */
function validateProjectFields(){
  let ok=true;
  [projectInput, costCenterInput].forEach(el=>{
    if(!el.value.trim()){ el.classList.add('required-empty'); ok=false; }
    else el.classList.remove('required-empty');
  });
  if(!ok) alert('Please fill in the Project name and Cost Center before continuing.');
  return ok;
}

// Re-evaluate gating whenever either field changes
function _updateGating(){
  const filled = getProject() && getCostCenter();
  [projectInput, costCenterInput].forEach(el=>el.classList.remove('required-empty'));
  // runBtn gating is also controlled by file selection — leave that untouched here
}
projectInput.addEventListener('input', _updateGating);
costCenterInput.addEventListener('input', _updateGating);

const dropZone=$('dropZone'),fileInput=$('fileInput'),
      fileChip=$('fileChip'),fcThumb=$('fcThumb'),fcName=$('fcName'),fcSize=$('fcSize'),fcRm=$('fcRm'),
      hintInput=$('hintInput'),runBtn=$('runBtn'),spin=$('spin'),runLabel=$('runLabel'),
      cancelBtn=$('cancelBtn'),clearBtn=$('clearBtn'),
      resultCard=$('resultCard'),rcHead=$('rcHead'),rcRows=$('rcRows'),
      sdot=$('sdot'),sLabel=$('sLabel'),
      progWrap=$('progWrap'),progFill=$('progFill'),progStage=$('progStage'),progPct=$('progPct'),
      dgmStage=$('dgmStage'),dgmEmpty=$('dgmEmpty'),rawImg=$('rawImg'),
      diagramSvg=$('diagramSvg'),dgmLabel=$('dgmLabel'),
      svcEmpty=$('svcEmpty'),svcList=$('svcList'),
      wsSplit=$('wsSplit'),dragH=$('dragH'),consoleEl=$('console');

const matrixBtn=$('matrixBtn');
const monitorBtn=$('monitorBtn');
const autofixToggle=$('autofixToggle'), autofixCheck=$('autofixCheck');
const tabBuild=$('tabBuild'),tabRun=$('tabRun'),runDot=$('runDot'),runCount=$('runCount'),
      tabConfig=$('tabConfig'),cfgChat=$('cfgChat'),cfgSvcSelect=$('cfgSvcSelect'),
      cfgTplBar=$('cfgTplBar'),cfgMsgs=$('cfgMsgs'),cfgEmpty=$('cfgEmpty'),
      cfgInput=$('cfgInput'),cfgSendBtn=$('cfgSendBtn');
const runConsole=$('runConsole'),runFilterBar=$('runFilterBar');

let objUrl=null, selectedFile=null, activeJobId=null, activeWs=null;
let activePreviewId=null, previewWs=null, runLogCount=0, _runFilters={};

// ── Pan/zoom state for Dagre SVG ───────────────────────────────────────────
let _pan={x:0,y:0,scale:1}, _svgDrag=false, _svgOrigin=null;

// ── AWS service metadata ───────────────────────────────────────────────────
const SVC_ICONS={
  s3:'🪣',lambda:'λ',sqs:'📬',dynamodb:'🗃️',cloudwatch:'📊',
  sns:'📢',eventbridge:'⚡',glue:'🔧',athena:'🔍',
  kinesis_streams:'🌊',kinesis_firehose:'🔥',kinesis_analytics:'📈',
  stepfunctions:'🔄',ec2:'🖥️',msk:'📦',dms:'🔀',
  redshift:'🔴',lake_formation:'🏞️',aurora:'🌌',
  glue_databrew:'🧪',emr:'⚙️',glue_data_catalog:'📚',iam:'🔑',
  emr_serverless:'💡',sagemaker:'🧠',quicksight:'📐',
};
const CAT_COLOR={
  s3:'#3F8624',lambda:'#FF9900',sqs:'#E7157B',dynamodb:'#4053D6',
  cloudwatch:'#E7157B',sns:'#E7157B',eventbridge:'#E7157B',
  glue:'#8C4FFF',athena:'#8C4FFF',kinesis_streams:'#8C4FFF',
  kinesis_firehose:'#8C4FFF',kinesis_analytics:'#8C4FFF',
  stepfunctions:'#E7157B',ec2:'#FF9900',msk:'#8C4FFF',dms:'#4053D6',
  redshift:'#4053D6',lake_formation:'#3F8624',aurora:'#4053D6',
  glue_databrew:'#8C4FFF',emr:'#FF9900',glue_data_catalog:'#8C4FFF',iam:'#DD344C',
  emr_serverless:'#FF9900',sagemaker:'#01A88D',quicksight:'#8C4FFF',
};
const ABBREV={
  s3:'S3',lambda:'λ',sqs:'SQS',dynamodb:'DDB',cloudwatch:'CW',
  sns:'SNS',eventbridge:'EB',glue:'GLU',athena:'ATH',
  kinesis_streams:'KDS',kinesis_firehose:'KFH',kinesis_analytics:'KDA',
  stepfunctions:'SFN',ec2:'EC2',msk:'MSK',dms:'DMS',
  redshift:'RS',lake_formation:'LF',aurora:'RDS',
  glue_databrew:'GDB',emr:'EMR',glue_data_catalog:'GDC',iam:'IAM',
  emr_serverless:'EMR-S',sagemaker:'SM',quicksight:'QS',
};
const catColor=t=>CAT_COLOR[t]||'#7d8590';
const abbrev=t=>ABBREV[t]||(t||'?').slice(0,3).toUpperCase();

const DOT_STATUS_COLOR={
  pending:'#2a3040',building:'#7c5cfc',done:'#3fb950',error:'#f85149'
};
const BORDER_COLOR={building:'#7c5cfc',done:'#3fb950',error:'#f85149'};
const BG_TINT={building:'#16202e',done:'#121e13',error:'#1d1313'};
const PULSE_SET=new Set(['building']);

const IND={
  pending:'<span style="color:var(--muted);font-size:9px">○</span>',
  building:'<span class="svc-spin" style="color:var(--accent)">◉</span>',
  done:'<span style="color:var(--green)">✓</span>',
  error:'<span style="color:var(--red)">✗</span>',
};
const fmtB=b=>b<1024?b+' B':b<1048576?(b/1024).toFixed(1)+' KB':(b/1048576).toFixed(1)+' MB';
const safe=n=>n.replace(/[^a-zA-Z0-9]/g,'_');

// ── File handling ──────────────────────────────────────────────────────────
dropZone.addEventListener('dragover',e=>{e.preventDefault();dropZone.classList.add('over')});
dropZone.addEventListener('dragleave',()=>dropZone.classList.remove('over'));
dropZone.addEventListener('drop',e=>{e.preventDefault();dropZone.classList.remove('over');
  if(e.dataTransfer.files[0]) loadFile(e.dataTransfer.files[0])});
fileInput.addEventListener('change',()=>{if(fileInput.files[0]) loadFile(fileInput.files[0])});
fcRm.addEventListener('click',clearFile);
clearBtn.addEventListener('click',()=>{
  consoleEl.innerHTML='<div class="con-empty">Console cleared.</div>';
  // Clear pipeline diagram
  diagramSvg.style.display='none'; diagramSvg.innerHTML='';
  rawImg.style.display='none'; rawImg.src='';
  dgmEmpty.style.display='none';
  dgmLabel.textContent='Input Diagram';
  _dgmNodes={}; _dgmEdges=[]; _dgmEdgeG=null;
});

function loadFile(f){
  selectedFile=f;
  if(objUrl) URL.revokeObjectURL(objUrl);
  objUrl=URL.createObjectURL(f);
  fcThumb.src=objUrl; fcName.textContent=f.name; fcSize.textContent=fmtB(f.size);
  fileChip.classList.add('show'); dropZone.style.display='none'; runBtn.disabled=false;
  // Show raw image preview
  dgmEmpty.style.display='none';
  diagramSvg.style.display='none'; diagramSvg.innerHTML='';
  rawImg.src=objUrl; rawImg.style.display='block';
  dgmLabel.textContent='Input Diagram';
}
function clearFile(){
  selectedFile=null; fileChip.classList.remove('show');
  dropZone.style.display=''; fileInput.value='';
  if(objUrl){URL.revokeObjectURL(objUrl);objUrl=null;}
  rawImg.style.display='none'; rawImg.src='';
  diagramSvg.style.display='none'; diagramSvg.innerHTML='';
  dgmEmpty.style.display='flex'; dgmLabel.textContent='Input Diagram';
  runBtn.disabled=true;
}

// ── Zoom buttons (work for both raw image and SVG) ─────────────────────────
$('zIn') .addEventListener('click',()=>{ if(diagramSvg.style.display!=='none') scaleSvg(1.25); });
$('zOut').addEventListener('click',()=>{ if(diagramSvg.style.display!=='none') scaleSvg(0.8);  });
$('zFit').addEventListener('click',()=>{ if(diagramSvg.style.display!=='none') fitSvg();       });

function scaleSvg(f){
  _pan.scale=Math.max(0.05,Math.min(10,_pan.scale*f));
  applyPan();
}
function applyPan(){
  const root=document.getElementById('_root');
  if(root) root.setAttribute('transform',`translate(${_pan.x.toFixed(1)},${_pan.y.toFixed(1)}) scale(${_pan.scale.toFixed(4)})`);
}

// ═══════════════════════════════════════════════════════════════════════════
// ── DAGRE SVG DIAGRAM ──────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

const NW=200, NH=66;  // node width / height

function svgE(tag,a={}){
  const el=document.createElementNS('http://www.w3.org/2000/svg',tag);
  for(const[k,v] of Object.entries(a)) el.setAttribute(k,v);
  return el;
}

// ── Diagram state: node positions + edge list for live redraw ────────────────
let _dgmNodes = {};       // name → {x, y}  (top-left corner in graph coords)
let _dgmEdges = [];       // [{src, tgt}]
let _dgmEdgeG = null;     // the SVG <g> holding all edge paths
let _dgmNodeDrag = null;  // {name, ox, oy, startClientX, startClientY}

// ── Last-rendered pipeline (for Edit Pipeline button) ────────────────────────
let _lastRenderedServices = null;
let _lastRenderedIntegrations = null;
let _lastRenderedPipelineName = '';

const editPipelineBtn = $('editPipelineBtn');
editPipelineBtn.addEventListener('click', () => {
  if (!_lastRenderedServices || !_lastRenderedServices.length) return;
  loadDesignToArchitect(
    _lastRenderedServices,
    _lastRenderedIntegrations || [],
    _lastRenderedPipelineName
  );
  editPipelineBtn.style.display = 'none';
});

// Compute straight edge path from node centres, with short arrow offset
function _edgePath(srcName, tgtName) {
  const s = _dgmNodes[srcName], t = _dgmNodes[tgtName];
  if (!s || !t) return '';
  const sx = s.x + NW, sy = s.y + NH / 2;   // right edge of source
  const tx = t.x,       ty = t.y + NH / 2;   // left edge of target
  const ARROW_OFFSET = 10;
  const dx = tx - sx, dy = ty - sy;
  const dist = Math.sqrt(dx*dx + dy*dy) || 1;
  const ex = tx - (dx/dist)*ARROW_OFFSET, ey = ty - (dy/dist)*ARROW_OFFSET;
  const cx1 = sx + dx*0.4, cx2 = ex - dx*0.4;
  return `M ${f(sx)} ${f(sy)} C ${f(cx1)} ${f(sy)} ${f(cx2)} ${f(ey)} ${f(ex)} ${f(ey)}`;
}

function _redrawEdges() {
  if (!_dgmEdgeG) return;
  // Each edge is two paths (shadow + animated dash); they come in pairs
  const paths = _dgmEdgeG.querySelectorAll('path[data-src]');
  for (const p of paths) {
    const d = _edgePath(p.dataset.src, p.dataset.tgt);
    p.setAttribute('d', d);
  }
}

function buildDagram(services, integrations){
  if(typeof dagre==='undefined'){ console.warn('dagre not loaded'); return; }

  // Track last-rendered pipeline for Edit Pipeline
  _lastRenderedServices = services;
  _lastRenderedIntegrations = integrations;
  editPipelineBtn.style.display = (services && services.length) ? '' : 'none';

  diagramSvg.innerHTML='';
  rawImg.style.display='none';
  dgmEmpty.style.display='none';
  diagramSvg.style.display='block';
  dgmLabel.textContent='Pipeline Architecture';
  _dgmNodes = {};
  _dgmEdges = [];
  _dgmEdgeG = null;
  _dgmNodeDrag = null;

  // ── Build graph ──────────────────────────────────────────────────────────
  const g=new dagre.graphlib.Graph({multigraph:false});
  g.setGraph({rankdir:'LR',ranksep:60,nodesep:22,marginx:48,marginy:48});
  g.setDefaultEdgeLabel(()=>({}));
  for(const s of services)       g.setNode(s.name,{width:NW,height:NH,type:s.type});
  for(const i of (integrations||[])){
    if(g.hasNode(i.source)&&g.hasNode(i.target)){
      g.setEdge(i.source,i.target,{event:i.event||''});
      _dgmEdges.push({src:i.source,tgt:i.target});
    }
  }
  dagre.layout(g);

  // Store initial positions from dagre layout
  for(const n of g.nodes()){
    const nd=g.node(n);
    _dgmNodes[n]={x: nd.x - NW/2, y: nd.y - NH/2};
  }

  const gi=g.graph();
  const gW=gi.width+96, gH=gi.height+96;

  // ── Defs ─────────────────────────────────────────────────────────────────
  const defs=svgE('defs');

  // Arrow
  const mk=svgE('marker',{id:'arr',markerWidth:'10',markerHeight:'7',
    refX:'9',refY:'3.5',orient:'auto',markerUnits:'userSpaceOnUse'});
  mk.appendChild(svgE('path',{d:'M0,0 L10,3.5 L0,7 Z',fill:'#4a5568'}));
  defs.appendChild(mk);

  // Glow filter
  const gf=svgE('filter',{id:'glow',x:'-80%',y:'-80%',width:'260%',height:'260%'});
  gf.appendChild(svgE('feGaussianBlur',{stdDeviation:'3',result:'b'}));
  const fm=svgE('feMerge');
  fm.append(svgE('feMergeNode',{in:'b'}),svgE('feMergeNode',{in:'SourceGraphic'}));
  gf.appendChild(fm); defs.appendChild(gf);

  // Clip paths
  for(const n of g.nodes()){
    const cp=svgE('clipPath',{id:'cp_'+safe(n)});
    cp.appendChild(svgE('rect',{width:NW,height:NH,rx:'10',ry:'10'}));
    defs.appendChild(cp);
  }
  diagramSvg.appendChild(defs);

  // ── Root group (pan/zoom target) ─────────────────────────────────────────
  const root=svgE('g',{id:'_root'});
  diagramSvg.appendChild(root);

  // ── Edges (drawn below nodes; paths use data-src/data-tgt for live redraw)
  _dgmEdgeG = svgE('g');
  for(const e of _dgmEdges){
    const d = _edgePath(e.src, e.tgt);
    const shadow = svgE('path',{d,fill:'none',stroke:'#1e2535','stroke-width':'2','stroke-linecap':'round'});
    shadow.dataset.src = e.src; shadow.dataset.tgt = e.tgt;
    _dgmEdgeG.appendChild(shadow);
    const dash = svgE('path',{d,fill:'none',stroke:'#3a4558','stroke-width':'1.5',
      'stroke-dasharray':'6 5','stroke-linecap':'round',class:'edge-flow','marker-end':'url(#arr)'});
    dash.dataset.src = e.src; dash.dataset.tgt = e.tgt;
    _dgmEdgeG.appendChild(dash);
  }
  root.appendChild(_dgmEdgeG);

  // ── Nodes ────────────────────────────────────────────────────────────────
  const nodeG=svgE('g');
  const BX=10,BY=9,BS=48, TX=BX+BS+12;

  for(const n of g.nodes()){
    const nd=g.node(n);
    const {x:nx,y:ny}=_dgmNodes[n];
    const cat=catColor(nd.type), ab=abbrev(nd.type), sid=safe(n);

    const grp=svgE('g',{id:'nd_'+sid,class:'dgm-node',
      transform:`translate(${f(nx)},${f(ny)})`,
      'data-name':n,'data-st':'pending',cursor:'grab'});

    // Shadow
    grp.appendChild(svgE('rect',{x:'1',y:'4',width:NW,height:NH,rx:'10',ry:'10',fill:'rgba(0,0,0,.5)'}));

    // Background + left accent bar (clipped)
    const cg=svgE('g',{'clip-path':`url(#cp_${sid})`});
    cg.appendChild(svgE('rect',{id:'bg_'+sid,width:NW,height:NH,fill:'#131720'}));
    cg.appendChild(svgE('rect',{x:'0',y:'0',width:'5',height:NH,fill:cat}));
    grp.appendChild(cg);

    // Border
    grp.appendChild(svgE('rect',{id:'br_'+sid,width:NW,height:NH,rx:'10',ry:'10',
      fill:'none',stroke:'#252d3d','stroke-width':'1',class:'node-border'}));

    // Icon badge background
    grp.appendChild(svgE('rect',{x:BX,y:BY,width:BS,height:BS,rx:'8',ry:'8',fill:cat}));
    grp.appendChild(svgE('rect',{x:BX,y:BY,width:BS,height:BS/2,rx:'8',ry:'8',fill:'rgba(255,255,255,.1)','pointer-events':'none'}));
    grp.appendChild(svgE('rect',{x:BX,y:BY+BS/2,width:BS,height:BS/2,fill:cat,'pointer-events':'none'}));
    grp.appendChild(svgE('rect',{x:BX,y:BY,width:BS,height:BS,rx:'8',ry:'8',fill:'none',
      stroke:'rgba(255,255,255,.12)','stroke-width':'1','pointer-events':'none'}));

    // Abbreviation in badge
    const aLen=ab.length, aSize=aLen<=2?'18':aLen===3?'13.5':'11';
    const abEl=svgE('text',{x:BX+BS/2,y:BY+BS/2,'text-anchor':'middle','dominant-baseline':'central',
      'font-size':aSize,'font-weight':'700',fill:'rgba(255,255,255,.95)',
      'font-family':"'JetBrains Mono',monospace",'pointer-events':'none'});
    abEl.textContent=ab; grp.appendChild(abEl);

    // Separator
    grp.appendChild(svgE('line',{x1:TX-5,y1:'11',x2:TX-5,y2:NH-11,stroke:'#1e2535','stroke-width':'1'}));

    // Name (truncated)
    const dispName=n.length>15?n.slice(0,14)+'…':n;
    const nmEl=svgE('text',{x:TX,y:'26','font-size':'11.5','font-weight':'600',fill:'#dde4ed',
      'dominant-baseline':'middle','pointer-events':'none'});
    nmEl.textContent=dispName; grp.appendChild(nmEl);

    // Type
    const tpEl=svgE('text',{x:TX,y:'45','font-size':'9',fill:'#4d5a70',
      'dominant-baseline':'middle','font-family':"'JetBrains Mono',monospace",'pointer-events':'none'});
    tpEl.textContent=nd.type||''; grp.appendChild(tpEl);

    // Status dot (top-right)
    grp.appendChild(svgE('circle',{id:'dt_'+sid,cx:NW-12,cy:'13',r:'5.5',fill:'#2a3040'}));

    // ── Per-node drag ──────────────────────────────────────────────────────
    grp.addEventListener('mousedown', e=>{
      if(e.button!==0) return;
      e.stopPropagation(); // don't trigger canvas pan
      const name=grp.dataset.name;
      _dgmNodeDrag={
        name,
        ox: _dgmNodes[name].x,
        oy: _dgmNodes[name].y,
        startCX: e.clientX,
        startCY: e.clientY,
      };
      grp.setAttribute('cursor','grabbing');
      e.preventDefault();
    });

    nodeG.appendChild(grp);
  }
  root.appendChild(nodeG);

  // ── Fit to stage ─────────────────────────────────────────────────────────
  fitSvg(gW, gH);

  // ── Pan/zoom setup ────────────────────────────────────────────────────────
  setupPanZoom();
}

function fitSvg(gW, gH){
  const w=dgmStage.clientWidth||900, h=dgmStage.clientHeight||500;
  const totalW=gW||_lastGW||900, totalH=gH||_lastGH||500;
  if(gW) {_lastGW=gW; _lastGH=gH;}
  const s=Math.min(w/totalW, h/totalH)*0.92;
  _pan={x:(w-totalW*s)/2, y:(h-totalH*s)/2, scale:s};
  applyPan();
}
let _lastGW=900,_lastGH=500,_pzSetup=false;

function buildPath(pts){
  let d=`M ${f(pts[0].x)} ${f(pts[0].y)}`;
  if(pts.length===2) d+=` L ${f(pts[1].x)} ${f(pts[1].y)}`;
  else{
    for(let i=1;i<pts.length-1;i++){
      const p=pts[i],pn=pts[i+1],mx=(p.x+pn.x)/2,my=(p.y+pn.y)/2;
      d+=` Q ${f(p.x)} ${f(p.y)} ${f(mx)} ${f(my)}`;
    }
    d+=` L ${f(pts[pts.length-1].x)} ${f(pts[pts.length-1].y)}`;
  }
  return d;
}
const f=n=>n.toFixed(1);

function setupPanZoom(){
  if(_pzSetup) return; _pzSetup=true;
  diagramSvg.addEventListener('wheel',e=>{
    e.preventDefault();
    const rect=diagramSvg.getBoundingClientRect();
    const mx=e.clientX-rect.left, my=e.clientY-rect.top;
    const d=e.deltaY<0?1.12:0.89;
    _pan.x=mx+(_pan.x-mx)*d; _pan.y=my+(_pan.y-my)*d;
    _pan.scale=Math.max(0.05,Math.min(12,_pan.scale*d));
    applyPan();
  },{passive:false});
  diagramSvg.addEventListener('mousedown',e=>{
    if(e.button!==0) return;
    if(_dgmNodeDrag) return; // node drag already started, don't also pan
    _svgDrag=true; _svgOrigin={x:e.clientX-_pan.x,y:e.clientY-_pan.y};
    diagramSvg.classList.add('grabbing'); e.preventDefault();
  });
}
document.addEventListener('mousemove',e=>{
  // Node drag takes priority over canvas pan
  if(_dgmNodeDrag){
    const dxScreen = e.clientX - _dgmNodeDrag.startCX;
    const dyScreen = e.clientY - _dgmNodeDrag.startCY;
    // Convert screen delta → graph delta (divide by current scale)
    const scale = _pan.scale || 1;
    const nx = _dgmNodeDrag.ox + dxScreen / scale;
    const ny = _dgmNodeDrag.oy + dyScreen / scale;
    _dgmNodes[_dgmNodeDrag.name] = {x: nx, y: ny};
    // Move the SVG group
    const sid = safe(_dgmNodeDrag.name);
    const grp = document.getElementById('nd_'+sid);
    if(grp) grp.setAttribute('transform',`translate(${f(nx)},${f(ny)})`);
    // Redraw all edges connected to this node
    _redrawEdges();
    return;
  }
  if(!_svgDrag||!_svgOrigin||_rowDrag) return;
  _pan.x=e.clientX-_svgOrigin.x; _pan.y=e.clientY-_svgOrigin.y; applyPan();
});
document.addEventListener('mouseup',e=>{
  if(e.button!==0) return;
  if(_dgmNodeDrag){
    const sid=safe(_dgmNodeDrag.name);
    const grp=document.getElementById('nd_'+sid);
    if(grp) grp.setAttribute('cursor','grab');
    _dgmNodeDrag=null;
  }
  if(_svgDrag){_svgDrag=false;_svgOrigin=null;diagramSvg.classList.remove('grabbing');}
});

// ── Node status update ─────────────────────────────────────────────────────
function updateNode(name, st){
  const sid=safe(name);
  const dt=document.getElementById('dt_'+sid);
  const br=document.getElementById('br_'+sid);
  const bg=document.getElementById('bg_'+sid);
  const grp=document.getElementById('nd_'+sid);
  if(!dt) return;
  grp && (grp.dataset.st=st);
  dt.setAttribute('fill',DOT_STATUS_COLOR[st]||'#2a3040');
  dt.setAttribute('filter',PULSE_SET.has(st)?'url(#glow)':'');
  dt.classList.toggle('ndot-pulse',PULSE_SET.has(st));
  if(br){ const bc=BORDER_COLOR[st]; br.setAttribute('stroke',bc||'#252d3d'); br.setAttribute('stroke-width',bc?'1.5':'1'); }
  if(bg) bg.setAttribute('fill',BG_TINT[st]||'#161b22');
}

// ── Services sidebar ───────────────────────────────────────────────────────
function initServices(svcs){
  _pipelineServices = svcs || [];
  svcList.innerHTML='';
  for(const s of svcs){
    const card=document.createElement('div');
    card.className='svc-card'; card.dataset.s='pending'; card.id='sc_'+s.name;
    card.innerHTML=`<span class="svc-ico">${SVC_ICONS[s.type]||'☁️'}</span>
      <div class="svc-body"><div class="svc-nm">${s.name}</div><div class="svc-tp">${s.type}</div></div>
      <span class="svc-ind" id="si_${s.name}">${IND.pending}</span>`;
    svcList.appendChild(card);
  }
}
function updService(name,st){
  const card=document.getElementById('sc_'+name);
  if(card){card.dataset.s=st;const i=document.getElementById('si_'+name);if(i)i.innerHTML=IND[st]||IND.pending;}
  updateNode(name,st);
}
function resetServices(){
  svcList.innerHTML='';
  dgmLabel.textContent='Input Diagram';
}

// ── Status / progress ──────────────────────────────────────────────────────
function setStatus(cls,txt){sdot.className='sdot '+cls;sLabel.textContent=txt}
function setBusy(b){
  runBtn.disabled=b; spin.style.display=b?'inline-block':'none';
  runLabel.textContent=b?'Running…':'Generate Terraform';
  cancelBtn.style.display=b?'block':'none';
}
function setProg(pct,stage,state){
  progWrap.classList.add('show');
  progFill.style.width=pct+'%'; progFill.className='prog-fill'+(state?' '+state:'');
  progStage.textContent=stage||''; progPct.textContent=pct+'%';
}
function resetProg(){
  progWrap.classList.remove('show'); progFill.style.width='0%';
  progFill.className='prog-fill'; progStage.textContent=''; progPct.textContent='';
}

// ── Result card ────────────────────────────────────────────────────────────
function showResult(code,res){
  const ok=code===0;
  resultCard.className='result-card show '+(ok?'ok':'fail');
  rcHead.textContent=ok?'✅  Terraform Generated':'❌  Pipeline Failed';
  const rows=[];
  if(res){
    if(res.pipeline_name) rows.push(['Pipeline',res.pipeline_name]);
    if(res.main_tf_path)  rows.push(['Output',res.main_tf_path]);
    if(res.services!=null) rows.push(['Services',String(res.services)]);
    if(res.lint_errors!=null) rows.push(['Lint errors',res.lint_errors===0?'✓ none':'✗ '+res.lint_errors]);
  }
  rcRows.innerHTML=rows.map(([k,v])=>{
    const c=v.startsWith('✓')?'ok-tag':v.startsWith('✗')?'fail-tag':'';
    return `<div class="rc-row"><span class="k">${k}</span><span class="v ${c}">${v}</span></div>`;
  }).join('');
}

// ── Cancel ─────────────────────────────────────────────────────────────────
cancelBtn.addEventListener('click',async()=>{
  if(!activeJobId) return;
  cancelBtn.disabled=true; cancelBtn.textContent='Cancelling…';
  try{await fetch(`/cancel/${activeJobId}`,{method:'DELETE'})}catch(_){}
  if(activeWs){try{activeWs.close()}catch(_){}}
});

// ── Draggable row split (3-pane: diagram / designer chat / console) ──────
let _rowDrag=0; // 0=none, 1=top handle, 2=bottom handle
const dragH2=$('dragH2');
// Track row fractions: [diagram, chat, console] in fr units
let _splitFr = [5, 2, 3]; // initial proportions

function _applyGridRows() {
  const chatCollapsed = _splitFr[1] <= 0;
  const conCollapsed  = _splitFr[2] <= 0;

  if (chatCollapsed && conCollapsed) {
    wsSplit.style.gridTemplateRows = '1fr 0px auto 0px auto';
  } else if (chatCollapsed) {
    const total = _splitFr[0] + _splitFr[2];
    wsSplit.style.gridTemplateRows =
      `${(_splitFr[0]/total*100).toFixed(1)}% 5px auto 0px ${(_splitFr[2]/total*100).toFixed(1)}%`;
  } else if (conCollapsed) {
    const total = _splitFr[0] + _splitFr[1];
    wsSplit.style.gridTemplateRows =
      `${(_splitFr[0]/total*100).toFixed(1)}% 5px ${(_splitFr[1]/total*100).toFixed(1)}% 0px auto`;
  } else {
    const total = _splitFr[0] + _splitFr[1] + _splitFr[2];
    wsSplit.style.gridTemplateRows =
      `${(_splitFr[0]/total*100).toFixed(1)}% 5px ${(_splitFr[1]/total*100).toFixed(1)}% 5px ${(_splitFr[2]/total*100).toFixed(1)}%`;
  }
}

dragH.addEventListener('mousedown',e=>{_rowDrag=1;e.preventDefault()});
dragH2.addEventListener('mousedown',e=>{_rowDrag=2;e.preventDefault()});
document.addEventListener('mousemove',e=>{
  if(!_rowDrag) return;
  const rect=wsSplit.getBoundingClientRect();
  const h=rect.height;
  const y=e.clientY-rect.top;
  const total = _splitFr[0]+_splitFr[1]+_splitFr[2];

  if(_rowDrag===1){
    // Top handle: resize diagram vs (chat+console)
    let topPct = Math.max(15, Math.min(70, y/h*100));
    const rest = 100 - topPct;
    const chatRatio = _splitFr[1]/(_splitFr[1]+_splitFr[2]);
    _splitFr[0] = topPct;
    _splitFr[1] = rest * chatRatio;
    _splitFr[2] = rest * (1-chatRatio);
  } else {
    // Bottom handle: resize (diagram+chat) vs console
    let topTwo = Math.max(30, Math.min(85, y/h*100));
    const dgmRatio = _splitFr[0]/(_splitFr[0]+_splitFr[1]);
    _splitFr[0] = topTwo * dgmRatio;
    _splitFr[1] = topTwo * (1-dgmRatio);
    _splitFr[2] = 100 - topTwo;
  }
  _applyGridRows();
  if(diagramSvg.style.display!=='none') fitSvg();
});
document.addEventListener('mouseup',()=>{_rowDrag=0});

// ── Console collapse / expand ────────────────────────────────────────────────
const conWrap=$('conWrap'),conToggle=$('conToggle');
let _conCollapsed = false;
let _conSavedFr = null;

function conCollapse() {
  if (_conCollapsed) return;
  _conCollapsed = true;
  _conSavedFr = [..._splitFr];
  conWrap.classList.add('collapsed');
  // Redistribute console space to chat (or diagram if chat collapsed)
  if (_splitFr[1] > 0) { _splitFr[1] += _splitFr[2]; }
  else { _splitFr[0] += _splitFr[2]; }
  _splitFr[2] = 0;
  _applyGridRows();
}
function conExpand() {
  if (!_conCollapsed) return;
  _conCollapsed = false;
  conWrap.classList.remove('collapsed');
  if (_conSavedFr) { _splitFr = [..._conSavedFr]; }
  else { _splitFr = [5, 2, 3]; }
  _applyGridRows();
}
conToggle.addEventListener('click', () => {
  if (_conCollapsed) conExpand(); else conCollapse();
});

// ── Console ────────────────────────────────────────────────────────────────
function log(level,time,logger,msg){
  const empty=consoleEl.querySelector('.con-empty'); if(empty) empty.remove();
  const ln=document.createElement('div'); ln.className='log-line '+level;
  const mk=(c,t)=>{const s=document.createElement('span');s.className=c;s.textContent=t;return s};
  ln.append(mk('lt',time),mk('ll',level),mk('lg','['+logger.split('.').pop()+']'),mk('lm',msg));
  consoleEl.appendChild(ln); consoleEl.scrollTop=consoleEl.scrollHeight;
}

// ── Run pipeline ───────────────────────────────────────────────────────────
runBtn.addEventListener('click',async()=>{
  if(!selectedFile) return;
  if(!validateProjectFields()) return;
  consoleEl.innerHTML='<div class="con-empty">Starting…</div>';
  resetProg(); resetServices();
  resultCard.className='result-card';
  setBusy(true); setStatus('running','Uploading…');
  // Keep raw image visible while T0 runs
  if(objUrl){ rawImg.src=objUrl; rawImg.style.display='block';
    diagramSvg.style.display='none'; dgmEmpty.style.display='none'; }

  const fd=new FormData();
  fd.append('file',selectedFile);
  fd.append('hint',hintInput.value.trim());
  fd.append('business_unit', getBusinessUnit() || getProject());
  fd.append('cost_center', getCostCenter());
  let jobId;
  try{
    const r=await fetch('/run',{method:'POST',body:fd});
    const d=await r.json();
    if(!r.ok) throw new Error(d.detail||'Upload failed');
    jobId=d.job_id;
  }catch(err){ log('ERROR',now(),'app','Upload failed: '+err.message); setStatus('fail','Upload failed'); setBusy(false); return; }
  activeJobId=jobId; setStatus('running','Pipeline starting…');

  function onPipelineMsg({data}){
    const m=JSON.parse(data);
    if(m.type==='log') log(m.level,m.time,m.logger,m.message);
    if(m.type==='progress'){ setProg(m.pct,m.stage,m.pct>=100?'done':''); setStatus('running',m.stage||(m.pct+'%')); }
    if(m.type==='services_init'){
      initServices(m.services);
      // Switch from raw image → Dagre SVG
      buildDagram(m.services, m.integrations||[]);
      // Populate config chat service dropdown
      cfgPopulateServices(m.services);
    }
    if(m.type==='service_update') updService(m.name,m.status);
    if(m.type==='done'){
      activeJobId=null; activeWs=null;
      cancelBtn.disabled=false; cancelBtn.textContent='✕  Cancel';
      setBusy(false);
      if(m.cancelled){ setStatus('fail','Cancelled'); setProg(0,'Cancelled','fail'); log('WARNING',now(),'pipeline','⊘ Cancelled.'); }
      else if(m.exit_code===0){ setStatus('ok','Completed successfully'); setProg(100,'Complete','done'); log('SUCCESS',now(),'pipeline','✓ Terraform written successfully.'); }
      else{ setStatus('fail','Failed'); log('ERROR',now(),'pipeline','✗ Pipeline failed.'); }
      if(!m.cancelled) showResult(m.exit_code,m.result);
      // Enable Plan + Matrix buttons on success
      if(!m.cancelled && m.exit_code===0){
        _deployJobId=jobId;
        _pipelineName = m.result?.pipeline_name || '';
        _lastRenderedPipelineName = _pipelineName;
        planBtn.disabled=false; planBtn.classList.add('enabled');
        matrixBtn.disabled=false; matrixBtn.classList.add('enabled');
        // Load config chat templates for all services
        cfgLoadServiceConfigs(jobId);
        // Auto-expand Terraform/AWS section so buttons are visible
        if (!tfOpen) {
          tfOpen = true;
          tfMenuRows.classList.add('open');
          tfChevron.classList.add('open');
        }
      }
    }
    if(m.type==='error'){ log('ERROR',now(),'app',m.message); setStatus('fail',m.message); setBusy(false); }
  }
  activeWs=makeWs(
    `${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws/${jobId}`,
    onPipelineMsg,
    { onGiveUp(){ log('ERROR',now(),'ws','Connection lost — could not reconnect. Refresh if the pipeline is still running.'); setStatus('fail','Connection error'); setBusy(false); } }
  );
});

function now(){ return new Date().toTimeString().slice(0,8); }

