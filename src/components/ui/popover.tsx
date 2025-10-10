import * as React from 'react';
export const Popover: React.FC<{open:boolean; onOpenChange:(o:boolean)=>void; children:React.ReactNode}> = ({children}) => (
  <div className='relative'>{children}</div>
);
export const PopoverTrigger: React.FC<{asChild?:boolean; children:React.ReactNode; onClick?:()=>void}> = ({children,onClick}) => {
  if(!React.isValidElement(children)) return <>{children}</>;
  const child = children as any;
  const existing = child.props?.onClick as (e: any) => void | undefined;
  const composed = (e:any)=>{
    if(typeof existing === 'function') existing(e);
    if(typeof onClick === 'function') onClick();
  };
  return React.cloneElement(child, { onClick: composed });
};
type Placement = 'top'|'bottom'|'left'|'right';
type Align = 'start'|'center'|'end';
interface PopoverContentProps extends React.HTMLAttributes<HTMLDivElement> {
  placement?: Placement;
  align?: Align;
  sideOffset?: number;
}

export const PopoverContent: React.FC<PopoverContentProps> = ({className='', style, placement='bottom', align='end', sideOffset=6, ...props}) => {
  const pos: React.CSSProperties = { maxHeight: '60vh', overflow: 'auto' };
  if(placement === 'bottom'){
    pos.top = '100%';
    pos.marginTop = sideOffset;
    if(align === 'start') pos.left = 0;
    else if(align === 'center'){ pos.left = '50%'; pos.transform = 'translateX(-50%)'; }
    else pos.right = 0;
  } else if(placement === 'top'){
    pos.bottom = '100%';
    pos.marginBottom = sideOffset;
    if(align === 'start') pos.left = 0;
    else if(align === 'center'){ pos.left = '50%'; pos.transform = 'translateX(-50%)'; }
    else pos.right = 0;
  } else if(placement === 'right'){
    pos.left = '100%';
    pos.marginLeft = sideOffset;
    if(align === 'start') pos.top = 0;
    else if(align === 'center'){ pos.top = '50%'; pos.transform = 'translateY(-50%)'; }
    else pos.bottom = 0;
  } else if(placement === 'left'){
    pos.right = '100%';
    pos.marginRight = sideOffset;
    if(align === 'start') pos.top = 0;
    else if(align === 'center'){ pos.top = '50%'; pos.transform = 'translateY(-50%)'; }
    else pos.bottom = 0;
  }
  return (
    <div
      className={`border bg-white rounded shadow p-2 absolute z-50 ${className}`}
      style={{ ...pos, ...style }}
      {...props}
    />
  );
};


