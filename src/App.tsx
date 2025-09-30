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
import { RELEVANT_ACTIVITIES, CURATED_ACTIVITIES, ALL_ACTIVITIES, Activity } from './lib/activities';

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

// Enhanced log color coding function
function getLogLineColor(line: string): string {
  // Error patterns - highest priority (including Exchange Online errors)
  if (/error|failed|exception|cannot|unable|invalid|fatal|critical|write-error|server side error|operation could not be completed|reach out to ms support/i.test(line)) {
    return 'text-red-400';
  }
  
  // Warning patterns
  if (/warning|retry|throttle|backed|rate limit|timeout|slow|delay/i.test(line)) {
    return 'text-orange-400';
  }
  
  // Success patterns
  if (/success|completed|connected|authenticated|found \d+ records|extraction complete|done|finished|ready/i.test(line)) {
    return 'text-green-400';
  }
  
  // Progress patterns - important milestones
  if (/\[\d+\.\d+%\]|Query \d+\/\d+|PA:PHASE|PA:POST|===.*===|\d+\/\d+ -/i.test(line)) {
    return 'text-yellow-300 font-semibold';
  }
  
  // Major sections and connection events
  if (/PA:PHASE|PA:POST|===.*===|connecting|authentication|session|import.*module/i.test(line)) {
    return 'text-cyan-400';
  }
  
  // Performance and optimization
  if (/optimization|batch|consolidated query|memory|streaming|performance|\d+\.\d+s|records\/sec/i.test(line)) {
    return 'text-purple-400';
  }
  
  // Processing and activity
  if (/starting|processing|querying|fetching|searching|exporting|building/i.test(line)) {
    return 'text-blue-400';
  }
  
  // Debug and verbose info
  if (/debug|verbose|info|sample|stats|details/i.test(line)) {
    return 'text-gray-400';
  }
  
  // Default color for regular content
  return 'text-gray-300';
}

// Multi-part line highlighting function  
function renderLogLineWithHighlights(line: string): string {
  // First convert any ANSI codes to HTML, then apply our custom highlighting
  let processedLine = convertANSIToHTML(line);
  
  return processedLine
    // Progress percentages
    .replace(/(\[\d+\.\d+%\])/g, '<span class="text-yellow-300 font-bold bg-yellow-900/20 px-1 rounded">$1</span>')
    // Query numbers
    .replace(/(Query \d+\/\d+)/g, '<span class="text-blue-400 font-medium">$1</span>')
    // Record counts
    .replace(/(\d+ records?)/g, '<span class="text-green-400 font-medium">$1</span>')
    // Phase markers
    .replace(/(PA:PHASE|PA:POST)/g, '<span class="text-cyan-400 font-bold bg-cyan-900/20 px-1 rounded">$1</span>')
    // Consolidated query optimization
    .replace(/(Consolidated query for \d+ operations)/g, '<span class="text-purple-400 font-medium bg-purple-900/20 px-1 rounded">$1</span>')
    // Session IDs (shortened for readability)
    .replace(/(session [a-f0-9-]{8})[a-f0-9-]{28}/g, '<span class="text-indigo-400">$1...</span>')
    // Time stamps
    .replace(/(\d{4}-\d{2}-\d{2} \d{2}:\d{2})/g, '<span class="text-blue-300">$1</span>')
    // Error keywords (enhance Write-Error detection)
    .replace(/(Write-Error|error|failed|exception|server side error)/gi, '<span class="text-red-400 font-bold bg-red-900/20 px-1 rounded">$1</span>')
    // Success keywords  
    .replace(/(success|completed|done|found \d+ records)/gi, '<span class="text-green-400 font-medium bg-green-900/20 px-1 rounded">$1</span>');
}

// ANSI color codes for log file output
const ANSI_COLORS = {
  red: '\x1b[31m',
  green: '\x1b[32m', 
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  gray: '\x1b[90m',
  orange: '\x1b[38;5;208m',
  purple: '\x1b[38;5;141m',
  reset: '\x1b[0m',
  bold: '\x1b[1m'
};

