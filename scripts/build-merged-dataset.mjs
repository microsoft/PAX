#!/usr/bin/env node
// Build audit-activities.merged.json from curated and generated datasets
// Usage: node scripts/build-merged-dataset.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const DIR = path.dirname(__filename);

const readJson = (file) => {
  const fp = path.join(DIR, file);
  if (!fs.existsSync(fp)) return null;
  try { return JSON.parse(fs.readFileSync(fp, 'utf8')); } catch { return null; }
};

const writeJson = (file, data) => {
  const fp = path.join(DIR, file);
  fs.writeFileSync(fp, JSON.stringify(data, null, 2), 'utf8');
};

const curated = readJson('audit-activities.json');
const generated = readJson('audit-activities.generated.json');

// Merge categories: prefer curated labels; add generated-only categories
const byKey = new Map(); // key -> { key, label, items: [] }
const ensureCat = (key, label) => {
  const k = key || label || 'other';
  if (!byKey.has(k)) byKey.set(k, { key: k, label: label ?? key ?? 'other', items: [] });
  return byKey.get(k);
};

const addItems = (ds, preferFields = false) => {
  if (!ds?.categories) return;
  for (const c of ds.categories) {
    const cat = ensureCat(c.key ?? c.id ?? c.label, c.label ?? c.title ?? c.id);
    for (const it of c.items ?? []) {
      const id = it.id ?? it.op ?? it.label;
      if (!id) continue;
      const existsIdx = cat.items.findIndex(x => (x.id ?? x.op) === id);
      const next = {
        id,
        op: it.op ?? id,
        label: it.label ?? it.title ?? id,
        tier: it.tier,
        premium: it.premium,
        highVolume: it.highVolume,
        recommended: typeof it.recommended === 'boolean' ? it.recommended : (typeof it.tier === 'number' ? (it.tier >= 1 && it.tier <= 3) : undefined),
      };
      if (existsIdx === -1) {
        cat.items.push(next);
      } else if (preferFields) {
        // Prefer curated fields over existing
        const prev = cat.items[existsIdx];
        cat.items[existsIdx] = { ...prev, ...next };
      }
    }
  }
};

// Order: add curated first (to establish labels), then generated for missing ops
addItems(curated, true);
addItems(generated, false);

// Sort categories and items
const categories = Array.from(byKey.values()).sort((a,b)=>String(a.label).localeCompare(String(b.label)));
for (const c of categories) {
  c.items = c.items
    .filter((v,i,a)=>a.findIndex(x=> (x.id ?? x.op) === (v.id ?? v.op)) === i)
    .sort((a,b)=>String(a.label).localeCompare(String(b.label)));
}

// Build presets: all, curated, recommended
const all = [];
const curatedIds = new Set();
const recommended = new Set();
for (const c of curated?.categories ?? []) {
  for (const it of c.items ?? []) curatedIds.add(it.id ?? it.op ?? it.label);
}
for (const c of categories) {
  for (const it of c.items) {
    const id = it.id ?? it.op;
    all.push(id);
    if (it.recommended) recommended.add(id);
  }
}

const out = {
  version: new Date().toISOString().slice(0,10),
  categories,
  presets: { all, curated: Array.from(curatedIds), recommended: Array.from(recommended) },
  meta: {
    sourceFiles: { curated: !!curated, generated: !!generated },
    categoryCount: categories.length,
    itemCount: all.length,
  },
};

writeJson('audit-activities.merged.json', out);
console.log(`Merged dataset written: ${path.join(DIR, 'audit-activities.merged.json')}\n  - Categories: ${out.meta.categoryCount}\n  - Items: ${out.meta.itemCount}\n  - Presets: all=${out.presets.all.length}, curated=${out.presets.curated.length}, recommended=${out.presets.recommended.length}`);
