import { DEFAULT_UI_STATE } from './defaults';
import { mergeControlsState } from './controls';
import { isPlainObject } from './utils';

function clonePlayers(players) {
  return players.map((player) => ({ ...player }));
}

function cloneRobots(robots) {
  return {
    left: robots.left.map((robot) => ({ ...robot })),
    right: robots.right.map((robot) => ({ ...robot })),
  };
}

export function mergeRadarTargets(baseTargets, incomingTargets) {
  if (!Array.isArray(incomingTargets)) return Array.isArray(baseTargets) ? baseTargets : [];
  const nextById = new Map();
  if (Array.isArray(baseTargets)) {
    baseTargets.forEach((target, index) => {
      const key = target?.robotId ?? `base-${index}`;
      nextById.set(key, target);
    });
  }
  incomingTargets.forEach((target, index) => {
    if (!isPlainObject(target)) return;
    const key = target.robotId ?? `incoming-${index}`;
    nextById.set(key, target);
  });
  return Array.from(nextById.values());
}

export function pickMapPatch(data) {
  if (!isPlainObject(data)) return null;

  const patch = {};
  if (isPlainObject(data.uiSizing)) {
    patch.uiSizing = data.uiSizing;
  }
  if (isPlainObject(data.miniMap)) {
    patch.miniMap = { ...data.miniMap, interactive: false };
  }
  if (isPlainObject(data.robots)) {
    patch.robots = data.robots;
  }
  if (isPlainObject(data.stats)) {
    patch.stats = data.stats;
  }
  if (isPlainObject(data.controls)) {
    patch.controls = data.controls;
  }
  if (Array.isArray(data.radarTargets)) {
    patch.radarTargets = data.radarTargets;
  }
  if (isPlainObject(data.pathPlan)) {
    patch.pathPlan = data.pathPlan;
  }

  return Object.keys(patch).length > 0 ? patch : null;
}

export function mergePendingPatch(base, incoming) {
  if (!base) return incoming;

  const next = { ...base };

  if (isPlainObject(incoming.uiSizing)) {
    next.uiSizing = isPlainObject(base.uiSizing)
      ? { ...base.uiSizing, ...incoming.uiSizing }
      : { ...incoming.uiSizing };
  }

  if (isPlainObject(incoming.miniMap)) {
    const mergedMiniMap = isPlainObject(base.miniMap)
      ? { ...base.miniMap, ...incoming.miniMap }
      : { ...incoming.miniMap };
    mergedMiniMap.interactive = false;
    if (Array.isArray(incoming.miniMap.players)) {
      mergedMiniMap.players = incoming.miniMap.players;
    }
    next.miniMap = mergedMiniMap;
  }

  if (isPlainObject(incoming.robots)) {
    const mergedRobots = isPlainObject(base.robots)
      ? { ...base.robots, ...incoming.robots }
      : { ...incoming.robots };
    if (Array.isArray(incoming.robots.left)) {
      mergedRobots.left = incoming.robots.left;
    }
    if (Array.isArray(incoming.robots.right)) {
      mergedRobots.right = incoming.robots.right;
    }
    next.robots = mergedRobots;
  }

  if (isPlainObject(incoming.stats)) {
    next.stats = isPlainObject(base.stats)
      ? { ...base.stats, ...incoming.stats }
      : { ...incoming.stats };
  }

  if (isPlainObject(incoming.controls)) {
    next.controls = mergeControlsState(base.controls, incoming.controls);
  }
  if (Array.isArray(incoming.radarTargets)) {
    next.radarTargets = mergeRadarTargets(base.radarTargets, incoming.radarTargets);
  }
  if (isPlainObject(incoming.pathPlan)) {
    next.pathPlan = isPlainObject(base.pathPlan)
      ? { ...base.pathPlan, ...incoming.pathPlan }
      : { ...incoming.pathPlan };
  }

  return next;
}

export function applyMapPatch(prev, patch) {
  if (!patch) return prev;

  let next = prev;

  if (isPlainObject(patch.uiSizing)) {
    next = next === prev ? { ...prev } : next;
    next.uiSizing = { ...prev.uiSizing, ...patch.uiSizing };
  }

  if (isPlainObject(patch.miniMap)) {
    next = next === prev ? { ...prev } : next;
    const mergedMiniMap = { ...prev.miniMap, ...patch.miniMap };
    mergedMiniMap.interactive = false;
    if (Array.isArray(patch.miniMap.players)) {
      mergedMiniMap.players = patch.miniMap.players;
    }
    next.miniMap = mergedMiniMap;
  }

  if (isPlainObject(patch.robots)) {
    next = next === prev ? { ...prev } : next;
    const mergedRobots = { ...prev.robots, ...patch.robots };
    if (Array.isArray(patch.robots.left)) {
      mergedRobots.left = patch.robots.left;
    }
    if (Array.isArray(patch.robots.right)) {
      mergedRobots.right = patch.robots.right;
    }
    next.robots = mergedRobots;
  }

  if (isPlainObject(patch.stats)) {
    next = next === prev ? { ...prev } : next;
    next.stats = { ...prev.stats, ...patch.stats };
  }

  if (isPlainObject(patch.controls)) {
    next = next === prev ? { ...prev } : next;
    next.controls = mergeControlsState(prev.controls, patch.controls);
  }
  if (Array.isArray(patch.radarTargets)) {
    next = next === prev ? { ...prev } : next;
    next.radarTargets = mergeRadarTargets(prev.radarTargets, patch.radarTargets);
  }
  if (isPlainObject(patch.pathPlan)) {
    next = next === prev ? { ...prev } : next;
    next.pathPlan = { ...(prev.pathPlan ?? {}), ...patch.pathPlan };
  }

  return next;
}

export function createDefaultMapDebugState() {
  const mapDebug = DEFAULT_UI_STATE.mapDebug ?? {};
  const mapDebugSizing = mapDebug.uiSizing ?? {};

  return {
    uiSizing: {
      ...DEFAULT_UI_STATE.uiSizing,
      ...mapDebugSizing,
    },
    miniMap: {
      ...DEFAULT_UI_STATE.miniMap,
      title: mapDebug.miniMapTitle ?? '地图',
      interactive: false,
      players: clonePlayers(DEFAULT_UI_STATE.miniMap.players),
    },
    robots: cloneRobots(DEFAULT_UI_STATE.robots),
    stats: { ...DEFAULT_UI_STATE.stats },
    controls: { ...DEFAULT_UI_STATE.controls },
    radarTargets: [],
    pathPlan: {},
  };
}
