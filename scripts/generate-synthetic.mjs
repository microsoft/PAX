#!/usr/bin/env node
/*
  Generate synthetic Purview audit data for 1,000 Entra users across a six-month window
  aligned with existing Copilot licensing/usage (Option B). The output overwrites
  output/Purview_Export_Synthetic_6mo_1000users.csv and preserves the original header.

  Key decisions:
  - Identity join key: Use Entra `UserPrincipalName` (hashed-style tokens) as both
    `UserId` and `Audit_UserId` to align with other CSVs.
  -function generateClientIP(upn, dt) {
  // Generate corporate IP ranges that would be realistic for M365MCP10711576
  const corporateRanges = [
    '10.117.11', // Corporate internal
    '172.16.57', // Corporate VPN  
    '192.168.6'  // Corporate office
  ];
  
  const hash = hashInt(upn + dt.getDate());
  const baseIndex = hash % corporateRanges.length;
  const baseRange = corporateRanges[baseIndex];
  const lastOctet = (hash % 254) + 1;
  
  return `${baseRange}.${lastOctet}`;
}025-03-01 through 2025-08-31 inclusive.
  - Copilot adoption: If user appears in Copilot CSVs, earliest Copilot date becomes
    their adoption start; post-adoption we add Copilot prompt events and uplift other activity.
  - Volume target: ~150k–200k rows (weekday-weighted, work-hours focus, sparse weekends).
*/

import fs from 'fs';
import path from 'path';

const ROOT = path.resolve('..');
const OUTPUT_DIR = path.join(ROOT, 'output');
const ENTRA_PATH = path.join(OUTPUT_DIR, 'EntraUserDetail.csv');
const COPILOT_LICENSED_PATH = path.join(OUTPUT_DIR, 'Copilot_Licensed_Users.csv');
const COPILOT_USAGE_PATH = path.join(OUTPUT_DIR, 'CopilotUsageUserDetail.csv');
const PURVIEW_OUT_PATH = path.join(OUTPUT_DIR, 'Purview_Export_Synthetic_6mo_1000users.csv');
const TEAMS_PATH = path.join(OUTPUT_DIR, 'TeamsUserActivityUserDetail.csv');
const SPO_PATH = path.join(OUTPUT_DIR, 'SharePointActivityUserDetail.csv');
const ODB_PATH = path.join(OUTPUT_DIR, 'OneDriveActivityUserDetail.csv');
const EMAIL_PATH = path.join(OUTPUT_DIR, 'EmailActivityUserDetail.csv');

const START_DATE = new Date(Date.UTC(2025, 2, 1)); // 2025-03-01 UTC
const END_DATE = new Date(Date.UTC(2025, 7, 31, 23, 59, 59)); // 2025-08-31

// Simple CSV splitter handling basic quoted fields
function splitCsvLine(line) {
  const out = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') {
      if (inQuotes && line[i + 1] === '"') { cur += '"'; i++; }
      else { inQuotes = !inQuotes; }
    } else if (c === ',' && !inQuotes) {
      out.push(cur); cur = '';
    } else { cur += c; }
  }
  out.push(cur);
  return out;
}

function parseCsv(content) {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  const header = lines[0] ? splitCsvLine(lines[0]) : [];
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const l = lines[i];
    if (!l) continue;
    const cols = splitCsvLine(l);
    if (cols.length === 1 && cols[0] === '') continue;
    rows.push(cols);
  }
  return { header, rows };
}

function formatPurviewDate(dt) {
  // Compliance portal-like US format: M/D/YYYY h:mm:ss tt (UTC)
  const y = dt.getUTCFullYear();
  const m = (dt.getUTCMonth() + 1).toString(); // no leading zero
  const d = dt.getUTCDate().toString(); // no leading zero
  const H = dt.getUTCHours();
  const h12 = ((H + 11) % 12) + 1;
  const mm = String(dt.getUTCMinutes()).padStart(2, '0');
  const ss = String(dt.getUTCSeconds()).padStart(2, '0');
  const ampm = H < 12 ? 'AM' : 'PM';
  return `${m}/${d}/${y} ${h12}:${mm}:${ss} ${ampm}`;
}

// Map friendly type to numeric RecordType codes (official Microsoft schema)
// Aligned with app's 32 recommended activity types for realistic enterprise coverage
const RECORD_TYPE = {
  // Core workloads (original 6)
  ExchangeItem: 2,               // Email operations (Send, Read, Delete, etc.)
  SharePoint: 4,                 // SharePoint site operations (SiteAccessed, PageViewed, etc.)
  SharePointFileOperation: 6,    // SharePoint file operations (FileAccessed, FileModified, etc.)
  OneDrive: 25,                  // OneDrive for Business operations
  Teams: 64,                     // Microsoft Teams operations
  Copilot: 261,                  // Official RecordType for CopilotInteraction events
  
  // Administrative operations (breadth + depth)
  ExchangeAdmin: 1,              // Exchange admin operations (mailbox management, policies)
  TeamsAdmin: 65,                // Teams admin operations (team settings, policies)
  
  // Modern workplace (aligns with UserLoggedIn, DocumentShared activities)
  AzureActiveDirectory: 8,       // User sign-in operations, group management
  PowerBI: 303,                  // Power BI report access, dashboard sharing
  
  // Collaboration & productivity (depth for existing activity types)  
  Microsoft365Group: 338,        // Groups creation, membership changes
  MicrosoftForms: 73,            // Forms creation, response collection
  
  // Power Platform (common enterprise tools)
  PowerAppsApp: 23,              // Power Apps usage, app launches
  PowerAutomate: 29,             // Power Automate workflow executions
};

function randChoice(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function uuidv4() {
  // Simple uuid v4 (not cryptographically secure)
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function* eachDay(start, end) {
  for (let d = new Date(start); d <= end; d = new Date(d.getTime() + 24*3600*1000)) {
    yield new Date(d);
  }
}
// Simple deterministic pseudo-id from upn + key (not cryptographic) - AUTHENTIC PATTERNS
function pseudoId(upn, key) {
  const base = `${upn}|${key}`;
  let h = 0;
  for (let i=0;i<base.length;i++) h = (h*31 + base.charCodeAt(i)) >>> 0;
  // Generate authentic-looking hex instead of obvious synthetic pattern
  const additionalHex = (h * 0x9e3779b9).toString(16).padStart(24, '0').slice(0, 24);
  const hex = h.toString(16).padStart(8,'0') + additionalHex;
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20,32)}`;
}

function chooseRegion(upn) {
  const bucket = upn.charCodeAt(0) % 3;
  return ['NA','EMEA','APAC'][bucket];
}

function chooseHost(upn) {
  const bucket = upn.charCodeAt(1) % 3;
  return ['Desktop','Web','Mobile'][bucket];
}

function spBaseUrl(upn) {
  const n = (upn.charCodeAt(2) % 30) + 1;
  return `https://contoso.sharepoint.com/sites/project-${n}`;
}


function odBaseUrl(upn) {
  const id = upn.slice(0,8).toLowerCase();
  return `https://contoso-my.sharepoint.com/personal/user_${id}_contoso_onmicrosoft_com`;
}

