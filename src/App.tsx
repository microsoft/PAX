import React, { useState, useEffect, useLayoutEffect } from 'react';
import { invoke } from '@tauri-apps/api/tauri';
import { open } from '@tauri-apps/api/shell';
import { save as saveDialog, confirm as confirmDialog } from '@tauri-apps/api/dialog';
import { exists, writeTextFile, readTextFile } from '@tauri-apps/api/fs';
import { Stepper } from './components/stepper';
import { HelpButton } from './components/HelpButton';
import { HelpModal } from './components/HelpModal';
import { appWindow, LogicalSize } from '@tauri-apps/api/window';
import { listen } from '@tauri-apps/api/event';
import { ActivityMultiSelect } from './components/activity-multi-select';
import { RELEVANT_ACTIVITIES, ALL_ACTIVITIES, Activity } from './lib/activities';

// Placeholder light-weight UI primitives (replace with shadcn added components)
import { Button } from './components/ui/button';
import { Input } from './components/ui/input';
import { DatePicker } from './components/ui/date-picker';
import { Switch } from './components/ui/switch';
import { Card } from './components/ui/card';
import { Progress } from './components/ui/progress';
import { Popover, PopoverTrigger, PopoverContent } from './components/ui/popover';
import { Command, CommandList, CommandGroup, CommandItem } from './components/ui/command';

interface LogLine { type:'stdout'|'stderr'; line:string }

interface FormState {
  startDate: string;
  endDate: string;
  activityIds: string[];
  outputFile: string;
  overwrite: boolean;
  blockHours: number;
  authMode: 'WebLogin' | 'DeviceCode' | 'Credential' | 'Silent';
  remember: boolean;
  detailedPost: boolean;
  resultSize: number;
  pacingMs: number;
}

function toYMD(d: Date){
  const y = d.getFullYear();
  const m = String(d.getMonth()+1).padStart(2,'0');
  const day = String(d.getDate()).padStart(2,'0');
  return `${y}-${m}-${day}`;
}
function timestamp(){
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth()+1).padStart(2,'0');
  const day = String(d.getDate()).padStart(2,'0');
  const hh = String(d.getHours()).padStart(2,'0');
  const mm = String(d.getMinutes()).padStart(2,'0');
  const ss = String(d.getSeconds()).padStart(2,'0');
  return `${y}${m}${day}_${hh}${mm}${ss}`;
}
async function getTempDir(){
  try {
    const mod: any = await import('@tauri-apps/api/path');
    if (typeof mod?.tempDir === 'function') {
      return await mod.tempDir();
    }
  } catch {}
  // Fallback
  return 'C:\\Temp';
}
async function defaultOutputPath(){
  const dir = await getTempDir();
  return `${dir.replace(/\\$/, '')}\\Purview_Export_${timestamp()}.csv`;
}

async function createUniqueLogPathInDir(dir: string){
  const base = `${dir.replace(/\\$/, '')}\\Purview_Export_${timestamp()}`;
  let candidate = `${base}.log`;
  let i = 1;
  while (await exists(candidate).catch(()=>false)){
    candidate = `${base}_${i}.log`;
    i++;
  }
  return candidate;
}
function newInitialForm(): FormState {
  const today = new Date();
  const tomorrow = new Date(today.getTime() + 24*60*60*1000);
  return {
    startDate: toYMD(today),
    endDate: toYMD(tomorrow),
    activityIds: RELEVANT_ACTIVITIES.map(a=>a.id),
    outputFile: '',
    overwrite: false,
  blockHours: 8,
    resultSize: 5000,
    pacingMs: 0,
    authMode: 'WebLogin',
    remember: false,
    detailedPost: false,
  };
}

const initialForm: FormState = newInitialForm();

