import {
  BatteryLow,
  Crosshair,
  HeartPlus,
  Snowflake,
  Zap,
} from 'lucide-react';
import { normalizeStatusBuff } from './statusBuffs';

function SwordIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M12 2 L15 6 V15 H9 V6 Z" />
      <line x1="12" y1="2" x2="12" y2="15" />
      <line x1="6" y1="15" x2="18" y2="15" strokeWidth="2.5" />
      <path d="M10.5 15 V20 H13.5 V15" />
      <line x1="9" y1="20" x2="15" y2="20" strokeWidth="2" />
    </svg>
  );
}

function BrokenSwordIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M9 15 V10 L11 11.5 L13 9 L15 10.5 V15 Z" />
      <line x1="12" y1="10.5" x2="12" y2="15" />
      <line x1="6" y1="15" x2="18" y2="15" strokeWidth="2.5" />
      <path d="M10.5 15 V20 H13.5 V15" />
      <line x1="9" y1="20" x2="15" y2="20" strokeWidth="2" />
      <g transform="translate(1.5, -2) rotate(15 12 5)">
        <path d="M15 8.5 V6 L12 2 L9 6 V7.5 L11 9 L13 6.5 Z" />
        <line x1="12" y1="2" x2="12" y2="7.5" />
      </g>
    </svg>
  );
}

function ShieldIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
  );
}

function BrokenShieldIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <path d="M12 2v8l-3 3M16 12l-4-2" />
    </svg>
  );
}

function InvincibleShieldIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <path d="M12 8v8M8 12h8" />
    </svg>
  );
}

function StairsIcon(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M4 20h4v-4h4v-4h4V8h4" />
    </svg>
  );
}

const ICONS = {
  sword: SwordIcon,
  shield: ShieldIcon,
  brokenShield: BrokenShieldIcon,
  snowflake: Snowflake,
  zap: Zap,
  heartPlus: HeartPlus,
  crosshair: Crosshair,
  stairs: StairsIcon,
  mountain: StairsIcon,
  invincibleShield: InvincibleShieldIcon,
  brokenSword: BrokenSwordIcon,
  batteryDown: BatteryLow,
};

export default function StatusBuffIcon({
  buff,
  displayMode,
  size = 'md',
  showLabel = false,
  className = '',
}) {
  const item = normalizeStatusBuff(displayMode ? { ...buff, displayMode } : buff);
  if (!item) return null;

  const Icon = ICONS[item.icon] ?? Zap;
  const timeLeft = Math.max(0, Math.ceil(Number(item.time) || 0));
  const maxTime = Number(item.maxTime) > 0 ? Number(item.maxTime) : Number(item.time);
  const cooldownDeg = maxTime > 0 ? Math.max(0, Math.min(360, (Math.max(0, item.time) / maxTime) * 360)) : 0;
  const hasTime = (item.displayMode === 'time-value' || item.displayMode === 'time-only') && item.time > 0;
  const hasValue = (item.displayMode === 'time-value' || item.displayMode === 'value-only') && item.value;
  const warning = item.time > 0 && item.time <= 3;

  return (
    <div className={`status-buff-item status-buff-item--${size} ${showLabel ? '' : 'status-buff-item--no-label'} ${className}`}>
      <div
        className={`status-buff-icon status-buff-icon--${size} status-buff-pop ${warning ? 'status-buff-warn' : ''} ${item.className || ''}`}
        style={{
          '--status-buff-color': item.color,
          '--status-buff-cooldown': `${cooldownDeg}deg`,
        }}
        title={item.label}
      >
        {hasTime && <div className="status-buff-cooldown" />}
        <Icon className="status-buff-svg" />
        {hasTime && <div className="status-buff-time font-orbitron">{timeLeft}s</div>}
        {hasValue && <div className="status-buff-value font-orbitron">{item.value}</div>}
        {item.shortLabel && !hasTime && !hasValue && (
          <div className="status-buff-label status-buff-label--inside">
            {item.shortLabel}
          </div>
        )}
      </div>
      {showLabel && !item.shortLabel && <div className="status-buff-label">{item.label}</div>}
    </div>
  );
}
