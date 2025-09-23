import * as React from 'react';
export const Progress: React.FC<{value?:number; indeterminate?:boolean}> = ({value, indeterminate}) => {
  return <div className='h-2 w-full bg-gray-200 rounded overflow-hidden'>
    <div className={`h-full bg-blue-600 transition-all ${indeterminate? 'animate-pulse w-1/2':''} ${value!==undefined? '' : ''}`} style={value!==undefined? {width: `${value}%`}: undefined} />
  </div>;
};
