import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';

const FILE = path.join('output','Purview_Export_Synthetic_6mo_1000users.csv');

if (!fs.existsSync(FILE)) {
  console.error('Missing file', FILE);
  process.exit(1);
}

(async () => {
  const rl = readline.createInterface({ input: fs.createReadStream(FILE), crlfDelay: Infinity });
  let header = null;
  let counts = [];
  let total = 0;
  const sampleVals = new Map(); // idx -> Set of sample non-empty values

  for await (const line of rl) {
    if (!line) continue;
    if (!header) {
      header = line.split(',');
      counts = new Array(header.length).fill(0);
      continue;
    }
    const cols = line.split(',');
    total++;
    for (let i=0;i<header.length;i++) {
      const v = cols[i] ?? '';
      const has = v.trim() !== '';
      if (has) {
        counts[i]++;
        if (!sampleVals.has(i)) sampleVals.set(i, new Set());
        const set = sampleVals.get(i);
        if (set.size < 5) set.add(v);
      }
    }
  }

  const rows = [];
  rows.push(['Index','Column','NonEmpty','Total','FillRate','Samples'].join(','));
  for (let i=0;i<header.length;i++) {
    const nonEmpty = counts[i];
    const fill = total ? (nonEmpty/total) : 0;
    const sample = sampleVals.has(i) ? [...sampleVals.get(i)].join(' | ') : '';
    rows.push([String(i), header[i], String(nonEmpty), String(total), fill.toFixed(4), sample.includes(',') ? '"'+sample+'"' : sample].join(','));
  }

  const out = path.join('output','purview_column_fill.csv');
  fs.writeFileSync(out, rows.join('\n'));
  console.log('Wrote', out);
  console.log('Completely empty columns:');
  for (let i=0;i<header.length;i++) {
    if (counts[i] === 0) console.log(i, header[i]);
  }
})();
