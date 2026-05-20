import { clamp } from './utils';

const STORAGE_KEY = 'rm-synapse-hud-settings-v1';

export const DEFAULT_HUD_SETTINGS = {
  mouseSensitivity: 1,
  ui: {
    scale: 1,
    opacity: 1,
  },
  hotkeys: {
    enabled: true,
    doubleTapMs: 420,
    heal: 'KeyH',
    directAmmo: 'KeyJ',
    remoteAmmo: 'KeyK',
    revive: 'KeyL',
  },
  network: {
    mqtt: {
      host: '127.0.0.1',
      port: 3333,
      clientId: '',
    },
    video: {
      port: 3334,
    },
  },
};

function toNumber(value, fallback) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

export function normalizeHudSettings(source) {
  return {
    mouseSensitivity: clamp(toNumber(source?.mouseSensitivity, 1), 0.1, 5),
    ui: {
      scale: clamp(toNumber(source?.ui?.scale, 1), 0.5, 1.8),
      opacity: clamp(toNumber(source?.ui?.opacity, 1), 0.15, 1),
    },
    hotkeys: {
      enabled: source?.hotkeys?.enabled !== false,
      doubleTapMs: clamp(toNumber(source?.hotkeys?.doubleTapMs, DEFAULT_HUD_SETTINGS.hotkeys.doubleTapMs), 250, 800),
      heal: normalizeKeyCode(source?.hotkeys?.heal, DEFAULT_HUD_SETTINGS.hotkeys.heal),
      directAmmo: normalizeKeyCode(source?.hotkeys?.directAmmo, DEFAULT_HUD_SETTINGS.hotkeys.directAmmo),
      remoteAmmo: normalizeKeyCode(source?.hotkeys?.remoteAmmo, DEFAULT_HUD_SETTINGS.hotkeys.remoteAmmo),
      revive: normalizeKeyCode(source?.hotkeys?.revive, DEFAULT_HUD_SETTINGS.hotkeys.revive),
    },
    network: normalizeNetworkSettings(source?.network),
  };
}

function normalizeKeyCode(value, fallback) {
  return typeof value === 'string' && value.trim() ? value : fallback;
}

function normalizeString(value, fallback = '') {
  return typeof value === 'string' ? value.trim() : fallback;
}

function normalizeNetworkSettings(source) {
  const defaults = DEFAULT_HUD_SETTINGS.network;

  return {
    mqtt: {
      host: normalizeString(source?.mqtt?.host, defaults.mqtt.host) || defaults.mqtt.host,
      port: Math.trunc(clamp(toNumber(source?.mqtt?.port, defaults.mqtt.port), 1, 65535)),
      clientId: normalizeString(source?.mqtt?.clientId, defaults.mqtt.clientId),
    },
    video: {
      port: Math.trunc(clamp(toNumber(source?.video?.port, defaults.video.port), 1, 65535)),
    },
  };
}

export function loadHudSettings() {
  if (typeof window === 'undefined') return DEFAULT_HUD_SETTINGS;

  try {
    const saved = window.localStorage?.getItem(STORAGE_KEY);
    return normalizeHudSettings(saved ? JSON.parse(saved) : DEFAULT_HUD_SETTINGS);
  } catch (error) {
    console.warn('Failed to load HUD settings:', error);
    return DEFAULT_HUD_SETTINGS;
  }
}

export function saveHudSettings(settings) {
  if (typeof window === 'undefined') return;

  try {
    window.localStorage?.setItem(STORAGE_KEY, JSON.stringify(normalizeHudSettings(settings)));
  } catch (error) {
    console.warn('Failed to save HUD settings:', error);
  }
}

function multiplyPositive(value, multiplier, fallback = 1) {
  const numeric = Number(value);
  const base = Number.isFinite(numeric) && numeric > 0 ? numeric : fallback;
  return base * multiplier;
}

export function buildEffectiveUiSizing(uiSizing, settings) {
  const source = uiSizing ?? {};
  const normalized = normalizeHudSettings(settings);
  const scale = normalized.ui.scale;

  return {
    ...source,
    topCoreScale: multiplyPositive(source.topCoreScale, scale),
    centerHudScale: multiplyPositive(source.centerHudScale, scale),
    mechaHudScale: multiplyPositive(source.mechaHudScale, scale),
    miniMapScale: multiplyPositive(source.miniMapScale, scale),
  };
}
