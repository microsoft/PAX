#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use regex::Regex;
use serde_json::Value;
#[cfg(not(debug_assertions))]
use std::fs;
use std::io::{BufRead, BufReader};
#[cfg(windows)]
use std::os::windows::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
#[cfg(not(debug_assertions))]
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::Manager;
use tauri::Window; // for creation_flags on Windows child processes
#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

struct RunState {
    pid: Mutex<Option<u32>>, // store child PID for cancellation
}

// E
#[cfg(not(debug_assertions))]
const EMBEDDED_DATASET_MERGED: &str = include_str!("../../scripts/audit-activities.merged.json");
#[cfg(not(debug_assertions))]
const EMBEDDED_DATASET_GENERATED: &str =
    include_str!("../../scripts/audit-activities.generated.json");
#[cfg(not(debug_assertions))]
const EMBEDDED_DATASET_CURATED: &str = include_str!("../../scripts/audit-activities.json");
#[cfg(not(debug_assertions))]
const EMBEDDED_PS1: &str = include_str!("../../scripts/CopilotAuditExport.ps1");
#[cfg(not(debug_assertions))]
const EMBEDDED_SIMPLE_PS1: &str = include_str!("../../scripts/SimpleCopilotAuditExport.ps1");

#[cfg(not(debug_assertions))]
fn embedded_dataset_value() -> Option<serde_json::Value> {
    // Prefer merged > generated > curated
    for raw in [
        EMBEDDED_DATASET_MERGED,
        EMBEDDED_DATASET_GENERATED,
        EMBEDDED_DATASET_CURATED,
    ] {
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(raw) {
            return Some(v);
        }
    }
    None
}

#[cfg(not(debug_assertions))]
fn write_embedded_ps1_to_temp() -> Result<PathBuf, String> {
    let tmp = std::env::temp_dir();
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| format!("time error: {e}"))?
        .as_millis();
    let path = tmp.join(format!("PAX_CopilotAuditExport_{}.ps1", millis));
    fs::write(&path, EMBEDDED_PS1).map_err(|e| format!("Failed to write temp PS1: {e}"))?;
    Ok(path)
}

// Compute days difference between two ISO dates yyyy-mm-dd (end exclusive)
fn parse_ymd(s: &str) -> Option<(i32, i32, i32)> {
    let parts: Vec<&str> = s.split('-').collect();
    if parts.len() != 3 {
        return None;
    }
    let y = parts[0].parse::<i32>().ok()?;
    let m = parts[1].parse::<i32>().ok()?;
    let d = parts[2].parse::<i32>().ok()?;
    Some((y, m, d))
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
    let (y1, m1, d1) = parse_ymd(start)?;
    let (y2, m2, d2) = parse_ymd(end)?;
    let a = days_from_civil(y1, m1, d1);
    let b = days_from_civil(y2, m2, d2);
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
                                if let Some(Value::Array(arr)) = co.get("items") {
                                    items += arr.len();
                                }
                            }
                        }
                        (cats.len(), items)
                    } else {
                        (0, 0)
                    }
                }
                _ => (0, 0),
            };
            return Ok(serde_json::json!({
              "meta": { "sourcePath": "<embedded>", "categoryCount": cat_count, "itemCount": item_count },
              "dataset": v
            }));
        }
    }
    // Prefer merged (richer) first, then generated, then curated
    if let Some(p) = resolver.resolve_resource("scripts/audit-activities.merged.json") {
        candidates.push(p);
    }
    if let Some(p) = resolver.resolve_resource("scripts/audit-activities.generated.json") {
        candidates.push(p);
    }
    if let Some(p) = resolver.resolve_resource("scripts/audit-activities.json") {
        candidates.push(p);
    }
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
    let chosen = candidates
        .into_iter()
        .find(|p| p.exists())
        .ok_or("Bundled dataset not found in resources or scripts directory".to_string())?;
    let content =
        std::fs::read_to_string(&chosen).map_err(|e| format!("Failed to read dataset: {e}"))?;
    let json_val: Value =
        serde_json::from_str(&content).map_err(|e| format!("Failed to parse dataset: {e}"))?;
    // Provide simple counts to help the UI verify completeness without parsing deeply
    let (cat_count, item_count) = match &json_val {
        Value::Object(map) => {
            if let Some(Value::Array(cats)) = map.get("categories") {
                let mut items = 0usize;
                for c in cats {
                    if let Value::Object(co) = c {
                        if let Some(Value::Array(arr)) = co.get("items") {
                            items += arr.len();
                        }
                    }
                }
                (cats.len(), items)
            } else {
                (0, 0)
            }
        }
        _ => (0, 0),
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
    // 1) Runtime env: PAX_EXEC_POLICY
    // 2) Build-time default: PAX_EXEC_POLICY_DEFAULT (set at compile time)
    // 3) Fallback: Bypass
    let exec_policy = std::env::var("PAX_EXEC_POLICY")
        .ok()
        .or_else(|| option_env!("PAX_EXEC_POLICY_DEFAULT").map(|s| s.to_string()))
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
    cmd.args([
        "-NoProfile",
        "-ExecutionPolicy",
        &exec_policy,
        "-Command",
        script,
    ])
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());
    #[cfg(windows)]
    {
        cmd.creation_flags(CREATE_NO_WINDOW);
    }
    let mut child = cmd
        .spawn()
        .map_err(|e| format!("Failed to spawn PowerShell for preflight: {e}"))?;

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();
    let win_out = window.clone();
    let win_err = window.clone();
    std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            if let Ok(l) = line {
                let _ = win_out.emit("ps-log", serde_json::json!({"type":"stdout","line":l}));
            }
        }
    });
    std::thread::spawn(move || {
        let reader = BufReader::new(stderr);
        for line in reader.lines() {
            if let Ok(l) = line {
                let _ = win_err.emit("ps-log", serde_json::json!({"type":"stderr","line":l}));
            }
        }
    });

    let status = child.wait().map_err(|e| format!("Preflight failed: {e}"))?;
    if !status.success() {
        return Err(format!("Preflight exited with code {:?}", status.code()));
    }
    Ok(())
}

