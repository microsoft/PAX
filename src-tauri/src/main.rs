#![cfg_attr(all(not(debug_assertions), target_os = "windows"), windows_subsystem = "windows")]

use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::sync::{Arc, Mutex};
use std::path::{Path, PathBuf};
#[cfg(not(debug_assertions))]
use std::fs;
#[cfg(not(debug_assertions))]
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::Window;
use tauri::Manager;
use regex::Regex;
use serde_json::Value;
#[cfg(windows)]
use std::os::windows::process::CommandExt; // for creation_flags on Windows child processes
#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

struct RunState {
  pid: Mutex<Option<u32>>, // store child PID for cancellation
}

// E
#[cfg(not(debug_assertions))]
const EMBEDDED_DATASET_MERGED: &str = include_str!("../../scripts/audit-activities.merged.json");
#[cfg(not(debug_assertions))]
const EMBEDDED_DATASET_GENERATED: &str = include_str!("../../scripts/audit-activities.generated.json");
#[cfg(not(debug_assertions))]
const EMBEDDED_DATASET_CURATED: &str = include_str!("../../scripts/audit-activities.json");
#[cfg(not(debug_assertions))]
const EMBEDDED_PS1: &str = include_str!("../../scripts/CopilotAuditExport.ps1");
#[cfg(not(debug_assertions))]
const EMBEDDED_SIMPLE_PS1: &str = include_str!("../../scripts/SimpleCopilotAuditExport.ps1");

#[cfg(not(debug_assertions))]
fn embedded_dataset_value() -> Option<serde_json::Value> {
  // Prefer merged > generated > curated
  for raw in [EMBEDDED_DATASET_MERGED, EMBEDDED_DATASET_GENERATED, EMBEDDED_DATASET_CURATED] {
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(raw) { return Some(v); }
  }
  None
}

#[cfg(not(debug_assertions))]
fn write_embedded_ps1_to_temp() -> Result<PathBuf, String> {
  let tmp = std::env::temp_dir();
  let millis = SystemTime::now().duration_since(UNIX_EPOCH).map_err(|e| format!("time error: {e}"))?.as_millis();
  let path = tmp.join(format!("PAX_CopilotAuditExport_{}.ps1", millis));
  fs::write(&path, EMBEDDED_PS1).map_err(|e| format!("Failed to write temp PS1: {e}"))?;
  Ok(path)
}

// Compute days difference between two ISO dates yyyy-mm-dd (end exclusive)
fn parse_ymd(s: &str) -> Option<(i32,i32,i32)> {
  let parts: Vec<&str> = s.split('-').collect();
  if parts.len()!=3 { return None; }
  let y = parts[0].parse::<i32>().ok()?;
  let m = parts[1].parse::<i32>().ok()?;
  let d = parts[2].parse::<i32>().ok()?;
  Some((y,m,d))
}
fn days_from_civil(y: i32, m: i32, d: i32) -> i64 {
  // Howard Hinnant algorithm
  let (y, m) = if m <= 2 { (y - 1, m + 12) } else { (y, m) };
  let era = (y as i64).div_euclid(400);
  let yoe = (y as i64) - era * 400;
  let doy = ((153 * (m as i64 - 3) + 2) / 5) + d as i64 - 1;
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + yoe / 400 + doy;
  era * 146097 + doe
}
fn days_between(start: &str, end: &str) -> Option<i64> {
  let (y1,m1,d1) = parse_ymd(start)?;
  let (y2,m2,d2) = parse_ymd(end)?;
  let a = days_from_civil(y1,m1,d1);
  let b = days_from_civil(y2,m2,d2);
  Some(b - a)
}