function hashInt(s) {
  let h = 0;
  for (let i=0;i<s.length;i++) h = (h*31 + s.charCodeAt(i)) >>> 0;
  return h >>> 0;
}

function pick(arr, idx) { return arr[idx % arr.length]; }

const FOLDERS = ['General','Design','Finance','Legal','Marketing','Product','Ops','Sales','HR'];
const FILE_SETS = [
  { app: 'Word', ext: 'docx', names: ['Project Plan','Proposal','Meeting Notes','Minutes','Spec'] },
  { app: 'WordMacro', ext: 'docm', names: ['Macro Spec','Automation Guide','Template Macro'] },
  { app: 'Excel', ext: 'xlsx', names: ['Budget','Forecast','KPI','Report','Dashboard'] },
  { app: 'ExcelMacro', ext: 'xlsm', names: ['Budget Model','Monte Carlo','Scenario Sheet'] },
  { app: 'PowerPoint', ext: 'pptx', names: ['AllHands','Quarterly Review','Roadmap','Training','Showcase'] },
  { app: 'PDF', ext: 'pdf', names: ['Contract','SOW','Statement','Brochure','Whitepaper'] },
  { app: 'ImagePng', ext: 'png', names: ['Diagram','Mockup','Wireframe','Screenshot'] },
  { app: 'ImageJpg', ext: 'jpg', names: ['Photo','Scan','Slide','Chart'] },
  { app: 'ImageSvg', ext: 'svg', names: ['Icon','Logo','Vector','Diagram'] },
  { app: 'Text', ext: 'txt', names: ['README','Changelog','ToDo','Checklist'] },
  { app: 'Markdown', ext: 'md', names: ['README','Design Notes','Runbook'] },
  { app: 'CSV', ext: 'csv', names: ['Export','Dataset','Input'] }
];

function buildFilePath(upn, dt, seq = 0) {
  const seed = `${upn}|${dt.toISOString()}|${seq}`;
  const h = hashInt(seed);
  const folder = pick(FOLDERS, h % FOLDERS.length);
  const fspec = pick(FILE_SETS, Math.floor(h / 7) % FILE_SETS.length);
  const name = pick(fspec.names, Math.floor(h / 11) % fspec.names.length);
  const vSuffix = seq > 0 ? `_v${String(seq + 1).padStart(2,'0')}` : '';
  const fn = `${name}${vSuffix}.${fspec.ext}`;
  return { folder, filename: fn };
}

function joinUrl(base, parts) {
  const enc = parts.map(p => encodeURIComponent(p));
  return `${base}/${enc.join('/')}`;
}

function weekOfYear(dt) {
  // Approximate ISO week number
  const d = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate()));
  // Thursday in current week decides the year.
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return weekNo;
}

function buildSubfolders(upn, dt) {
  // Deterministically choose no subfolder, a Sprint, or a Release folder
  const h = hashInt(`${upn}|${yyyymmdd(dt)}`) % 3;
  if (h === 1) {
    const wk = weekOfYear(dt);
    return ['Sprints', `Sprint-${String(wk).padStart(2,'0')}`];
  }
  if (h === 2) {
    const y = dt.getUTCFullYear();
    const m = String(dt.getUTCMonth()+1).padStart(2,'0');
    return ['Releases', `R${y}.${m}`];
  }
  return [];
}

function chooseActionForExt(ext, op) {
  const lower = ext.toLowerCase();
  const editable = ['docx','docm','xlsx','xlsm','pptx','md','csv','txt'];
  const readMostly = ['pdf'];
  const image = ['png','jpg','jpeg','svg'];
  function pickWeighted(pairs) {
    const total = pairs.reduce((s,[,w])=>s+w,0);
    let r = Math.random()*total;
    for (const [val, w] of pairs) { if ((r-=w) <= 0) return val; }
    return pairs[0][0];
  }
  if (/FileUploaded/i.test(op)) return 'Upload';
  if (editable.includes(lower)) {
    if (/FileModified/i.test(op)) return pickWeighted([['Edit',90],['View',10]]);
    return pickWeighted([['View',60],['Edit',40]]);
  }
  if (readMostly.includes(lower)) {
    if (/FileModified/i.test(op)) return pickWeighted([['Edit',15],['View',85]]);
    return pickWeighted([['View',90],['Preview',10]]);
  }
  if (image.includes(lower)) {
    return pickWeighted([['View',85],['Preview',15]]);
  }
  // default
  return /FileModified/i.test(op) ? 'Edit' : 'View';
}

const AU_POOLS = [
  'North America','EMEA','APAC','Sales','Engineering','Finance','HR','Operations'
];
function getAdminUnits(upn) {
  // deterministically assign 1-2 units based on upn hash
  const a = upn.charCodeAt(3) % AU_POOLS.length;
  const b = (upn.charCodeAt(4) + a + 1) % AU_POOLS.length;
  const names = a === b ? [AU_POOLS[a]] : [AU_POOLS[a], AU_POOLS[b]];
  const ids = names.map(n => pseudoId(upn, `au-${n.toLowerCase().replace(/\s+/g,'-')}`));
  return { ids, names };
}

function yyyymmdd(dt) {
  const y = dt.getUTCFullYear();
  const m = String(dt.getUTCMonth()+1).padStart(2,'0');
  const d = String(dt.getUTCDate()).padStart(2,'0');
  return `${y}${m}${d}`;
}

function weekStartKey(dt) {
  // ISO week start (Monday) as YYYYMMDD for chain grouping across a week
  const wd = (dt.getUTCDay() + 6) % 7; // 0=Monday
  const start = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate() - wd));
  return yyyymmdd(start);
}

function policyFor(upn, dt, op) {
  // Deterministic distribution ~85% Compliant, 10% Warning, 5% Blocked
  const seed = `${upn}|${yyyymmdd(dt)}|${op}`;
  let h = 0;
  for (let i=0;i<seed.length;i++) h = (h*33 + seed.charCodeAt(i)) >>> 0;
  const r = h % 100;
  if (r < 5) return 'Blocked';
  if (r < 15) return 'Warning';
  return 'Compliant';
}

// Use exact PAX app field order to ensure structural compatibility
const headerNames = [
  'RecordId', 'CreationDate', 'RecordType', 'CreationDateIsoUtc', 'OrganizationId',
  'UserType', 'UserKey', 'Workload', 'Operation', 'UserId', 'AssociatedAdminUnits',
  'AssociatedAdminUnitsNames', 'AgentId', 'AgentName', 'AppIdentity_AppId',
  'AppIdentity_DisplayName', 'AppIdentity_PublisherId', 'ApplicationName',
  'CreationTime', 'CreationTimeIsoUtc', 'ClientIP', 'ObjectId', 'ResultStatus',
  'ClientRegion', 'Audit_UserId', 'AppHost', 'ThreadId', 'Context_Id', 'Context_Type',
  'Message_Id', 'Message_isPrompt', 'AccessedResource_Action', 'AccessedResource_PolicyDetails',
  'AccessedResource_SiteUrl', 'AISystemPlugin_Id', 'AISystemPlugin_Name', 
  'ModelTransparencyDetails_ModelName', 'MessageIds'
];
const outHeader = headerNames.join(',');

