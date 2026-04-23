import { mergeControlsState, resolveControlsConfig } from './controls';
import { DEFAULT_UI_STATE } from './defaults';
import { deepMerge } from './utils';

export function resolveUiSizing(uiSizing) {
  return { ...DEFAULT_UI_STATE.uiSizing, ...(uiSizing ?? {}) };
}

export function resolveRobotSides(robots) {
  return {
    leftRobots: Array.isArray(robots?.left) ? robots.left : DEFAULT_UI_STATE.robots.left,
    rightRobots: Array.isArray(robots?.right) ? robots.right : DEFAULT_UI_STATE.robots.right,
  };
}

export function resolveMiniMapState(miniMap) {
  const mergedMiniMap = { ...DEFAULT_UI_STATE.miniMap, ...(miniMap ?? {}) };
  return {
    ...mergedMiniMap,
    players: Array.isArray(mergedMiniMap.players)
      ? mergedMiniMap.players
      : DEFAULT_UI_STATE.miniMap.players,
  };
}

export function resolveRespawnState(respawn) {
  return { ...DEFAULT_UI_STATE.respawn, ...(respawn ?? {}) };
}

export function resolveStatsState(stats) {
  return { ...DEFAULT_UI_STATE.stats, ...(stats ?? {}) };
}

export function resolveMessageCenterState(messageCenter) {
  const defaults = DEFAULT_UI_STATE.messageCenter ?? {};
  const incoming = messageCenter ?? {};

  return {
    ...defaults,
    ...incoming,
    levels: { ...(defaults.levels ?? {}), ...(incoming.levels ?? {}) },
    priorityMap: { ...(defaults.priorityMap ?? {}), ...(incoming.priorityMap ?? {}) },
    items: Array.isArray(incoming.items) ? incoming.items : (defaults.items ?? []),
  };
}

export function resolveControlsState(controls) {
  return resolveControlsConfig(controls);
}

export function buildRobotHpById(leftRobots, rightRobots) {
  const hpMap = {};
  leftRobots.forEach((robot) => {
    hpMap[`red-${robot.id}`] = robot.hp;
  });
  rightRobots.forEach((robot) => {
    hpMap[`blue-${robot.id}`] = robot.hp;
  });
  return hpMap;
}

export function resolveMechaState(mecha) {
  return deepMerge(DEFAULT_UI_STATE.mecha, mecha ?? {});
}

export function resolveCenterHudState(centerHud) {
  return deepMerge(DEFAULT_UI_STATE.centerHud, centerHud ?? {});
}

export function resolveBoostBuffs(boostBuffs) {
  return Array.isArray(boostBuffs) ? boostBuffs : DEFAULT_UI_STATE.boostBuffs;
}

export function resolveMapDebugControls(controls) {
  return mergeControlsState(DEFAULT_UI_STATE.controls, controls);
}
