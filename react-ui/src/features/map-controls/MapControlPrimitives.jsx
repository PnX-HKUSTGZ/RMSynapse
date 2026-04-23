import { createElement } from 'react';
import { Activity } from 'lucide-react';

export function ToastBanner({ message }) {
  if (!message) return null;

  return (
    <div className="pointer-events-none fixed left-1/2 top-4 z-[60] -translate-x-1/2 rounded-full border border-cyan-500 bg-cyan-900/90 px-4 py-2 text-sm text-cyan-50 shadow-lg shadow-cyan-900/30">
      <div className="flex items-center gap-2">
        <Activity size={14} />
        <span>{message}</span>
      </div>
    </div>
  );
}

export function RoleTab({ role, label, icon, activeRole, onSelect }) {
  return (
    <button
      onClick={() => onSelect(role)}
      className={`flex items-center gap-2 rounded-md border px-3 py-1.5 text-xs font-bold transition-colors ${
        activeRole === role
          ? 'border-cyan-400 bg-cyan-500/15 text-cyan-300'
          : 'border-slate-700 bg-slate-900/70 text-slate-300 hover:bg-slate-800'
      }`}
    >
      {createElement(icon, { size: 14 })}
      <span>{label}</span>
    </button>
  );
}

export function SelectionButton({ active, onClick, disabled, children }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`flex-1 rounded-md border px-2 py-1.5 text-xs font-medium transition-colors ${
        disabled ? 'cursor-not-allowed opacity-60' : 'hover:bg-slate-700'
      } ${active ? 'border-cyan-500 bg-cyan-500/15 text-cyan-300' : 'border-slate-700 bg-slate-800 text-slate-300'}`}
    >
      {children}
    </button>
  );
}

export function CommandButton({ num, text, onClick, color = 'border-slate-700 hover:bg-slate-700 text-slate-300' }) {
  return (
    <button onClick={onClick} className={`rounded-lg border bg-slate-800 p-2 transition-colors ${color}`}>
      <div className="mb-1 text-[10px] font-mono opacity-60">[{num}]</div>
      <div className="text-xs font-bold leading-tight">{text}</div>
    </button>
  );
}

export function SectionPanel({ title, icon, accentClass = 'bg-cyan-500', children, minWidth = 'min-w-[360px]' }) {
  return (
    <section className={`${minWidth} rounded-xl border border-slate-700 bg-slate-900/92 p-3`}>
      <div className="mb-2.5 flex items-center gap-2 text-sm font-bold text-white">
        <span className={`h-4 w-1 rounded-full ${accentClass}`} />
        {createElement(icon, { size: 16, className: 'text-slate-300' })}
        <span>{title}</span>
      </div>
      {children}
    </section>
  );
}
