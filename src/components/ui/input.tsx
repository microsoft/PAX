import * as React from 'react';
import { clsx } from 'clsx';
export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(({className, ...props}, ref)=>{
  return <input ref={ref} className={clsx('flex h-9 w-full rounded-md border px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500', className)} {...props} />;
});
Input.displayName='Input';
