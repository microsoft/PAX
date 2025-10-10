import * as React from 'react';
export const Card: React.FC<React.HTMLAttributes<HTMLDivElement>> = ({className='', ...props}) => (
  <div className={`bg-white border rounded-lg shadow-sm ${className}`} {...props} />
);