// Build fast index map for header columns
const H = Object.fromEntries(headerNames.map((n, i) => [n, i]));

// Load Entra users (UPN join key)
const entraCsv = parseCsv(fs.readFileSync(ENTRA_PATH, 'utf8'));
const upnIdx = entraCsv.header.findIndex(h => h.replace(/"/g, '') === 'UserPrincipalName');
if (upnIdx < 0) throw new Error('EntraUserDetail.csv missing UserPrincipalName');
// Select the first 1000 UPNs
const upns = entraCsv.rows.slice(0, 1000).map(r => r[upnIdx].replace(/^"|"$/g, ''));
const upnSet = new Set(upns);

// Build Copilot adoption map (earliest date present in Licensed or Usage files),
// plus per-user license date and app-specific activity dates for exact anchoring.
function parseDateYYYYMMDD(s) {
  if (!s) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return new Date(Date.UTC(+m[1], +m[2]-1, +m[3]));
}

const adoption = new Map(); // upn -> Date (UTC)
const licenseDate = new Map(); // upn -> Date (UTC) if present
const appActivity = new Map(); // upn -> { appName: [Date, ...] }

function considerAdoption(upn, d) {
  if (!d) return;
  const prev = adoption.get(upn);
  if (!prev || d < prev) adoption.set(upn, d);
}

// Licensed users file
const licensedCsv = parseCsv(fs.readFileSync(COPILOT_LICENSED_PATH, 'utf8'));
const licHeader = licensedCsv.header.map(h => h.replace(/\"/g, ''));
const licUpnIdx = licHeader.findIndex(h => /User Principal Name/i.test(h));
const licDateCols = licHeader
  .map((name, idx) => ({ name, idx }))
  .filter(c => /Last Used Date|Last Activity Date/i.test(c.name));
for (const row of licensedCsv.rows) {
  const upn = row[licUpnIdx]?.replace(/^"|"$/g, '');
  if (!upn || !upnSet.has(upn)) continue;
  for (const c of licDateCols) {
    const d = parseDateYYYYMMDD(row[c.idx]?.replace(/^"|"$/g, ''));
    if (d) considerAdoption(upn, d);
  }
  // Treat "Last Activity Date" as license evidence if present earliest
  const lastIdx = licHeader.findIndex(h => /Last Activity Date/i.test(h));
  const lastDate = lastIdx >= 0 ? parseDateYYYYMMDD(row[lastIdx]?.replace(/^"|"$/g, '')) : null;
  if (lastDate) {
    const prev = licenseDate.get(upn);
    if (!prev || lastDate < prev) licenseDate.set(upn, lastDate);
  }
}

// Usage user detail file
const usageCsv = parseCsv(fs.readFileSync(COPILOT_USAGE_PATH, 'utf8'));
const usageHeader = usageCsv.header.map(h => h.replace(/\"/g, ''));
const usageUpnIdx = usageHeader.findIndex(h => /User Principal Name/i.test(h));
const usageDateCols = usageHeader
  .map((name, idx) => ({ name, idx }))
  .filter(c => /Last Activity Date|Copilot .* Last Activity Date/i.test(c.name));
for (const row of usageCsv.rows) {
  const upn = row[usageUpnIdx]?.replace(/^"|"$/g, '');
  if (!upn || !upnSet.has(upn)) continue;
  for (const c of usageDateCols) {
    const d = parseDateYYYYMMDD(row[c.idx]?.replace(/^"|"$/g, ''));
    if (d) considerAdoption(upn, d);
  }
  // Collect app-specific dates for exact anchoring
  // Columns include: Copilot Chat Last Activity Date, Microsoft Teams Copilot Last Activity Date,
  // Word Copilot Last Activity Date, Excel Copilot Last Activity Date, PowerPoint Copilot Last Activity Date,
  // Outlook Copilot Last Activity Date, OneNote Copilot Last Activity Date, Loop Copilot Last Activity Date
  const appCols = [
    { key: 'BizChat', regex: /^Copilot Chat Last Activity Date$/i },
    { key: 'Teams', regex: /^Microsoft Teams Copilot Last Activity Date$/i },
    { key: 'Word', regex: /^Word Copilot Last Activity Date$/i },
    { key: 'Excel', regex: /^Excel Copilot Last Activity Date$/i },
    { key: 'PowerPoint', regex: /^PowerPoint Copilot Last Activity Date$/i },
    { key: 'Outlook', regex: /^Outlook Copilot Last Activity Date$/i },
    { key: 'OneNote', regex: /^OneNote Copilot Last Activity Date$/i },
    { key: 'Loop', regex: /^Loop Copilot Last Activity Date$/i },
  ];
  const appMap = appActivity.get(upn) || {};
  for (const app of appCols) {
    const idx = usageHeader.findIndex(h => app.regex.test(h));
    if (idx >= 0) {
      const d = parseDateYYYYMMDD(row[idx]?.replace(/^"|"$/g, ''));
      if (d) {
        (appMap[app.key] ||= []).push(d);
      }
    }
  }
  if (Object.keys(appMap).length) appActivity.set(upn, appMap);
}

// Activity model with comprehensive Microsoft 365 operations (14 RecordTypes total)
// Aligned with app's recommended activity types for realistic enterprise diversity
const recordTypes = [
  // Core Exchange operations (existing + admin depth)
  { type: 'ExchangeItem', ops: ['Send', 'MailItemsAccessed', 'MailItemsDeleted', 'Move', 'MoveToDeletedItems', 'SoftDelete', 'HardDelete', 'Forward', 'Reply'] },
  { type: 'ExchangeAdmin', ops: ['New-Mailbox', 'Set-Mailbox', 'Remove-Mailbox', 'New-DistributionGroup', 'Set-RetentionPolicy'] },
  
  // SharePoint operations (existing breadth)
  { type: 'SharePoint', ops: ['SiteAccessed', 'PageViewed', 'SearchQueryPerformed', 'SiteCollectionCreated', 'WebCreated'] },
  { type: 'SharePointFileOperation', ops: ['FileAccessed', 'FileModified', 'FileDeleted', 'FileUploaded', 'FileDownloaded', 'FileMoved', 'FileCopied', 'FileShared', 'FileRenamed', 'FileCheckedOut', 'FileCheckedIn'] },
  
  // OneDrive operations (existing)
  { type: 'OneDrive', ops: ['FileAccessed', 'FileModified', 'FileSynced', 'FileShared', 'FileDownloaded', 'FolderCreated', 'FileRenamed', 'FileDeleted', 'FileUploaded', 'SharingLinkCreated'] },
  
  // Teams operations (existing + admin depth)
  { type: 'Teams', ops: ['MeetingJoined', 'MeetingCreated', 'MessageSentTeamsChat', 'MessageSentTeamsChannel', 'CallStarted', 'CallEnded', 'TeamCreated', 'ChannelCreated', 'TeamDeleted', 'MemberAdded', 'MemberRemoved', 'TabAdded', 'AppInstalled', 'BotAddedToTeam'] },
  { type: 'TeamsAdmin', ops: ['TeamsPolicyChange', 'TeamsAppInstalled', 'TeamsAppBlocked', 'TeamsChannelPolicyUpdate', 'TeamsMeetingPolicyChange'] },
  
  // Azure AD / Security (aligns with UserLoggedIn)
  { type: 'AzureActiveDirectory', ops: ['UserLoggedIn', 'UserLoggedOut', 'UserSignInFailed', 'GroupCreated', 'GroupMemberAdded', 'GroupMemberRemoved', 'ApplicationAccessed'] },
  
  // Microsoft 365 Groups (aligns with collaboration activities)
  { type: 'Microsoft365Group', ops: ['GroupCreated', 'GroupDeleted', 'MemberAdded', 'MemberRemoved', 'GroupUpdated', 'GroupFileAccessed'] },
  
  // Power BI (aligns with DocumentShared, DocumentDownloaded)
  { type: 'PowerBI', ops: ['ViewReport', 'ViewDashboard', 'ExportReport', 'ShareDashboard', 'CreateReport', 'DeleteReport', 'DatasetAccessed'] },
  
  // Microsoft Forms (common collaboration tool)
  { type: 'MicrosoftForms', ops: ['FormCreated', 'FormDeleted', 'FormResponseSubmitted', 'FormShared', 'FormViewed', 'FormResponseViewed'] },
  
  // Power Apps (enterprise applications)
  { type: 'PowerAppsApp', ops: ['AppLaunched', 'AppCreated', 'AppDeleted', 'AppShared', 'AppModified', 'ConnectorAccessed'] },
  
  // Power Automate (workflow automation)
  { type: 'PowerAutomate', ops: ['FlowCreated', 'FlowDeleted', 'FlowRun', 'FlowShared', 'FlowModified', 'FlowFailed'] },
  
  // Copilot (existing)
  { type: 'Copilot', ops: ['CopilotInteraction'] },
];

function isWeekend(d) {
  const wd = d.getUTCDay();
  return wd === 0 || wd === 6;
}

function workHour(d) {
  // Return a random work-hour time (UTC) roughly mapping to 8:00–18:00 with spread
  const baseH = randInt(8, 17);
  const minute = randInt(0, 59);
  const dt = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), baseH, minute));
  return dt;
}

function offHour(d) {
  const baseH = randChoice([6,7,18,19,20]);
  const minute = randInt(0,59);
  const dt = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), baseH, minute));
  return dt;
}