#[allow(non_snake_case)]
#[tauri::command]
async fn run_audit_script(
    window: Window,
    state: tauri::State<'_, RunState>,
    startDate: String,
    endDate: String,
    activityTypes: Vec<String>,
    outputFile: String,
    _overwrite: Option<bool>,
    blockHours: Option<f64>,
    authMode: Option<String>,
    resultSize: Option<u64>,
    pacingMs: Option<u64>,
    explodeArrays: Option<bool>,
    copilotInteractionOnly: Option<bool>,
    devTestMode: Option<bool>,
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
                } else {
                    p
                }
            } else {
                candidate
            }
        }
        #[cfg(not(debug_assertions))]
        {
            write_embedded_ps1_to_temp()? // write to temp and return path
        }
    };

    // Emit script path and check existence for diagnostics
    let _ = window.emit("ps-log", serde_json::json!({"type":"stdout","line": format!("Using script: {}", script_path.display())}));
    if !script_path.exists() {
        let msg = format!(
            "Script not found at resolved path: {}",
            script_path.display()
        );
        let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line": msg}));
        return Err(msg);
    }

    // Ensure output directory exists
    if let Some(parent) = Path::new(&outputFile).parent() {
        if !parent.exists() {
            std::fs::create_dir_all(parent)
                .map_err(|e| format!("Failed to create output directory {:?}: {e}", parent))?;
        }
    }

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
    if let Some(bh) = blockHours {
        inner.push_str(&format!(" -BlockHours {}", bh));
    }
    let auth = authMode.unwrap_or_else(|| "WebLogin".into());
    inner.push_str(&format!(" -Auth {}", q(&auth)));
    // No helper needed; script will open system browser directly
    if let Some(rs) = resultSize {
        inner.push_str(&format!(" -ResultSize {}", rs.min(10000)));
    }
    if let Some(pm) = pacingMs {
        inner.push_str(&format!(" -PacingMs {}", pm.min(10000)));
    }
    if let Some(ea) = explodeArrays {
        if !ea {
            inner.push_str(" -NoExplodeArrays");
        }
    }
    if copilotInteractionOnly == Some(true) {
        inner.push_str(" -CopilotInteractionOnly");
    }
    if devTestMode == Some(true) {
        inner.push_str(" -DevTest");
    }

    // Note: PowerShell script handles its own logging automatically
    // Wrap in a script block and redirect streams 3..5 to 1 (stdout).
    // NOTE: We intentionally do NOT redirect 6 (Information) because Write-Host in PS7
    // writes to the Information stream AND to the host; redirecting 6 causes duplicate lines.
    let command_str = format!("& {{ {} }} 3>&1 4>&1 5>&1", inner);

    // PowerShell flags for predictable behavior
    // Execution policy (configurable). Priority order matches preflight.
    let exec_policy = std::env::var("PAX_EXEC_POLICY")
        .ok()
        .or_else(|| option_env!("PAX_EXEC_POLICY_DEFAULT").map(|s| s.to_string()))
        .unwrap_or_else(|| "Bypass".into());
    let args: Vec<String> = vec![
        "-NoProfile".into(),
        "-ExecutionPolicy".into(),
        exec_policy.clone(),
        "-Command".into(),
        command_str.clone(),
    ];

    let _ = window.emit("ps-log", serde_json::json!({"type":"stdout","line": format!("Output will be written to: {}", outputFile)}));

    // Emit the command line for debugging
    let printable = format!(
        "{} -NoProfile -ExecutionPolicy {} -Command {}",
        pwsh_path.display(),
        exec_policy,
        command_str
    );
    let _ = window.emit(
        "ps-log",
        serde_json::json!({"type":"stdout","line": format!("Invoking: {}", printable)}),
    );

    let mut cmd2 = Command::new(pwsh_path);
    cmd2.args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    #[cfg(windows)]
    {
        cmd2.creation_flags(CREATE_NO_WINDOW);
    }
    let mut child = cmd2
        .spawn()
        .map_err(|e| format!("Failed to spawn PowerShell: {e}"))?;

    // Store PID for potential cancellation
    if let Ok(mut slot) = state.pid.lock() {
        *slot = Some(child.id());
    }

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();
    let win_out = window.clone();
    let win_err = window.clone();
    let err_tail: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    let err_tail_for_thread = err_tail.clone();

    // Defaults if markers aren't emitted
    let activities_count = activityTypes.len();
    let total_days = days_between(&startDate, &endDate).unwrap_or(0).max(0) as u64; // end exclusive
    let bh = blockHours.unwrap_or(0.5).max(0.016667).min(24.0); // 1min to 24h safety, default 30min
    let blocks_per_day: u64 = (24.0 / bh).ceil() as u64;
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
        let re_kw_start =
            Regex::new(r"(?i)Starting keyword search for Copilot/AI in AuditData").ok();
        let re_totals = Regex::new(r"(?i)^\s*PA:TOTALS\s+queries\s*=\s*(?P<q>\d+)\s+keywords\s*=\s*(?P<k>\d+)(?:\s+post\s*=\s*(?P<p>\d+))?\s*$").ok();
        let re_phase = Regex::new(
            r"(?i)^\s*PA:PHASE\s+(?P<name>queries|keywords|post)\s+(?P<event>start|end)\s*$",
        )
        .ok();
        // Post category markers: PA:POST start|progress|end <cat> [x/y]
        let re_post_cat_start = Regex::new(r"(?i)^\s*PA:POST\s+start\s+(?P<cat>convert|export|sample|stats|finalize)\b(?:.*total\s*=\s*(?P<tot>\d+))?").ok();
        let re_post_cat_progress = Regex::new(r"(?i)^\s*PA:POST\s+progress\s+(?P<cat>convert|export|sample|stats|finalize)\s+(?P<cur>\d+)\s*/\s*(?P<tot>\d+)").ok();
        let re_post_cat_end =
            Regex::new(r"(?i)^\s*PA:POST\s+end\s+(?P<cat>convert|export|sample|stats|finalize)\b")
                .ok();
        let mut phase: &str = "queries"; // or "keywords" | "post"
        let mut q_cur: u64 = 0;
        let mut q_tot: u64 = q_tot_fixed;
        let mut k_cur: u64 = 0;
        let mut k_tot: u64 = k_tot_fixed;
        let mut p_cur: u64 = 0;
        let mut p_tot: u64 = 0;
        // Track per-category post progress
        let mut post_cat_cur: std::collections::HashMap<String, u64> =
            std::collections::HashMap::new();
        let mut post_cat_tot: std::collections::HashMap<String, u64> =
            std::collections::HashMap::new();
        let mut post_current_cat: Option<String> = None;
        // Track dynamic totals seen in the stream (x/y) and marker-provided totals
        let mut q_tot_dyn: u64 = 0;
        let mut k_tot_dyn: u64 = 0;
        let mut p_tot_dyn: u64 = 0;
        let mut q_tot_marker: u64 = 0;
        let mut k_tot_marker: u64 = 0;
        let mut p_tot_marker: u64 = 0;
        // Keep overall progress monotonic non-decreasing
        let mut last_overall: f64 = 0.0;
        // Track last emitted line to suppress immediate duplicates (host + info echo etc.)
        let mut last_emitted: Option<String> = None;
        let ansi_re = Regex::new("\\x1B\\[[0-9;]*[A-Za-z]").ok();
        for line in reader.lines() {
            if let Ok(mut l) = line {
                // Remove ANSI escape sequences if any (PowerShell color codes etc.)
                if let Some(rx) = &ansi_re {
                    l = rx.replace_all(&l, "").to_string();
                }
                let l_lower = l.to_lowercase();
                // Phase inference and counts parsing
                if let Some(rx) = &re_totals {
                    if let Some(c) = rx.captures(&l) {
                        if let (Ok(a), Ok(b)) = (
                            c.name("q")
                                .map(|m| m.as_str().parse::<u64>())
                                .unwrap_or(Ok(q_tot_fixed)),
                            c.name("k")
                                .map(|m| m.as_str().parse::<u64>())
                                .unwrap_or(Ok(k_tot_fixed)),
                        ) {
                            q_tot_marker = a;
                            k_tot_marker = b; // capture marker totals
                            q_tot_fixed = a;
                            k_tot_fixed = b; // align fixed totals to markers when available
                            if let Some(pm) = c.name("p") {
                                if let Ok(p) = pm.as_str().parse::<u64>() {
                                    p_tot_marker = p;
                                    p_tot = p;
                                }
                            }
                        }
                    }
                }
                if let Some(rx) = &re_phase {
                    if let Some(c) = rx.captures(&l) {
                        let name = c.name("name").map(|m| m.as_str()).unwrap_or(phase);
                        let event = c.name("event").map(|m| m.as_str()).unwrap_or("start");
                        if event == "start" {
                            // Assign a static phase value to avoid borrowing from line buffer
                            phase = if name == "keywords" {
                                "keywords"
                            } else if name == "post" {
                                "post"
                            } else {
                                "queries"
                            };
                            // entering post phase
                        } else if event == "end" {
                            // leaving post phase
                        }
                    }
                }
                if let Some(rx) = &re_kw_start {
                    if rx.is_match(&l) {
                        phase = "keywords";
                    }
                }
                if let Some(rx) = &re_kw {
                    if let Some(c) = rx.captures(&l) {
                        if let (Ok(a), Ok(b)) = (
                            c.name("cur")
                                .map(|m| m.as_str().parse::<u64>())
                                .unwrap_or(Ok(0)),
                            c.name("tot")
                                .map(|m| m.as_str().parse::<u64>())
                                .unwrap_or(Ok(0)),
                        ) {
                            k_cur = a;
                            k_tot = b;
                            k_tot_dyn = b;
                            phase = "keywords";
                        }
                    }
                }
                // Avoid treating keyword lines as plain queries
                if !l_lower.contains("keyword") {
                    if let Some(rx) = &re_query {
                        if let Some(c) = rx.captures(&l) {
                            if let (Ok(a), Ok(b)) = (
                                c.name("cur")
                                    .map(|m| m.as_str().parse::<u64>())
                                    .unwrap_or(Ok(0)),
                                c.name("tot")
                                    .map(|m| m.as_str().parse::<u64>())
                                    .unwrap_or(Ok(0)),
                            ) {
                                q_cur = a;
                                q_tot = b;
                                q_tot_dyn = b;
                                if k_tot == 0 {
                                    phase = "queries";
                                }
                            }
                        }
                    }
                }
                // Post-processing counts
                if let Some(rx) = &re_post {
                    if let Some(c) = rx.captures(&l) {
                        if let (Ok(a), Ok(b)) = (
                            c.name("cur")
                                .map(|m| m.as_str().parse::<u64>())
                                .unwrap_or(Ok(0)),
                            c.name("tot")
                                .map(|m| m.as_str().parse::<u64>())
                                .unwrap_or(Ok(0)),
                        ) {
                            p_cur = a;
                            p_tot = b;
                            p_tot_dyn = b;
                            phase = "post";
                        }
                    }
                }
                // Post category markers
                if let Some(rx) = &re_post_cat_start {
                    if let Some(c) = rx.captures(&l) {
                        let cat = c
                            .name("cat")
                            .map(|m| m.as_str().to_lowercase())
                            .unwrap_or("unknown".into());
                        let tot = c
                            .name("tot")
                            .and_then(|m| m.as_str().parse::<u64>().ok())
                            .unwrap_or(0);
                        if tot > 0 {
                            post_cat_tot.insert(cat.clone(), tot);
                        }
                        post_cat_cur.entry(cat.clone()).or_insert(0);
                        post_current_cat = Some(cat);
                        phase = "post";
                    }
                }
                if let Some(rx) = &re_post_cat_progress {
                    if let Some(c) = rx.captures(&l) {
                        let cat = c
                            .name("cat")
                            .map(|m| m.as_str().to_lowercase())
                            .unwrap_or("unknown".into());
                        let cur = c
                            .name("cur")
                            .and_then(|m| m.as_str().parse::<u64>().ok())
                            .unwrap_or(0);
                        let tot = c
                            .name("tot")
                            .and_then(|m| m.as_str().parse::<u64>().ok())
                            .unwrap_or(0);
                        post_cat_cur.insert(cat.clone(), cur);
                        if tot > 0 {
                            post_cat_tot.insert(cat.clone(), tot);
                        }
                        post_current_cat = Some(cat);
                        phase = "post";
                    }
                }
                if let Some(rx) = &re_post_cat_end {
                    if let Some(c) = rx.captures(&l) {
                        let cat = c
                            .name("cat")
                            .map(|m| m.as_str().to_lowercase())
                            .unwrap_or("unknown".into());
                        let tot = post_cat_tot.get(&cat).cloned().unwrap_or(1);
                        post_cat_cur.insert(cat.clone(), tot);
                        post_current_cat = Some(cat);
                        phase = "post";
                    }
                }

                let mut current_percent: Option<f64> = None;
                if let Some(r) = &re {
                    if let Some(caps) = r.captures(&l) {
                        if let Some(m) = caps.name("pct") {
                            if let Ok(val) = m.as_str().parse::<f64>() {
                                current_percent = Some(val);
                                let _ = win_out
                                    .emit("ps-progress", serde_json::json!({"percent": val}));
                            }
                        }
                    }
                }
                // Compute overall using weighted shares so keywords visibly move the bar
                // Strategy:
                // - Reserve pre_share (95%) for queries+keywords combined
                // - Allocate that pre_share between queries and keywords using their estimated totals,
                //   but clamp query share so it can't consume effectively all 95% when there are many activities.
                //   This ensures the overall bar still moves during the keyword phase.
                // - Reserve post_share (5%) for post-processing.
                let eff_q_tot = if q_tot_dyn > 0 {
                    q_tot_dyn
                } else if q_tot_marker > 0 {
                    q_tot_marker
                } else {
                    q_tot_fixed
                };
                let eff_k_tot = if k_tot_dyn > 0 {
                    k_tot_dyn
                } else if k_tot_marker > 0 {
                    k_tot_marker
                } else {
                    k_tot_fixed
                };
                let eff_p_tot = if p_tot_dyn > 0 {
                    p_tot_dyn
                } else if p_tot_marker > 0 {
                    p_tot_marker
                } else {
                    p_tot
                };
                let mut overall_percent: Option<f64> = None;
                // Since keywords phase no longer exists, simplify to queries + post-processing only
                if eff_q_tot + eff_p_tot > 0 {
                    // Realistic shares based on actual workflow timing
                    let q_share: f64 = 80.0; // queries take ~80% of total time
                    let post_share: f64 = 20.0; // post-processing takes ~20% (15% + 5% final)

                    // Phase progresses
                    let q_prog = if eff_q_tot > 0 {
                        (q_cur.min(eff_q_tot) as f64) / (eff_q_tot as f64)
                    } else {
                        0.0
                    };
                    let p_prog = if eff_p_tot > 0 {
                        (p_cur.min(eff_p_tot) as f64) / (eff_p_tot as f64)
                    } else {
                        0.0
                    };

                    let mut val = q_share * q_prog + post_share * p_prog;
                    if val < last_overall {
                        val = last_overall;
                    } // enforce monotonicity
                    if val > 100.0 {
                        val = 100.0;
                    }
                    last_overall = val;
                    overall_percent = Some(val);
                }
                // Emit richer progress event
                // Compute current category percent if available
                let (cat_name, cat_pct) = if let Some(cat) = &post_current_cat {
                    let cur = post_cat_cur.get(cat).cloned().unwrap_or(0) as f64;
                    let tot = post_cat_tot.get(cat).cloned().unwrap_or(0) as f64;
                    if tot > 0.0 {
                        (Some(cat.clone()), Some(((cur / tot) * 100.0).min(100.0)))
                    } else {
                        (Some(cat.clone()), None)
                    }
                } else {
                    (None, None)
                };

                let _ = win_out.emit("ps-progress2", serde_json::json!({
          "phase": phase,
          "currentPercent": current_percent,
          "overallPercent": overall_percent,
          "postCurrentCat": cat_name,
          "postCurrentCatPercent": cat_pct,
          "queries": {"current": q_cur, "total": q_tot},
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
                    let _ = win_out.emit(
                        "ps-log",
                        serde_json::json!({"type":"stdout","line": l.clone()}),
                    );
                    last_emitted = Some(l);
                }
            }
        }
    });
    let err_handle = std::thread::spawn(move || {
        let reader = BufReader::new(stderr);
        let mut last_emitted: Option<String> = None;
        for line in reader.lines() {
            if let Ok(l) = line {
                // retain last 10 stderr lines
                if let Ok(mut v) = err_tail_for_thread.lock() {
                    v.push(l.clone());
                    if v.len() > 10 {
                        let _ = v.remove(0);
                    }
                }
                // Emit if not an immediate duplicate
                let should_emit = match &last_emitted {
                    Some(prev) => prev != &l,
                    None => true,
                };
                if should_emit {
                    let _ = win_err.emit(
                        "ps-log",
                        serde_json::json!({"type":"stderr","line":l.clone()}),
                    );
                    last_emitted = Some(l);
                }
            }
        }
    });

    let status = child
        .wait()
        .map_err(|e| format!("Failed waiting for script: {e}"))?;
    // Cleanup embedded temp script on release
    #[cfg(not(debug_assertions))]
    {
        let _ = fs::remove_file(&script_path);
    }
    out_handle.join().ok();
    err_handle.join().ok();

    // Clear stored PID
    if let Ok(mut slot) = state.pid.lock() {
        *slot = None;
    }

    if !status.success() {
        let _ = window.emit(
            "ps-complete",
            serde_json::json!({
              "success": false,
              "code": status.code(),
              "outputFile": outputFile,
            }),
        );
        let tail = err_tail.lock().ok().map(|v| v.clone()).unwrap_or_default();
        let extra = if tail.is_empty() {
            String::new()
        } else {
            format!("\nLast errors:\n{}", tail.join("\n"))
        };
        return Err(format!(
            "Script exited with code {:?}{}",
            status.code(),
            extra
        ));
    }
    // Success completion event
    let _ = window.emit(
        "ps-complete",
        serde_json::json!({
          "success": true,
          "code": 0,
          "outputFile": outputFile,
        }),
    );
    Ok(())
}

