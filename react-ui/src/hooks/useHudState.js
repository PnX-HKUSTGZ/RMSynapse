import { useEffect, useState } from 'react';
import { parseGodotPayload } from '../bridge/godot';
import { DEFAULT_UI_STATE, deepMerge, mergeRadarTargets, normalizeIncomingData } from '../state';
import { ENEMY_AUX_STALE_MS } from '../state/enemyAux';

const RADAR_TARGET_TTL_MS = 3000;
const REVIVE_HIGHLIGHT_MS = 3000;

function buffKey(buff, fallback = 'unknown') {
  return `${buff?.robotId ?? 'global'}:${buff?.id ?? buff?.type ?? fallback}`;
}

function mergeRobotMax(prevRobots, incomingRobots, { now = Date.now(), detectRevive = false } = {}) {
  if (!incomingRobots) return incomingRobots;
  const next = { ...incomingRobots };

  ['left', 'right'].forEach((side) => {
    if (!Array.isArray(incomingRobots[side])) return;
    const prevById = new Map(
      (Array.isArray(prevRobots?.[side]) ? prevRobots[side] : [])
        .map((robot) => [Number(robot.id), robot]),
    );
    next[side] = incomingRobots[side].map((robot) => {
      const hp = Number(robot.hp);
      const prevRobot = prevById.get(Number(robot.id));
      const prevHp = Number(prevRobot?.hp);
      const prevMax = Number(prevRobot?.max);
      const incomingMax = Number(robot.max);
      const max = Math.max(
        Number.isFinite(prevMax) ? prevMax : 0,
        Number.isFinite(incomingMax) ? incomingMax : 0,
        Number.isFinite(hp) ? hp : 0,
        1,
      );
      const prevHighlightUntil = Number(prevRobot?.reviveHighlightUntil);
      const reviveHighlightUntil = detectRevive
        && Number.isFinite(prevHp)
        && prevHp <= 0
        && Number.isFinite(hp)
        && hp > 0
        && hp >= max
        ? now + REVIVE_HIGHLIGHT_MS
        : prevHighlightUntil > now
          ? prevHighlightUntil
          : undefined;

      return {
        ...robot,
        max,
        ...(reviveHighlightUntil ? { reviveHighlightUntil } : {}),
      };
    });
  });

  return next;
}

function mergeBoostBuffs(prevBuffs, incomingBuffs, now = Date.now()) {
  if (!Array.isArray(incomingBuffs)) return pruneBoostBuffs(prevBuffs, now);
  const nextByKey = new Map();
  pruneBoostBuffs(prevBuffs, now).forEach((buff, index) => {
    nextByKey.set(buffKey(buff, index), buff);
  });

  incomingBuffs.forEach((buff, index) => {
    if (!buff || typeof buff !== 'object') return;
    const key = buffKey(buff, index);
    const time = Number(buff.time ?? buff.duration);
    if (buff.active === false || !Number.isFinite(time) || time <= 0) {
      nextByKey.delete(key);
      return;
    }
    nextByKey.set(key, {
      ...buff,
      time,
      expiresAt: now + (time * 1000),
    });
  });

  return Array.from(nextByKey.values());
}

function pruneRadarTargets(targets, now = Date.now()) {
  if (!Array.isArray(targets)) return [];
  const nextTargets = targets.filter((target) => {
    const timestamp = Number(target?.timestamp);
    return Number.isFinite(timestamp) && now - timestamp <= RADAR_TARGET_TTL_MS;
  });
  return nextTargets.length === targets.length ? targets : nextTargets;
}

function pruneBoostBuffs(buffs, now = Date.now()) {
  if (!Array.isArray(buffs)) return [];
  let changed = false;
  const nextBuffs = buffs.reduce((items, buff) => {
    if (!buff || typeof buff !== 'object') {
      changed = true;
      return items;
    }
    const expiresAt = Number(buff.expiresAt);
    if (Number.isFinite(expiresAt)) {
      changed = true;
      if (expiresAt <= now) return items;
      items.push({
        ...buff,
        time: Math.max(0, (expiresAt - now) / 1000),
      });
      return items;
    }

    const time = Number(buff.time ?? buff.duration);
    if (!Number.isFinite(time) || time <= 0 || buff.active === false) {
      changed = true;
      return items;
    }
    items.push(buff);
    return items;
  }, []);
  return changed ? nextBuffs : buffs;
}