export default function App(){
  const [step,setStep] = useState(0);
  const [form,setForm] = useState<FormState>(initialForm);
  const [errors,setErrors] = useState<Record<string,string>>({});
  const [logs,setLogs] = useState<LogLine[]>([]);
  const [status,setStatus] = useState<'idle'|'running'|'success'|'error'|'noresults'>('idle');
  const [csvPath,setCsvPath] = useState<string|null>(null);
  const [running,setRunning] = useState(false);
  const [canCancel, setCanCancel] = useState(false);
  const [percent,setPercent] = useState<number>(0);
  const [overallPercent, setOverallPercent] = useState<number>(0);
  const [phase, setPhase] = useState<'queries'|'keywords'|'post'|'unknown'>('unknown');
  const [postCats, setPostCats] = useState<Record<string, { current:number; total:number }>>({});
  const [postCurrentCat, setPostCurrentCat] = useState<string | null>(null);
  const [postCurrentCatPercent, setPostCurrentCatPercent] = useState<number | null>(null);
  const [activitiesVersion, setActivitiesVersion] = useState<string | null>(null);
  const [activitiesFresh, setActivitiesFresh] = useState<boolean | null>(null);
  const [dynRelevant, setDynRelevant] = useState<Activity[] | null>(null);
  const [dynCategories, setDynCategories] = useState<Record<string, Activity[]> | null>(null);
  const [showOnlySelected, setShowOnlySelected] = useState<boolean>(false);
  const [showOnlyRecommended, setShowOnlyRecommended] = useState<boolean>(false);
  // New: control whether the dropdown shows the curated (~48) list or the full catalog
  const [viewScope, setViewScope] = useState<'curated'|'full'>('curated');
  // New: curated id set derived from dataset presets or curated intersection
  const [dynCuratedIds, setDynCuratedIds] = useState<Set<string> | null>(null);
  const [selectionTouched, setSelectionTouched] = useState<boolean>(false);
  const [datasetLoadError, setDatasetLoadError] = useState<string | null>(null);
  const [showDetailedFlipNotice, setShowDetailedFlipNotice] = useState(false);
  const [showWebLoginHint, setShowWebLoginHint] = useState(false);
  const [autoScroll, setAutoScroll] = useState<boolean>(true);
  const [authInfoOpen, setAuthInfoOpen] = useState(false);
  const [authInfoOpenReview, setAuthInfoOpenReview] = useState(false);
  const [totalFound,setTotalFound] = useState<number|null>(null);
  const [noResults,setNoResults] = useState(false);
  const [logPath, setLogPath] = useState<string | null>(null);
  const [helpOpen, setHelpOpen] = useState(false);
  const logPathRef = React.useRef<string | null>(null);
  // Buffered logging to avoid UI stalls
  const logBufferRef = React.useRef<LogLine[]>([]);
  const fileLogBufferRef = React.useRef<string[]>([]);
  const lastLogRef = React.useRef<LogLine | null>(null);
  const uiFlushTimerRef = React.useRef<number | null>(null);
  const fileFlushTimerRef = React.useRef<number | null>(null);
  const LOG_UI_FLUSH_MS = 50; // batch UI updates ~20fps
  const LOG_FILE_FLUSH_MS = 200; // fewer fs writes
  const LOG_MAX_LINES = 5000; // cap in-memory lines
  React.useEffect(()=>{ logPathRef.current = logPath; }, [logPath]);
  // Load saved auto-scroll preference
  useEffect(()=>{
    try {
      const raw = localStorage.getItem('purview_auto_scroll_log');
      if (raw === 'false') setAutoScroll(false);
    } catch {}
  },[]);
  // Persist auto-scroll preference
  useEffect(()=>{
    try { localStorage.setItem('purview_auto_scroll_log', String(autoScroll)); } catch {}
  }, [autoScroll]);
  // Autoscroll log container to bottom as new lines arrive (always keep latest visible)
  const logContainerRef = React.useRef<HTMLDivElement|null>(null);
  useEffect(()=>{
    const el = logContainerRef.current;
    if(!el) return;
    if (autoScroll) el.scrollTop = el.scrollHeight;
  }, [logs.length, step, autoScroll]);
  // Queue a log line into UI and file buffers
  function queueLogLine(type: 'stdout'|'stderr', line: string){
    const item: LogLine = { type, line };
    // Immediate dedupe vs last emitted
    const last = lastLogRef.current;
    if (last && last.type === item.type && last.line === item.line) {
      return;
    }
    lastLogRef.current = item;
    logBufferRef.current.push(item);
    fileLogBufferRef.current.push(`[${type}] ${line}${line.endsWith('\n') ? '' : '\n'}`);
    scheduleUiFlush();
    scheduleFileFlush();
  }
  function scheduleUiFlush(){
    if (uiFlushTimerRef.current) return;
    uiFlushTimerRef.current = window.setTimeout(() => {
      uiFlushTimerRef.current = null;
      const batch = logBufferRef.current;
      if (!batch.length) return;
      logBufferRef.current = [];
      setLogs((prev)=>{
        let next = prev.length ? prev.concat(batch) : batch.slice();
        if (next.length > LOG_MAX_LINES) {
          next = next.slice(next.length - LOG_MAX_LINES);
        }
        return next;
      });
    }, LOG_UI_FLUSH_MS);
  }
  function scheduleFileFlush(){
    if (fileFlushTimerRef.current) return;
    fileFlushTimerRef.current = window.setTimeout(async () => {
      fileFlushTimerRef.current = null;
      const chunk = fileLogBufferRef.current.join('');
      fileLogBufferRef.current = [];
      if (!chunk) return;
      const p = logPathRef.current;
      if (!p) return;
      try { await (writeTextFile as any)(p, chunk, { append: true } as any); } catch {}
    }, LOG_FILE_FLUSH_MS);
  }

  // Dynamically fit window height to content (no artificial minimums)
  const rootRef = React.useRef<HTMLDivElement|null>(null);
  async function fitWindowToContent(){
    try {
      // Avoid resizing during the Export step to keep UI responsive for buttons
      if (step === 3) return;
      const el = rootRef.current;
      if(!el) return;
      // Measure multiple sources to be safe
      const elH = el.scrollHeight || 0;
      const docH = (document.documentElement?.scrollHeight || 0);
      const bodyH = (document.body?.scrollHeight || 0);
      const contentHLogical = Math.ceil(Math.max(elH, docH, bodyH));
      const currentInner = await appWindow.innerSize(); // PhysicalSize
      const scale = await appWindow.scaleFactor();
      const widthLogical = (currentInner.width as number) / (scale || 1);
      const availH = (window.screen?.availHeight || contentHLogical) - 4;
      const nextHLogical = Math.max(1, Math.min(contentHLogical, availH));
      // Set a tiny min size before shrinking to avoid clamping
      // @ts-ignore
      await (appWindow as any).setMinSize({ width: 1, height: 1 });
      await appWindow.setSize(new LogicalSize(widthLogical, nextHLogical));
    } catch {}
  }
  React.useEffect(()=>{
    // Ensure window is resizable and has no min size at runtime
    (async ()=>{
      try {
        await appWindow.setResizable(true);
        // Remove min size constraints so we can go tight
        // @ts-ignore: allow null per API
        await (appWindow as any).setMinSize(null);
        // @ts-ignore: allow null per API
        await (appWindow as any).setMaxSize(null);
      } catch {}
    })();
    const el = rootRef.current;
    if(!el) return;
    // When on the Export step, skip observers to avoid resize thrash
    if (step === 3) {
      // Do a single fit before we stop
      fitWindowToContent();
      return ()=>{};
    }
    const RO = (window as any).ResizeObserver;
    const ro = RO ? new RO((entries:any)=>{ fitWindowToContent(); }) : null;
    if(ro){ ro.observe(el); }
    // Observe any DOM mutations under root to trigger re-fit
    const mo = new MutationObserver(() => {
      // Debounce slightly to allow layout to settle
      window.setTimeout(() => { fitWindowToContent(); }, 0);
    });
    try { mo.observe(el, { childList: true, subtree: true, attributes: true, characterData: false }); } catch {}
    // Also refit on window resize events
    const onResize = () => { fitWindowToContent(); };
    window.addEventListener('resize', onResize);
    // Run once on mount and on step changes
    fitWindowToContent();
    return ()=>{ try { ro && ro.disconnect(); mo.disconnect(); window.removeEventListener('resize', onResize); } catch {} };
  }, [step]);

  // Ensure an immediate re-fit at layout time when the step changes
  useLayoutEffect(()=>{
    fitWindowToContent();
  }, [step]);

  // After step changes, perform a few delayed re-fits to catch async layout
  useEffect(()=>{
    const timers: number[] = [];
    [0, 50, 150, 300].forEach((ms)=>{
      timers.push(window.setTimeout(()=>{ fitWindowToContent(); }, ms));
    });
    return ()=>{ timers.forEach(t=> window.clearTimeout(t)); };
  }, [step]);

  // Ensure popovers are closed when entering Export step
  useEffect(()=>{
    if (step === 3) {
      setAuthInfoOpen(false);
      setAuthInfoOpenReview(false);
    }
  }, [step]);
  const authInfoCloseTimer = React.useRef<number | null>(null);
  const authInfoCloseTimerReview = React.useRef<number | null>(null);

  function scheduleAuthInfoClose(kind: 'main'|'review'){
    const ref = kind==='main' ? authInfoCloseTimer : authInfoCloseTimerReview;
    const setOpen = kind==='main' ? setAuthInfoOpen : setAuthInfoOpenReview;
    if(ref.current){ window.clearTimeout(ref.current); ref.current = null; }
    ref.current = window.setTimeout(()=>{ setOpen(false); ref.current = null; }, 150);
  }
  function cancelAuthInfoClose(kind: 'main'|'review'){
    const ref = kind==='main' ? authInfoCloseTimer : authInfoCloseTimerReview;
    if(ref.current){ window.clearTimeout(ref.current); ref.current = null; }
  }

  // Load cached settings on mount
  useEffect(()=>{
    try {
      const raw = localStorage.getItem('purview_audit_exporter_settings_v1');
      if(raw){
        const parsed = JSON.parse(raw);
        // basic shape guard
        if(parsed && typeof parsed === 'object'){
          setForm((f)=>({
            ...f,
            ...(parsed.startDate? {startDate: parsed.startDate}:{}),
            ...(parsed.endDate? {endDate: parsed.endDate}:{}),
            ...(Array.isArray(parsed.activityIds)? {activityIds: parsed.activityIds}:{}),
            ...(parsed.outputFile? {outputFile: parsed.outputFile}:{}),
            ...(typeof parsed.overwrite==='boolean'? {overwrite: parsed.overwrite}:{}),
            ...(typeof parsed.blockHours==='number'? {blockHours: parsed.blockHours}:{}),
            ...(typeof parsed.resultSize==='number'? {resultSize: parsed.resultSize}:{}),
            ...(typeof parsed.pacingMs==='number'? {pacingMs: parsed.pacingMs}:{}),
            ...(parsed.authMode? {authMode: parsed.authMode}:{}),
            ...(typeof parsed.detailedPost==='boolean'? {detailedPost: parsed.detailedPost}:{}),
            remember: true,
          }));
        }
      }
    } catch {}
  },[]);

  // Persist settings when remember is enabled
  useEffect(()=>{
    try {
      if(form.remember){
        localStorage.setItem('purview_audit_exporter_settings_v1', JSON.stringify({
          startDate: form.startDate,
          endDate: form.endDate,
          activityIds: form.activityIds,
          outputFile: form.outputFile,
          overwrite: form.overwrite,
          blockHours: form.blockHours,
          resultSize: form.resultSize,
          pacingMs: form.pacingMs,
          authMode: form.authMode,
          detailedPost: form.detailedPost,
        }));
      } else {
        localStorage.removeItem('purview_audit_exporter_settings_v1');
      }
    } catch {}
  },[form.startDate, form.endDate, form.activityIds, form.outputFile, form.overwrite, form.blockHours, form.authMode, form.detailedPost, form.resultSize, form.pacingMs, form.remember]);

  function validateStep1(){
    const e:Record<string,string>={};
    if(!form.startDate) e.startDate='Start date required';
    if(!form.endDate) e.endDate='End date required';
    if(form.startDate && form.endDate && form.startDate>=form.endDate) e.endDate='End date must be after start date';
    if(!form.activityIds.length) e.activityIds='Select at least one activity';
    setErrors(e); return Object.keys(e).length===0;
  }

  // Refresh activity list on-demand (Step 1 button)
  // simplified: no Learn refresh/discovery state
  // removed Learn refresh

  // Helper: parse a dataset JSON object into categories/relevant and update defaults
  function applyDataset(dataset: any){
    if (!dataset || !Array.isArray(dataset.categories)) throw new Error('Invalid dataset structure');
    const cats: Record<string, Activity[]> = {};
    const relevantFromTier: Activity[] = [];
    for (const cat of dataset.categories) {
      const catKey = String(cat.key || '');
      const labelRaw = String(cat.label || cat.key || 'Other');
      const label = labelRaw.replace(/\s*\(Optional\)\s*/i, '');
      const acts: Activity[] = [];
      for (const it of (cat.items || [])) {
        const id = String(it.op || it.id || ''); if (!id) continue;
        acts.push({ id, name: String(it.label || id), description: '', category: label });
        if ((it.tier ?? 0) >= 1 && (it.tier ?? 0) <= 3) {
          if (!/^(security[_-]?copilot)$/i.test(catKey)) {
            relevantFromTier.push({ id, name: String(it.label || id), description: '', category: label });
          }
        }
      }
      if (acts.length) cats[label] = acts;
    }
    // Reorder categories: Copilot first, then by relevance priority
    const pri = (key:string,label:string) => {
      const k = key.toLowerCase();
      const l = label.toLowerCase();
      if (k.includes('m365') && k.includes('copilot')) return 1000; // Microsoft 365 Copilot
      if (k.includes('security') && k.includes('copilot')) return 900; // Security Copilot (still high but after M365)
      if (k.includes('teams')) return 800;
      if (k.includes('files') || l.includes('sharepoint') || l.includes('onedrive')) return 700;
      if (k.includes('exchange')) return 600;
      if (k.includes('governance')) return 500;
      return 100; // others
    };
    const entries = Object.entries(cats).map(([label, acts])=>{
      // find original key by searching dataset.categories for matching label
      const catObj = dataset.categories.find((c:any)=> String(c.label || c.key) === label);
      const key = String(catObj?.key || label);
      return { label, acts, p: pri(key,label) };
    }).sort((a,b)=> b.p - a.p);
    const ordered: Record<string, Activity[]> = {};
    for (const e of entries) ordered[e.label] = e.acts;
    setDynCategories(ordered);
    // Build unified relevant = tiers 1–3 + curated-intersection
    const allOps = new Set<string>(Object.values(cats).flat().map(a=>a.id));
    const curatedIds = new Set<string>((RELEVANT_ACTIVITIES||[]).map(a=>a.id));
    const curatedIntersect: Activity[] = [];
    for (const [label, acts] of Object.entries(cats)){
      for (const a of acts){ if (curatedIds.has(a.id)) curatedIntersect.push(a); }
    }
    const unified: Activity[] = [];
    const seen = new Set<string>();
    for (const a of [...relevantFromTier, ...curatedIntersect]){ if(!seen.has(a.id)){ unified.push(a); seen.add(a.id);} }
    setDynRelevant(unified);
    // Build curated id set for the curated view scope:
    // If dataset.presets.curated exists, use it; otherwise derive: tiers 1–3 across Copilot/Teams/Files
    let curatedIdsFinal: string[] = [];
    if (dataset && typeof dataset === 'object' && dataset.presets && Array.isArray(dataset.presets.curated) && dataset.presets.curated.length) {
      curatedIdsFinal = dataset.presets.curated.map((x: any)=> String(x));
    } else {
      const preferredCats = ['m365_copilot','teams','files'];
      const ids: string[] = [];
      for (const c of dataset.categories as any[]) {
        const key = String(c.key || '').toLowerCase();
        const isPreferred = preferredCats.includes(key);
        for (const it of (c.items||[])) {
          const tier = Number(it.tier ?? 0);
          const id = String(it.op || it.id || '');
          if (!id) continue;
          if (isPreferred && tier>=1 && tier<=3) ids.push(id);
        }
      }
      // Augment with a small optional allowlist relevant to Copilot analytics
      const optionalAllowlist = [
        // Exchange signals (mail context)
        'MailItemsAccessed','Send','MailboxLogin','MailItemsSent','MailItemsDeleted',
        // Governance/sensitivity/sharing context
        'FileSensitivityLabelApplied','FileSensitivityLabelChanged','FileSensitivityLabelRemoved',
        'SharingSet','SharingInvitationAccepted','SecureLinkCreated','SecureLinkUsed'
      ];
      const availableIds = new Set<string>();
      for (const c of dataset.categories as any[]) {
        for (const it of (c.items||[])) {
          const id = String(it.op || it.id || '');
          if (id) availableIds.add(id);
        }
      }
      for (const id of optionalAllowlist) { if (availableIds.has(id)) ids.push(id); }
      curatedIdsFinal = Array.from(new Set(ids));
    }
    setDynCuratedIds(new Set(curatedIdsFinal));
    // Default selection behavior:
    // - If user hasn't interacted yet, prefer Recommended (tiers 1–3 + curated intersection)
    // - If user has interacted, preserve selection when possible; otherwise fall back
    const available = new Set<string>(Object.values(cats).flat().map(a=>a.id));
    if (!selectionTouched) {
      if (unified.length > 0) {
        setForm((f:any)=>({...f, activityIds: Array.from(new Set(unified.map(a=>a.id))) }));
      } else {
        const all = Array.from(available);
        setForm((f:any)=>({...f, activityIds: all }));
      }
    } else {
      const intersect = form.activityIds.filter(id => available.has(id));
      if (intersect.length > 0) {
        setForm((f:any)=>({...f, activityIds: Array.from(new Set(intersect)) }));
      } else if (unified.length > 0) {
        setForm((f:any)=>({...f, activityIds: Array.from(new Set(unified.map(a=>a.id))) }));
      } else {
        const all = Array.from(available);
        setForm((f:any)=>({...f, activityIds: all }));
      }
    }
  }

  async function loadDatasetFromFile(){
    try {
      setDatasetLoadError(null);
      const { open } = await import('@tauri-apps/api/dialog');
      const picked: any = await open({ title: 'Select activity dataset JSON', filters:[{ name: 'JSON', extensions:['json'] }] });
      if (!picked) return;
      const path = Array.isArray(picked) ? picked[0] : picked;
      const text = await readTextFile(path as string);
      const parsed = JSON.parse(text);
      applyDataset(parsed);
      setActivitiesVersion(String(parsed.version || 'n/a'));
      setActivitiesFresh(false);
      queueLogLine('stdout', `Loaded dataset from file: ${path}`);
    } catch(e:any){ setDatasetLoadError(e?.message || String(e)); }
  }

  async function loadBundledDataset(){
    try {
      setDatasetLoadError(null);
      const envelope: any = await invoke('load_bundled_dataset');
      const dataset = envelope?.dataset;
      if (!dataset) throw new Error('No dataset in bundle response');
      applyDataset(dataset);
      setActivitiesVersion(String(dataset.version || 'n/a'));
      setActivitiesFresh(false);
      const c = envelope?.meta?.categoryCount;
      const i = envelope?.meta?.itemCount;
      const src = envelope?.meta?.sourcePath || 'resources bundle';
      queueLogLine('stdout', `Loaded bundled dataset: ${src}${(c!=null && i!=null) ? ` (categories: ${c}, items: ${i})` : ''}`);
    } catch(e:any){ setDatasetLoadError(e?.message || String(e)); }
  }

  function selectEverything(){
    const cats = dynCategories || ALL_ACTIVITIES;
    const all = Object.values(cats).flat().map(a=>a.id);
    setSelectionTouched(true);
    setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(all)) }));
  }
  function selectRecommended(){
    if (dynCategories){
      const rel = dynRelevant || [];
      if (rel.length){ setSelectionTouched(true); setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(rel.map(a=>a.id))) })); return; }
      // If dynRelevant is empty (e.g., no tiers present), intersect curated with dataset
      const allOps = new Set<string>(Object.values(dynCategories).flat().map(a=>a.id));
      const curated = RELEVANT_ACTIVITIES.map(a=>a.id).filter(id=> allOps.has(id));
      if (curated.length){ setSelectionTouched(true); setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(curated)) })); return; }
      // Fallback: select everything
      const all = Object.values(dynCategories).flat().map(a=>a.id);
      setSelectionTouched(true);
      setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(all)) }));
    } else {
      setSelectionTouched(true);
      setForm((f:FormState)=>({...f, activityIds: RELEVANT_ACTIVITIES.map(a=>a.id) }));
    }
  }

  // removed discovery functionality

  // Initial auto-load bundled dataset once on mount to populate full catalog offline
  useEffect(()=>{ (async ()=>{ try { await loadBundledDataset(); } catch {} })(); },[]);
  // When user navigates back to Step 1, ensure catalog is loaded (prefer bundled)
  useEffect(()=>{
    if (step === 0 && !dynCategories) {
      (async ()=>{ try { await loadBundledDataset(); } catch {} })();
    }
  }, [step]);
  function validateStep2(){
    const e:Record<string,string>={};
    if(!form.outputFile) e.outputFile='Output file required';
    setErrors(e); return Object.keys(e).length===0;
  }

  async function runExport(){
    setRunning(true); setCanCancel(true); setStatus('running'); setLogs([]); setCsvPath(null); setPercent(0); setTotalFound(null); setNoResults(false);
    // reset buffers
    logBufferRef.current = [];
    fileLogBufferRef.current = [];
    lastLogRef.current = null;
    // Create a per-run log path in the same directory as the chosen CSV
    try {
      // Keep app window on top during export/auth flow
      try { await appWindow.setAlwaysOnTop(true); await appWindow.setFocus(); } catch {}
      const csv = form.outputFile;
      let csvDir = await getTempDir();
      try {
        const idx = Math.max(csv.lastIndexOf('\\'), csv.lastIndexOf('/'));
        if (idx >= 0) csvDir = csv.substring(0, idx);
      } catch {}
      const lp = await createUniqueLogPathInDir(csvDir);
      setLogPath(lp);
      // Create the log file immediately so the Open Log button works even if no output arrives
      await writeTextFile(lp, `=== Purview Audit Exporter Log ===\nStarted: ${new Date().toISOString()}\nCSV: ${form.outputFile}\nLog: ${lp}\n`);
    } catch {}
    try {
      // If file exists and overwrite is off, ask user before proceeding
      if (await exists(form.outputFile)) {
        if (!form.overwrite) {
          const ok = await confirmDialog(`The file already exists:\n${form.outputFile}\n\nDo you want to overwrite it?`, { title: 'File exists', type: 'warning' });
          if (!ok) {
            setRunning(false);
            setCanCancel(false);
            setStatus('idle');
            setStep(1); // return to Output step
            return;
          }
        }
      }

    // Preflight: ensure ExchangeOnlineManagement is available
    await invoke('preflight_exchange_module');
      
      await invoke('run_purview_script', {
        startDate: form.startDate,
        endDate: form.endDate,
        activityTypes: form.activityIds,
        outputFile: form.outputFile,
        overwrite: form.overwrite,
        blockHours: form.blockHours,
        authMode: form.authMode,
        detailedPost: form.detailedPost,
        resultSize: form.resultSize,
        pacingMs: form.pacingMs,
      });
      // Verify the file was actually created before reporting success
      const created = await exists(form.outputFile).catch(()=>false);
      if (created) {
        setStatus('success');
        setCsvPath(form.outputFile);
        setPercent((p:number)=> p < 100 ? 100 : p);
      } else {
        if (noResults || totalFound === 0) {
          setStatus('noresults');
          setPercent(100);
        } else {
          setStatus('error');
          const msg = 'No CSV was created. The script may have returned no results or exited early. Check the log above for details.';
          setLogs((l:LogLine[])=>[...l,{type:'stderr', line: msg}]);
          queueLogLine('stderr', msg);
        }
      }
    } catch (err:any){
      setStatus('error');
      const emsg = err?.message || String(err);
      queueLogLine('stderr', emsg);
    } finally {
      setRunning(false);
      setCanCancel(false);
      try { await appWindow.setAlwaysOnTop(false); } catch {}
    }
  }

  function onCancelWizard(){
    console.log('onCancelWizard called!');
    queueLogLine('stderr', 'Cancel button was clicked');
    
    // Use Tauri confirmDialog with proper allowlist configuration
    confirmDialog('Are you sure you want to cancel?\n\nThe export will be cancelled and the wizard will return to the first step with your selections preserved.', { 
      title: 'Cancel export', 
      type: 'warning' 
    })
    .then(ok => {
      console.log('confirmDialog result:', ok);
      if (!ok) {
        queueLogLine('stderr', 'User cancelled the cancel dialog');
        return;
      }
      
      queueLogLine('stderr', 'User confirmed Cancel - terminating PowerShell process');
      
      // Immediately update UI state to prevent further actions
      setRunning(false);
      setCanCancel(false);
      setStatus('idle');
      
      // Cancel the PowerShell process
      invoke('cancel_current_run')
        .then(() => {
          queueLogLine('stderr', 'PowerShell process terminated successfully');
        })
        .catch((err) => {
          queueLogLine('stderr', `Error terminating process: ${err}`);
          console.error('Cancel error:', err);
        });
      
      // Reset window state
      appWindow.setAlwaysOnTop(false).catch(() => {});
      
      // Return to first step with existing inputs preserved
      setPercent(0);
      setOverallPercent(0);
      setPhase('unknown');
      setCsvPath(null);
      setStep(0);
      
      queueLogLine('stderr', 'Export cancelled - returned to first step');
    })
    .catch(err => {
      console.error('confirmDialog error:', err);
      queueLogLine('stderr', `Cancel dialog error: ${err}`);
      
      // Fallback: cancel without confirmation if dialog fails
      queueLogLine('stderr', 'Dialog failed - forcing cancellation');
      setRunning(false);
      setCanCancel(false);
      setStatus('idle');
      
      invoke('cancel_current_run').catch((cancelErr) => {
        queueLogLine('stderr', `Fallback cancel error: ${cancelErr}`);
      });
      
      appWindow.setAlwaysOnTop(false).catch(() => {});
      setPercent(0);
      setOverallPercent(0);
      setPhase('unknown');
      setCsvPath(null);
      setStep(0);
    });
  }

  // Close the app (used on steps 0–2 and on step 3 when not running)
  async function onCloseApp(){
    try { if (running) { await invoke('cancel_current_run'); } } catch {}
    try { await appWindow.setAlwaysOnTop(false); } catch {}
    try { await appWindow.close(); } catch {}
    try { await invoke('quit_app'); } catch {}
  }

  useEffect(()=>{
    // Ensure only ONE active subscription set across StrictMode + Vite HMR
    const g = window as any;
    if (g.__ps_unlisten__) { try { g.__ps_unlisten__(); } catch {} }
    (async ()=>{
      try {
        const unsubs: Array<() => void> = [];
        const un1 = await listen('ps-log', (ev:any)=>{
          const payload = ev.payload as LogLine;
          const line = payload?.line || '';
          // Detect web login popup hints from script
          if (/launching|browser|authentication|sign-in|signin|auth/i.test(line) && /visible|helper|window|web/i.test(line)) {
            setShowWebLoginHint(true);
            // auto-hide after a short period
            window.setTimeout(()=> setShowWebLoginHint(false), 10000);
          }
          if (/^PA:DONE\s*$/i.test(line)) {
            // Flip to success as soon as script reports done; also set csvPath if the file exists
            setStatus('success');
            setRunning(false);
            setCanCancel(false);
            (async ()=>{
              try {
                const existsCsv = await exists(form.outputFile).catch(()=>false);
                if (existsCsv) {
                  setCsvPath(form.outputFile);
                }
              } catch {}
            })();
          }
          const m = /Total unique records found:\s*(\d+)/i.exec(line);
          if (m) {
            const n = parseInt(m[1], 10);
            if (!Number.isNaN(n)) {
              setTotalFound(n);
              if (n === 0) setNoResults(true);
            }
          }
          if (/No Copilot-related audit logs found/i.test(line)) {
            setNoResults(true);
          }
          // Queue into buffers (dedupe handled inside)
          if (payload && typeof payload.type === 'string' && typeof payload.line === 'string') {
            queueLogLine(payload.type as 'stdout'|'stderr', payload.line);
          }
        });
        unsubs.push(un1);
        const un2 = await listen('ps-progress', (ev:any)=>{
          const p = ev?.payload?.percent;
          if(typeof p === 'number' && !Number.isNaN(p)) setPercent(p);
        });
        unsubs.push(un2);
        const un3 = await listen('ps-progress2', (ev:any)=>{
          const payload = ev?.payload || {};
          const cp = payload.currentPercent;
          const op = payload.overallPercent;
          if (typeof cp === 'number' && !Number.isNaN(cp)) setPercent(cp);
          if (typeof op === 'number' && !Number.isNaN(op)) setOverallPercent(op);
          const ph = payload.phase;
          if (ph === 'queries' || ph === 'keywords' || ph === 'post') setPhase(ph);
          if (payload.postCategories && typeof payload.postCategories === 'object') {
            setPostCats(payload.postCategories as any);
          }
          if (typeof payload.postCurrentCat === 'string') setPostCurrentCat(payload.postCurrentCat);
          if (typeof payload.postCurrentCatPercent === 'number') setPostCurrentCatPercent(payload.postCurrentCatPercent);
        });
        unsubs.push(un3);
        const un4 = await listen('ps-complete', (ev:any)=>{
          const payload = ev?.payload || {};
          const ok = !!payload.success;
          const out = payload.outputFile as string | undefined;
          setRunning(false);
          setCanCancel(false);
          if (ok) {
            setStatus('success');
            setOverallPercent(100);
            if (out) setCsvPath(out);
          } else {
            setStatus('error');
          }
        });
        unsubs.push(un4);
        
        const un5 = await listen('ps-cancelled', (ev:any)=>{
          const payload = ev?.payload || {};
          console.log('PowerShell process cancelled:', payload);
          queueLogLine('stderr', 'PowerShell process cancellation confirmed');
          setRunning(false);
          setCanCancel(false);
          setStatus('idle');
          setPercent(0);
          setOverallPercent(0);
          setPhase('unknown');
          setCsvPath(null);
        });
        unsubs.push(un5);
        
        // Add window close event handler to ensure proper cleanup when "X" button is clicked
        // Note: Using beforeunload event instead of onCloseRequested to avoid blocking close behavior
        const handleBeforeUnload = () => {
          console.log('Window closing - performing cleanup');
          try {
            if (running) {
              console.log('Export is running - attempting cancel');
              // Fire and forget - don't wait for cleanup to complete
              invoke('cancel_current_run').catch(() => {});
            }
          } catch (e) {
            console.error('Error during close cleanup:', e);
          }
        };
        
        window.addEventListener('beforeunload', handleBeforeUnload);
        unsubs.push(() => window.removeEventListener('beforeunload', handleBeforeUnload));
        
        g.__ps_unlisten__ = () => { unsubs.forEach(u=>{ try { u(); } catch {} }); g.__ps_unlisten__ = null; };
      } catch {}
    })();
    return ()=>{ if ((window as any).__ps_unlisten__) { try { (window as any).__ps_unlisten__(); } catch {} } };
  },[]);

  // Also refit window on key UI changes
  useEffect(()=>{
    const t = window.setTimeout(() => { fitWindowToContent(); }, 0);
    return ()=> window.clearTimeout(t);
  }, [step, logs.length, authInfoOpen, authInfoOpenReview, form.activityIds.length]);

  // When moving to Output step, ensure default path present if empty
  useEffect(()=>{
    if(step===1 && !form.outputFile){
      (async ()=>{
        const def = await defaultOutputPath();
        setForm((f)=>({...f, outputFile: def }));
      })();
    }
  },[step]);

  function renderStep(){
    if(step===0){
      return (
        <Card className="p-6 space-y-6">
          <div>
            <label className="font-semibold">Start Date</label>
            <DatePicker value={form.startDate} onChange={(v:string)=> setForm((f:FormState)=>({...f,startDate:v}))} />
            {errors.startDate && <div className="text-red-600 text-sm">{errors.startDate}</div>}
          </div>
          <div>
            <label className="font-semibold">End Date</label>
            <DatePicker value={form.endDate} onChange={(v:string)=> setForm((f:FormState)=>({...f,endDate:v}))} />
            {errors.endDate && <div className="text-red-600 text-sm">{errors.endDate}</div>}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <label className="font-semibold">Auth Mode</label>
              <Popover open={authInfoOpen} onOpenChange={setAuthInfoOpen}>
                <PopoverTrigger>
                  <button
                    type="button"
                    className="text-xs px-2 py-0.5 rounded border bg-white hover:bg-gray-50"
                    aria-label="What are the auth modes?"
                    onMouseEnter={()=>{ cancelAuthInfoClose('main'); setAuthInfoOpen(true); }}
                    onMouseLeave={()=> scheduleAuthInfoClose('main')}
                    onFocus={()=>{ cancelAuthInfoClose('main'); setAuthInfoOpen(true); }}
                    onBlur={()=> scheduleAuthInfoClose('main')}
                  >i</button>
                </PopoverTrigger>
                {authInfoOpen && (
                <PopoverContent
                  placement="right"
                  align="start"
                  className="max-w-sm text-sm"
                  onMouseEnter={()=>{ cancelAuthInfoClose('main'); setAuthInfoOpen(true); }}
                  onMouseLeave={()=> scheduleAuthInfoClose('main')}
                  tabIndex={0}
                  onFocus={()=>{ cancelAuthInfoClose('main'); setAuthInfoOpen(true); }}
                  onBlur={()=> scheduleAuthInfoClose('main')}
                >
                  <div className="font-semibold mb-1">Authentication modes</div>
                  <ul className="list-disc ml-5 space-y-1">
                    <li><span className="font-medium">Web Login</span>: Opens Microsoft sign-in in a native window; best for admin accounts with MFA.</li>
                    <li><span className="font-medium">Device Code</span>: Shows a code to enter at microsoft.com/devicelogin; useful if window prompts are blocked.</li>
                    <li><span className="font-medium">Credential</span>: Prompts for username/password; may fail with MFA/CA; not recommended unless allowed.</li>
                    <li><span className="font-medium">Silent</span>: Re-uses an existing session if available; fails otherwise.</li>
                  </ul>
                  <div className="mt-2">
                    <button
                      type="button"
                      className="text-blue-600 underline"
                      onClick={()=> open('https://learn.microsoft.com/powershell/module/exchange/connect-exchangeonline?view=exchange-ps')}
                    >Learn more: Connect-ExchangeOnline authentication options</button>
                  </div>
                </PopoverContent>
                )}
              </Popover>
            </div>
            <div className="mt-1">
              <AuthModeSelect value={form.authMode} onChange={(v)=> setForm((f)=>({...f, authMode: v}))} />
            </div>
            <div className="text-xs text-gray-600 mt-1">Choose how to authenticate to Exchange Online for Purview audit access.</div>
          </div>
            <div>
              <div className="flex items-start gap-4">
                <div className="flex-1">
                  <div className="flex items-center justify-end mb-1 gap-3">
                    {/* View scope segmented control */}
                    <div className="text-xs flex items-center gap-2">
                      <span className="text-gray-600">List view:</span>
                      <div className="inline-flex border rounded overflow-hidden">
                        <button
                          type="button"
                          className={`px-2 py-0.5 ${viewScope==='curated' ? 'bg-blue-600 text-white' : 'bg-white text-gray-700'}`}
                          onClick={()=> setViewScope('curated')}
                          title="Show curated list (~48)"
                        >Curated{dynCuratedIds ? ` (${dynCuratedIds.size})` : ''}</button>
                        <button
                          type="button"
                          className={`px-2 py-0.5 border-l ${viewScope==='full' ? 'bg-blue-600 text-white' : 'bg-white text-gray-700'}`}
                          onClick={()=> setViewScope('full')}
                          title="Show full catalog"
                        >Full ({Object.values(dynCategories || ALL_ACTIVITIES).reduce((n,arr)=>n+arr.length,0)})</button>
                      </div>
                    </div>
                    <label className="text-xs flex items-center gap-1">
                      <input
                        type="checkbox"
                        checked={showOnlySelected}
                        onChange={(e)=> { const v = e.target.checked; setShowOnlySelected(v); if (v) setShowOnlyRecommended(false); }}
                      />
                      <span>Show only selected</span>
                    </label>
                    <label className="text-xs flex items-center gap-1">
                      <input
                        type="checkbox"
                        checked={showOnlyRecommended}
                        onChange={(e)=> { const v = e.target.checked; setShowOnlyRecommended(v); if (v) setShowOnlySelected(false); }}
                      />
                      <span>Show only recommended</span>
                    </label>
                    <button
                      type="button"
                      className="text-xs text-blue-700 underline"
                      onClick={()=>{
                        // Reset to recommended selection set
                        const rel = dynRelevant || [];
                        if (rel.length) {
                          setSelectionTouched(true);
                          setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(rel.map(a=>a.id))) }));
                        } else if (dynCategories) {
                          // Fallback to recommended via curated intersect if relevant is empty
                          const allOps = new Set<string>(Object.values(dynCategories).flat().map(a=>a.id));
                          const curated = RELEVANT_ACTIVITIES.map(a=>a.id).filter(id=> allOps.has(id));
                          if (curated.length) {
                            setSelectionTouched(true);
                            setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(curated)) }));
                          }
                        }
                      }}
                    >Reset to Recommended</button>
                  </div>
                  <ActivityMultiSelect
                    value={form.activityIds}
                    onChange={(ids:string[])=>{ setSelectionTouched(true); setForm((f:FormState)=>({...f,activityIds:ids})); }}
                    error={errors.activityIds}
                    categories={(() => {
                      const base = dynCategories || ALL_ACTIVITIES;
                      // Show only recommended view
                      if (showOnlyRecommended) {
                        const recIds = new Set((dynRelevant || []).map(a=>a.id));
                        const filtered: Record<string, Activity[]> = {};
                        for (const [cat, acts] of Object.entries(base)){
                          const keep = acts.filter(a=> recIds.has(a.id));
                          if (keep.length) filtered[cat] = keep;
                        }
                        return filtered;
                      }
                      // Show only selected view
                      if (showOnlySelected) {
                        const sel = new Set(form.activityIds);
                        const filtered: Record<string, Activity[]> = {};
                        for (const [cat, acts] of Object.entries(base)){
                          const keep = acts.filter(a=> sel.has(a.id));
                          if (keep.length) filtered[cat] = keep;
                        }
                        return filtered;
                      }
                      // View scope: curated vs full (default curated)
                      if (viewScope === 'curated' && dynCuratedIds) {
                        const filtered: Record<string, Activity[]> = {};
                        for (const [cat, acts] of Object.entries(base)){
                          const keep = acts.filter(a=> dynCuratedIds.has(a.id));
                          if (keep.length) filtered[cat] = keep;
                        }
                        return filtered;
                      }
                      return base;
                    })() || undefined}
                    relevant={dynRelevant || undefined}
                  />
                </div>
              </div>
              {(activitiesVersion || activitiesFresh===false || datasetLoadError) && (
                <div className="text-xs text-gray-600 mt-1">
                  {activitiesVersion && <span>Activities version: {activitiesVersion}</span>}
                  {activitiesFresh===false && <span className="ml-2 text-amber-700">(loaded from bundle or file)</span>}
                  <span className="ml-2">Loaded categories: {Object.keys(dynCategories || {}).length}, items: {Object.values(dynCategories || ALL_ACTIVITIES).reduce((n,arr)=>n+arr.length,0)}</span>
                  {datasetLoadError && <span className="ml-2 text-red-700">Load error: {datasetLoadError}</span>}
                </div>
              )}
              {/* Hide Learn refresh/discovery errors in simplified mode */}
              <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="p-2 border rounded">
                  <div className="text-xs font-semibold mb-2">Selection</div>
                  <div className="flex flex-wrap gap-2 justify-center md:justify-start">
                    <Button type="button" variant="ghost" className="text-xs border hover:bg-gray-50" onClick={selectRecommended}>Select Recommended</Button>
                    <Button type="button" variant="ghost" className="text-xs border hover:bg-gray-50" onClick={selectEverything}>Select Everything</Button>
                  </div>
                  <div className="text-[10px] text-gray-600 mt-1">Recommended (Copilot): tiers 1–3 (Copilot core, Teams, Files). Excludes Security Copilot; Exchange/Governance optional.</div>
                </div>
                <div className="p-2 border rounded">
                  <div className="flex flex-wrap gap-2 justify-center md:justify-start">
                    <Button type="button" variant="ghost" className="text-xs border hover:bg-gray-50" onClick={loadDatasetFromFile}>Load from file…</Button>
                  </div>
                </div>
              </div>
              {/* Discovered operations UI removed in simplified mode */}
            </div>
          <div className="flex items-center gap-2">
            <input id="remember-settings" type="checkbox" checked={form.remember} onChange={(e)=> setForm((f)=>({...f, remember: e.target.checked}))} />
            <label htmlFor="remember-settings" className="text-sm">Remember my selections and output path on this device</label>
          </div>
          <div className="flex justify-end">
            <div className="flex gap-2">
              <Button variant="ghost" className="bg-gray-50 text-gray-700 hover:bg-gray-100" onClick={onCloseApp}>Close</Button>
              <Button onClick={()=>{ if(validateStep1()) setStep(1); }}>Next</Button>
            </div>
          </div>
        </Card>
      );
    }
    if(step===1){
      return (
        <Card className="p-6 space-y-6">
          <div>
            <label className="font-semibold">Output File (CSV + Log Folder)</label>
            <div className="flex gap-2">
              <Input value={form.outputFile} onChange={(e:React.ChangeEvent<HTMLInputElement>)=>setForm((f:FormState)=>({...f,outputFile:e.target.value}))} placeholder="Choose output CSV file..." />
              <Button type="button" onClick={async ()=>{ const def = form.outputFile || await defaultOutputPath(); const file = await saveDialog({ defaultPath: def, filters:[{name:'CSV', extensions:['csv']}] }); if(file) setForm((f:FormState)=>({...f,outputFile:file as string})); }}>Browse…</Button>
            </div>
            {errors.outputFile && <div className="text-red-600 text-sm">{errors.outputFile}</div>}
            <div className="text-xs text-gray-600 mt-1">
            The selected folder will also contain the log file for this run.  The CSV name is chosen above; the log name will be <code>Purview_Export_YYYYMMDD_HHMMSS.log</code>.
            </div>
          </div>
          <div>
            <label className="font-semibold">Search interval</label>
            <div className="flex items-center gap-2 mt-1">
              <select
                className="border rounded px-2 py-1 bg-white"
                value={form.blockHours}
                onChange={(e)=> setForm((f:FormState)=>({...f, blockHours: parseInt(e.target.value, 10)}))}
              >
                {[2,4,6,8,12,24].map(h=> <option key={h} value={h}>{h} hours</option>)}
              </select>
              <span className="text-xs text-gray-600">
                How many hours per query window. Default is 8 hours. Shorter intervals (more frequent windows) make the export process take longer overall.
                {' '}
                <button
                  type="button"
                  className="text-blue-700 hover:underline"
                  title="Search-UnifiedAuditLog result limits and paging"
                  onClick={async ()=>{ try { await open('https://learn.microsoft.com/powershell/module/exchange/search-unifiedauditlog'); } catch(e:any){ queueLogLine('stderr', `Failed to open docs: ${e?.message || e}`); } }}
                >Learn about result limits</button>.
              </span>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Switch checked={form.overwrite} onCheckedChange={(v:boolean)=>setForm((f:FormState)=>({...f,overwrite:v}))} />
            <span>Overwrite if file exists</span>
          </div>
          <div className="pt-2">
            <details className="border rounded">
              <summary className="px-3 py-2 cursor-pointer select-none font-semibold">Advanced</summary>
              <div className="p-3 space-y-3 text-sm">
                <div>
                  <label className="font-semibold">Result size per call</label>
                  <div className="flex items-center gap-2 mt-1">
                    <input
                      type="number"
                      min={1}
                      max={5000}
                      step={100}
                      className="border rounded px-2 py-1 w-32"
                      value={form.resultSize}
                      onChange={(e)=> setForm((f)=> ({...f, resultSize: Math.max(1, Math.min(5000, parseInt(e.target.value||'0',10) || 0))}))}
                    />
                    <span className="text-xs text-gray-600">Default 5000. Higher returns more rows per call and reduces the chance of dropped records in busy windows.</span>
                  </div>
                </div>
                <div>
                  <label className="font-semibold">Pacing between calls (ms)</label>
                  <div className="flex items-center gap-2 mt-1">
                    <input
                      type="number"
                      min={0}
                      max={10000}
                      step={50}
                      className="border rounded px-2 py-1 w-32"
                      value={form.pacingMs}
                      onChange={(e)=> setForm((f)=> ({...f, pacingMs: Math.max(0, Math.min(10000, parseInt(e.target.value||'0',10) || 0))}))}
                    />
                    <span className="text-xs text-gray-600">Default 0. Add 150–300ms to reduce throttling (429/503) in busy tenants.</span>
                  </div>
                </div>
                <div className="flex justify-end pt-1">
                  <Button
                    type="button"
                    variant="ghost"
                    className="text-xs border hover:bg-gray-50"
                    onClick={()=> setForm((f:FormState)=> ({...f, resultSize: 5000, pacingMs: 0}))}
                  >Reset to defaults</Button>
                </div>
              </div>
            </details>
          </div>
          <div className="flex justify-between items-center">
            <Button variant="soft" onClick={()=>setStep(0)}>Back</Button>
            <div className="flex gap-2">
              <Button variant="ghost" className="bg-gray-50 text-gray-700 hover:bg-gray-100" onClick={onCloseApp}>Close</Button>
              <Button onClick={()=>{ if(validateStep2()) setStep(2); }}>Next</Button>
            </div>
          </div>
        </Card>
      );
    }
    if(step===2){
      return (
        <Card className="p-6 space-y-6">
          <h2 className="font-bold text-lg">Review & Run</h2>
          <div className="border-l-4 border-blue-500 bg-blue-50 p-3 rounded">
            <div className="flex items-center gap-2">
              <div className="font-semibold">Authentication</div>
              <Popover open={authInfoOpenReview} onOpenChange={setAuthInfoOpenReview}>
                <PopoverTrigger>
                  <button
                    type="button"
                    className="text-xs px-2 py-0.5 rounded border bg-white hover:bg-gray-50"
                    aria-label="What are the auth modes?"
                    onMouseEnter={()=>{ cancelAuthInfoClose('review'); setAuthInfoOpenReview(true); }}
                    onMouseLeave={()=> scheduleAuthInfoClose('review')}
                    onFocus={()=>{ cancelAuthInfoClose('review'); setAuthInfoOpenReview(true); }}
                    onBlur={()=> scheduleAuthInfoClose('review')}
                  >i</button>
                </PopoverTrigger>
                {authInfoOpenReview && (
                <PopoverContent
                  placement="right"
                  align="start"
                  className="max-w-sm text-sm"
                  onMouseEnter={()=>{ cancelAuthInfoClose('review'); setAuthInfoOpenReview(true); }}
                  onMouseLeave={()=> scheduleAuthInfoClose('review')}
                  tabIndex={0}
                  onFocus={()=>{ cancelAuthInfoClose('review'); setAuthInfoOpenReview(true); }}
                  onBlur={()=> scheduleAuthInfoClose('review')}
                >
                  <div className="font-semibold mb-1">Authentication modes</div>
                  <ul className="list-disc ml-5 space-y-1">
                    <li><span className="font-medium">Web Login</span>: Opens Microsoft sign-in in a native window; best for admin accounts with MFA.</li>
                    <li><span className="font-medium">Device Code</span>: Shows a code to enter at microsoft.com/devicelogin; useful if window prompts are blocked.</li>
                    <li><span className="font-medium">Credential</span>: Prompts for username/password; may fail with MFA/CA; not recommended unless allowed.</li>
                    <li><span className="font-medium">Silent</span>: Re-uses an existing session if available; fails otherwise.</li>
                  </ul>
                  <div className="mt-2">
                    <button
                      type="button"
                      className="text-blue-600 underline"
                      onClick={()=> open('https://learn.microsoft.com/powershell/module/exchange/connect-exchangeonline?view=exchange-ps')}
                    >Learn more: Connect-ExchangeOnline authentication options</button>
                  </div>
                </PopoverContent>
                )}
              </Popover>
            </div>
            <div className="text-sm mt-1">Mode: <span className="font-medium">{form.authMode}</span></div>
          </div>
          <div className="space-y-2 text-sm">
            <div><span className="font-semibold">Start Date:</span> {form.startDate}</div>
            <div><span className="font-semibold">End Date:</span> {form.endDate}</div>
            <div><span className="font-semibold">Search interval:</span> {form.blockHours} hours</div>
            <div><span className="font-semibold">Result size:</span> {form.resultSize}</div>
            <div><span className="font-semibold">Pacing (ms):</span> {form.pacingMs}</div>
            <div>
              <span className="font-semibold">Activities:</span> {form.activityIds.length} selected
              <div className="mt-2 flex flex-wrap gap-1">
                {form.activityIds.map(id=>{
                  const act = RELEVANT_ACTIVITIES.find(a=>a.id===id) || { name: id } as any;
                  return <span key={id} className="bg-blue-100 text-blue-800 px-2 py-0.5 rounded text-xs">{(act as any).name || id}</span>;
                })}
              </div>
            </div>
            <div><span className="font-semibold">Output File:</span> {form.outputFile}</div>
            <div className="flex items-center gap-2 mt-2">
              <Switch checked={form.detailedPost} onCheckedChange={(v:boolean)=> setForm((f:FormState)=>({...f, detailedPost: v}))} />
              <span>Show detailed post logs</span>
            </div>
            <div><span className="font-semibold">Remember Settings:</span> {form.remember ? 'Yes' : 'No'}</div>
          </div>
          <div className="flex justify-between items-center">
            <div className="flex gap-2">
              <Button variant="soft" onClick={()=>setStep(1)}>Back</Button>
              <Button 
                variant="ghost" 
                className="bg-blue-50 text-blue-700 border border-blue-300 hover:bg-blue-100" 
                onClick={async ()=>{
                  const def = (await getTempDir()) + `\\Purview_Export_Script_${timestamp()}.ps1`;
                  const file = await saveDialog({ defaultPath: def, filters:[{name:'PowerShell script', extensions:['ps1']}] });
                  if(!file) return;
                  try {
                    await invoke('export_hardcoded_script', {
                      startDate: form.startDate,
                      endDate: form.endDate,
                      activityTypes: form.activityIds,
                      outputFile: form.outputFile,
                      authMode: form.authMode,
                      blockHours: form.blockHours,
                      resultSize: form.resultSize,
                      pacingMs: form.pacingMs,
                      detailedPost: form.detailedPost,
                      targetPath: file,
                    });
                    // Show success message or navigate somewhere
                    alert(`PowerShell script exported to: ${file}`);
                  } catch(err:any){
                    const emsg = err?.message || String(err);
                    alert(`Export script failed: ${emsg}`);
                  }
                }}
                title="Generate a standalone PowerShell script with these exact settings"
              >
                📄 Export to .ps1
              </Button>
            </div>
            <div className="flex gap-2">
              <Button variant="ghost" className="bg-gray-50 text-gray-700 hover:bg-gray-100" onClick={onCloseApp}>Close</Button>
              <Button disabled={running} onClick={()=>{ setStep(3); runExport(); }}>Run Export</Button>
            </div>
          </div>
        </Card>
      );
    }
    // Step 3: Export
    if(step===3){
      return (
        <Card className="p-6 space-y-6">
          <div className="flex items-center gap-4">
            <span className={`px-3 py-1 rounded-full text-white text-sm ${status==='running'?'bg-blue-500':status==='success'?'bg-green-600':status==='error'?'bg-red-600':status==='noresults'?'bg-yellow-600':'bg-gray-400'}`}>{status==='running'?'Running':status==='success'?'Success':status==='error'?'Error':status==='noresults'?'No Results':'Idle'}</span>
            <div className="flex-1">
              <div className="flex items-center justify-between text-xs font-medium mb-1"><span>Overall progress</span><span>{overallPercent.toFixed(1)}%</span></div>
              <Progress value={overallPercent} />
              <div className="mt-2 flex items-center justify-between text-xs font-medium mb-1">
                <span>Current task progress {phase === 'post' && postCurrentCat ? `(post: ${postCurrentCat})` : phase !== 'unknown' ? `(${phase})` : ''}</span>
                <span>{(phase === 'post' && typeof postCurrentCatPercent === 'number') ? postCurrentCatPercent.toFixed(1) : percent.toFixed(1)}%</span>
              </div>
              <Progress value={(phase === 'post' && typeof postCurrentCatPercent === 'number') ? postCurrentCatPercent : percent} />
            </div>
          </div>
          {step===3 && (
            <div className="flex items-center gap-3 text-xs">
              <div className="flex items-center gap-2">
                <Switch checked={form.detailedPost} onCheckedChange={(v:boolean)=>{ setForm((f:FormState)=>({...f, detailedPost: v})); setShowDetailedFlipNotice(true); setTimeout(()=> setShowDetailedFlipNotice(false), 3000); }} />
                <span>Show detailed post logs</span>
              </div>
              {showDetailedFlipNotice && (
                <span className="px-2 py-1 rounded bg-blue-50 text-blue-700 border border-blue-200">Applies to the next run</span>
              )}
              <div className="ml-auto flex items-center gap-2">
                <input id="auto-scroll" type="checkbox" checked={autoScroll} onChange={(e)=> setAutoScroll(e.target.checked)} />
                <label htmlFor="auto-scroll">Auto scroll log</label>
              </div>
            </div>
          )}
          {showWebLoginHint && (
            <div className="border-2 border-red-500 bg-red-100 text-red-900 text-sm font-bold rounded p-3 shadow-lg animate-pulse">
              🔑 MICROSOFT SIGN-IN WINDOW OPENED - Complete authentication in the browser window to continue
            </div>
          )}
          {status==='noresults' && (
            <div className="border border-yellow-300 bg-yellow-50 text-yellow-900 text-sm rounded p-3">
              No results found for the selected dates and activities. Try expanding the date range or selecting different activities.
            </div>
          )}
          <div ref={logContainerRef} className="h-[55vh] min-h-[360px] overflow-auto bg-black text-xs p-2 rounded font-mono">
            {logs.map((l, i)=><div key={i} className={l.type==='stderr'?'text-red-400':'text-white'}>{l.line}</div>)}
          </div>
          <div className="w-full flex flex-col items-center gap-3">
            <div className="flex flex-wrap justify-center gap-2">
              <Button disabled={!csvPath || status==='noresults' || status==='error'} onClick={async ()=>{ if(!csvPath) return; try { await invoke('open_file_externally', { path: csvPath }); } catch(e:any){ queueLogLine('stderr', `Failed to open CSV: ${e?.message || e}`); } }}>Open CSV</Button>
              <Button disabled={!csvPath || status==='noresults' || status==='error'} onClick={async ()=>{ if(!csvPath) return; try { const idx = Math.max(csvPath.lastIndexOf('\\'), csvPath.lastIndexOf('/')); const folder = idx>=0 ? csvPath.substring(0, idx) : csvPath; await invoke('open_file_externally', { path: folder }); } catch(e:any){ queueLogLine('stderr', `Failed to open folder: ${e?.message || e}`); } }}>Open Folder</Button>
              <Button 
                onClick={async ()=> { 
                  console.log('Open Log clicked, logPath:', logPath);
                  queueLogLine('stderr', `Attempting to open log file: ${logPath}`);
                  if(!logPath) return; 
                  try { 
                    // Try using invoke to open the file via Rust backend
                    await invoke('open_file_externally', { path: logPath });
                  } catch(e:any){ 
                    console.error('Open log error via invoke:', e);
                    // Fallback: try the shell open with original path
                    try {
                      await open(logPath);
                    } catch(e2:any) {
                      console.error('Open log error via shell:', e2);
                      queueLogLine('stderr', `Failed to open log: ${e2?.message || e2}`); 
                    }
                  } 
                }}
              >Open Log</Button>
              <Button onClick={async ()=>{
              const def = (await getTempDir()) + `\\Purview_Export_Script_${timestamp()}.ps1`;
              const file = await saveDialog({ defaultPath: def, filters:[{name:'PowerShell script', extensions:['ps1']}] });
              if(!file) return;
              try {
                await invoke('export_hardcoded_script', {
                  startDate: form.startDate,
                  endDate: form.endDate,
                  activityTypes: form.activityIds,
                  outputFile: form.outputFile,
                  authMode: form.authMode,
                  blockHours: form.blockHours,
                  resultSize: form.resultSize,
                  pacingMs: form.pacingMs,
                  detailedPost: form.detailedPost,
                  targetPath: file,
                });
              } catch(err:any){
                const emsg = err?.message || String(err);
                queueLogLine('stderr', `Export script failed: ${emsg}`);
              }
            }}>Export as .ps1</Button>
            </div>
            <div className="flex flex-wrap justify-center gap-2">
              {canCancel ? (
                <>
                  <Button variant="ghost" className="bg-red-50 text-red-700 hover:bg-red-100" onClick={onCancelWizard}>Cancel</Button>
                </>
              ) : (
                <>
                  <Button
                    variant="ghost"
                    className="bg-gray-50 text-gray-700 hover:bg-gray-100"
                    onClick={onCloseApp}
                  >Close</Button>
                  <Button variant="soft" onClick={()=>{ /* run again or new run */ setStep(0); setStatus('idle'); setLogs([]); setCsvPath(null); setPercent(0); setOverallPercent(0); setPhase('unknown'); }}>Start Over</Button>
                </>
              )}
            </div>
          </div>
        </Card>
      );
    }
    return null;
  }

  return <div ref={rootRef} className="max-w-xl mx-auto pt-4 pb-2">
    <div className="flex items-start justify-between gap-2">
      <div className="flex-1 min-w-0">
        <Stepper step={step} steps={['Parameters','Output','Review','Export']} />
      </div>
      <HelpButton onClick={()=> setHelpOpen(true)} title="Help" />
    </div>
    <div className="mt-4">{renderStep()}</div>
    <HelpModal open={helpOpen} onClose={()=> setHelpOpen(false)} />
  </div>;
}