// Microsoft Learn Common Schema field generators
function generateOrganizationId() {
  // Use consistent tenant GUID derived from actual Entra data for correlation
  return '28e69c51-28e6-4be6-8e69-28e69c511576';
}

function getUserType(upn, recordType) {
  // Microsoft Learn UserType enum: 0=Regular, 1=Reserved, 2=Admin, 3=DCAdmin, 4=System, 5=Application, 6=ServicePrincipal, 7=CustomPolicy, 8=SystemPolicy, 9=PartnerTechnician, 10=Guest
  if (upn.includes('admin')) return 2; // Admin
  if (recordType === 'System') return 4; // System
  if (upn.includes('guest') || upn.includes('#EXT#')) return 10; // Guest
  return 0; // Regular user (most common)
}

function generateUserKey(upn) {
  // Generate UserKey that correlates with Entra ObjectId pattern for consistency
  if (!upn) return null;
  
  // Use the same hashing pattern as Entra data for correlation
  const cleanUpn = upn.replace('@M365MCP10711576.OnMicrosoft.com', '');
  let hash = 0;
  for (let i = 0; i < cleanUpn.length; i++) {
    hash = ((hash << 5) - hash + cleanUpn.charCodeAt(i)) & 0xffffffff;
  }
  
  // Generate 16-digit hex that correlates with existing user pattern
  const puid = Math.abs(hash).toString(16).padStart(16, '0');
  return puid.slice(0, 16);
}

function getWorkloadFromType(recordType) {
  // Map RecordType to Office 365 service names per Microsoft Learn
  const workloadMap = {
    'ExchangeItem': 'Exchange',
    'ExchangeAdmin': 'Exchange',
    'SharePoint': 'SharePoint',
    'SharePointFileOperation': 'SharePoint',
    'OneDrive': 'OneDrive',
    'Teams': 'MicrosoftTeams',
    'TeamsAdmin': 'MicrosoftTeams',
    'AzureActiveDirectory': 'AzureActiveDirectory',
    'Microsoft365Group': 'Office365',
    'PowerBI': 'PowerBI',
    'MicrosoftForms': 'MicrosoftForms',
    'PowerAppsApp': 'PowerApps',
    'PowerAutomate': 'PowerAutomate',
    'Copilot': 'MicrosoftCopilot'
  };
  return workloadMap[recordType] || 'Office365';
}

function generateClientIP(upn, dt) {
  // Generate corporate IP ranges that would be realistic for M365MCP10711576
  const corporateRanges = [
    '10.117.11', // Corporate internal
    '172.16.57', // Corporate VPN  
    '192.168.6'  // Corporate office
  ];
  
  const hash = hashInt(upn + dt.getDate());
  const baseIndex = hash % corporateRanges.length;
  const baseRange = corporateRanges[baseIndex];
  const lastOctet = (hash % 254) + 1;
  
  return `${baseRange}.${lastOctet}`;
}

function generateObjectId(recordType, operation, upn, dt) {
  // Generate ObjectId that correlates with M365MCP10711576 tenant for authenticity
  const hash = hashInt(upn + dt.getTime()).toString(16).slice(0,8);
  
  if (operation.includes('File')) {
    return `https://M365MCP10711576.sharepoint.com/sites/team/Shared Documents/file_${hash}.docx`;
  } else if (operation.includes('Mail')) {
    return `<message_${hash}@M365MCP10711576.OnMicrosoft.com>`;
  } else if (operation.includes('Team') || operation.includes('Meeting')) {
    return `19:meeting_${hash}@thread.v2`;
  } else if (recordType === 'Copilot') {
    return `copilot-conversation-${hash}`;
  }
  return `object-${hash}`;
}

function getResultStatus(recordType, operation) {
  // Microsoft Learn ResultStatus: Succeeded, PartiallySucceeded, Failed
  // Most operations succeed, occasional failures for realism
  const random = Math.random();
  if (random < 0.92) return 'Succeeded';
  if (random < 0.97) return 'PartiallySucceeded';
  return 'Failed';
}

