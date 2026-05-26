import { useState } from 'react';
import {
  Crosshair,
  Eye,
  FileText,
  FolderOpen,
  HeartPulse,
  Keyboard,
  Maximize2,
  MousePointer2,
  Radio,
  RotateCcw,
  Server,
  SlidersHorizontal,
  Video,
  X,
  Zap,
} from 'lucide-react';
import { emitGodotOperation } from '../../bridge/godot';
import { DEFAULT_HUD_SETTINGS, DEFAULT_MQTT_BROKER_HOST, normalizeHudSettings } from '../../state/settings';

const HOTKEY_ROWS = [
  { key: 'heal', label: '买血', icon: HeartPulse },
  { key: 'directAmmo', label: '买弹', icon: Crosshair },
  { key: 'remoteAmmo', label: '远程买弹', icon: Radio },
  { key: 'revive', label: '立即复活', icon: Zap },
];

const MODIFIER_CODES = new Set([
  'AltLeft',
  'AltRight',
  'ControlLeft',
  'ControlRight',
  'MetaLeft',
  'MetaRight',
  'ShiftLeft',
  'ShiftRight',
]);

const CLIENT_ID_OPTIONS = [
  { value: '', label: '未指定' },
  { value: '1', label: '红方英雄 1' },
  { value: '2', label: '红方工程 2' },
  { value: '3', label: '红方步兵 3' },
  { value: '4', label: '红方步兵 4' },
  { value: '6', label: '红方空中 6' },
  { value: '7', label: '红方哨兵 7' },
  { value: '101', label: '蓝方英雄 101' },
  { value: '102', label: '蓝方工程 102' },
  { value: '103', label: '蓝方步兵 103' },
  { value: '104', label: '蓝方步兵 104' },
  { value: '106', label: '蓝方空中 106' },
  { value: '107', label: '蓝方哨兵 107' },
];

function formatScale(value) {
  return `${Math.round(Number(value) * 100)}%`;
}

function formatSensitivity(value) {
  return `${Number(value).toFixed(2)}x`;
}

function formatMilliseconds(value) {
  return `${Math.round(Number(value))}ms`;
}

function formatKeyCode(code) {
  if (code?.startsWith('Key')) return code.slice(3);
  if (code?.startsWith('Digit')) return code.slice(5);
  if (code?.startsWith('Numpad')) return `Num ${code.slice(6)}`;
  return String(code ?? '').replace(/([a-z])([A-Z])/g, '$1 $2') || '-';
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

function TextInputRow({ label, icon: Icon, value, onChange, type = 'text', placeholder = '', monospace = true, readOnly = false }) {
  return (
    <label className="grid grid-cols-[110px_minmax(0,1fr)] items-center gap-3 text-xs text-slate-200">
      <span className="flex min-w-0 items-center gap-2 font-bold">
        {Icon && <Icon size={14} className="shrink-0 text-cyan-300" />}
        <span className="truncate">{label}</span>
      </span>
      <input
        type={type}
        value={value}
        placeholder={placeholder}
        readOnly={readOnly}
        onChange={(event) => onChange(event.target.value)}
        className={`min-w-0 rounded border border-slate-700 bg-slate-950/90 px-2 py-1.5 text-xs text-slate-100 outline-none transition-colors placeholder:text-slate-600 focus:border-cyan-400/70 ${readOnly ? 'cursor-default text-slate-300' : ''} ${monospace ? 'font-mono' : ''}`}
      />
    </label>
  );
}

function SelectRow({ label, icon: Icon, value, options, onChange }) {
  return (
    <label className="grid grid-cols-[110px_minmax(0,1fr)] items-center gap-3 text-xs text-slate-200">
      <span className="flex min-w-0 items-center gap-2 font-bold">
        {Icon && <Icon size={14} className="shrink-0 text-cyan-300" />}
        <span className="truncate">{label}</span>
      </span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="min-w-0 rounded border border-slate-700 bg-slate-950/90 px-2 py-1.5 font-mono text-xs text-slate-100 outline-none transition-colors focus:border-cyan-400/70"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>{option.label}</option>
        ))}
      </select>
    </label>
  );
}