#[tauri::command]
async fn load_bundled_dataset(window: Window) -> Result<Value, String> {
  // Try resources first, then repo scripts, then current dir.
  let app = window.app_handle();
  let resolver = app.path_resolver();
  let mut candidates: Vec<PathBuf> = Vec::new();
  // In release, prefer embedded JSON to avoid needing bundled files
  #[cfg(not(debug_assertions))]
  {
    if let Some(v) = embedded_dataset_value() {
      // Provide simple counts for UI diagnostics
      let (cat_count, item_count) = match &v {
        Value::Object(map) => {
          if let Some(Value::Array(cats)) = map.get("categories") {
            let mut items = 0usize;
            for c in cats {
              if let Value::Object(co) = c {
                if let Some(Value::Array(arr)) = co.get("items") { items += arr.len(); }
              }
            }
            (cats.len(), items)
          } else { (0, 0) }
        }
        _ => (0, 0)
      };
      return Ok(serde_json::json!({
        "meta": { "sourcePath": "<embedded>", "categoryCount": cat_count, "itemCount": item_count },
        "dataset": v
      }));
    }
  }
  // Prefer merged (richer) first, then generated, then curated
  if let Some(p) = resolver.resolve_resource("scripts/audit-activities.merged.json") { candidates.push(p); }
  if let Some(p) = resolver.resolve_resource("scripts/audit-activities.generated.json") { candidates.push(p); }
  if let Some(p) = resolver.resolve_resource("scripts/audit-activities.json") { candidates.push(p); }
  // Repo scripts folder relative to src-tauri
  let repo_scripts = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../scripts");
  candidates.push(repo_scripts.join("audit-activities.merged.json"));
  candidates.push(repo_scripts.join("audit-activities.generated.json"));
  candidates.push(repo_scripts.join("audit-activities.json"));
  // Current working dir fallbacks
  if let Ok(cd) = std::env::current_dir() {
    candidates.push(cd.join("scripts/audit-activities.merged.json"));
    candidates.push(cd.join("scripts/audit-activities.generated.json"));
    candidates.push(cd.join("scripts/audit-activities.json"));
  }
  let chosen = candidates.into_iter().find(|p| p.exists())
    .ok_or("Bundled dataset not found in resources or scripts directory".to_string())?;
  let content = std::fs::read_to_string(&chosen).map_err(|e| format!("Failed to read dataset: {e}"))?;
  let json_val: Value = serde_json::from_str(&content).map_err(|e| format!("Failed to parse dataset: {e}"))?;
  // Provide simple counts to help the UI verify completeness without parsing deeply
  let (cat_count, item_count) = match &json_val {
    Value::Object(map) => {
      if let Some(Value::Array(cats)) = map.get("categories") {
        let mut items = 0usize;
        for c in cats {
          if let Value::Object(co) = c {
            if let Some(Value::Array(arr)) = co.get("items") { items += arr.len(); }
          }
        }
        (cats.len(), items)
      } else { (0, 0) }
    }
    _ => (0, 0)
  };
  Ok(serde_json::json!({
    "meta": { "sourcePath": chosen.to_string_lossy(), "categoryCount": cat_count, "itemCount": item_count },
    "dataset": json_val
  }))
}

#[tauri::command]
async fn preflight_exchange_module(window: Window) -> Result<(), String> {
  // Try PowerShell 7 first, fall back to PowerShell 5.1 for compatibility
  let pwsh_path = if cfg!(windows) {
    // On Windows, try pwsh.exe first, then powershell.exe
    which::which("pwsh.exe")
      .or_else(|_| which::which("powershell.exe"))
      .map_err(|_| "PowerShell not found. Please install PowerShell 5.1+ or PowerShell 7.\nInstall PowerShell 7: winget install --id Microsoft.Powershell -e\nDocs: https://learn.microsoft.com/powershell/".to_string())?
  } else {
    // On non-Windows, try pwsh first, then powershell
    which::which("pwsh")
      .or_else(|_| which::which("powershell"))
      .map_err(|_| "PowerShell not found. Please install PowerShell.\n  macOS:   brew install --cask powershell\n  Ubuntu:  sudo apt-get install -y powershell\n  Docs:    https://learn.microsoft.com/powershell/".to_string())?
  };
  // Execution policy (configurable). Priority:
  // 1) Runtime env: PURVIEW_EXEC_POLICY
  // 2) Build-time default: PURVIEW_EXEC_POLICY_DEFAULT (set at compile time)
  // 3) Fallback: Bypass
  let exec_policy = std::env::var("PURVIEW_EXEC_POLICY").ok()
    .or_else(|| option_env!("PURVIEW_EXEC_POLICY_DEFAULT").map(|s| s.to_string()))
    .unwrap_or_else(|| "Bypass".into());

  let script = r#"
  $ErrorActionPreference = 'Stop'
  if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host 'ExchangeOnlineManagement module not found. Installing for current user...' -ForegroundColor Yellow
    try {
      # Ensure NuGet is available
      if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false | Out-Null
      }
      # Trust PSGallery for this session
      Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
      Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      Write-Host 'ExchangeOnlineManagement installed.' -ForegroundColor Green
    } catch {
      Write-Error "Failed to install ExchangeOnlineManagement: $($_.Exception.Message)"
      exit 1
    }
  } else {
    Write-Host 'ExchangeOnlineManagement module is present.' -ForegroundColor Green
  }
  "#;

  let mut cmd = Command::new(pwsh_path);
  cmd.args(["-NoProfile","-ExecutionPolicy", &exec_policy, "-Command", script])
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());
  #[cfg(windows)]
  {
    cmd.creation_flags(CREATE_NO_WINDOW);
  }
  let mut child = cmd.spawn().map_err(|e| format!("Failed to spawn PowerShell for preflight: {e}"))?;

  let stdout = child.stdout.take().unwrap();
  let stderr = child.stderr.take().unwrap();
  let win_out = window.clone();
  let win_err = window.clone();
  std::thread::spawn(move || {
    let reader = BufReader::new(stdout);
    for line in reader.lines() { if let Ok(l)=line { let _ = win_out.emit("ps-log", serde_json::json!({"type":"stdout","line":l})); } }
  });
  std::thread::spawn(move || {
    let reader = BufReader::new(stderr);
    for line in reader.lines() { if let Ok(l)=line { let _ = win_err.emit("ps-log", serde_json::json!({"type":"stderr","line":l})); } }
  });

  let status = child.wait().map_err(|e| format!("Preflight failed: {e}"))?;
  if !status.success() { return Err(format!("Preflight exited with code {:?}", status.code())); }
  Ok(())
}