function makeRow({ dt, upn, type, op, isCopilot, appHost }) {
  // Preserve the original header’s column count; fill unused as empty
  // Header (as seen from the file):
    // RecordId,CreationDate,RecordType,Operation,UserId,OrganizationId,UserType,UserKey,Workload,AssociatedAdminUnits,AssociatedAdminUnitsNames,AgentId,AgentName,AppIdentity_AppId,AppIdentity_DisplayName,AppIdentity_PublisherId,ApplicationName,CreationTime,ClientRegion,ClientIP,Audit_UserId,AppHost,ThreadId,Context_Id,Context_Type,Message_Id,Message_isPrompt,AccessedResource_Action,AccessedResource_PolicyDetails,AccessedResource_SiteUrl,ObjectId,ResultStatus,AISystemPlugin_Id,AISystemPlugin_Name,ModelTransparencyDetails_ModelName,MessageIdsnUnitsNames,AgentId,AgentName,AppIdentity_AppId,AppIdentity_DisplayName,AppIdentity_PublisherId,ApplicationName,CreationTime,ClientRegion,Audit_UserId,AppHost,ThreadId,Context_Id,Context_Type,Message_Id,Message_isPrompt,AccessedResource_Action,AccessedResource_PolicyDetails,AccessedResource_SiteUrl,AISystemPlugin_Id,AISystemPlugin_Name,ModelTransparencyDetails_ModelName,MessageIds
  const cols = new Array(headerNames.length).fill('TRUE'); // Match Microsoft Purview API empty field behavior
  
  // Default appHost for non-Copilot operations based on RecordType
  if (!appHost) {
    const appHostMap = {
      'ExchangeItem': 'Outlook',
      'ExchangeAdmin': 'ExchangeAdmin',
      'SharePoint': 'SharePoint',
      'SharePointFileOperation': 'SharePoint',
      'OneDrive': 'OneDrive',
      'Teams': 'Teams',
      'TeamsAdmin': 'TeamsAdmin',
      'AzureActiveDirectory': 'AzureAD',
      'Microsoft365Group': 'Office365',
      'PowerBI': 'PowerBI',
      'MicrosoftForms': 'Forms',
      'PowerAppsApp': 'PowerApps',
      'PowerAutomate': 'PowerAutomate'
    };
    appHost = appHostMap[type] || 'Office365';
  }
  
  cols[H.RecordId] = uuidv4();
  const ts = formatPurviewDate(dt);
  cols[H.CreationDate] = ts; // CreationDate
  if (H.CreationDateIsoUtc !== undefined) cols[H.CreationDateIsoUtc] = new Date(dt).toISOString();
  cols[H.RecordType] = type; // Use string RecordType to match actual Purview API output
  cols[H.Operation] = op;
  cols[H.UserId] = upn; // UserId (use hashed UPN for join)
  // Microsoft Learn Common Schema required fields
  cols[H.OrganizationId] = generateOrganizationId(); // Consistent tenant GUID
  cols[H.UserType] = getUserType(upn, type); // 0=Regular, 2=Admin, 4=System, 5=Application
  cols[H.UserKey] = generateUserKey(upn); // Alternative user ID (PUID-style)
  cols[H.Workload] = getWorkloadFromType(type); // Office 365 service name
  cols[H.ClientIP] = generateClientIP(upn, dt); // Realistic client IP
  cols[H.ObjectId] = generateObjectId(type, op, upn, dt); // Object that was acted upon
  cols[H.ResultStatus] = getResultStatus(type, op); // Succeeded/Failed/PartiallySucceeded
  // Admin units (deterministic)
  const au = getAdminUnits(upn);
  cols[H.AssociatedAdminUnits] = au.ids.join(';');
  cols[H.AssociatedAdminUnitsNames] = au.names.join(';');
  // Agent and App identity (selectively filled below)
  cols[H.AgentId] = pseudoId(upn, 'agent');
  cols[H.AgentName] = ''; // Leave empty like real Purview data
  // App identity defaults (override per workload)
  // cols[9] AppIdentity_AppId
  // cols[10] AppIdentity_DisplayName
  cols[H.AppIdentity_PublisherId] = 'Microsoft Corporation';
  // cols[12] ApplicationName
  cols[H.CreationTime] = new Date(dt).toISOString();
  if (H.CreationTimeIsoUtc !== undefined) cols[H.CreationTimeIsoUtc] = cols[H.CreationTime];
  cols[H.ClientRegion] = chooseRegion(upn);
  cols[H.Audit_UserId] = upn;
  cols[H.AppHost] = chooseHost(upn);
  // Thread/Context for conversational workloads
  // cols[17] ThreadId
  // cols[18] Context_Id
  
  // AUTHENTIC COPILOT PATTERNS FROM REAL MICROSOFT PURVIEW DATA (Sample_Purview_Data_Raw_JSON_Copilot_Examples.csv)
  if (isCopilot) {
    // Real AppHost distribution from 501 record analysis: Teams(42%), Office(28%), Word(8%), Outlook(7%), Excel(5%), PowerPoint(3%), Designer(2.5%), Copilot Studio(2%), Unknown(1.5%), Forms(1%)
    const realAppHostWeights = {
      'Teams': 42, 'Office': 28, 'Word': 8, 'Outlook': 7, 'Excel': 5, 
      'PowerPoint': 3, 'Designer': 2.5, 'Copilot Studio': 2, 'Unknown': 1.5, 'Forms': 1
    };
    
    // Use provided appHost or select based on real distribution
    if (!appHost) {
      const totalWeight = Object.values(realAppHostWeights).reduce((sum, w) => sum + w, 0);
      const rand = Math.random() * totalWeight;
      let currentWeight = 0;
      for (const [host, weight] of Object.entries(realAppHostWeights)) {
        currentWeight += weight;
        if (rand <= currentWeight) {
          appHost = host;
          break;
        }
      }
    }
    cols[H.AppHost] = appHost;

    // Real AgentId/AgentName patterns (0.8% usage rate - 4/501 records) - AUTHENTIC PATTERNS FROM REAL DATA
    const hasAgent = Math.random() < 0.008; // 0.8% realistic usage rate from real data
    if (hasAgent) {
      const realAgentPatterns = [
        { id: 'SYSTEM_CreateGPT.declarativeCopilot', name: 'Visual Creator' },
        { id: 'CopilotStudio.Declarative.T_4e671777-fa6c-601a-b416-df08b6ae4c14.03dc0b8b-a75a-4b77-86d7-98185a176d1b', name: 'Meeting Prep Assistant' },
        { id: 'P_301fad66-fa35-ca43-824c-11cd5e9c4cf3.SYSTEM_CreateGPT', name: 'CRU QA Analyzer Agent' },
        { id: `P_${uuidv4().slice(0,8)}-${uuidv4().slice(0,4)}-${uuidv4().slice(0,4)}-${uuidv4().slice(0,4)}-${uuidv4().slice(0,12)}.SYSTEM_CreateGPT`, name: `Custom Agent ${Math.floor(Math.random() * 100)}` }
      ];
      const agent = realAgentPatterns[Math.floor(Math.random() * realAgentPatterns.length)];
      cols[H.AgentId] = agent.id;
      cols[H.AgentName] = agent.name;
    } else {
      cols[H.AgentId] = ''; // Empty like real data (99.2% of records)
      cols[H.AgentName] = ''; // Empty like real data (99.2% of records)
    }

    // Real ThreadId patterns from authentic Microsoft data - Teams thread format "19:xxx@thread.v2"
    const threadIdPatterns = [
      `19:${uuidv4().replace(/-/g, '')}@thread.v2`,
      `19:${uuidv4().replace(/-/g, '').slice(0,25)}@thread.v2`,
      `19:${uuidv4().replace(/-/g, '').slice(0,30)}_${uuidv4().slice(0,8)}-${uuidv4().slice(0,4)}-${uuidv4().slice(0,4)}-${uuidv4().slice(0,4)}-${uuidv4().slice(0,12)}@unq.gbl.spaces`
    ];
    cols[H.ThreadId] = threadIdPatterns[Math.floor(Math.random() * threadIdPatterns.length)];
    
    // CorrelationId patterns - extensive in Security Copilot and Designer contexts from real data
    let correlationId = '';
    if (appHost === 'Unknown' || appHost === 'Designer') {
      // Security Copilot uses CorrelationId extensively, Designer has unique patterns
      correlationId = uuidv4();
      if (appHost === 'Designer') {
        cols[H.ThreadId] = ''; // Designer contexts have empty ThreadId in real data
      }
    }
    
    // Real Context patterns from authentic data
    const realContextPatterns = {
      'Word': [
        { Id: `https://savingsandinvestments.sharepoint.com/sites/ProjectNina/_layouts/15/Doc.aspx?sourcedoc=%7B${uuidv4().toUpperCase()}%7D&file=Document_${Math.floor(Math.random() * 1000)}.docx&action=default&mobileredirect=true`, Type: 'docx' },
        { Id: `https://savingsandinvestments-my.sharepoint.com/personal/user_${Math.floor(Math.random() * 1000)}_contoso_com/_layouts/15/Doc.aspx?sourcedoc=%7B${uuidv4().toUpperCase()}%7D&file=Report_${Math.floor(Math.random() * 100)}.docx&action=edit&mobileredirect=true`, Type: 'docx' }
      ],
      'Teams': [
        { Id: `https://teams.microsoft.com/_#/conversations/19:meeting_${uuidv4().replace(/-/g, '').slice(0,40)}@thread.v2?ctx=chat`, Type: 'TeamsChat' }
      ],
      'PowerPoint': [
        { Id: `https://savingsandinvestments.sharepoint.com/sites/TechRationalisation/_layouts/15/Doc.aspx?sourcedoc=%7B${uuidv4().toUpperCase()}%7D&file=Presentation_${Math.floor(Math.random() * 100)}.pptx&action=edit&mobileredirect=true`, Type: 'pptx' }
      ]
    };
    
    const contextTypes = realContextPatterns[appHost] || [];
    if (contextTypes.length > 0) {
      const context = contextTypes[Math.floor(Math.random() * contextTypes.length)];
      cols[H.Context_Id] = context.Id;
      cols[H.Context_Type] = context.Type;
    } else {
      cols[H.Context_Id] = '';
      cols[H.Context_Type] = '';
    }

    // Real Message patterns with authentic timestamp-based IDs
    const messageId = Math.floor(Date.now() / 1000) + Math.floor(Math.random() * 1000000);
    cols[H.Message_Id] = messageId.toString();
    cols[H.Message_isPrompt] = Math.random() < 0.5 ? 'true' : 'false'; // Real data shows 50/50 split

    // Real AISystemPlugin patterns - BingWebSearch is most common, otherwise empty
    const hasBingPlugin = Math.random() < 0.15; // ~15% have BingWebSearch based on real data
    if (hasBingPlugin) {
      cols[H.AISystemPlugin_Id] = 'BingWebSearch';
      cols[H.AISystemPlugin_Name] = 'BuiltIn';
    } else {
      cols[H.AISystemPlugin_Id] = ''; // Empty like majority of real data
      cols[H.AISystemPlugin_Name] = ''; // Empty like majority of real data
    }

    // Real ModelTransparencyDetails patterns - DEEP_LEO when present, otherwise empty
    const hasModelInfo = Math.random() < 0.25; // ~25% have model info in real data
    if (hasModelInfo) {
      cols[H.ModelTransparencyDetails_ModelName] = 'DEEP_LEO'; // Real model name from authentic data
    } else {
      cols[H.ModelTransparencyDetails_ModelName] = ''; // Empty like majority of real data
    }

    // Real AccessedResources patterns from authentic Microsoft Purview data
    const realResourceTypes = ['docx', 'pptx', 'xlsx', 'aspx', 'EmailMessage', 'TeamsMessage', 'http://schema.skype.com/HyperLink', 'onepart'];
    const realActions = ['Read', 'ExecuteDatasetQuery']; // Primary actions from real data
    const realSensitivityLabels = [
      '3439374f-170d-4d1d-ad34-00f2ff8691e7',
      '145b9cce-5262-4471-b691-53ccdbfa697d', 
      '6cd3c5f5-c566-4dc5-8864-6f6d9b127b45'
    ]; // Real SensitivityLabelId values from data

    cols[H.AccessedResource_Action] = realActions[Math.floor(Math.random() * realActions.length)];
    
    // Real PolicyDetails patterns (complex nested JSON from real data)
    const realPolicyPatterns = [
      '', // Most common - empty
      '[{"PolicyType":"Purview","PolicyOutcomes":["None"],"AuditLog":""}]',
      '[{"PolicyType":"RightsManagementService","PolicyOutcomes":["None"],"AuditLog":""},{"PolicyType":"ConditionalAccess","PolicyOutcomes":["None"],"AuditLog":""},{"PolicyType":"Purview","PolicyOutcomes":["None"],"AuditLog":""}]'
    ];
    cols[H.AccessedResource_PolicyDetails] = realPolicyPatterns[Math.floor(Math.random() * realPolicyPatterns.length)];
    
    // Real SiteUrl patterns from authentic SharePoint/Teams/Forms URLs
    const realSiteUrlPatterns = [
      `https://savingsandinvestments.sharepoint.com/sites/Project${Math.floor(Math.random() * 100)}/SitePages/Document${Math.floor(Math.random() * 1000)}.aspx?web=1`,
      `https://forms.office.com/Pages/DesignPageV2.aspx?prevorigin=shell&origin=NeoPortalPage&subpage=design&id=${uuidv4().replace(/-/g, '')}`,
      `https://teams.microsoft.com/l/message/19:${uuidv4().replace(/-/g, '').slice(0,32)}@thread.v2/${Math.floor(Date.now() / 1000)}?context=%7B%22contextType%22:%22chat%22%7D`,
      `https://outlook.office365.com/owa/?ItemID=${Buffer.from(uuidv4()).toString('base64').slice(0,100)}&exvsurl=1&viewmodel=ReadMessageItem`
    ];
    
    if (Math.random() < 0.3) { // 30% have SiteUrl
      cols[H.AccessedResource_SiteUrl] = realSiteUrlPatterns[Math.floor(Math.random() * realSiteUrlPatterns.length)];
    } else {
      cols[H.AccessedResource_SiteUrl] = '';
    }
    
    // MessageIds chain pattern from real data
    cols[H.MessageIds] = `${messageId}-chain-${appHost.toLowerCase()}`;
  }

  // Workload-specific enrichment
  if (type === 'SharePointFileOperation') {
    // AccessedResource_* and identity for SharePoint
    cols[H.AppIdentity_AppId] = '00000003-0000-0ff1-ce00-000000000000';
    cols[H.AppIdentity_DisplayName] = 'Microsoft SharePoint Online';
    cols[H.ApplicationName] = 'SharePoint';
    cols[H.AccessedResource_PolicyDetails] = policyFor(upn, dt, op);
    {
      const base = spBaseUrl(upn);
      // Vary file path within the same day to simulate versions
      const key = `${upn}|${yyyymmdd(dt)}`;
      const seq = (makeRow._spSeq?.get(key) || 0);
      makeRow._spSeq = makeRow._spSeq || new Map();
      makeRow._spSeq.set(key, seq + 1);
      const { folder, filename } = buildFilePath(upn, dt, seq);
      const sub = buildSubfolders(upn, dt);
      cols[H.AccessedResource_SiteUrl] = joinUrl(base, ['Shared Documents', folder, ...sub, filename]);
      const ext = filename.split('.').pop() || '';
      cols[H.AccessedResource_Action] = chooseActionForExt(ext, op);
    }
  } else if (type === 'OneDrive') {
    // OneDrive for Business is backed by SharePoint Online
    cols[H.AppIdentity_AppId] = '00000003-0000-0ff1-ce00-000000000000';
    cols[H.AppIdentity_DisplayName] = 'Microsoft OneDrive';
    cols[H.ApplicationName] = 'OneDrive';
    cols[H.AccessedResource_PolicyDetails] = policyFor(upn, dt, op);
    {
      const base = odBaseUrl(upn);
      const key = `${upn}|${yyyymmdd(dt)}`;
      const seq = (makeRow._odSeq?.get(key) || 0);
      makeRow._odSeq = makeRow._odSeq || new Map();
      makeRow._odSeq.set(key, seq + 1);
      const { folder, filename } = buildFilePath(upn, dt, seq);
      const sub = buildSubfolders(upn, dt);
      cols[H.AccessedResource_SiteUrl] = joinUrl(base, ['Documents', folder, ...sub, filename]);
      const ext = filename.split('.').pop() || '';
      cols[H.AccessedResource_Action] = chooseActionForExt(ext, op);
    }
  } else if (type === 'Teams') {
    cols[H.AppIdentity_AppId] = '1fec8e78-bce4-4aaf-ab1b-5451cc387264';
    cols[H.AppIdentity_DisplayName] = 'Microsoft Teams';
    cols[H.ApplicationName] = 'Teams';
    cols[H.ThreadId] = pseudoId(upn, 'teams-thread');
    cols[H.Context_Id] = pseudoId(upn, 'teams-context');
    if (/MessageSent|MeetingDetail/i.test(op)) cols[H.MessageIds] = `teamsmsg-${weekStartKey(dt)}-${upn.slice(2,8).toLowerCase()}`;
    // Some policy context for Teams as interaction with resources
    cols[H.AccessedResource_Action] = /Meeting/i.test(op) ? 'Join' : 'Post';
    cols[H.AccessedResource_PolicyDetails] = policyFor(upn, dt, op);
  } else if (type === 'ExchangeItem') {
    cols[H.AppIdentity_AppId] = '00000002-0000-0ff1-ce00-000000000000';
    cols[H.AppIdentity_DisplayName] = 'Microsoft Exchange Online';
    cols[H.ApplicationName] = 'Outlook';
    if (/Create/i.test(op)) cols[H.MessageIds] = `mailmsg-${weekStartKey(dt)}-${upn.slice(4,10).toLowerCase()}`;
    if (/MailItemsAccessed/i.test(op)) cols[H.MessageIds] = `mailmsg-${weekStartKey(dt)}-${upn.slice(4,10).toLowerCase()}`;
    // Treat access policy for mail read/create
    cols[H.AccessedResource_Action] = /Create/i.test(op) ? 'Send' : (/MailItemsAccessed/i.test(op) ? 'Read' : 'Access');
    cols[H.AccessedResource_PolicyDetails] = policyFor(upn, dt, op);
  } else if (type === 'Copilot') {
    // Copilot-specific fields are already handled in the main isCopilot section above
    // This section is preserved for any additional non-Copilot specific processing
    cols[H.MessageIds] = `chain-${appHost.toLowerCase()}-${weekStartKey(dt)}-${upn.slice(0,6).toLowerCase()}`;
  }
  return cols.map(v => v).join(',');
}

