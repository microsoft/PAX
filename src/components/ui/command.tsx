import * as React from 'react';
export const Command: React.FC<{children:React.ReactNode}> = ({children}) => <div>{children}</div>;
export const CommandInput: React.FC<{placeholder?:string; value:string; onValueChange:(v:string)=>void}> = ({placeholder,value,onValueChange}) => <input className='w-full border rounded px-2 py-1 mb-2' placeholder={placeholder} value={value} onChange={e=>onValueChange(e.target.value)} />;
export const CommandList: React.FC<{children:React.ReactNode}> = ({children}) => <div className='max-h-80 overflow-auto'>{children}</div>;
export const CommandGroup: React.FC<{heading?:string; children:React.ReactNode}> = ({heading, children}) => <div className='mb-3'><div className='text-[10px] font-semibold uppercase text-gray-500 mb-1'>{heading}</div>{children}</div>;
export const CommandItem: React.FC<{onSelect?:()=>void; className?:string; children:React.ReactNode}> = ({onSelect, className='', children}) => <div onClick={onSelect} className={`cursor-pointer px-1 py-1 rounded hover:bg-gray-100 flex items-start gap-2 ${className}`}>{children}</div>;


