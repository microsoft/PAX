import * as React from 'react';
export const Switch: React.FC<{checked:boolean; onCheckedChange:(v:boolean)=>void}> = ({checked,onCheckedChange}) => (
  <button type='button' onClick={()=>onCheckedChange(!checked)} className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${checked? 'bg-blue-600':'bg-gray-300'}`}>
    <span className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform ${checked? 'translate-x-5':'translate-x-1'}`}></span>
  </button>
);