// Custom select to render a styled dropdown with a visible Recommended badge
function AuthModeSelect({ value, onChange }:{ value: 'WebLogin'|'DeviceCode'|'Credential'|'Silent'; onChange:(v:'WebLogin'|'DeviceCode'|'Credential'|'Silent')=>void }){
  const [open,setOpen] = React.useState(false);
  const triggerRef = React.useRef<HTMLButtonElement|null>(null);
  const contentRef = React.useRef<HTMLDivElement|null>(null);
  const options: Array<{value:'WebLogin'|'DeviceCode'|'Credential'|'Silent'; label:string; recommended?:boolean; desc:string}> = [
    { value:'WebLogin', label:'Web Login', recommended:true, desc:'Native Microsoft sign-in; best with MFA/CA.' },
    { value:'DeviceCode', label:'Device Code', desc:'Enter code at microsoft.com/devicelogin.' },
    { value:'Credential', label:'Credential Prompt', desc:'Username/password prompt; may fail with MFA/CA.' },
    { value:'Silent', label:'Silent (cached context)', desc:'Reuse existing session if available.' },
  ];
  const current = options.find(o=>o.value===value)!;
  const [activeIndex, setActiveIndex] = React.useState<number>(options.findIndex(o=>o.value===value));

  React.useEffect(()=>{
    if(open){
      const idx = options.findIndex(o=>o.value===value);
      setActiveIndex(idx >= 0 ? idx : 0);
    }
  },[open, value]);

  function selectIndex(idx:number){
    const opt = options[idx];
    if(!opt) return;
    onChange(opt.value);
    setOpen(false);
    // return focus to trigger for accessibility
    setTimeout(()=> triggerRef.current?.focus(), 0);
  }

  function onTriggerKeyDown(e: React.KeyboardEvent<HTMLButtonElement>){
    if(e.key === 'ArrowDown' || e.key === 'ArrowUp' || e.key === 'Enter' || e.key === ' '){
      e.preventDefault();
      if(!open){ setOpen(true); return; }
      if(e.key === 'ArrowDown') setActiveIndex(i=> (i+1) % options.length);
      else if(e.key === 'ArrowUp') setActiveIndex(i=> (i-1+options.length) % options.length);
      else if(e.key === 'Enter' || e.key === ' ') selectIndex(activeIndex);
    } else if(e.key === 'Escape'){
      if(open){ e.preventDefault(); setOpen(false); }
    }
  }

  function onContentKeyDown(e: React.KeyboardEvent<HTMLDivElement>){
    if(e.key === 'ArrowDown') { e.preventDefault(); setActiveIndex(i=> (i+1) % options.length); }
    else if(e.key === 'ArrowUp') { e.preventDefault(); setActiveIndex(i=> (i-1+options.length) % options.length); }
    else if(e.key === 'Enter') { e.preventDefault(); selectIndex(activeIndex); }
    else if(e.key === 'Escape') { e.preventDefault(); setOpen(false); setTimeout(()=> triggerRef.current?.focus(), 0); }
    else if(e.key === 'Tab') { setOpen(false); }
  }

  const listId = 'authmode-listbox';
  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger>
        <button
          ref={triggerRef}
          role="combobox"
          aria-haspopup="listbox"
          aria-expanded={open}
          aria-controls={listId}
          type="button"
          onClick={()=> setOpen(o=>!o)}
          onKeyDown={onTriggerKeyDown}
          className="w-full border rounded px-3 py-2 bg-white flex items-center justify-between"
        >
          <span className="flex items-center gap-2">
            {current.label}
            {current.recommended && <span className="text-[10px] px-1.5 py-0.5 rounded bg-green-100 text-green-800">Recommended</span>}
          </span>
          <span className="text-xs text-gray-500">▼</span>
        </button>
      </PopoverTrigger>
      {open && (
      <PopoverContent className="p-0" onKeyDown={onContentKeyDown}>
        <div ref={contentRef} role="listbox" id={listId} aria-activedescendant={`authmode-${activeIndex}`} className="w-80 p-2">
          <Command>
            <CommandList>
              <CommandGroup>
                {options.map((opt, idx)=> (
                  <CommandItem key={opt.value} className={(idx===activeIndex? 'bg-blue-50 ' : '') + 'rounded'} onSelect={()=>{ selectIndex(idx); }}>
                    <div id={`authmode-${idx}`} role="option" aria-selected={idx===activeIndex} className="flex flex-col w-full">
                      <div className="flex items-center justify-between">
                        <div className="font-medium">{opt.label}</div>
                        {opt.recommended && <span className="text-[10px] px-1.5 py-0.5 rounded bg-green-100 text-green-800">Recommended</span>}
                      </div>
                      <div className="text-xs text-gray-600">{opt.desc}</div>
                    </div>
                  </CommandItem>
                ))}
              </CommandGroup>
            </CommandList>
          </Command>
        </div>
      </PopoverContent>
      )}
    </Popover>
  );
}
