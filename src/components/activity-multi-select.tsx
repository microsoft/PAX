import React, { useState, useMemo } from 'react';
import { open as openExternal } from '@tauri-apps/api/shell';
import { ALL_ACTIVITIES, Activity } from '../lib/activities';
interface Props {
  value: string[];
  onChange: (ids: string[]) => void;
  error?: string;
  categories?: Record<string, Activity[]>; // optional dynamic override
  relevant?: Activity[]; // optional dynamic override
}

export function ActivityMultiSelect({ value, onChange, error, categories, relevant }: Props){
  const [open,setOpen] = useState(false);
  const [search,setSearch] = useState('');
  // Only show categories; do not render a separate "Relevant" section.
  const ALL = categories ?? ALL_ACTIVITIES;

  // For chip labels and lookups, flatten all category activities
  const allActivities: Activity[] = useMemo(()=>[
    ...Object.values(ALL).flat()
  ],[ALL]);

  const filteredCategories = useMemo(()=>{
    const out:Record<string,Activity[]>={};
    for(const [cat, acts] of Object.entries(ALL)){
      const f = acts.filter(a=> a.name.toLowerCase().includes(search.toLowerCase()) || (a.description||'').toLowerCase().includes(search.toLowerCase()));
      if(f.length) out[cat]=f;
    }
    return out;
  },[search, ALL]);

  function toggle(id:string){
    if(value.includes(id)) onChange(value.filter(v=>v!==id)); else onChange([...value,id]);
  }

  return <div>
    <label className="font-semibold flex items-center gap-2">Activities
      <a
        className="text-blue-600 underline text-xs"
        href="#"
        onClick={(e)=>{ e.preventDefault(); openExternal('https://learn.microsoft.com/en-us/purview/audit-log-activities'); }}
      >View full activity reference</a>
    </label>
    <div className="flex items-start gap-3 min-w-0">
  <div className="flex-1 min-w-0 relative">
        <button
          type="button"
          className="w-full border rounded px-3 py-2 bg-white flex items-center justify-between min-w-0"
          onClick={()=>setOpen(o=>!o)}
          aria-haspopup="listbox"
          aria-expanded={open}
        >
          <span className="truncate text-left">{value.length?`${value.length} selected`:'Select activities...'}</span>
          <span className={`text-xs text-gray-500 transition-transform ${open? 'rotate-180':''}`} aria-hidden="true">▼</span>
        </button>
  {open && <div className="border rounded bg-white shadow p-2 max-h-96 overflow-y-auto overflow-x-hidden text-sm w-full max-w-full absolute left-0 right-0 z-20 mt-1">
      {/* Search only; selected chips are shown above the control */}
      <div className="sticky top-0 z-10 bg-white pb-2">
        <input placeholder="Search..." value={search} onChange={e=>setSearch(e.target.value)} className="w-full border rounded px-2 py-1 mb-2" />
      </div>
      {Object.entries(filteredCategories).map(([cat, acts])=> <div key={cat} className="mt-3">
        <div className="mb-1 font-semibold text-xs text-gray-600 uppercase break-words whitespace-normal">{cat}</div>
        {acts.map(a=> <div key={a.id} className="flex items-start gap-2 py-1 cursor-pointer break-words whitespace-normal min-w-0" onClick={()=>toggle(a.id)}>
          <input type="checkbox" readOnly checked={value.includes(a.id)} />
          <div className="min-w-0 flex-1">
            <div className="font-medium break-words whitespace-normal">{a.name}</div>
            <div className="text-xs text-gray-500 break-words whitespace-normal">{a.description}</div>
          </div>
        </div>)}
      </div>)}
        </div>}
      </div>
      {/* Always-visible selected chips summary on the right */}
      <div className="flex-none w-64 max-w-[50%] mt-1 border rounded bg-white p-2 max-h-96 overflow-y-auto overflow-x-hidden min-w-0">
        <div className="text-xs font-semibold text-gray-600 mb-1">Selected</div>
        <div className="flex flex-wrap gap-1 min-w-0">
          {value.map(id=>{ const a = allActivities.find(x=>x.id===id); return a && <span key={id} className="bg-blue-100 text-blue-800 px-2 py-0.5 rounded text-xs break-words whitespace-normal max-w-full inline-block">{a.name}</span>; })}
        </div>
      </div>
    </div>
    {error && <div className="text-red-600 text-sm mt-1">{error}</div>}
  </div>;
}
