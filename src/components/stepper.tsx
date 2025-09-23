import React from 'react';

export function Stepper({ step, steps }: { step:number; steps:string[] }) {
  return (
    <div className="flex items-center justify-between mb-4">
      {steps.map((label,i)=>(
        <div key={label} className="flex-1 flex items-center">
          <div className={`w-8 h-8 flex items-center justify-center rounded-full font-bold ${i===step?'bg-blue-600 text-white':i<step?'bg-green-600 text-white':'bg-gray-200 text-gray-600'}`}>{i+1}</div>
          <div className="ml-2 font-medium text-sm">{label}</div>
          {i<steps.length-1 && <div className="flex-1 h-1 bg-gray-200 mx-2 rounded" />}
        </div>
      ))}
    </div>
  );
}