// Generation
const out = [];
out.push(outHeader);

// Parameters controlling volume with realistic Copilot adoption patterns
const WEEKDAY_ACTIVE_FRACTION = 0.6;
const WEEKEND_ACTIVE_FRACTION = 0.08;
const BASE_EVENTS_WEEKDAY = [0,1,1,2]; // average ~1.1
const BASE_EVENTS_WEEKEND = [0,0,0,1]; // sparse
const UPLIFT_MULTIPLIER = 1.4; // 40% productivity increase after adoption (realistic ROI)

// Enhanced Copilot usage patterns for staggered 80% adoption
function getCopilotUsageRate(adoptionDate, currentDate) {
  const daysSinceAdoption = Math.floor((currentDate - adoptionDate) / (1000 * 60 * 60 * 24));
  
  if (daysSinceAdoption < 7) {
    // First week: 60% daily usage (learning phase)
    return 0.6;
  } else if (daysSinceAdoption < 30) {
    // First month: 75% daily usage (ramping up)
    return 0.75;
  } else if (daysSinceAdoption < 60) {
    // Month 2: 85% daily usage (regular use)
    return 0.85;
  } else {
    // Mature users: 90% daily usage (power users)
    return 0.9;
  }
}

// Enhanced Copilot events per day based on user maturity
function getCopilotEventsPerDay(adoptionDate, currentDate, isWeekend) {
  const daysSinceAdoption = Math.floor((currentDate - adoptionDate) / (1000 * 60 * 60 * 24));
  const baseMultiplier = isWeekend ? 0.3 : 1.0;
  
  if (daysSinceAdoption < 7) {
    // New users: 1-2 Copilot interactions per active day
    return Math.floor(Math.random() * 2 + 1) * baseMultiplier;
  } else if (daysSinceAdoption < 30) {
    // Ramping users: 2-4 Copilot interactions per active day
    return Math.floor(Math.random() * 3 + 2) * baseMultiplier;
  } else if (daysSinceAdoption < 60) {
    // Regular users: 3-6 Copilot interactions per active day
    return Math.floor(Math.random() * 4 + 3) * baseMultiplier;
  } else {
    // Power users: 4-8 Copilot interactions per active day
    return Math.floor(Math.random() * 5 + 4) * baseMultiplier;
  }
}