// Get ANSI color for log file based on content
function getANSIColor(line: string): string {
  // Error patterns
  if (/error|failed|exception|cannot|unable|invalid|fatal|critical/i.test(line)) {
    return ANSI_COLORS.red + ANSI_COLORS.bold;
  }
  
  // Warning patterns
  if (/warning|retry|throttle|backed|rate limit|timeout|slow|delay/i.test(line)) {
    return ANSI_COLORS.orange;
  }
  
  // Success patterns
  if (/success|completed|connected|authenticated|found \d+ records|extraction complete|done|finished|ready/i.test(line)) {
    return ANSI_COLORS.green + ANSI_COLORS.bold;
  }
  
  // Progress patterns
  if (/\[\d+\.\d+%\]|Query \d+\/\d+|PA:PHASE|PA:POST|===.*===|\d+\/\d+ -/i.test(line)) {
    return ANSI_COLORS.yellow + ANSI_COLORS.bold;
  }
  
  // Major sections
  if (/PA:PHASE|PA:POST|===.*===|connecting|authentication|session|import.*module/i.test(line)) {
    return ANSI_COLORS.cyan + ANSI_COLORS.bold;
  }
  
  // Performance and optimization
  if (/optimization|batch|consolidated query|memory|streaming|performance|\d+\.\d+s|records\/sec/i.test(line)) {
    return ANSI_COLORS.purple;
  }
  
  // Processing and activity
  if (/starting|processing|querying|fetching|searching|exporting|building/i.test(line)) {
    return ANSI_COLORS.blue;
  }
  
  // Debug and verbose info
  if (/debug|verbose|info|sample|stats|details/i.test(line)) {
    return ANSI_COLORS.gray;
  }
  
  // Default white
  return ANSI_COLORS.white;
}

