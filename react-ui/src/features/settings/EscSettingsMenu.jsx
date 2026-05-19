import { Eye, Maximize2, MousePointer2, RotateCcw, SlidersHorizontal, X } from 'lucide-react';
import { DEFAULT_HUD_SETTINGS, normalizeHudSettings } from '../../state/settings';

function formatScale(value) {
  return `${Math.round(Number(value) * 100)}%`;
}

function formatSensitivity(value) {
  return `${Number(value).toFixed(2)}x`;
}

function SliderRow({ label, icon: Icon, value, min, max, step, onChange, format = formatScale }) {
  return (
    <label className="grid grid-cols-[110px_minmax(0,1fr)_54px] items-center gap-3 text-xs text-slate-200">
      <span className="flex min-w-0 items-center gap-2 font-bold">
        {Icon && <Icon size={14} className="shrink-0 text-cyan-300" />}
        <span className="truncate">{label}</span>
      </span>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(event) => onChange(Number(event.target.value))}
        className="h-1.5 w-full accent-cyan-400"
      />
      <span className="rounded border border-slate-700 bg-slate-950/80 px-1.5 py-1 text-right font-mono text-[10px] font-black text-cyan-100">
        {format(value)}
      </span>
    </label>
  );
}

export default function EscSettingsMenu({ open, settings, onSettingsChange, onOpenChange }) {
  if (!open) return null;

  const normalized = normalizeHudSettings(settings);

  const updateSettings = (patch) => {
    onSettingsChange?.(normalizeHudSettings({
      ...normalized,
      ...patch,
      ui: {
        ...normalized.ui,
        ...(patch.ui ?? {}),
      },
    }));
  };

  const updateUi = (patch) => {
    updateSettings({
      ui: {
        ...normalized.ui,
        ...patch,
      },
    });
  };

  return (
    <div className="pointer-events-auto fixed inset-0 z-[90] flex items-center justify-center bg-black/42 p-6 font-sans text-white backdrop-blur-[2px]">
      <div className="w-[min(520px,94vw)] overflow-hidden rounded-lg border border-slate-700 bg-slate-950/95 shadow-[0_0_44px_rgba(0,0,0,0.78)]">
        <div className="flex items-center justify-between border-b border-slate-800 px-5 py-3">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded border border-cyan-400/45 bg-cyan-500/12 text-cyan-200">
              <SlidersHorizontal size={18} />
            </div>
            <div>
              <div className="font-mono text-sm font-black tracking-widest text-cyan-100">ESC MENU</div>
              <div className="text-[10px] font-bold uppercase tracking-wider text-slate-500">HUD CONTROL</div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => onSettingsChange?.(DEFAULT_HUD_SETTINGS)}
              className="flex h-9 w-9 items-center justify-center rounded border border-slate-700 bg-slate-900 text-slate-300 transition-colors hover:bg-slate-800"
              aria-label="reset settings"
              title="重置"
            >
              <RotateCcw size={16} />
            </button>
            <button
              type="button"
              onClick={() => onOpenChange?.(false)}
              className="flex h-9 w-9 items-center justify-center rounded border border-slate-700 bg-slate-900 text-slate-300 transition-colors hover:bg-red-500/20 hover:text-red-200"
              aria-label="close settings"
              title="关闭"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        <div className="space-y-5 p-5">
          <section className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.18em] text-slate-500">Mouse</div>
            <SliderRow
              label="灵敏度"
              icon={MousePointer2}
              value={normalized.mouseSensitivity}
              min={0.1}
              max={5}
              step={0.05}
              onChange={(mouseSensitivity) => updateSettings({ mouseSensitivity })}
              format={formatSensitivity}
            />
          </section>

          <section className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.18em] text-slate-500">Global UI</div>
            <SliderRow
              label="总体大小"
              icon={Maximize2}
              value={normalized.ui.scale}
              min={0.5}
              max={1.8}
              step={0.05}
              onChange={(scale) => updateUi({ scale })}
            />
            <SliderRow
              label="总体透明"
              icon={Eye}
              value={normalized.ui.opacity}
              min={0.15}
              max={1}
              step={0.05}
              onChange={(opacity) => updateUi({ opacity })}
            />
          </section>
        </div>
      </div>
    </div>
  );
}