const upnList = upns; // maintain selection order

for (const day of eachDay(START_DATE, END_DATE)) {
  const weekend = isWeekend(day);
  const activeFraction = weekend ? WEEKEND_ACTIVE_FRACTION : WEEKDAY_ACTIVE_FRACTION;
  const activeCount = Math.floor(upnList.length * activeFraction);
  // Pick a random subset of active users
  const shuffled = [...upnList].sort(() => Math.random() - 0.5);
  const actives = shuffled.slice(0, activeCount);
  for (const upn of actives) {
    const adopted = adoption.get(upn);
    const hasAdopted = adopted && adopted <= day;
    
    // Generate base M365 activity (with productivity uplift if adopted)
    const base = weekend ? randChoice(BASE_EVENTS_WEEKEND) : randChoice(BASE_EVENTS_WEEKDAY);
    const baseAfter = hasAdopted ? Math.round(base * UPLIFT_MULTIPLIER) : base;
    const nEvents = Math.min(4, Math.max(0, baseAfter)); // Increased max to 4 for adopted users
    
    for (let i = 0; i < nEvents; i++) {
      const rt = randChoice(recordTypes);
      const dt = weekend ? offHour(day) : workHour(day);
      const row = makeRow({ dt, upn, type: rt.type, op: randChoice(rt.ops), isCopilot: false });
      out.push(row);
    }
    
    // Enhanced Copilot event generation for adopted users
    if (hasAdopted) {
      const usageRate = getCopilotUsageRate(adopted, day);
      const willUseCopilot = Math.random() < usageRate;
      
      if (willUseCopilot) {
        const copilotEventsToday = getCopilotEventsPerDay(adopted, day, weekend);
        
        // Generate multiple Copilot interactions per day for active users
        for (let c = 0; c < copilotEventsToday; c++) {
          const dt = weekend ? offHour(day) : workHour(day);
          
          // Vary the Copilot AppHost based on user maturity and randomness (authentic Microsoft 365 Copilot AppHost values)
          const daysSinceAdoption = Math.floor((day - adopted) / (1000 * 60 * 60 * 24));
          const appHosts = ['BizChat', 'Teams', 'Word', 'Excel', 'PowerPoint', 'Outlook', 'OneNote', 'Loop', 'SharePoint', 'OneDrive'];
          
          // New users start with basic AppHosts, mature users use all AppHosts
          let availableAppHosts;
          if (daysSinceAdoption < 14) {
            availableAppHosts = ['BizChat', 'Teams', 'Word']; // Basic AppHosts
          } else if (daysSinceAdoption < 45) {
            availableAppHosts = ['BizChat', 'Teams', 'Word', 'Excel', 'Outlook']; // Expanding usage
          } else {
            availableAppHosts = appHosts; // All AppHosts for power users including SharePoint/OneDrive
          }
          
          const appHost = availableAppHosts[Math.floor(Math.random() * availableAppHosts.length)];
          const row = makeRow({ dt, upn, type: 'Copilot', op: 'CopilotInteraction', isCopilot: true, appHost });
          out.push(row);
        }
      }
    }
  }
}

