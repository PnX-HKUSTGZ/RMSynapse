import { DEFAULT_UI_STATE } from './defaults';

function mergeAmmoStore(defaults, current, incoming) {
  return {
    infantry: {
      normal: {
        ...(defaults.ammoStore?.infantry?.normal ?? {}),
        ...(current?.ammoStore?.infantry?.normal ?? {}),
        ...(incoming?.ammoStore?.infantry?.normal ?? {}),
      },
      airdrop: {
        ...(defaults.ammoStore?.infantry?.airdrop ?? {}),
        ...(current?.ammoStore?.infantry?.airdrop ?? {}),
        ...(incoming?.ammoStore?.infantry?.airdrop ?? {}),
      },
    },
    hero: {
      normal: {
        ...(defaults.ammoStore?.hero?.normal ?? {}),
        ...(current?.ammoStore?.hero?.normal ?? {}),
        ...(incoming?.ammoStore?.hero?.normal ?? {}),
      },
      airdrop: {
        ...(defaults.ammoStore?.hero?.airdrop ?? {}),
        ...(current?.ammoStore?.hero?.airdrop ?? {}),
        ...(incoming?.ammoStore?.hero?.airdrop ?? {}),
      },
    },
  };
}

export function mergeControlsState(base, incoming) {
  const defaults = DEFAULT_UI_STATE.controls ?? {};
  const current = base ?? defaults;
  const patch = incoming ?? {};

  return {
    ...defaults,
    ...current,
    ...patch,
    infantrySettings: {
      ...(defaults.infantrySettings ?? {}),
      ...(current.infantrySettings ?? {}),
      ...(patch.infantrySettings ?? {}),
    },
    heroSettings: {
      ...(defaults.heroSettings ?? {}),
      ...(current.heroSettings ?? {}),
      ...(patch.heroSettings ?? {}),
    },
    sentrySettings: {
      ...(defaults.sentrySettings ?? {}),
      ...(current.sentrySettings ?? {}),
      ...(patch.sentrySettings ?? {}),
    },
    costs: {
      ...(defaults.costs ?? {}),
      ...(current.costs ?? {}),
      ...(patch.costs ?? {}),
    },
    ammoStore: mergeAmmoStore(defaults, current, patch),
  };
}

export function resolveControlsConfig(controls) {
  return mergeControlsState(DEFAULT_UI_STATE.controls, controls);
}
