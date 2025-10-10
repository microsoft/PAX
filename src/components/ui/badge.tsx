import * as React from 'react';
export const Badge: React.FC<React.HTMLAttributes<HTMLSpanElement>> = ({className='', ...props}) => (
  <span className={`inline-flex items-center rounded bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800 ${className}`} {...props} />
);


