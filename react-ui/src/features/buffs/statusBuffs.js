export const STATUS_BUFF_PRESETS = {
  attack: {
    label: '攻击增益',
    color: '#ef4444',
    icon: 'sword',
    displayMode: 'time-value',
    value: '+20%',
  },
  defense: {
    label: '防御增益',
    color: '#3b82f6',
    icon: 'shield',
    displayMode: 'time-value',
    value: '+150%',
  },
  armorBreak: {
    label: '碎甲',
    color: '#a855f7',
    icon: 'brokenShield',
    displayMode: 'time-value',
    value: '-50%',
  },
  cooling: {
    label: '射击热量冷却',
    color: '#22d3ee',
    icon: 'snowflake',
    displayMode: 'value-only',
    value: '+5/s',
  },
  power: {
    label: '底盘功率',
    color: '#eab308',
    icon: 'zap',
    displayMode: 'time-only',
  },
  regen: {
    label: '回血增益',
    color: '#22c55e',
    icon: 'heartPlus',
    displayMode: 'time-value',
    value: '+10%',
  },
  ammo: {
    label: '弹量增益',
    color: '#8b5cf6',
    icon: 'crosshair',
    displayMode: 'time-only',
  },
  terrain: {
    label: '地形跨越',
    shortLabel: '地形',
    color: '#cf8c5c',
    icon: 'stairs',
    displayMode: 'hidden',
    time: -1,
    className: 'status-buff-icon--stripes',
  },
  invincible: {
    label: '无敌',
    shortLabel: '无敌',
    color: '#facc15',
    icon: 'invincibleShield',
    displayMode: 'hidden',
    className: 'status-buff-icon--invincible',
  },
  weak: {
    label: '虚弱',
    shortLabel: '虚弱',
    color: '#286ac6',
    icon: 'brokenSword',
    displayMode: 'hidden',
    time: -1,
  },
  eco: {
    label: '节能',
    shortLabel: '节能',
    color: '#ea580c',
    icon: 'batteryDown',
    displayMode: 'hidden',
    time: -1,
  },
};

const COLOR_ALIASES = {
  rose: '#ef4444',
  red: '#ef4444',
  blue: '#3b82f6',
  cyan: '#22d3ee',
  amber: '#eab308',
  yellow: '#facc15',
  emerald: '#22c55e',
  green: '#22c55e',
  violet: '#8b5cf6',
  purple: '#a855f7',
  stone: '#78716c',
  slate: '#64748b',
  orange: '#ea580c',
};

const TYPE_ALIASES = {
  'buff-atk': 'attack',
  'buff-def': 'defense',
  'debuff-armor-break': 'armorBreak',
  'buff-cooling': 'cooling',
  'buff-power': 'power',
  'buff-heal': 'regen',
  'trait-terrain': 'terrain',
  'trait-invincible': 'invincible',
  'debuff-weak': 'weak',
  'debuff-eco': 'eco',
};

function resolvePresetKey(buff) {
  const type = buff?.type;
  if (type && STATUS_BUFF_PRESETS[type]) return type;
  if (type && TYPE_ALIASES[type]) return TYPE_ALIASES[type];

  const id = buff?.id;
  if (id && STATUS_BUFF_PRESETS[id]) return id;
  if (id && TYPE_ALIASES[id]) return TYPE_ALIASES[id];

  return type || id || 'unknown';
}

function resolveColor(color, fallback) {
  if (typeof color !== 'string') return fallback;
  if (color.startsWith('#') || color.startsWith('rgb') || color.startsWith('hsl')) return color;
  return COLOR_ALIASES[color] ?? fallback;
}

function formatBuffValue(buff, value) {
  if (value == null || value === '') return '';
  const text = String(value).trim();
  if (!text || buff.icon === 'snowflake' || buff.type === 'cooling') return text;
  if (text.includes('%') || text.includes('/')) return text;
  const numericValue = Number(text);
  if (!Number.isFinite(numericValue)) return text;
  const sign = numericValue > 0 ? '+' : '';
  return `${sign}${numericValue}%`;
}

export function normalizeStatusBuff(buff) {
  if (!buff || typeof buff !== 'object') return null;

  const presetKey = resolvePresetKey(buff);
  const preset = STATUS_BUFF_PRESETS[presetKey] ?? {};
  const rawTime = buff.time ?? buff.duration ?? preset.time ?? preset.duration ?? 0;
  const time = Number(rawTime);
  const maxTime = Number(buff.maxTime ?? buff.duration ?? preset.duration ?? rawTime);
  const displayMode = buff.displayMode ?? buff.mode ?? preset.displayMode ?? 'time-only';
  const color = resolveColor(buff.color, preset.color ?? '#22d3ee');
  const icon = buff.icon ?? preset.icon ?? 'zap';
  const normalizedType = presetKey;
  const value = formatBuffValue({ ...buff, icon, type: normalizedType }, buff.value ?? preset.value ?? '');

  return {
    ...preset,
    ...buff,
    key: buff.id ?? buff.type ?? presetKey,
    label: buff.label ?? buff.name ?? preset.label ?? 'BUFF',
    color,
    displayMode,
    time: Number.isFinite(time) ? time : 0,
    maxTime: Number.isFinite(maxTime) ? maxTime : 0,
    value,
    icon,
    className: [preset.className, buff.className].filter(Boolean).join(' '),
  };
}

export function shouldShowStatusBuff(buff) {
  if (!buff) return false;
  if (buff.active === false) return false;
  if (buff.time < 0) return true;
  if (buff.displayMode === 'hidden' && buff.time === 0 && buff.maxTime <= 0) return true;
  return buff.time > 0;
}
