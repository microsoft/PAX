import * as React from 'react';
import { Popover, PopoverTrigger, PopoverContent } from './popover';

function toYMD(d: Date){
  const y = d.getFullYear();
  const m = String(d.getMonth()+1).padStart(2,'0');
  const day = String(d.getDate()).padStart(2,'0');
  return `${y}-${m}-${day}`;
}
function parseYMD(ymd?: string): Date{
  if(!ymd) return new Date();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd);
  if(!m) return new Date();
  const d = new Date(Number(m[1]), Number(m[2])-1, Number(m[3]));
  if(Number.isNaN(d.getTime())) return new Date();
  return d;
}
function fmtDisplay(ymd?: string){
  const d = parseYMD(ymd);
  const mm = String(d.getMonth()+1).padStart(2,'0');
  const dd = String(d.getDate()).padStart(2,'0');
  const yyyy = d.getFullYear();
  return `${mm}/${dd}/${yyyy}`;
}

export function DatePicker({ value, onChange, label }:{ value?: string; onChange:(v:string)=>void; label?: string }){
  const [open, setOpen] = React.useState(false);
  const rootRef = React.useRef<HTMLDivElement|null>(null);
  const selected = parseYMD(value);
  const [viewYear, setViewYear] = React.useState(selected.getFullYear());
  const [viewMonth, setViewMonth] = React.useState(selected.getMonth());

  React.useEffect(()=>{
    const s = parseYMD(value);
    setViewYear(s.getFullYear());
    setViewMonth(s.getMonth());
  }, [value, open]);

  // Close when clicking outside or pressing Escape
  React.useEffect(()=>{
    if(!open) return;
    const onDocMouseDown = (e: MouseEvent)=>{
      const el = rootRef.current;
      if(!el) return;
      if(e.target instanceof Node && !el.contains(e.target)){
        setOpen(false);
      }
    };
    const onKeyDown = (e: KeyboardEvent)=>{
      if(e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDocMouseDown);
    document.addEventListener('keydown', onKeyDown);
    return ()=>{
      document.removeEventListener('mousedown', onDocMouseDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [open]);

  function daysInMonth(y:number, m:number){ return new Date(y, m+1, 0).getDate(); }
  function startDay(y:number, m:number){ return new Date(y, m, 1).getDay(); }
  function isSameDay(a:Date, b:Date){ return a.getFullYear()===b.getFullYear() && a.getMonth()===b.getMonth() && a.getDate()===b.getDate(); }

  const today = new Date();
  const dim = daysInMonth(viewYear, viewMonth);
  const firstDow = startDay(viewYear, viewMonth); // 0=Sun
  const cells: Array<{date: Date; inMonth: boolean}> = [];
  // leading blanks from prev month
  for(let i=0; i<firstDow; i++){
    const d = new Date(viewYear, viewMonth, -(firstDow - 1 - i));
    cells.push({ date: d, inMonth: false });
  }
  // days of current month
  for(let d=1; d<=dim; d++) cells.push({ date: new Date(viewYear, viewMonth, d), inMonth: true });
  // pad to full weeks
  while(cells.length % 7){
    const last = cells[cells.length-1].date;
    cells.push({ date: new Date(last.getFullYear(), last.getMonth(), last.getDate()+1), inMonth: false });
  }

  function prevMonth(){
    const m = viewMonth - 1;
    if(m < 0){ setViewMonth(11); setViewYear(y=>y-1); } else setViewMonth(m);
  }
  function nextMonth(){
    const m = viewMonth + 1;
    if(m > 11){ setViewMonth(0); setViewYear(y=>y+1); } else setViewMonth(m);
  }
  function pick(d: Date){ onChange(toYMD(d)); setOpen(false); }

  const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const dow = ['Su','Mo','Tu','We','Th','Fr','Sa'];

  return (
    <div ref={rootRef} className="relative">
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger>
        <button type="button" onClick={()=> setOpen(o=>!o)} className="w-full border rounded px-3 py-2 bg-white flex items-center justify-between">
          <span className="text-left">{fmtDisplay(value)}</span>
          <span className="text-xs text-gray-500" aria-hidden="true">📅</span>
        </button>
      </PopoverTrigger>
      {open && (
      <PopoverContent className="p-3 w-72">
        <div className="flex items-center justify-between mb-2">
          <button type="button" className="text-sm px-2 py-1 hover:bg-gray-100 rounded" onClick={prevMonth}>‹</button>
          <div className="font-medium text-sm">{monthNames[viewMonth]} {viewYear}</div>
          <button type="button" className="text-sm px-2 py-1 hover:bg-gray-100 rounded" onClick={nextMonth}>›</button>
        </div>
        <div className="grid grid-cols-7 gap-1 text-center text-xs text-gray-600 mb-1">
          {dow.map(d=> <div key={d}>{d}</div>)}
        </div>
        <div className="grid grid-cols-7 gap-1 text-center">
          {cells.map((c, i)=>{
            const sel = isSameDay(c.date, selected);
            const isToday = isSameDay(c.date, today);
            return (
              <button
                key={i}
                type="button"
                onClick={()=> c.inMonth && pick(c.date)}
                className={`h-8 w-8 rounded ${c.inMonth? 'text-gray-900':'text-gray-400'} ${sel? 'bg-blue-600 text-white': isToday? 'ring-1 ring-blue-300':'hover:bg-gray-100'}`}
              >{c.date.getDate()}</button>
            );
          })}
        </div>
        <div className="flex justify-between mt-3 text-xs">
          <button type="button" className="px-2 py-1 rounded border hover:bg-gray-50" onClick={()=>{ onChange(''); setOpen(false); }}>Clear</button>
          <button type="button" className="px-2 py-1 rounded border hover:bg-gray-50" onClick={()=>{ onChange(toYMD(today)); setOpen(false); }}>Today</button>
        </div>
      </PopoverContent>
      )}
    </Popover>
    </div>
  );
}


