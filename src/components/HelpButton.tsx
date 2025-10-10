import React from 'react';

export function HelpButton({ onClick, className, title }: { onClick: ()=>void; className?: string; title?: string }){
  return (
    <button
      type="button"
      aria-label={title || 'Help'}
      title={title || 'Help'}
      onClick={onClick}
      className={(className||'') + ' inline-flex items-center justify-center w-7 h-7 rounded-full border border-red-500 text-red-600 bg-white hover:bg-red-50 active:bg-red-100 shadow-sm'}
    >
      <span className="font-bold text-sm">?</span>
    </button>
  );
}


