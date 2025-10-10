const fs = require('fs');
const path = require('path');

// Paths to check (resources bundled and dist)
const distDir = path.resolve(__dirname, '../dist');
const tauriResDir = path.resolve(__dirname, '../src-tauri/resources');

const forbiddenPatterns = [
  /generate-synthetic\.mjs$/i,
  /validate-synthetic\.mjs$/i,
  /analyze-purview-columns\.mjs$/i,
  /debug-adoption\.mjs$/i,
  /enhance-copilot-data\.mjs$/i,
  /sync-activities\.ts$/i,
  /output\//i,
];

function collectFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  const stack = [dir];
  while (stack.length) {
    const d = stack.pop();
    const entries = fs.readdirSync(d, { withFileTypes: true });
    for (const e of entries) {
      const full = path.join(d, e.name);
      if (e.isDirectory()) stack.push(full);
      else out.push(full);
    }
  }
  return out;
}

function checkDir(dir) {
  const files = collectFiles(dir);
  const hits = [];
  for (const f of files) {
    const rel = f.replace(/\\/g, '/');
    if (forbiddenPatterns.some((re) => re.test(rel))) hits.push(rel);
  }
  return hits;
}

const problems = [];
problems.push(...checkDir(distDir));
problems.push(...checkDir(tauriResDir));

if (problems.length) {
  console.error('Forbidden synthetic artifacts found in build output/resources:\n' + problems.join('\n'));
  process.exit(1);
} else {
  console.log('Synthetic generation/validation artifacts not present in packaged outputs.');
}