#[allow(non_snake_case)]
#[tauri::command]
async fn run_purview_script(
  window: Window,
  state: tauri::State<'_, RunState>,
  startDate: String,
  endDate: String,
  activityTypes: Vec<String>,
  outputFile: String,
  _overwrite: Option<bool>,
  blockHours: Option<u64>,
  authMode: Option<String>,
  detailedPost: Option<bool>,
  resultSize: Option<u64>,
  pacingMs: Option<u64>,
) -> Result<(), String> {
  // Try PowerShell 7 first, fall back to PowerShell 5.1 for compatibility
  let pwsh_path = if cfg!(windows) {
    // On Windows, try pwsh.exe first, then powershell.exe
    which::which("pwsh.exe")
      .or_else(|_| which::which("powershell.exe"))
      .map_err(|_| "PowerShell not found. Please install PowerShell 5.1+ or PowerShell 7.\nInstall PowerShell 7: winget install --id Microsoft.Powershell -e\nDocs: https://learn.microsoft.com/powershell/".to_string())?
  } else {
    // On non-Windows, try pwsh first, then powershell
    which::which("pwsh")
      .or_else(|_| which::which("powershell"))
      .map_err(|_| "PowerShell not found. Please install PowerShell.\n  macOS:   brew install --cask powershell\n  Ubuntu:  sudo apt-get install -y powershell\n  Docs:    https://learn.microsoft.com/powershell/".to_string())?
  };

  // Prefer the real repo script in dev; fall back to bundled resource otherwise
  let script_path: PathBuf = {
    #[cfg(debug_assertions)]
    {
      let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")); // points to src-tauri
      let candidate = manifest_dir.join("../scripts/CopilotAuditExport.ps1");
      if candidate.exists() {
        let p = std::fs::canonicalize(&candidate).unwrap_or(candidate);
        if cfg!(windows) {
          let s = p.to_string_lossy();
          let s = s.strip_prefix("\\\\?\\").unwrap_or(&s);
          PathBuf::from(s)
        } else { p }
      } else { candidate }
    }
    #[cfg(not(debug_assertions))]
    {
      write_embedded_ps1_to_temp()? // write to temp and return path
    }
  };

  // Emit script path and check existence for diagnostics
  let _ = window.emit("ps-log", serde_json::json!({"type":"stdout","line": format!("Using script: {}", script_path.display())}));
  if !script_path.exists() {
    let msg = format!("Script not found at resolved path: {}", script_path.display());
    let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line": msg}));
    return Err(msg);
  }

  // Ensure output directory exists
  if let Some(parent) = Path::new(&outputFile).parent() { if !parent.exists() {
    std::fs::create_dir_all(parent).map_err(|e| format!("Failed to create output directory {:?}: {e}", parent))?;
  }}

  // Build a single -Command string to run the script and merge PS streams so we capture Write-Host/Warning/etc.
  // Quote helpers for PS single-quoted strings
  let q = |s: &str| -> String { format!("'{}'", s.replace("'", "''")) };
  let script_q = q(&script_path.to_string_lossy());
  let mut inner = format!(
    "$ErrorActionPreference='Continue'; $InformationPreference='Continue'; $WarningPreference='Continue'; & {} -StartDate {} -EndDate {}",
    script_q,
    q(&startDate),
    q(&endDate)
  );
  if !activityTypes.is_empty() {
    let parts: Vec<String> = activityTypes.iter().map(|a| q(a)).collect();
    inner.push_str(&format!(" -ActivityTypes @({})", parts.join(",")));
  }
  inner.push_str(&format!(" -OutputFile {}", q(&outputFile)));
  if let Some(bh) = blockHours { inner.push_str(&format!(" -BlockHours {}", bh)); }
  let auth = authMode.unwrap_or_else(|| "WebLogin".into());
  inner.push_str(&format!(" -Auth {}", q(&auth)));
  // No helper needed; script will open system browser directly
  if detailedPost.unwrap_or(false) { inner.push_str(" -DetailedPost"); }
  if let Some(rs) = resultSize { inner.push_str(&format!(" -ResultSize {}", rs.min(5000))); }
  if let Some(pm) = pacingMs { inner.push_str(&format!(" -PacingMs {}", pm.min(10000))); }
  // Wrap in a script block and redirect streams 3..5 to 1 (stdout).
  // NOTE: We intentionally do NOT redirect 6 (Information) because Write-Host in PS7
  // writes to the Information stream AND to the host; redirecting 6 causes duplicate lines.
  let command_str = format!("& {{ {} }} 3>&1 4>&1 5>&1", inner);

  // PowerShell flags for predictable behavior
  // Execution policy (configurable). Priority order matches preflight.
  let exec_policy = std::env::var("PURVIEW_EXEC_POLICY").ok()
    .or_else(|| option_env!("PURVIEW_EXEC_POLICY_DEFAULT").map(|s| s.to_string()))
    .unwrap_or_else(|| "Bypass".into());
  let args: Vec<String> = vec![
    "-NoProfile".into(),
    "-ExecutionPolicy".into(), exec_policy.clone(),
    "-Command".into(), command_str.clone(),
  ];

  let _ = window.emit("ps-log", serde_json::json!({"type":"stdout","line": format!("Output will be written to: {}", outputFile)}));

  // Emit the command line for debugging
  let printable = format!("{} -NoProfile -ExecutionPolicy {} -Command {}", pwsh_path.display(), exec_policy, command_str);
  let _ = window.emit("ps-log", serde_json::json!({"type":"stdout","line": format!("Invoking: {}", printable)}));

  let mut cmd2 = Command::new(pwsh_path);
  cmd2.args(&args)
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());
  #[cfg(windows)]
  { cmd2.creation_flags(CREATE_NO_WINDOW); }
  let mut child = cmd2.spawn().map_err(|e| format!("Failed to spawn PowerShell: {e}"))?;

  // Store PID for potential cancellation
  if let Ok(mut slot) = state.pid.lock() { *slot = Some(child.id()); }

  let stdout = child.stdout.take().unwrap();
  let stderr = child.stderr.take().unwrap();
  let win_out = window.clone();
  let win_err = window.clone();
  let err_tail: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
  let err_tail_for_thread = err_tail.clone();

  // Defaults if markers aren't emitted
  let activities_count = activityTypes.len();
  let total_days = days_between(&startDate, &endDate).unwrap_or(0).max(0) as u64; // end exclusive
  let bh = blockHours.unwrap_or(8).max(1).min(24); // 1..24 safety, default 8
  let blocks_per_day: u64 = 24 / bh;
  let mut q_tot_fixed: u64 = total_days * blocks_per_day * (activities_count as u64);
  let mut k_tot_fixed: u64 = total_days * blocks_per_day;

  let out_handle = std::thread::spawn(move || {
    let reader = BufReader::new(stdout);
    // Match lines like: [42.5%] ...
    let re = Regex::new(r"^\[(?P<pct>\d+(?:\.\d+)?)%\]").ok();
    let re_query = Regex::new(r"(?i)Query\s+(?P<cur>\d+)/(\s?)(?P<tot>\d+)").ok();
  let re_kw = Regex::new(r"(?i)Keyword\s+Query\s+(?P<cur>\d+)/(\s?)(?P<tot>\d+)").ok();
  // Post-processing progress lines: "[nn%] Post a/b - ..."
  let re_post = Regex::new(r"(?i)Post\s+(?P<cur>\d+)/(\s?)(?P<tot>\d+)").ok();
    let re_kw_start = Regex::new(r"(?i)Starting keyword search for Copilot/AI in AuditData").ok();
  let re_totals = Regex::new(r"(?i)^\s*PA:TOTALS\s+queries\s*=\s*(?P<q>\d+)\s+keywords\s*=\s*(?P<k>\d+)(?:\s+post\s*=\s*(?P<p>\d+))?\s*$").ok();
  let re_phase = Regex::new(r"(?i)^\s*PA:PHASE\s+(?P<name>queries|keywords|post)\s+(?P<event>start|end)\s*$").ok();
  // Post category markers: PA:POST start|progress|end <cat> [x/y]
  let re_post_cat_start = Regex::new(r"(?i)^\s*PA:POST\s+start\s+(?P<cat>convert|export|sample|stats|finalize)\b(?:.*total\s*=\s*(?P<tot>\d+))?").ok();
  let re_post_cat_progress = Regex::new(r"(?i)^\s*PA:POST\s+progress\s+(?P<cat>convert|export|sample|stats|finalize)\s+(?P<cur>\d+)\s*/\s*(?P<tot>\d+)").ok();
  let re_post_cat_end = Regex::new(r"(?i)^\s*PA:POST\s+end\s+(?P<cat>convert|export|sample|stats|finalize)\b").ok();
  let mut phase: &str = "queries"; // or "keywords" | "post"
  let mut q_cur: u64 = 0; let mut q_tot: u64 = q_tot_fixed;
  let mut k_cur: u64 = 0; let mut k_tot: u64 = k_tot_fixed;
  let mut p_cur: u64 = 0; let mut p_tot: u64 = 0;
  // Track per-category post progress
  let mut post_cat_cur: std::collections::HashMap<String, u64> = std::collections::HashMap::new();
  let mut post_cat_tot: std::collections::HashMap<String, u64> = std::collections::HashMap::new();
  let mut post_current_cat: Option<String> = None;
    // Track dynamic totals seen in the stream (x/y) and marker-provided totals
  let mut q_tot_dyn: u64 = 0; let mut k_tot_dyn: u64 = 0; let mut p_tot_dyn: u64 = 0;
  let mut q_tot_marker: u64 = 0; let mut k_tot_marker: u64 = 0; let mut p_tot_marker: u64 = 0;
    // Keep overall progress monotonic non-decreasing
  let mut last_overall: f64 = 0.0;
    // Track last emitted line to suppress immediate duplicates (host + info echo etc.)
    let mut last_emitted: Option<String> = None;
    let ansi_re = Regex::new("\\x1B\\[[0-9;]*[A-Za-z]").ok();
    for line in reader.lines() {
      if let Ok(mut l) = line {
        // Remove ANSI escape sequences if any (PowerShell color codes etc.)
        if let Some(rx) = &ansi_re { l = rx.replace_all(&l, "").to_string(); }
        let l_lower = l.to_lowercase();
        // Phase inference and counts parsing
        if let Some(rx) = &re_totals { if let Some(c) = rx.captures(&l) {
          if let (Ok(a), Ok(b)) = (
            c.name("q").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(q_tot_fixed)),
            c.name("k").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(k_tot_fixed))
          ) {
            q_tot_marker = a; k_tot_marker = b; // capture marker totals
            q_tot_fixed = a; k_tot_fixed = b;   // align fixed totals to markers when available
            if let Some(pm) = c.name("p") { if let Ok(p) = pm.as_str().parse::<u64>() { p_tot_marker = p; p_tot = p; } }
          }
        }}
        if let Some(rx) = &re_phase { if let Some(c) = rx.captures(&l) {
          let name = c.name("name").map(|m| m.as_str()).unwrap_or(phase);
          let event = c.name("event").map(|m| m.as_str()).unwrap_or("start");
          if event == "start" {
            // Assign a static phase value to avoid borrowing from line buffer
            phase = if name == "keywords" { "keywords" } else if name == "post" { "post" } else { "queries" };
            // entering post phase
          } else if event == "end" {
            // leaving post phase
          }
        }}
        if let Some(rx) = &re_kw_start { if rx.is_match(&l) { phase = "keywords"; } }
        if let Some(rx) = &re_kw { if let Some(c) = rx.captures(&l) {
          if let (Ok(a), Ok(b)) = (
            c.name("cur").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(0)),
            c.name("tot").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(0))
          ) {
            k_cur = a; k_tot = b; k_tot_dyn = b; phase = "keywords";
          }
        }}
        // Avoid treating keyword lines as plain queries
        if !l_lower.contains("keyword") { if let Some(rx) = &re_query { if let Some(c) = rx.captures(&l) {
          if let (Ok(a), Ok(b)) = (
            c.name("cur").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(0)),
            c.name("tot").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(0))
          ) {
            q_cur = a; q_tot = b; q_tot_dyn = b; if k_tot == 0 { phase = "queries"; }
          }
        }}}
        // Post-processing counts
        if let Some(rx) = &re_post { if let Some(c) = rx.captures(&l) {
          if let (Ok(a), Ok(b)) = (
            c.name("cur").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(0)),
            c.name("tot").map(|m| m.as_str().parse::<u64>()).unwrap_or(Ok(0))
          ) {
            p_cur = a; p_tot = b; p_tot_dyn = b; phase = "post";
          }
        }}
        // Post category markers
        if let Some(rx) = &re_post_cat_start { if let Some(c) = rx.captures(&l) {
          let cat = c.name("cat").map(|m| m.as_str().to_lowercase()).unwrap_or("unknown".into());
          let tot = c.name("tot").and_then(|m| m.as_str().parse::<u64>().ok()).unwrap_or(0);
          if tot > 0 { post_cat_tot.insert(cat.clone(), tot); }
          post_cat_cur.entry(cat.clone()).or_insert(0);
          post_current_cat = Some(cat);
          phase = "post";
        } }
        if let Some(rx) = &re_post_cat_progress { if let Some(c) = rx.captures(&l) {
          let cat = c.name("cat").map(|m| m.as_str().to_lowercase()).unwrap_or("unknown".into());
          let cur = c.name("cur").and_then(|m| m.as_str().parse::<u64>().ok()).unwrap_or(0);
          let tot = c.name("tot").and_then(|m| m.as_str().parse::<u64>().ok()).unwrap_or(0);
          post_cat_cur.insert(cat.clone(), cur);
          if tot > 0 { post_cat_tot.insert(cat.clone(), tot); }
          post_current_cat = Some(cat);
          phase = "post";
        } }
        if let Some(rx) = &re_post_cat_end { if let Some(c) = rx.captures(&l) {
          let cat = c.name("cat").map(|m| m.as_str().to_lowercase()).unwrap_or("unknown".into());
          let tot = post_cat_tot.get(&cat).cloned().unwrap_or(1);
          post_cat_cur.insert(cat.clone(), tot);
          post_current_cat = Some(cat);
          phase = "post";
        } }

        let mut current_percent: Option<f64> = None;
        if let Some(r) = &re { if let Some(caps) = r.captures(&l) {
          if let Some(m) = caps.name("pct") { if let Ok(val) = m.as_str().parse::<f64>() { current_percent = Some(val); let _ = win_out.emit("ps-progress", serde_json::json!({"percent": val})); }}
        }}
        // Compute overall using weighted shares so keywords visibly move the bar
        // Strategy:
        // - Reserve pre_share (95%) for queries+keywords combined
        // - Allocate that pre_share between queries and keywords using their estimated totals,
        //   but clamp query share so it can't consume effectively all 95% when there are many activities.
        //   This ensures the overall bar still moves during the keyword phase.
        // - Reserve post_share (5%) for post-processing.
        let eff_q_tot = if q_tot_dyn > 0 { q_tot_dyn } else if q_tot_marker > 0 { q_tot_marker } else { q_tot_fixed };
        let eff_k_tot = if k_tot_dyn > 0 { k_tot_dyn } else if k_tot_marker > 0 { k_tot_marker } else { k_tot_fixed };
        let eff_p_tot = if p_tot_dyn > 0 { p_tot_dyn } else if p_tot_marker > 0 { p_tot_marker } else { p_tot };
        let mut overall_percent: Option<f64> = None;
        let pre_tot = eff_q_tot.saturating_add(eff_k_tot);
        if eff_q_tot + eff_k_tot + eff_p_tot > 0 {
          // Shares (of 100)
          let pre_share: f64 = 95.0; // queries + keywords combined
          let post_share: f64 = 100.0 - pre_share; // 5%

          // Determine query share within pre_share; clamp so queries can't exceed 90% overall
          // and leave at least 5% for keywords when both phases exist.
          let q_share: f64 = if pre_tot == 0 {
            0.0
          } else if eff_k_tot == 0 {
            pre_share // only queries exist pre-post
          } else if eff_q_tot == 0 {
            0.0
          } else {
            // raw proportional share within pre_share
            let raw = (eff_q_tot as f64 / pre_tot as f64) * pre_share;
            // clamp between 60% and 90% of overall
            let min_q: f64 = 60.0; // ensure queries visibly move bar early
            let max_q: f64 = 90.0; // keep headroom for keywords before post
            raw.max(min_q).min(max_q)
          };
          let k_share: f64 = if pre_tot == 0 { 0.0 } else { pre_share - q_share };

          // Phase progresses
          let q_prog = if eff_q_tot > 0 { (q_cur.min(eff_q_tot) as f64) / (eff_q_tot as f64) } else { 0.0 };
          let k_prog = if eff_k_tot > 0 { (k_cur.min(eff_k_tot) as f64) / (eff_k_tot as f64) } else { 0.0 };
          let p_prog = if eff_p_tot > 0 { (p_cur.min(eff_p_tot) as f64) / (eff_p_tot as f64) } else { 0.0 };

          let mut val = q_share * q_prog + k_share * k_prog + post_share * p_prog;
          if val < last_overall { val = last_overall; } // enforce monotonicity
          if val > 100.0 { val = 100.0; }
          last_overall = val;
          overall_percent = Some(val);
        }
        // Emit richer progress event
        // Compute current category percent if available
        let (cat_name, cat_pct) = if let Some(cat) = &post_current_cat {
          let cur = post_cat_cur.get(cat).cloned().unwrap_or(0) as f64;
          let tot = post_cat_tot.get(cat).cloned().unwrap_or(0) as f64;
          if tot > 0.0 { (Some(cat.clone()), Some(((cur/tot)*100.0).min(100.0))) } else { (Some(cat.clone()), None) }
        } else { (None, None) };

        let _ = win_out.emit("ps-progress2", serde_json::json!({
          "phase": phase,
          "currentPercent": current_percent,
          "overallPercent": overall_percent,
          "postCurrentCat": cat_name,
          "postCurrentCatPercent": cat_pct,
          "queries": {"current": q_cur, "total": q_tot},
          "keywords": {"current": k_cur, "total": k_tot},
          "post": {"current": p_cur, "total": eff_p_tot},
          "postCategories": {
            "convert": {"current": post_cat_cur.get("convert").cloned().unwrap_or(0), "total": post_cat_tot.get("convert").cloned().unwrap_or(0)},
            "export": {"current": post_cat_cur.get("export").cloned().unwrap_or(0), "total": post_cat_tot.get("export").cloned().unwrap_or(0)},
            "sample": {"current": post_cat_cur.get("sample").cloned().unwrap_or(0), "total": post_cat_tot.get("sample").cloned().unwrap_or(0)},
            "stats": {"current": post_cat_cur.get("stats").cloned().unwrap_or(0), "total": post_cat_tot.get("stats").cloned().unwrap_or(0)},
            "finalize": {"current": post_cat_cur.get("finalize").cloned().unwrap_or(0), "total": post_cat_tot.get("finalize").cloned().unwrap_or(0)}
          }
        }));
        // Emit log only if it's not an immediate duplicate
        let should_emit = match &last_emitted {
          Some(prev) => prev != &l,
          None => true,
        };
        if should_emit {
          let _ = win_out.emit("ps-log", serde_json::json!({"type":"stdout","line": l.clone()}));
          last_emitted = Some(l);
        }
      }
    }
  });
  let err_handle = std::thread::spawn(move || {
    let reader = BufReader::new(stderr);
    let mut last_emitted: Option<String> = None;
    for line in reader.lines() {
      if let Ok(l)=line {
        // retain last 10 stderr lines
        if let Ok(mut v) = err_tail_for_thread.lock() {
          v.push(l.clone());
          if v.len() > 10 { let _ = v.remove(0); }
        }
        // Emit if not an immediate duplicate
        let should_emit = match &last_emitted { Some(prev) => prev != &l, None => true };
        if should_emit {
          let _ = win_err.emit("ps-log", serde_json::json!({"type":"stderr","line":l.clone()}));
          last_emitted = Some(l);
        }
      }
    }
  });

  let status = child.wait().map_err(|e| format!("Failed waiting for script: {e}"))?;
  // Cleanup embedded temp script on release
  #[cfg(not(debug_assertions))]
  {
    let _ = fs::remove_file(&script_path);
  }
  out_handle.join().ok();
  err_handle.join().ok();

  // Clear stored PID
  if let Ok(mut slot) = state.pid.lock() { *slot = None; }

  if !status.success(){
    let _ = window.emit("ps-complete", serde_json::json!({
      "success": false,
      "code": status.code(),
      "outputFile": outputFile,
    }));
    let tail = err_tail.lock().ok().map(|v| v.clone()).unwrap_or_default();
    let extra = if tail.is_empty() { String::new() } else { format!("\nLast errors:\n{}", tail.join("\n")) };
    return Err(format!("Script exited with code {:?}{}", status.code(), extra));
  }
  // Success completion event
  let _ = window.emit("ps-complete", serde_json::json!({
    "success": true,
    "code": 0,
    "outputFile": outputFile,
  }));
  Ok(())
}