// Inject exact license-date events and app-specific prompt anchors so Power BI visuals
// match MS Graph CSVs exactly for those dates.
function clampToRange(d) {
  if (d < START_DATE) return START_DATE;
  if (d > END_DATE) return END_DATE;
  return d;
}

for (const upn of upnList) {
  // Use adoption (earliest across licensed and usage) for anchor
  const lic = adoption.get(upn) || licenseDate.get(upn);
  if (lic) {
    const dt = workHour(clampToRange(lic));
    // Map license anchor to a realistic host operation for the earliest likely surface
    // All Copilot events should use the official "CopilotInteraction" operation
    let appHost = 'BizChat';
    let op = 'CopilotInteraction';
    const apps = appActivity.get(upn);
    if (apps) {
      if (apps['Teams']?.length) { appHost = 'Teams'; op = 'CopilotInteraction'; }
      else if (apps['Outlook']?.length) { appHost = 'Outlook'; op = 'CopilotInteraction'; }
      else if (apps['Word']?.length || apps['Excel']?.length || apps['PowerPoint']?.length || apps['OneNote']?.length || apps['Loop']?.length) {
        // any file-based app
        appHost = (apps['Word']?.length && 'Word') || (apps['Excel']?.length && 'Excel') || (apps['PowerPoint']?.length && 'PowerPoint') || (apps['OneNote']?.length && 'OneNote') || 'Loop';
        op = 'CopilotInteraction';
      }
    }
    out.push(makeRow({ dt, upn, type: 'Copilot', op, isCopilot: true, appHost }));
  }
  const apps = appActivity.get(upn);
  if (apps) {
    for (const [appName, dates] of Object.entries(apps)) {
      for (const d of dates) {
        const dt = workHour(clampToRange(d));
        // Use official host operations for prompts per app context
        let op = 'CopilotInteraction'; // All Copilot events use official CopilotInteraction operation
        // All Copilot events, regardless of AppHost, should use CopilotInteraction operation
        // Legacy mapping logic removed - Microsoft schema requires consistent operation for RecordType 261
        // Map legacy app names to authentic AppHost values
        let appHost = appName;
        if (appName === 'BizChat') appHost = 'BizChat';
        const row = makeRow({ dt, upn, type: 'Copilot', op, isCopilot: true, appHost });
        out.push(row);
      }
    }
  }
}

// Inject workload-specific anchors from non-Copilot CSVs so Purview has an event on each Last Activity Date
function injectWorkloadAnchors(csvPath, upnHeaderRegex, dateHeaderRegex, recordType, op) {
  if (!fs.existsSync(csvPath)) return;
  const { header, rows } = parseCsv(fs.readFileSync(csvPath, 'utf8'));
  const names = header.map(h => h.replace(/"/g, ''));
  const upnIdx = names.findIndex(h => upnHeaderRegex.test(h));
  const dateIdx = names.findIndex(h => dateHeaderRegex.test(h));
  if (upnIdx < 0 || dateIdx < 0) return;
  for (const r of rows) {
    const upn = (r[upnIdx] || '').replace(/^"|"$/g, '');
    if (!upn || !upnSet.has(upn)) continue;
    const d0 = (r[dateIdx] || '').replace(/^"|"$/g, '');
    const d = parseDateYYYYMMDD(d0);
    if (!d) continue;
    const dt = workHour(clampToRange(d));
    // Regular Teams activity should not have Copilot context
    out.push(makeRow({ dt, upn, type: recordType, op, isCopilot: false }));
  }
}

injectWorkloadAnchors(TEAMS_PATH, /User Principal Name/i, /Last Activity Date/i, 'Teams', 'MessageSent');
injectWorkloadAnchors(SPO_PATH, /User Principal Name/i, /Last Activity Date/i, 'SharePointFileOperation', 'FileAccessed');
injectWorkloadAnchors(ODB_PATH, /User Principal Name/i, /Last Activity Date/i, 'OneDrive', 'FileAccessed');
injectWorkloadAnchors(EMAIL_PATH, /User Principal Name/i, /Last Activity Date/i, 'ExchangeItem', 'MailItemsAccessed');

fs.writeFileSync(PURVIEW_OUT_PATH, out.join('\n'));
console.log(`Wrote ${PURVIEW_OUT_PATH} with ${out.length-1} rows`);