#[tauri::command]
async fn cancel_current_run(
    window: Window,
    state: tauri::State<'_, RunState>,
) -> Result<(), String> {
    let pid_opt = { state.pid.lock().ok().and_then(|g| *g) };
    if let Some(pid) = pid_opt {
        #[cfg(windows)]
        {
            let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line":format!("Cancellation requested by user. Killing PID {} via taskkill...", pid)}));
            let status = Command::new("taskkill")
                .args(["/PID", &pid.to_string(), "/T", "/F"])
                .status()
                .map_err(|e| format!("Failed to invoke taskkill: {e}"))?;
            if !status.success() {
                return Err(format!("taskkill exited with code {:?}", status.code()));
            }
        }
        #[cfg(not(windows))]
        {
            let _ = window.emit("ps-log", serde_json::json!({"type":"stderr","line":format!("Cancellation requested by user. Sending SIGKILL to PID {}...", pid)}));
            let status = Command::new("kill")
                .args(["-9", &pid.to_string()])
                .status()
                .map_err(|e| format!("Failed to invoke kill: {e}"))?;
            if !status.success() {
                return Err(format!("kill exited with code {:?}", status.code()));
            }
        }
        // Clear PID after attempting kill
        if let Ok(mut g) = state.pid.lock() {
            *g = None;
        }

        // Emit cancellation complete event
        let _ = window.emit(
            "ps-cancelled",
            serde_json::json!({"success": true, "pid": pid}),
        );
        let _ = window.emit(
            "ps-log",
            serde_json::json!({"type":"stderr","line":"PowerShell process has been terminated"}),
        );
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
    blockHours: Option<f64>,
    resultSize: Option<u64>,
    pacingMs: Option<u64>,
    explodeArrays: Option<bool>,
    copilotInteractionOnly: Option<bool>,
    devTestMode: Option<bool>,
    targetPath: String,
) -> Result<(), String> {
    // Use the full-featured original script (with PS 5.1 compatibility fixes)
    let src: String = {
        #[cfg(debug_assertions)]
        {
            let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
            let candidate = manifest_dir.join("../scripts/CopilotAuditExport.ps1");
            std::fs::read_to_string(&candidate)
                .map_err(|e| format!("Failed to read source script: {e}"))?
        }
        #[cfg(not(debug_assertions))]
        {
            EMBEDDED_PS1.to_string()
        }
    };

    // For exported scripts, preserve user's activity selection to ensure identical behavior
    let bh = blockHours.unwrap_or(0.5).max(0.016667).min(24.0); // 30min default, 1min-24h range

    // Format ActivityTypes array for PowerShell
    let activities_ps = if activityTypes.is_empty() {
        "# Using script's built-in default activities\n".to_string()
    } else {
        format!(
            "$ActivityTypes = @(\n{}\n)\n",
            activityTypes
                .iter()
                .map(|a| format!("    '{}'", a.replace("'", "''")))
                .collect::<Vec<_>>()
                .join(",\n")
        )
    };

    // Check if user left the default app-generated path vs selected a custom path
    // Default pattern: ends with "PAX_Export_YYYYMMDD_HHMMSS.csv" (generated by defaultOutputPath())
    let is_app_default_pattern = {
        use regex::Regex;
        let pattern = Regex::new(r"\\PAX_Export_\d{8}_\d{6}\.csv$")
            .unwrap_or_else(|_| Regex::new("").unwrap());
        pattern.is_match(&outputFile)
    };

    let (output_file_config, csv_output_desc, runtime_note) = if outputFile.is_empty() {
        // No path specified - use PowerShell script's built-in default
        (
            "# No output file specified - using PowerShell script's built-in default".to_string(),
            "Using script default path".to_string(),
            " (script default)".to_string(),
        )
    } else if is_app_default_pattern {
        // User left the app's default suggestion - generate fresh timestamp at script runtime
        let path_without_filename = {
            use regex::Regex;
            let pattern = Regex::new(r"\\PAX_Export_\d{8}_\d{6}\.csv$")
                .unwrap_or_else(|_| Regex::new("").unwrap());
            pattern.replace(&outputFile, "").to_string()
        };
        (
      format!("# Generate fresh timestamp for default path at script runtime\n$OutputFile = '{path}\\PAX_Export_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.csv'", path = path_without_filename),
      format!("Dynamic: {}\\PAX_Export_YYYYMMDD_HHMMSS.csv", path_without_filename),
      " (fresh timestamp at runtime)".to_string()
    )
    } else {
        // User selected a custom path/filename - use it exactly
        (
            format!(
                "# Export to user-selected custom output file path\n$OutputFile = '{}'",
                outputFile.replace("'", "''")
            ),
            outputFile.clone(),
            " (custom user selection)".to_string(),
        )
    };

    // Build config vars in smaller chunks to avoid Rust string literal issues
    let header_comment = format!(
        "# Auto-generated by Microsoft Portable Audit eXporter (PAX) - v{}\n\
        # \n\
        # OVERVIEW:\n\
        # - Exports Microsoft 365 Copilot/AI and user activity audit logs to CSV\n\
        # - Uses curated activity tiers: Tier 1=Copilot core, Tier 2=Teams context, Tier 3=Files context\n\
        # - Creates automatic transcript logs (.log files) alongside CSV output\n\
        # - Handles Microsoft 365 throttling with exponential backoff and optional pacing\n\
        # \n\
        # IMPORTANT - QUERY TIMING:\n\
        # - Individual queries may appear to 'hang' for 30-120 seconds - this is NORMAL\n\
        # - Microsoft 365 audit system processes complex queries server-side, causing apparent delays\n\
        # - Be patient during query phases - true timeouts are very rare (10+ minutes)\n\
        # - Progress shows '[25%] Query 5/20 - ActivityName' then waits for Microsoft's response\n\
        # \n\
        # AUTHENTICATION: {} (WebLogin=browser, DeviceCode=code entry, Credential=stored creds)\n\
        # TIME WINDOWS: Queries run in {}-hour blocks across date range (EndDate exclusive)\n\
        # THROTTLING: {}ms pacing between API calls (0=no delay, 500-2000 recommended for busy tenants)\n\
        # STRUCTURED MARKERS: Emits PA:TOTALS, PA:PHASE, PA:POST for automated parsing\n\
        # \n\
        # HARD-CODED CRITERIA (configured via PAX application):\n\
        #   Start Date  : {} (inclusive - data from this date included)\n\
        #   End Date    : {} (exclusive - data up to but not including this date)\n\
        #   Auth Mode   : {}\n\
        #   Block Hours : {} (smaller = more queries, better for large datasets)\n\
        #   Result Size : {} records per API call\n\
        #   Pacing Ms   : {} milliseconds delay between requests\n\
        #   CSV Output  : {}\n\
        #   Log File    : Auto-generated .log file in same directory\n\
        #   Activities  : {} curated activities selected in PAX\n\n",
        env!("CARGO_PKG_VERSION"),
        authMode,
        bh,
        pacingMs.unwrap_or(0).min(10000),
        startDate,
        endDate,
        authMode,
        bh,
        resultSize.unwrap_or(10000).min(10000),
        pacingMs.unwrap_or(0).min(10000),
        csv_output_desc,
        activityTypes.len()
    );

    let powershell_vars = format!(
        "$StartDate = '{}'\n\
        $EndDate = '{}'\n\
        $Auth = '{}'\n\
        $BlockHours = {}\n\
        $ResultSize = {}\n\
        $PacingMs = {}\n\
        $NoExplodeArrays = ${}\n\
        $CopilotInteractionOnly = ${}\n\
        $DevTest = ${}\n\
        {}\n\
        # Generate log file name based on output file\n\
        $LogFile = $OutputFile -replace '\\.csv$', '.log'\n\
        if ($LogFile -eq $OutputFile) {{ $LogFile += '.log' }}\n\
        {}\n\n",
        startDate,
        endDate,
        authMode,
        bh,
        resultSize.unwrap_or(10000).min(10000),
        pacingMs.unwrap_or(0).min(10000),
        if explodeArrays == Some(false) {
            "true"
        } else {
            "false"
        },
        if copilotInteractionOnly == Some(true) {
            "true"
        } else {
            "false"
        },
        if devTestMode == Some(true) {
            "true"
        } else {
            "false"
        },
        output_file_config,
        activities_ps
    );

    let display_config = format!(
        "Write-Host 'PAX Auto-Generated Script - Hard-coded Configuration:' -ForegroundColor Cyan\n\
        Write-Host ('  Start Date  : ' + $StartDate + ' (inclusive)')\n\
        Write-Host ('  End Date    : ' + $EndDate + ' (exclusive)')\n\
        Write-Host ('  Auth Mode   : ' + $Auth)\n\
        Write-Host ('  Block Hours : ' + $BlockHours + ' (time window per query)')\n\
        Write-Host ('  Result Size : ' + $ResultSize + ' (records per API call)')\n\
        Write-Host ('  Pacing Ms   : ' + $PacingMs + ' (delay between requests)')\n\
        Write-Host ('  CSV Output  : ' + $OutputFile + '{}')\n\
        Write-Host ('  Log File    : ' + $LogFile)\n\
        Write-Host ('  Activities  : {} selected (curated tiers 1-3)')\n\
        Write-Host ('NOTE: Queries may appear to hang 30-120 seconds - this is normal Microsoft 365 behavior') -ForegroundColor Yellow\n\n",
        runtime_note,
        activityTypes.len()
    );

    let config_vars = format!("{}{}{}", header_comment, powershell_vars, display_config);

    // ULTRA-SAFE ZERO PROCESSING: Advanced validation with complete integrity checking
    println!("PAX: Using ULTRA-SAFE zero-processing approach with comprehensive validation");

    // COMPREHENSIVE SOURCE VALIDATION
    println!("PAX: ULTRA-SAFE validation - performing comprehensive integrity checks...");
    if src.is_empty() {
        return Err("CRITICAL: Source script is empty!".to_string());
    }

    let src_lines = src.lines().count();
    println!("PAX: Source script has {} lines", src_lines);

    // Validate minimum expected script size (should be ~2000+ lines)
    if src_lines < 1500 {
        println!(
            "PAX: WARNING - Source script seems truncated (only {} lines)",
            src_lines
        );
        return Err(format!(
            "Source script appears truncated: only {} lines found",
            src_lines
        ));
    }

    // Check for critical PowerShell syntax elements
    let has_function_def = src.contains("function ");
    let has_param_block = src.contains("param(");
    let has_try_catch = src.contains("try {") && src.contains("catch {");
    let has_finally = src.contains("finally {");

    println!(
        "PAX: Syntax validation - Functions: {}, Params: {}, Try/Catch: {}, Finally: {}",
        has_function_def, has_param_block, has_try_catch, has_finally
    );

    if !has_param_block {
        return Err("CRITICAL: Source script missing param block!".to_string());
    }

    // Advanced quote and brace validation
    let quote_count = src.matches('"').count();
    let single_quote_count = src.matches("'").count();
    let open_braces = src.matches('{').count();
    let close_braces = src.matches('}').count();
    let open_parens = src.matches('(').count();
    let close_parens = src.matches(')').count();

    println!(
        "PAX: Structure validation - Quotes: {}, Single quotes: {}",
        quote_count, single_quote_count
    );
    println!(
        "PAX: Structure validation - Braces: {} open, {} close",
        open_braces, close_braces
    );
    println!(
        "PAX: Structure validation - Parens: {} open, {} close",
        open_parens, close_parens
    );

    // Check for balanced braces (informational for source; final output will be enforced)
    if open_braces != close_braces {
        println!(
            "PAX: WARNING - Unbalanced braces in source script: {} open, {} close (will validate final output strictly)",
            open_braces, close_braces
        );
    }

    // Check for balanced parentheses (informational for source; final output will be enforced)
    if open_parens != close_parens {
        println!(
            "PAX: WARNING - Unbalanced parentheses in source script: {} open, {} close (will validate final output strictly)",
            open_parens, close_parens
        );
    }

    // Validate script ending
    let src_trimmed = src.trim();
    if !src_trimmed.ends_with('}') {
        println!("PAX: WARNING - Script doesn't end with closing brace");
        println!(
            "PAX: Last 100 characters: {}",
            &src_trimmed[src_trimmed.len().saturating_sub(100)..]
        );
    }

    // Ensure consistent Windows line endings (CRLF) for PowerShell compatibility
    println!("PAX: Normalizing line endings to CRLF for PowerShell compatibility...");
    let normalized_src = src.replace("\r\n", "\n").replace("\n", "\r\n");
    let normalized_config = config_vars.replace("\r\n", "\n").replace("\n", "\r\n");

    // ULTRA-SAFE CONCATENATION with buffer pre-allocation for performance
    println!("PAX: Performing ultra-safe string concatenation...");
    let estimated_size = normalized_config.len() + normalized_src.len() + 10;
    let mut out = String::with_capacity(estimated_size);

    // CRITICAL FIX: Insert configuration variables AFTER param() block, not before
    // PowerShell requires #Requires and param() to be at the very start of the script
    println!("PAX: Locating param() block and computing its true end to insert config safely...");

    // Robustly locate the first top-level param( ... ) and find its matching ')'
    let lc = normalized_src.to_lowercase();
    if let Some(param_start_kw) = lc.find("param(") {
        // Find the index of the '(' that starts the param block
        let paren_start = param_start_kw + "param".len();
        let chars: Vec<char> = normalized_src.chars().collect();

        let mut depth: i32 = 0;
        let mut i = paren_start; // index into chars
        let mut in_sgl = false;
        let mut in_dbl = false;
        let mut prev_backtick = false; // PowerShell escape character
        let mut closing_paren_idx: Option<usize> = None;

        // Walk from the '(' onward to find the matching ')'
        while i < chars.len() {
            let c = chars[i];

            // Track quotes (ignore parentheses inside strings)
            if !in_dbl && c == '\'' {
                if !prev_backtick {
                    in_sgl = !in_sgl;
                }
            } else if !in_sgl && c == '"' {
                if !prev_backtick {
                    in_dbl = !in_dbl;
                }
            }

            if !in_sgl && !in_dbl {
                if c == '(' {
                    depth += 1;
                } else if c == ')' {
                    depth -= 1;
                    if depth == 0 {
                        closing_paren_idx = Some(i);
                        break;
                    }
                }
            }

            // Track PowerShell escape char ` (backtick)
            prev_backtick = c == '`';
            if prev_backtick {
                // Backtick only escapes the very next char; reset on next loop
                // We deliberately don't skip the next char; we just know the quote won't toggle
            }

            i += 1;
        }

        if let Some(end_idx) = closing_paren_idx {
            // Insert config right after the closing ')'
            let before = &normalized_src[..end_idx + 1];
            let after = &normalized_src[end_idx + 1..];

            out.push_str(before);
            out.push_str("\r\n\r\n");
            out.push_str(&normalized_config);
            out.push_str("\r\n");
            out.push_str(after);

            println!(
                "PAX: Successfully inserted configuration variables after param() block (index {})",
                end_idx
            );
        } else {
            println!("PAX: WARNING - Failed to compute end of param() block. Prepending config as fallback.");
            out.push_str(&normalized_config);
            out.push_str("\r\n\r\n");
            out.push_str(&normalized_src);
        }
    } else {
        println!("PAX: WARNING - No param() block found. Prepending config as fallback.");
        out.push_str(&normalized_config);
        out.push_str("\r\n\r\n");
        out.push_str(&normalized_src);
    }

    // SAFETY FIXUPS for PowerShell 5.1 parsing:
    // 1) Convert any here-string markers to single-quoted (@' ... '@) to avoid interpolation pitfalls
    // 2) Rewrite transcript Write-Host lines to string concatenation instead of double-quoted interpolation
    println!("PAX: Applying PowerShell 5.1 safety fixups (here-strings, transcript messages)...");
    {
        // Convert any line-starting @" to @'
        let re_open = Regex::new(r#"(?m)^(\s*)@""#).unwrap();
        out = re_open.replace_all(&out, "$1@'").to_string();
        // Convert any line-starting "@ to '@
        let re_close = Regex::new(r#"(?m)^(\s*)"@"#).unwrap();
        out = re_close.replace_all(&out, "$1'@").to_string();

        // Rewrite transcript Write-Host lines (double-quoted with $LogFile) to concatenation
        let re_transcript_start =
            Regex::new(r#"(?m)Write-Host\s+"Transcript\s+logging\s+started:\s*\$LogFile""#)
                .unwrap();
        out = re_transcript_start
            .replace_all(
                &out,
                "Write-Host ('Transcript logging started: ' + $LogFile)",
            )
            .to_string();
        let re_transcript_saved =
            Regex::new(r#"(?m)Write-Host\s+"Transcript\s+log\s+saved:\s*\$LogFile""#).unwrap();
        out = re_transcript_saved
            .replace_all(&out, "Write-Host ('Transcript log saved: ' + $LogFile)")
            .to_string();
    }

    // POST-GENERATION VALIDATION
    let src_line_count = normalized_src.lines().count();
    let config_line_count = normalized_config.lines().count();
    let output_line_count = out.lines().count();

    println!("PAX: POST-GENERATION validation:");
    println!("PAX: - Config lines: {}", config_line_count);
    println!("PAX: - Source lines: {}", src_line_count);
    println!("PAX: - Output lines: {}", output_line_count);
    println!(
        "PAX: - Expected lines: {}",
        src_line_count + config_line_count + 2
    );

    // Validate output integrity
    if output_line_count < src_line_count {
        return Err(format!(
            "CRITICAL: Output truncated! Source: {} lines, Output: {} lines",
            src_line_count, output_line_count
        ));
    }

    // Final syntax validation on output
    let output_open_braces = out.matches('{').count();
    let output_close_braces = out.matches('}').count();
    if output_open_braces != output_close_braces {
        return Err(format!(
            "CRITICAL: Output has unbalanced braces: {} open, {} close",
            output_open_braces, output_close_braces
        ));
    }

    println!("PAX: ULTRA-SAFE ZERO PROCESSING - All validations PASSED");
    println!(
        "PAX: Final validation complete - {} lines generated",
        output_line_count
    );

    // Zero-processing success summary
    if output_line_count >= src_line_count {
        println!(
            "PAX: Zero-processing SUCCESS: +{} lines (config added successfully)",
            output_line_count - src_line_count
        );
    } else {
        println!(
            "PAX: Zero-processing WARNING: {} lines lost",
            src_line_count - output_line_count
        );
    }
    println!(
        "PAX: ULTRA-SAFE zero-processing COMPLETE - Source: {} lines, Output: {} lines",
        src_line_count, output_line_count
    );

    // Zero-processing approach complete - use the output directly (no double headers)
    println!("PAX: Final script lines: {}", out.lines().count());

    // Additional validation - check script integrity
    let final_lines = out.lines().count();
    let expected_minimum = src_line_count + 50; // Config should add at least 50 lines
    if final_lines < expected_minimum {
        println!(
            "PAX: WARNING - Output script appears truncated: {} lines (expected >= {})",
            final_lines, expected_minimum
        );
    }

    // Check for basic PowerShell script integrity
    let has_param_block = out.contains("param(");
    let has_final_brace = out.trim_end().ends_with("}");
    if !has_param_block {
        println!("PAX: WARNING - Script missing param block");
    }
    if !has_final_brace {
        println!("PAX: WARNING - Script doesn't end with closing brace");
    }

    println!("PAX: Script integrity check complete");

    // HYPERAGGRESSIVE: Check if script ends properly BEFORE writing
    println!("PAX: HYPERAGGRESSIVE PRE-WRITE ANALYSIS");
    println!("PAX: Final script size: {} bytes", out.len());
    println!("PAX: Final script lines: {}", out.lines().count());

    // Check if script ends with proper closing
    let last_500_chars = if out.len() > 500 {
        &out[out.len() - 500..]
    } else {
        &out
    };
    println!("PAX: Last 500 characters of script:");
    println!("--- START LAST 500 ---");
    println!("{}", last_500_chars);
    println!("--- END LAST 500 ---");

    // Check for common truncation indicators
    let ends_with_brace = out.trim_end().ends_with("}");
    let ends_properly = out.trim_end().ends_with("}\n") || out.trim_end().ends_with("}");
    println!("PAX: Script ends with brace: {}", ends_with_brace);
    println!("PAX: Script ends properly: {}", ends_properly);

    // Count braces before writing
    let total_open_braces = out.matches('{').count();
    let total_close_braces = out.matches('}').count();
    println!(
        "PAX: Pre-write brace count - Open: {}, Close: {}",
        total_open_braces, total_close_braces
    );

    // Check for quote balance
    let double_quotes = out.matches('"').count();
    let single_quotes = out.matches('\'').count();
    println!(
        "PAX: Quote count - Double: {}, Single: {}",
        double_quotes, single_quotes
    );

    // Look for the specific problem area around line 2073
    let lines: Vec<&str> = out.lines().collect();
    if lines.len() >= 2070 {
        println!("PAX: Checking lines around 2070-2075:");
        for i in 2070..=std::cmp::min(2075, lines.len() - 1) {
            if i < lines.len() {
                println!("Line {}: {}", i + 1, lines[i]);
            }
        }
    }

    // HYPERAGGRESSIVE: If script appears truncated, refuse to write it
    if !ends_with_brace {
        return Err(format!("HYPERAGGRESSIVE: Script doesn't end with closing brace - refusing to write potentially corrupted script!"));
    }

    if total_open_braces != total_close_braces {
        return Err(format!("HYPERAGGRESSIVE: Unbalanced braces detected BEFORE writing - Open: {}, Close: {} - refusing to write!", total_open_braces, total_close_braces));
    }

    println!("PAX: HYPERAGGRESSIVE validation passed - script appears complete");

    // ULTRA-SAFE FILE WRITING with integrity verification
    let parent = Path::new(&targetPath)
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or(PathBuf::from("."));
    if !parent.exists() {
        std::fs::create_dir_all(&parent).map_err(|e| format!("Failed to create folder: {e}"))?;
    }

    // Pre-write validation
    let pre_write_size = out.len();
    let pre_write_lines = out.lines().count();
    println!(
        "PAX: PRE-WRITE validation - Size: {} bytes, Lines: {}",
        pre_write_size, pre_write_lines
    );

    // Use File::create for more control over the writing process
    use std::fs::File;
    use std::io::Write;

    let mut file =
        File::create(&targetPath).map_err(|e| format!("Failed to create script file: {e}"))?;

    // Write in chunks to prevent potential buffer issues
    let bytes = out.as_bytes();
    let chunk_size = 65536; // 64KB chunks
    let mut written_total = 0;

    for chunk in bytes.chunks(chunk_size) {
        let written = file
            .write(chunk)
            .map_err(|e| format!("Failed to write script chunk: {e}"))?;
        written_total += written;
        if written != chunk.len() {
            return Err(format!(
                "Incomplete write: expected {} bytes, wrote {} bytes",
                chunk.len(),
                written
            ));
        }
    }

    // Ensure all data is flushed to disk
    file.flush()
        .map_err(|e| format!("Failed to flush script file: {e}"))?;
    drop(file); // Explicitly close the file

    // POST-WRITE VERIFICATION
    let written_content = std::fs::read_to_string(&targetPath)
        .map_err(|e| format!("Failed to verify written script: {e}"))?;
    let post_write_size = written_content.len();
    let post_write_lines = written_content.lines().count();

    println!(
        "PAX: POST-WRITE verification - Size: {} bytes, Lines: {}",
        post_write_size, post_write_lines
    );
    println!(
        "PAX: Written {} total bytes across {} chunks",
        written_total,
        (bytes.len() + chunk_size - 1) / chunk_size
    );

    // Verify file integrity
    if post_write_size != pre_write_size {
        return Err(format!(
            "CRITICAL: File write corruption! Pre-write: {} bytes, Post-write: {} bytes",
            pre_write_size, post_write_size
        ));
    }
    if post_write_lines != pre_write_lines {
        return Err(format!(
            "CRITICAL: File write truncation! Pre-write: {} lines, Post-write: {} lines",
            pre_write_lines, post_write_lines
        ));
    }

    // Final syntax validation on written file
    let written_open_braces = written_content.matches('{').count();
    let written_close_braces = written_content.matches('}').count();
    if written_open_braces != written_close_braces {
        return Err(format!(
            "CRITICAL: Written file has unbalanced braces: {} open, {} close",
            written_open_braces, written_close_braces
        ));
    }

    println!("PAX: ULTRA-SAFE FILE WRITE SUCCESS - All integrity checks passed");
    // Emit success message for single-file export
    let _ = window.emit(
        "ps-log",
        serde_json::json!({
            "type":"stdout",
            "line": format!("Exported script to: {}", targetPath)
        }),
    );
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
        .manage(RunState {
            pid: Mutex::new(None),
        })
        .invoke_handler(tauri::generate_handler![
            preflight_exchange_module,
            run_audit_script,
            cancel_current_run,
            export_hardcoded_script,
            open_file_externally,
            quit_app,
            load_bundled_dataset,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