#[tauri::command]
async fn cancel_current_run(window: Window, state: tauri::State<'_, RunState>) -> Result<(), String> {
  let pid_opt = { state.pid.lock().ok().and_then(|g| *g) };
  if let Some(pid) = pid_opt {
    #[cfg(windows)]
    {
      let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line":format!("Cancellation requested by user. Killing PID {} via taskkill...", pid)}));
      let status = Command::new("taskkill").args(["/PID", &pid.to_string(), "/T", "/F"]).status()
        .map_err(|e| format!("Failed to invoke taskkill: {e}"))?;
      if !status.success() { return Err(format!("taskkill exited with code {:?}", status.code())); }
    }
    #[cfg(not(windows))]
    {
      let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line":format!("Cancellation requested by user. Sending SIGKILL to PID {}...", pid)}));
      let status = Command::new("kill").args(["-9", &pid.to_string()]).status()
        .map_err(|e| format!("Failed to invoke kill: {e}"))?;
      if !status.success() { return Err(format!("kill exited with code {:?}", status.code())); }
    }
    // Clear PID after attempting kill
    if let Ok(mut g) = state.pid.lock() { *g = None; }
    
    // Emit cancellation complete event
    let _ = window.emit("ps-cancelled", serde_json::json!({"success": true, "pid": pid}));
    let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line":"PowerShell process has been terminated"}));
  } else {
    let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line":"No running PowerShell process found to cancel"}));
  }
  Ok(())
}