// Helper function to strip ANSI color codes from log lines when parsing saved files
function stripANSI(text: string): string {
  // Enhanced regex to handle all ANSI escape sequences including PowerShell Write-Error format
  return text
    .replace(/\x1b\[[0-9;]*m/g, '') // Standard ANSI codes
    .replace(/\[([0-9;]+)m/g, '') // Bracket-only format from Write-Error
    .replace(/\[0m/g, ''); // Reset codes
}

// Enhanced function to convert ANSI codes to HTML for better display
function convertANSIToHTML(text: string): string {
  return text
    // Handle standard ANSI codes
    .replace(/\x1b\[31m/g, '<span class="text-red-400">')
    .replace(/\x1b\[31;1m/g, '<span class="text-red-400 font-bold">')
    .replace(/\x1b\[32m/g, '<span class="text-green-400">')
    .replace(/\x1b\[33m/g, '<span class="text-yellow-400">')
    .replace(/\x1b\[34m/g, '<span class="text-blue-400">')
    .replace(/\x1b\[35m/g, '<span class="text-purple-400">')
    .replace(/\x1b\[36m/g, '<span class="text-cyan-400">')
    .replace(/\x1b\[37m/g, '<span class="text-white">')
    .replace(/\x1b\[90m/g, '<span class="text-gray-400">')
    .replace(/\x1b\[0m/g, '</span>')
    .replace(/\x1b\[1m/g, '<span class="font-bold">')
    // Handle PowerShell Write-Error bracket format
    .replace(/\[31;1m/g, '<span class="text-red-400 font-bold">')
    .replace(/\[31m/g, '<span class="text-red-400">')
    .replace(/\[32m/g, '<span class="text-green-400">')
    .replace(/\[33m/g, '<span class="text-yellow-400">')
    .replace(/\[34m/g, '<span class="text-blue-400">')
    .replace(/\[35m/g, '<span class="text-purple-400">')
    .replace(/\[36m/g, '<span class="text-cyan-400">')
    .replace(/\[37m/g, '<span class="text-white">')
    .replace(/\[90m/g, '<span class="text-gray-400">')
    .replace(/\[0m/g, '</span>')
    .replace(/\[1m/g, '<span class="font-bold">');
}

// Helper function to parse log line format with ANSI color support
function parseLogLine(line: string): LogLine {
  // Strip ANSI colors first, then parse the format
  const cleanLine = stripANSI(line);
  
  if (cleanLine.startsWith('[stdout] ')) {
    return { type: 'stdout' as const, line: cleanLine.substring(9) };
  } else if (cleanLine.startsWith('[stderr] ')) {
    return { type: 'stderr' as const, line: cleanLine.substring(9) };
  } else {
    return { type: 'stdout' as const, line: cleanLine };
  }
}

// ResultSize dropdown options
const RESULT_SIZE_OPTIONS = [
  { value: 50000, label: '50,000 (Maximum)' },
  { value: 40000, label: '40,000' },
  { value: 30000, label: '30,000' },
  { value: 25000, label: '25,000 (Default)' },
  { value: 20000, label: '20,000' },
  { value: 15000, label: '15,000' },
  { value: 10000, label: '10,000' },
  { value: 7500, label: '7,500' },
  { value: 5000, label: '5,000' },
  { value: 2500, label: '2,500' },
  { value: 1000, label: '1,000' }
];

interface FormState {
  startDate: string;
  endDate: string;
  activityIds: string[];
  outputFile: string;
  overwrite: boolean;
  blockHours: number;
  authMode: 'WebLogin' | 'DeviceCode' | 'Credential' | 'Silent';
  remember: boolean;
  resultSize: number;
  pacingMs: number;
  explodeArrays: boolean;
  copilotInteractionOnly: boolean;
  devTestMode: boolean;
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
  // Fallback - create temp directory if C:\Temp doesn't exist
  return 'C:\\Temp';
}
async function defaultOutputPath(){
  const dir = await getTempDir();
  return `${dir.replace(/\\$/, '')}\\PAX_Export_${timestamp()}.csv`;
}

async function createUniqueLogPathInDir(dir: string){
  const base = `${dir.replace(/\\$/, '')}\\PAX_Export_${timestamp()}`;
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
  blockHours: 0.5,
    resultSize: 25000,
    pacingMs: 0,
    authMode: 'WebLogin',
    remember: false,
    explodeArrays: false,
    copilotInteractionOnly: false,
    devTestMode: false,
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
  const [showWebLoginHint, setShowWebLoginHint] = useState(false);
  const [autoScroll, setAutoScroll] = useState<boolean>(true);
  const [authInfoOpen, setAuthInfoOpen] = useState(false);
  const [authInfoOpenReview, setAuthInfoOpenReview] = useState(false);
  const [totalFound,setTotalFound] = useState<number|null>(null);
  const [noResults,setNoResults] = useState(false);
  const [logPath, setLogPath] = useState<string | null>(null);
  const [helpOpen, setHelpOpen] = useState(false);
  const [loadingFullLog, setLoadingFullLog] = useState<boolean>(false);
  const logPathRef = React.useRef<string | null>(null);
  // Buffered logging to avoid UI stalls
  const logBufferRef = React.useRef<LogLine[]>([]);
  const fileLogBufferRef = React.useRef<string[]>([]);
  const lastLogRef = React.useRef<LogLine | null>(null);
  const uiFlushTimerRef = React.useRef<number | null>(null);
  const fileFlushTimerRef = React.useRef<number | null>(null);
  const LOG_UI_FLUSH_MS = 50; // batch UI updates ~20fps
  const LOG_FILE_FLUSH_MS = 200; // fewer fs writes
  const LOG_MAX_LINES = 15000; // increased buffer for full log history scrollback
  React.useEffect(()=>{ logPathRef.current = logPath; }, [logPath]);
  // Load saved auto-scroll preference
  useEffect(()=>{
    try {
      const raw = localStorage.getItem('pax_auto_scroll_log');
      if (raw === 'false') setAutoScroll(false);
    } catch {}
  },[]);
  // Persist auto-scroll preference
  useEffect(()=>{
    try { localStorage.setItem('pax_auto_scroll_log', String(autoScroll)); } catch {}
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
    
    // Add ANSI colors to log file for better readability in text editors that support colors
    const colorCode = getANSIColor(line);
    const coloredLine = `${colorCode}[${type}] ${line}${ANSI_COLORS.reset}${line.endsWith('\n') ? '' : '\n'}`;
    fileLogBufferRef.current.push(coloredLine);
    
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

  // Log navigation functions
  async function scrollLogToTop(){
    const el = logContainerRef.current;
    if (!el) return;
    
    // If we have a log file, load the beginning of the full file
    const p = logPathRef.current;
    if (p) {
      try {
        setLoadingFullLog(true);
        // Read the full log file
        const fullLogContent = await readTextFile(p);
        const allLines = fullLogContent.split('\n');
        
        if (allLines.length > LOG_MAX_LINES) {
          // Show the first LOG_MAX_LINES from the beginning of the file
          const topLines = allLines.slice(0, LOG_MAX_LINES);
          const topLogLines: LogLine[] = topLines.map(line => {
            // Parse the log format with ANSI color support
            return parseLogLine(line);
          }).filter(item => item.line.trim()); // Remove empty lines
          
          setLogs(topLogLines);
          setTimeout(() => {
            if (el) el.scrollTop = 0;
          }, 50);
          setAutoScroll(false);
        } else {
          // File is small enough, just scroll to top
          setTimeout(() => {
            if (el) el.scrollTop = 0;
          }, 50);
          setAutoScroll(false);
        }
      } catch (error) {
        console.log('Could not read full log file:', error);
        // Fallback: just scroll to top of current view
        el.scrollTop = 0;
        setAutoScroll(false);
      } finally {
        setLoadingFullLog(false);
      }
    } else {
      // Fallback: just scroll to top of current view
      el.scrollTop = 0;
      setAutoScroll(false);
    }
  }

  async function scrollLogToBottom(){
    const el = logContainerRef.current;
    if (!el) return;
    
    // If we have a log file, load the end of the full file
    const p = logPathRef.current;
    if (p) {
      try {
        setLoadingFullLog(true);
        // Read the full log file
        const fullLogContent = await readTextFile(p);
        const allLines = fullLogContent.split('\n');
        
        if (allLines.length > LOG_MAX_LINES) {
          // Show the last LOG_MAX_LINES from the end of the file
          const bottomLines = allLines.slice(-LOG_MAX_LINES);
          const bottomLogLines: LogLine[] = bottomLines.map(line => {
            // Parse the log format with ANSI color support
            return parseLogLine(line);
          }).filter(item => item.line.trim()); // Remove empty lines
          
          setLogs(bottomLogLines);
          setTimeout(() => {
            if (el) el.scrollTop = el.scrollHeight;
          }, 50);
          setAutoScroll(true);
        } else {
          // File is small enough, just scroll to bottom
          setTimeout(() => {
            if (el) el.scrollTop = el.scrollHeight;
          }, 50);
          setAutoScroll(true);
        }
      } catch (error) {
        console.log('Could not read full log file:', error);
        // Fallback: just scroll to bottom of current view
        el.scrollTop = el.scrollHeight;
        setAutoScroll(true);
      } finally {
        setLoadingFullLog(false);
      }
    } else {
      // Fallback: just scroll to bottom of current view
      el.scrollTop = el.scrollHeight;
      setAutoScroll(true);
    }
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
      const raw = localStorage.getItem('pax_audit_exporter_settings_v1');
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
            ...(typeof parsed.explodeArrays==='boolean'? {explodeArrays: parsed.explodeArrays}:{}),
            ...(parsed.authMode? {authMode: parsed.authMode}:{}),
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
        localStorage.setItem('pax_audit_exporter_settings_v1', JSON.stringify({
          startDate: form.startDate,
          endDate: form.endDate,
          activityIds: form.activityIds,
          outputFile: form.outputFile,
          overwrite: form.overwrite,
          blockHours: form.blockHours,
          resultSize: form.resultSize,
          pacingMs: form.pacingMs,
          authMode: form.authMode,
          explodeArrays: form.explodeArrays,
        }));
      } else {
        localStorage.removeItem('pax_audit_exporter_settings_v1');
      }
    } catch {}
  },[form.startDate, form.endDate, form.activityIds, form.outputFile, form.overwrite, form.blockHours, form.authMode, form.resultSize, form.pacingMs, form.explodeArrays, form.remember]);

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
    const curatedIds = new Set<string>((CURATED_ACTIVITIES||[]).map(a=>a.id));
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
      const curated = CURATED_ACTIVITIES.map(a=>a.id).filter(id=> allOps.has(id));
      if (curated.length){ setSelectionTouched(true); setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(curated)) })); return; }
      // Fallback: select everything
      const all = Object.values(dynCategories).flat().map(a=>a.id);
      setSelectionTouched(true);
      setForm((f:FormState)=>({...f, activityIds: Array.from(new Set(all)) }));
    } else {
      setSelectionTouched(true);
      setForm((f:FormState)=>({...f, activityIds: CURATED_ACTIVITIES.map(a=>a.id) }));
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
      await writeTextFile(lp, `=== Portable Audit eXporter (PAX) Log ===\nStarted: ${new Date().toISOString()}\nCSV: ${form.outputFile}\nLog: ${lp}\n`);
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
      
      await invoke('run_audit_script', {
        startDate: form.startDate,
        endDate: form.endDate,
        activityTypes: form.activityIds,
        outputFile: form.outputFile,
        overwrite: form.overwrite,
        blockHours: form.blockHours,
        authMode: form.authMode,
        resultSize: form.resultSize,
        pacingMs: form.pacingMs,
        explodeArrays: form.explodeArrays,
        copilotInteractionOnly: form.copilotInteractionOnly,
        devTestMode: form.devTestMode,
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
            <div className="text-xs text-gray-600 mt-1">Choose how to authenticate to Exchange Online for Microsoft 365 audit access.</div>
          </div>

          {/* Activities Section Label */}
          <div>
            <label className="font-semibold flex items-center gap-2">Activities
              <a
                className="text-blue-600 underline text-xs"
                href="#"
                onClick={(e)=>{ e.preventDefault(); open('https://learn.microsoft.com/en-us/purview/audit-log-activities'); }}
              >View full activity reference</a>
            </label>
          </div>

          {/* CopilotInteraction Only Toggle */}
          <div className="p-3 border rounded bg-blue-50">
            <div className="flex items-center gap-3">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.copilotInteractionOnly}
                  onChange={(e) => {
                    const enabled = e.target.checked;
                    setSelectionTouched(true);
                    setForm((f: FormState) => ({
                      ...f,
                      copilotInteractionOnly: enabled,
                      devTestMode: enabled ? false : f.devTestMode,
                      activityIds: enabled ? ['CopilotInteraction'] : CURATED_ACTIVITIES.map(a => a.id)
                    }));
                  }}
                  disabled={form.devTestMode}
                  className="rounded"
                />
                <span className="text-sm font-semibold text-blue-700">CopilotInteraction Only</span>
              </label>
              <span className="text-xs text-blue-600">
                Fast, focused extraction of core Copilot usage data only
              </span>
            </div>
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
                    <div className="flex flex-wrap gap-2 justify-center md:justify-start">
                      <Button 
                        type="button" 
                        variant="ghost" 
                        className="text-xs border hover:bg-gray-50" 
                        onClick={selectRecommended}
                        disabled={form.copilotInteractionOnly || form.devTestMode}
                      >
                        Select Recommended (40)
                      </Button>
                      <Button 
                        type="button" 
                        variant="ghost" 
                        className="text-xs border hover:bg-gray-50" 
                        onClick={selectEverything}
                        disabled={form.copilotInteractionOnly || form.devTestMode}
                      >
                        Select Everything
                      </Button>
                    </div>
                    <div className="text-[10px] text-gray-600 mt-2 space-y-1">
                      <div><strong>Recommended (40):</strong> Comprehensive Copilot & M365 activities</div>
                      <div><strong>Everything:</strong> All 1000+ available activities</div>
                    </div>
                  </div>
                  <ActivityMultiSelect
                    value={form.activityIds}
                    onChange={(ids:string[])=>{ setSelectionTouched(true); setForm((f:FormState)=>({...f,activityIds:ids})); }}
                    error={errors.activityIds}
                    disabled={form.copilotInteractionOnly || form.devTestMode}
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
                  <span className="ml-2">Loaded categories: {Object.keys(dynCategories || {}).length}, items: {Object.values(dynCategories || ALL_ACTIVITIES).reduce((n,arr)=>n+arr.length,0)}</span>
                  {datasetLoadError && <span className="ml-2 text-red-700">Load error: {datasetLoadError}</span>}
                </div>
              )}
              {/* Hide Learn refresh/discovery errors in simplified mode */}
              
              {/* Discovered operations UI removed in simplified mode */}
            </div>

          {/* Dev Test Mode Toggle - FOR TESTING ONLY */}
          <div className="p-3 border-2 border-orange-200 rounded bg-orange-50">
            <div className="flex items-center gap-3">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.devTestMode}
                  onChange={(e) => {
                    const enabled = e.target.checked;
                    setSelectionTouched(true);
                    setForm((f: FormState) => ({
                      ...f,
                      devTestMode: enabled,
                      copilotInteractionOnly: enabled ? false : f.copilotInteractionOnly,
                      activityIds: enabled ? ['CopilotInteraction'] : (f.copilotInteractionOnly ? ['CopilotInteraction'] : CURATED_ACTIVITIES.map(a => a.id))
                    }));
                  }}
                  className="rounded"
                />
                <span className="text-sm font-semibold text-orange-700">🧪 CopilotInteraction Only Dev Test</span>
              </label>
              <span className="text-xs text-orange-600">
                Testing mode: Filters for "Create" operations, converts to synthetic CopilotInteraction data
              </span>
            </div>
            {form.devTestMode && (
              <div className="mt-2 text-xs text-orange-600 bg-orange-100 p-2 rounded">
                <strong>⚠️ DEV TEST MODE ACTIVE:</strong> This will search for "Create" operations and convert them to realistic CopilotInteraction data with synthetic JSON structures. Remove before production release.
              </div>
            )}
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
            The selected folder will also contain the log file for this run.  The CSV name is chosen above; the log name will be <code>PAX_Export_YYYYMMDD_HHMMSS.log</code>.
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
                  <label className="font-semibold">Records per time block</label>
                  <div className="flex items-center gap-2 mt-1">
                    <select
                      className="border rounded px-2 py-1 w-40"
                      value={form.resultSize}
                      onChange={(e)=> setForm((f)=> ({...f, resultSize: parseInt(e.target.value, 10)}))}
                    >
                      {RESULT_SIZE_OPTIONS.map(option => (
                        <option key={option.value} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                    <span className="text-xs text-gray-600">Records to fetch per time block. Values &gt;5,000 use session-based pagination to bypass Exchange limits. Higher values = fewer API calls but longer sessions.</span>
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
                <div>
                  <label className="font-semibold">Search interval</label>
                  <div className="flex items-center gap-2 mt-1">
                    <select
                      className="border rounded px-2 py-1 bg-white"
                      value={form.blockHours}
                      onChange={(e)=> setForm((f:FormState)=>({...f, blockHours: parseFloat(e.target.value)}))}
                    >
                      {[
                        {value: 0.016667, label: "1 minute"},
                        {value: 0.033333, label: "2 minutes"},
                        {value: 0.066667, label: "4 minutes"},
                        {value: 0.133333, label: "8 minutes"},
                        {value: 0.25, label: "15 minutes"},
                        {value: 0.5, label: "30 minutes (Enterprise Default)"},
                        {value: 1, label: "1 hour"},
                        {value: 2, label: "2 hours"},
                        {value: 4, label: "4 hours"},
                        {value: 8, label: "8 hours"},
                        {value: 12, label: "12 hours"},
                        {value: 24, label: "24 hours"}
                      ].map(h=> <option key={h.value} value={h.value}>{h.label}</option>)}
                    </select>
                    <span className="text-xs text-gray-600">
                      Default is 30 minutes (enterprise-optimized). Auto-subdivides progressively when hitting limits. Shorter intervals prevent expensive throwaway queries.
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
                <div>
                  <label className="font-semibold">Array Explosion</label>
                  <div className="space-y-2 mt-1">
                    <div className="flex items-center gap-2">
                      <input
                        type="radio"
                        id="explode-true"
                        name="explodeArrays"
                        checked={form.explodeArrays === true}
                        onChange={() => setForm((f: FormState) => ({ ...f, explodeArrays: true }))}
                        className="w-4 h-4"
                      />
                      <label htmlFor="explode-true" className="text-sm">
                        <span className="font-medium">Create separate rows for each array element</span>
                        <span className="text-gray-600"> (detailed output, analytics-ready)</span>
                      </label>
                    </div>
                    <div className="flex items-center gap-2">
                      <input
                        type="radio"
                        id="explode-false"
                        name="explodeArrays"
                        checked={form.explodeArrays === false}
                        onChange={() => setForm((f: FormState) => ({ ...f, explodeArrays: false }))}
                        className="w-4 h-4"
                      />
                      <label htmlFor="explode-false" className="text-sm">
                        <span className="font-medium">Preserve raw JSON in AuditData column</span>
                        <span className="text-gray-600"> (simplified CSV with raw JSON for custom parsing)</span>
                      </label>
                    </div>
                  </div>
                </div>
                <div className="flex justify-end pt-1">
                  <Button
                    type="button"
                    variant="ghost"
                    className="text-xs border hover:bg-gray-50"
                    onClick={()=> setForm((f:FormState)=> ({...f, blockHours: 0.5, resultSize: 25000, pacingMs: 0, explodeArrays: true}))}
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
            <div><span className="font-semibold">Date Range:</span> {form.startDate} to {form.endDate}</div>
            <div><span className="font-semibold">Output File:</span> {form.outputFile}</div>
            <div><span className="font-semibold">Authentication Mode:</span> {form.authMode}</div>
            <div><span className="font-semibold">Block Hours (Time Window):</span> {form.blockHours}</div>
            <div><span className="font-semibold">Result Size (Records per API call):</span> {form.resultSize}</div>
            <div><span className="font-semibold">Pacing (Delay between calls):</span> {form.pacingMs}ms</div>
            <div><span className="font-semibold">Max Concurrent Queries:</span> 3 (default)</div>
            <div><span className="font-semibold">Array Explosion:</span> {form.explodeArrays ? 'Enabled (separate rows)' : 'Disabled (raw JSON)'}</div>
            <div>
              <span className="font-semibold">Activity Types:</span> {form.activityIds.length} selected
              <div className="mt-2 flex flex-wrap gap-1">
                {form.activityIds.map(id=>{
                  const act = RELEVANT_ACTIVITIES.find(a=>a.id===id) || { name: id } as any;
                  return <span key={id} className="bg-blue-100 text-blue-800 px-2 py-0.5 rounded text-xs">{(act as any).name || id}</span>;
                })}
              </div>
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
                  const def = (await getTempDir()) + `\\PAX_Export_Script_${timestamp()}.ps1`;
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
                      explodeArrays: form.explodeArrays,
                      copilotInteractionOnly: form.copilotInteractionOnly,
                      devTestMode: form.devTestMode,
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
            <div className="flex items-center gap-3 text-xs mb-2">
              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  onClick={scrollLogToTop}
                  disabled={loadingFullLog}
                  className="h-7 px-3 text-xs bg-blue-600 hover:bg-blue-700 text-white disabled:opacity-50 disabled:bg-gray-500 transition-all duration-200 shadow-sm"
                  title="Load and scroll to beginning of full log file"
                >
                  {loadingFullLog ? "⏳" : "↑ Top"}
                </Button>
                <Button
                  type="button"
                  onClick={scrollLogToBottom}
                  disabled={loadingFullLog}
                  className="h-7 px-3 text-xs bg-blue-600 hover:bg-blue-700 text-white disabled:opacity-50 disabled:bg-gray-500 transition-all duration-200 shadow-sm"
                  title="Load and scroll to end of full log file"
                >
                  {loadingFullLog ? "⏳" : "↓ Bottom"}
                </Button>
                <div className="text-gray-500 text-xs ml-2">
                  {logs.length > 0 && `${logs.length.toLocaleString()} lines`}
                </div>
              </div>
              <div className="ml-auto flex items-center gap-2">
                <input 
                  id="auto-scroll" 
                  type="checkbox" 
                  checked={autoScroll} 
                  onChange={(e)=> setAutoScroll(e.target.checked)}
                  className="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 focus:ring-2"
                />
                <label htmlFor="auto-scroll" className="text-gray-600 font-medium">Auto scroll log</label>
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
          <div ref={logContainerRef} className="h-[55vh] min-h-[360px] overflow-auto bg-gray-900 text-xs p-3 rounded-lg font-mono border border-gray-700 shadow-inner">
            {logs.map((l, i) => {
              // Use stderr for base color detection, then apply intelligent pattern matching
              const baseColor = l.type === 'stderr' ? 'text-red-400' : getLogLineColor(l.line);
              const highlightedContent = renderLogLineWithHighlights(l.line);
              
              return (
                <div 
                  key={i} 
                  className={`${baseColor} leading-relaxed hover:bg-gray-800/30 px-1 py-0.5 rounded transition-colors duration-150`}
                  dangerouslySetInnerHTML={{ __html: highlightedContent }}
                />
              );
            })}
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
              const def = (await getTempDir()) + `\\PAX_Export_Script_${timestamp()}.ps1`;
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
                  explodeArrays: form.explodeArrays,
                  copilotInteractionOnly: form.copilotInteractionOnly,
                  devTestMode: form.devTestMode,
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
