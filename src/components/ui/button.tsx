import * as React from 'react';
import { clsx } from 'clsx';
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> { variant?: 'default'|'secondary'|'ghost'|'soft'; }
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(({ className, variant='default', ...props}, ref)=>{
  const base = 'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 h-9 px-4 py-2';
  const styles: Record<string,string> = {
    default: 'bg-blue-600 text-white hover:bg-blue-700',
    secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
    soft: 'bg-blue-100 text-blue-900 hover:bg-blue-200',
    ghost: 'bg-transparent hover:bg-gray-100'
  };
  return <button ref={ref} className={clsx(base, styles[variant], className)} {...props} />;
});
Button.displayName = 'Button';