#[allow(non_snake_case)]
#[tauri::command]
async fn export_hardcoded_script(
  window: Window,
  startDate: String,
  endDate: String,
  activityTypes: Vec<String>,
  outputFile: String,
  authMode: String,
  blockHours: Option<u64>,
  resultSize: Option<u64>,
  pacingMs: Option<u64>,
  detailedPost: Option<bool>,
  targetPath: String,
) -> Result<(), String> {
  // Use the full-featured original script (with PS 5.1 compatibility fixes)
  let src: String = {
    #[cfg(debug_assertions)]
    {
      let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
      let candidate = manifest_dir.join("../scripts/CopilotAuditExport.ps1");
      std::fs::read_to_string(&candidate).map_err(|e| format!("Failed to read source script: {e}"))?
    }
    #[cfg(not(debug_assertions))]
    {
      EMBEDDED_PS1.to_string()
    }
  };

  // Prepare header with hard-coded config (preserving full functionality)
  let esc = |s: &str| s.replace("'", "''");
  let acts: Vec<String> = activityTypes.iter().map(|a| format!("'{}'", esc(a))).collect();
  let bh = blockHours.unwrap_or(8);
  let header = format!(
    "# Auto-generated by Purview Audit Exporter\n# Help (summary):\n# - Exports Copilot/AI and user-facing activities from Microsoft 365 Purview audit logs to CSV.\n# - Auth modes: WebLogin (recommended), DeviceCode, Credential, Silent (falls back to web).\n# - EndDate is exclusive; queries run in time windows of BlockHours across the range.\n# - Backoff with jitter on 429/503; optional PacingMs helps reduce throttling.\n# - Emits structured markers: PA:TOTALS, PA:PHASE (queries|keywords|post), PA:POST <cat>.\n# Hard-coded criteria in this exported script:\n#   StartDate   : {sd}\n#   EndDate     : {ed}  (exclusive)\n#   Auth        : {au}\n#   BlockHours  : {bh}\n#   ResultSize  : {rs}\n#   PacingMs    : {pm}\n#   Output      : {of}\n#   Activities  :\n#     {acts}\n\n$StartDate = '{sd}'\n$EndDate = '{ed}'\n$Auth = '{au}'\n$BlockHours = {bh}\n$ResultSize = {rs}\n$PacingMs = {pm}\n$OutputFile = '{of}'\n$ActivityTypes = @({acts_list})\n\nWrite-Host 'Running with hard-coded criteria:' -ForegroundColor Cyan\nWrite-Host ('  StartDate   : ' + $StartDate)\nWrite-Host ('  EndDate     : ' + $EndDate + ' (exclusive)')\nWrite-Host ('  Auth        : ' + $Auth)\nWrite-Host ('  BlockHours  : ' + $BlockHours)\nWrite-Host ('  ResultSize  : ' + $ResultSize)\nWrite-Host ('  PacingMs    : ' + $PacingMs)\nWrite-Host ('  Output      : ' + $OutputFile)\nWrite-Host ('  Activities  : ' + ($ActivityTypes -join ', '))\n\n",
    sd = startDate,
    ed = endDate,
    au = authMode,
    of = outputFile,
    bh = bh,
    rs = resultSize.unwrap_or(5000).min(5000),
    pm = pacingMs.unwrap_or(0).min(10000),
    acts = activityTypes.join("\n#     "),
    acts_list = acts.join(",")
  );

  // If DetailedPost is requested, enable it in the exported script via a switch variable
  let detailed_switch = if detailedPost.unwrap_or(false) { "$DetailedPost = $true\n" } else { "$DetailedPost = $false\n" };

  let mut header_with_detail = header.clone();
  header_with_detail.push_str(detailed_switch);
  header_with_detail.push_str("Write-Host ('  DetailedPost: ' + $DetailedPost)\n\n");

  // Process the full-featured script while preserving all functionality
  let mut out = String::new();
  out.push_str(&header_with_detail);
  
  // Ensure exported script accepts the helper switch used for visible re-exec
  let replacement_param = "param([switch]$InHelper)\n\n";
  let mut skip_show_help = false;
  let mut skip_help_guard = false;
  let mut in_param = false;
  let mut param_paren_depth: i32 = 0;
  let mut injected_replacement_param = false;
  
  for line in src.lines() {
    let trimmed = line.trim();
    
    // Handle param block with proper parenthesis counting
    if !in_param && trimmed.starts_with("param(") {
      in_param = true;
      param_paren_depth = line.matches('(').count() as i32 - line.matches(')').count() as i32;
      continue;
    }
    if in_param {
      param_paren_depth += line.matches('(').count() as i32;
      param_paren_depth -= line.matches(')').count() as i32;
      if param_paren_depth <= 0 {
        in_param = false;
        if !injected_replacement_param {
          out.push_str(replacement_param);
          injected_replacement_param = true;
        }
      }
      continue;
    }
    
    // Skip Show-Help function (preserve complex functionality by removing only the help)
    if !skip_show_help && trimmed.starts_with("function Show-Help") {
      skip_show_help = true;
      continue;
    }
    if skip_show_help {
      if trimmed == "}" {
        skip_show_help = false;
      }
      continue;
    }
    
    // Skip help guard (preserve complex functionality by removing only the help check)
    if !skip_help_guard && trimmed.starts_with("if ($Help") {
      skip_help_guard = true;
      continue;
    }
    if skip_help_guard {
      if trimmed == "}" {
        skip_help_guard = false;
      }
      continue;
    }
    
    // Preserve all other functionality - authentication, retry logic, data transformation, etc.
    out.push_str(line);
    out.push('\n');
  }

  // Write to target path
  let parent = Path::new(&targetPath).parent().map(|p| p.to_path_buf()).unwrap_or(PathBuf::from("."));
  if !parent.exists() { std::fs::create_dir_all(&parent).map_err(|e| format!("Failed to create folder: {e}"))?; }
  std::fs::write(&targetPath, out).map_err(|e| format!("Failed to write exported script: {e}"))?;
  let _ = window.emit("ps-log", serde_json::json!({"type":"stdout","line": format!("Exported hard-coded script to: {}", targetPath)}));
  Ok(())
}

