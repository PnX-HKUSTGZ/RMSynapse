import { useEffect, useMemo, useRef, useState } from 'react';
import MiniMapHUD from './MiniMapHUD';
import MapTopControls from './MapTopControls';
import { DEFAULT_UI_STATE, normalizeIncomingData } from './uiState';

function isPlainObject(value) {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function mergeControlsState(base, incoming) {
  const defaults = DEFAULT_UI_STATE.controls ?? {};
  const prev = isPlainObject(base) ? base : defaults;
  const patch = isPlainObject(incoming) ? incoming : {};
  const next = { ...prev, ...patch };

  next.infantrySettings = {
    ...(prev.infantrySettings ?? defaults.infantrySettings ?? {}),
    ...(patch.infantrySettings ?? {}),
  };
  next.heroSettings = {
    ...(prev.heroSettings ?? defaults.heroSettings ?? {}),
    ...(patch.heroSettings ?? {}),
  };
  next.sentrySettings = {
    ...(prev.sentrySettings ?? defaults.sentrySettings ?? {}),
    ...(patch.sentrySettings ?? {}),
  };
  next.costs = {
    ...(prev.costs ?? defaults.costs ?? {}),
    ...(patch.costs ?? {}),
  };
  next.ammoStore = {
    infantry: {
      normal: {
        ...(prev.ammoStore?.infantry?.normal ?? defaults.ammoStore?.infantry?.normal ?? {}),
        ...(patch.ammoStore?.infantry?.normal ?? {}),
      },
      airdrop: {
        ...(prev.ammoStore?.infantry?.airdrop ?? defaults.ammoStore?.infantry?.airdrop ?? {}),
        ...(patch.ammoStore?.infantry?.airdrop ?? {}),
      },
    },
    hero: {
      normal: {
        ...(prev.ammoStore?.hero?.normal ?? defaults.ammoStore?.hero?.normal ?? {}),
        ...(patch.ammoStore?.hero?.normal ?? {}),
      },
      airdrop: {
        ...(prev.ammoStore?.hero?.airdrop ?? defaults.ammoStore?.hero?.airdrop ?? {}),
        ...(patch.ammoStore?.hero?.airdrop ?? {}),
      },
    },
  };

  return next;
}

function pickMapPatch(data) {
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

  return Object.keys(patch).length > 0 ? patch : null;
}

function mergePendingPatch(base, incoming) {
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
    next.stats = isPlainObject(base.stats) ? { ...base.stats, ...incoming.stats } : { ...incoming.stats };
  }
  if (isPlainObject(incoming.controls)) {
    next.controls = mergeControlsState(base.controls, incoming.controls);
  }

  return next;
}

function applyMapPatch(prev, patch) {
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

  return next;
}

function clonePlayers(players) {
  return players.map((player) => ({ ...player }));
}

function cloneRobots(robots) {
  return {
    left: robots.left.map((robot) => ({ ...robot })),
    right: robots.right.map((robot) => ({ ...robot }))
  };
}

function createDefaultMapDebugState() {
  const mapDebug = DEFAULT_UI_STATE.mapDebug ?? {};
  const mapDebugSizing = mapDebug.uiSizing ?? {};

  return {
    uiSizing: {
      ...DEFAULT_UI_STATE.uiSizing,
      ...mapDebugSizing
    },
    miniMap: {
      ...DEFAULT_UI_STATE.miniMap,
      title: mapDebug.miniMapTitle ?? '地图',
      interactive: false,
      players: clonePlayers(DEFAULT_UI_STATE.miniMap.players)
    },
    robots: cloneRobots(DEFAULT_UI_STATE.robots),
    stats: { ...DEFAULT_UI_STATE.stats },
    controls: { ...DEFAULT_UI_STATE.controls }
  };
}

export default function MapDebugApp() {
  const [state, setState] = useState(() => createDefaultMapDebugState());
  const pendingPatchRef = useRef(null);
  const rafIdRef = useRef(null);
  const lastFlushAtRef = useRef(0);
  const mapUpdateIntervalMs = Number(DEFAULT_UI_STATE.mapDebug?.updateIntervalMs) > 0
    ? Number(DEFAULT_UI_STATE.mapDebug.updateIntervalMs)
    : 33;

  useEffect(() => {
    const flushStateUpdate = (timestamp) => {
      if (timestamp - lastFlushAtRef.current < mapUpdateIntervalMs) {
        rafIdRef.current = window.requestAnimationFrame(flushStateUpdate);
        return;
      }

      lastFlushAtRef.current = timestamp;
      const patch = pendingPatchRef.current;
      pendingPatchRef.current = null;
      rafIdRef.current = null;
      if (!patch) return;
      setState((prev) => applyMapPatch(prev, patch));
    };

    const handler = (payload) => {
      let data = payload;
      if (typeof payload === 'string') {
        try {
          data = JSON.parse(payload);
        } catch (error) {
          console.error('godotMapPush payload is not valid JSON:', error);
          return;
        }
      }

      const normalized = normalizeIncomingData(data);
      const patch = pickMapPatch(normalized);
      if (!patch) return;
      pendingPatchRef.current = mergePendingPatch(pendingPatchRef.current, patch);

      if (rafIdRef.current == null) {
        rafIdRef.current = window.requestAnimationFrame(flushStateUpdate);
      }
    };

    window.godotMapPush = handler;
    // 兼容直接沿用 godotPush 的场景
    window.godotPush = handler;

    return () => {
      delete window.godotMapPush;
      delete window.godotPush;
      if (rafIdRef.current != null) {
        window.cancelAnimationFrame(rafIdRef.current);
        rafIdRef.current = null;
      }
      pendingPatchRef.current = null;
    };
  }, [mapUpdateIntervalMs]);

  const mergedMiniMap = useMemo(
    () => ({ ...DEFAULT_UI_STATE.miniMap, ...(state.miniMap ?? {}) }),
    [state.miniMap],
  );
  const mergedStats = useMemo(
    () => ({ ...DEFAULT_UI_STATE.stats, ...(state.stats ?? {}) }),
    [state.stats],
  );
  const mergedControls = useMemo(
    () => ({ ...DEFAULT_UI_STATE.controls, ...(state.controls ?? {}) }),
    [state.controls],
  );

  const miniMapPlayers = Array.isArray(mergedMiniMap.players)
    ? mergedMiniMap.players
    : DEFAULT_UI_STATE.miniMap.players;
  const currentEco = Number(mergedStats.eco) || 0;

  const leftRobots = Array.isArray(state.robots?.left) ? state.robots.left : DEFAULT_UI_STATE.robots.left;
  const rightRobots = Array.isArray(state.robots?.right) ? state.robots.right : DEFAULT_UI_STATE.robots.right;

  const robotHpById = useMemo(() => {
    const hpMap = {};
    leftRobots.forEach((robot) => {
      hpMap[`red-${robot.id}`] = robot.hp;
    });
    rightRobots.forEach((robot) => {
      hpMap[`blue-${robot.id}`] = robot.hp;
    });
    return hpMap;
  }, [leftRobots, rightRobots]);

  return (
    <div className="min-h-screen bg-transparent relative overflow-hidden text-white font-mono">
      <MapTopControls eco={currentEco} controls={mergedControls} />

      <MiniMapHUD
        miniMap={{ ...mergedMiniMap, interactive: false, players: miniMapPlayers }}
        uiSizing={state.uiSizing}
        robotHpById={robotHpById}
      />
    </div>
  );
}
