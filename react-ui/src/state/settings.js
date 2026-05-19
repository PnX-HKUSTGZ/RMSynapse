import { clamp } from './utils';

const STORAGE_KEY = 'rm-synapse-hud-settings-v1';

export const DEFAULT_HUD_SETTINGS = {
  mouseSensitivity: 1,
  ui: {
    scale: 1,
    opacity: 1,
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