#[tauri::command]
async fn open_file_externally(path: String) -> Result<(), String> {
  // Use the system's default program to open the file
  #[cfg(target_os = "windows")]
  {
    Command::new("cmd")
      .args(&["/C", "start", "", &path])
      .creation_flags(CREATE_NO_WINDOW)
      .spawn()
      .map_err(|e| format!("Failed to open file: {e}"))?;
  }
  
  #[cfg(target_os = "macos")]
  {
    Command::new("open")
      .arg(&path)
      .spawn()
      .map_err(|e| format!("Failed to open file: {e}"))?;
  }
  
  #[cfg(target_os = "linux")]
  {
    Command::new("xdg-open")
      .arg(&path)
      .spawn()
      .map_err(|e| format!("Failed to open file: {e}"))?;
  }
  
  Ok(())
}

#[tauri::command]
async fn quit_app(app: tauri::AppHandle) -> Result<(), String> {
  // Exit the application process. Using app.exit ensures a clean shutdown.
  app.exit(0);
  Ok(())
}

fn main() {
  // Emit a build timestamp to stdout on startup (helps verify fresh build)
  if let Some(ts) = option_env!("PAX_BUILD_TS") {
    println!("PAX:BUILD_TS {}", ts);
  }
  tauri::Builder::default()
    .manage(RunState { pid: Mutex::new(None) })
    .invoke_handler(tauri::generate_handler![
      preflight_exchange_module,
      run_purview_script,
      cancel_current_run,
      export_hardcoded_script,
      open_file_externally,
      quit_app,
      load_bundled_dataset,
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