function pruneRobotHighlights(robots, now = Date.now()) {
  if (!robots) return robots;
  let changed = false;
  const next = { ...robots };

  ['left', 'right'].forEach((side) => {
    if (!Array.isArray(robots[side])) return;
    next[side] = robots[side].map((robot) => {
      const reviveHighlightUntil = Number(robot?.reviveHighlightUntil);
      if (!Number.isFinite(reviveHighlightUntil) || reviveHighlightUntil > now) return robot;
      changed = true;
      const rest = { ...robot };
      delete rest.reviveHighlightUntil;
      return rest;
    });
  });

  return changed ? next : robots;
}

function markEnemyAuxStale(enemyAux, now = Date.now()) {
  if (!enemyAux) return enemyAux;
  const lastUpdateMs = Number(enemyAux.lastUpdateMs);
  const isStale = !Number.isFinite(lastUpdateMs) || now - lastUpdateMs > ENEMY_AUX_STALE_MS;
  return enemyAux.isStale === isStale ? enemyAux : { ...enemyAux, isStale };
}

function mergeHudState(prev, incoming) {
  const now = Date.now();
  const adjustedIncoming = { ...incoming };
  if (incoming.robots) {
    adjustedIncoming.robots = mergeRobotMax(prev.robots, incoming.robots, {
      now,
      detectRevive: prev.globalUnit?.sideBasis === 'ally_enemy',
    });
  }
  const merged = deepMerge(prev, adjustedIncoming);
  if (adjustedIncoming.enemyAux?.lastPacket) {
    merged.enemyAux = {
      ...(merged.enemyAux ?? {}),
      lastPacket: {
        ...(merged.enemyAux?.lastPacket ?? {}),
      },
    };
    if (adjustedIncoming.enemyAux.lastPacket.enemyProjectile) {
      merged.enemyAux.lastPacket.enemyProjectile = adjustedIncoming.enemyAux.lastPacket.enemyProjectile;
    }
    if (adjustedIncoming.enemyAux.lastPacket.enemyEconomy) {
      merged.enemyAux.lastPacket.enemyEconomy = adjustedIncoming.enemyAux.lastPacket.enemyEconomy;
    }
  }
  if (adjustedIncoming.robots) {
    merged.robots = adjustedIncoming.robots;
  }
  if (Array.isArray(incoming.radarTargets)) {
    merged.radarTargets = pruneRadarTargets(mergeRadarTargets(prev.radarTargets, incoming.radarTargets), now);
  } else {
    merged.radarTargets = pruneRadarTargets(merged.radarTargets, now);
  }
  if (Array.isArray(incoming.boostBuffs)) {
    merged.boostBuffs = mergeBoostBuffs(prev.boostBuffs, incoming.boostBuffs, now);
  } else {
    merged.boostBuffs = pruneBoostBuffs(merged.boostBuffs, now);
  }
  merged.robots = pruneRobotHighlights(merged.robots, now);
  merged.enemyAux = markEnemyAuxStale(merged.enemyAux, now);
  return merged;
}

export function useHudState() {
  const [uiState, setUiState] = useState(DEFAULT_UI_STATE);

  useEffect(() => {
    const handler = (payload) => {
      const data = parseGodotPayload(payload, 'godotPush');
      if (!data) return;
      if (data.settingsPatch && typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('hudSettingsPatch', { detail: data.settingsPatch }));
      }

      const normalizedData = normalizeIncomingData(data);
      setUiState((prev) => mergeHudState(prev, normalizedData));
    };

    window.godotPush = handler;
  }, []);

  useEffect(() => {
    const timer = window.setInterval(() => {
      setUiState((prev) => {
        const now = Date.now();
        const nextTargets = pruneRadarTargets(prev.radarTargets, now);
        const nextBuffs = pruneBoostBuffs(prev.boostBuffs, now);
        const nextRobots = pruneRobotHighlights(prev.robots, now);
        const nextEnemyAux = markEnemyAuxStale(prev.enemyAux, now);
        if (
          nextTargets === prev.radarTargets
          && nextBuffs === prev.boostBuffs
          && nextRobots === prev.robots
          && nextEnemyAux === prev.enemyAux
        ) {
          return prev;
        }
        return {
          ...prev,
          radarTargets: nextTargets,
          boostBuffs: nextBuffs,
          robots: nextRobots,
          enemyAux: nextEnemyAux,
        };
      });
    }, 1000);

    return () => window.clearInterval(timer);
  }, []);

  return { uiState, setUiState };
}
