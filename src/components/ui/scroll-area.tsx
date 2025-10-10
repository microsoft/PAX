import * as React from 'react';
export const ScrollArea: React.FC<React.HTMLAttributes<HTMLDivElement>> = ({className='', ...props}) => (
  <div className={`overflow-auto ${className}`} {...props} />
);