function CheckboxRow({ label, icon: Icon, checked, onChange }) {
  return (
    <label className="flex items-center justify-between rounded border border-slate-800 bg-slate-900/60 px-3 py-2 text-xs text-slate-200">
      <span className="flex min-w-0 items-center gap-2 font-bold">
        {Icon && <Icon size={14} className="shrink-0 text-cyan-300" />}
        <span className="truncate">{label}</span>
      </span>
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
        className="h-4 w-4 accent-cyan-400"
      />
    </label>
  );
}

export default function EscSettingsMenu({ open, settings, onSettingsChange, onOpenChange }) {
  const [capturingAction, setCapturingAction] = useState(null);

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
      hotkeys: {
        ...normalized.hotkeys,
        ...(patch.hotkeys ?? {}),
      },
      logging: {
        ...normalized.logging,
        ...(patch.logging ?? {}),
      },
      network: {
        ...normalized.network,
        ...(patch.network ?? {}),
        mqtt: {
          ...normalized.network.mqtt,
          ...(patch.network?.mqtt ?? {}),
        },
        video: {
          ...normalized.network.video,
          ...(patch.network?.video ?? {}),
        },
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

  const updateHotkeys = (patch) => {
    updateSettings({
      hotkeys: {
        ...normalized.hotkeys,
        ...patch,
      },
    });
  };

  const updateNetwork = (section, patch) => {
    updateSettings({
      network: {
        ...normalized.network,
        [section]: {
          ...normalized.network[section],
          ...patch,
        },
      },
    });
  };

  const updateLogging = (patch) => {
    updateSettings({
      logging: {
        ...normalized.logging,
        ...patch,
      },
    });
  };

  const chooseDebugLogPath = () => {
    emitGodotOperation(
      { type: 'chooseDebugLogPath', currentPath: normalized.logging.path },
      '[settings] chooseDebugLogPath',
      normalized.logging.path,
    );
  };

  const applyMqttConnection = () => {
    emitGodotOperation(
      {
        type: 'setConnectionSettings',
        settings: { mqtt: normalized.network.mqtt },
        applyConnection: true,
      },
      '[settings] applyMqttConnection',
      `${normalized.network.mqtt.host}:${normalized.network.mqtt.port}`,
    );
  };

  const captureHotkey = (action, event) => {
    if (capturingAction !== action) return;
    event.preventDefault();
    event.stopPropagation();

    if (event.code === 'Escape') {
      setCapturingAction(null);
      return;
    }

    if (MODIFIER_CODES.has(event.code)) return;
    updateHotkeys({ [action]: event.code });
    setCapturingAction(null);
  };

  return (
    <div className="pointer-events-auto fixed inset-0 z-[90] flex items-center justify-center bg-black/42 p-6 font-sans text-white backdrop-blur-[2px]">
      <div className="max-h-[90vh] w-[min(640px,94vw)] overflow-hidden rounded-lg border border-slate-700 bg-slate-950/95 shadow-[0_0_44px_rgba(0,0,0,0.78)]">
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

        <div className="max-h-[calc(90vh-66px)] space-y-5 overflow-y-auto p-5">
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

          <section className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.18em] text-slate-500">MQTT</div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <TextInputRow
                label="Broker"
                icon={Server}
                value={normalized.network.mqtt.host}
                onChange={(host) => updateNetwork('mqtt', { host })}
                placeholder={DEFAULT_MQTT_BROKER_HOST}
              />
              <TextInputRow
                label="Port"
                icon={Server}
                type="number"
                value={normalized.network.mqtt.port}
                onChange={(port) => updateNetwork('mqtt', { port })}
                placeholder="3333"
              />
              <SelectRow
                label="Client ID"
                icon={Server}
                value={normalized.network.mqtt.clientId}
                options={CLIENT_ID_OPTIONS}
                onChange={(clientId) => updateNetwork('mqtt', { clientId })}
              />
            </div>
            <div className="flex justify-end">
              <button
                type="button"
                onClick={applyMqttConnection}
                className="flex min-h-9 items-center justify-center gap-1 rounded border border-cyan-400/45 bg-cyan-500/12 px-3 text-xs font-bold text-cyan-100 transition-colors hover:border-cyan-300 hover:bg-cyan-500/20"
              >
                <RotateCcw size={14} />
                应用并重连
              </button>
            </div>
          </section>

          <section className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.18em] text-slate-500">Video</div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <TextInputRow
                label="UDP Port"
                icon={Video}
                type="number"
                value={normalized.network.video.port}
                onChange={(port) => updateNetwork('video', { port })}
                placeholder="3334"
              />
            </div>
          </section>

          <section className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.18em] text-slate-500">Debug Log</div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
              <CheckboxRow
                label="记录日志"
                icon={FileText}
                checked={normalized.logging.enabled}
                onChange={(enabled) => updateLogging({ enabled })}
              />
              <SelectRow
                label="记录范围"
                icon={FileText}
                value={normalized.logging.mode}
                options={[
                  { value: 'receive', label: '只记录接收' },
                  { value: 'all', label: '全部记录' },
                ]}
                onChange={(mode) => updateLogging({ mode })}
              />
            </div>
            <div className="grid grid-cols-[minmax(0,1fr)_96px] gap-2">
              <TextInputRow
                label="保存地址"
                icon={FileText}
                value={normalized.logging.path}
                onChange={() => {}}
                placeholder="user://logs/rm_synapse_debug.jsonl"
                monospace={false}
                readOnly
              />
              <button
                type="button"
                onClick={chooseDebugLogPath}
                className="flex min-h-9 items-center justify-center gap-1 rounded border border-slate-700 bg-slate-900 px-3 text-xs font-bold text-slate-200 transition-colors hover:border-slate-500 hover:bg-slate-800"
              >
                <FolderOpen size={14} className="text-cyan-300" />
                选择
              </button>
            </div>
          </section>

          <section className="space-y-3">
            <div className="text-[10px] font-black uppercase tracking-[0.18em] text-slate-500">Action Hotkeys</div>
            <label className="flex items-center justify-between rounded border border-slate-800 bg-slate-900/60 px-3 py-2 text-xs text-slate-200">
              <span className="flex items-center gap-2 font-bold">
                <Keyboard size={14} className="text-cyan-300" />
                双击快捷键
              </span>
              <input
                type="checkbox"
                checked={normalized.hotkeys.enabled}
                onChange={(event) => updateHotkeys({ enabled: event.target.checked })}
                className="h-4 w-4 accent-cyan-400"
              />
            </label>
            <SliderRow
              label="双击间隔"
              icon={Keyboard}
              value={normalized.hotkeys.doubleTapMs}
              min={250}
              max={800}
              step={10}
              onChange={(doubleTapMs) => updateHotkeys({ doubleTapMs })}
              format={formatMilliseconds}
            />
            <div className="grid grid-cols-2 gap-2">
              {HOTKEY_ROWS.map((row) => {
                const RowIcon = row.icon;
                return (
                  <button
                    key={row.key}
                    type="button"
                    onClick={() => setCapturingAction(row.key)}
                    onKeyDown={(event) => captureHotkey(row.key, event)}
                    className={`flex min-h-10 items-center justify-between gap-2 rounded border px-3 text-left text-xs font-bold transition-colors ${
                      capturingAction === row.key
                        ? 'border-cyan-300 bg-cyan-500/18 text-cyan-50'
                        : 'border-slate-700 bg-slate-900 text-slate-200 hover:border-slate-500 hover:bg-slate-800'
                    }`}
                  >
                    <span className="flex min-w-0 items-center gap-2">
                      <RowIcon size={14} className="shrink-0 text-cyan-300" />
                      <span className="truncate">{row.label}</span>
                    </span>
                    <span className="shrink-0 rounded border border-slate-700 bg-slate-950/80 px-2 py-1 font-mono text-[10px] font-black text-cyan-100">
                      {capturingAction === row.key ? '按键' : formatKeyCode(normalized.hotkeys[row.key])}
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
