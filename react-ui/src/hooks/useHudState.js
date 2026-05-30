import { useEffect, useState } from 'react';
import { parseGodotPayload } from '../bridge/godot';
import { DEFAULT_UI_STATE, deepMerge, mergeRadarTargets, normalizeIncomingData } from '../state';

const RADAR_TARGET_TTL_MS = 3000;
const DESTROYED_OUTPOST_STATES = new Set([3, 4, 5]);

function mergeRobotMax(prevRobots, incomingRobots) {
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
      const prevMax = Number(prevById.get(Number(robot.id))?.max);
      const incomingMax = Number(robot.max);
      const max = Math.max(
        Number.isFinite(prevMax) ? prevMax : 0,
        Number.isFinite(incomingMax) ? incomingMax : 0,
        Number.isFinite(hp) ? hp : 0,
        1,
      );
      return { ...robot, max };
    });
  });

  return next;
}

function mergeBoostBuffs(prevBuffs, incomingBuffs) {
  if (!Array.isArray(incomingBuffs)) return Array.isArray(prevBuffs) ? prevBuffs : [];
  const nextByKey = new Map();
  if (Array.isArray(prevBuffs)) {
    prevBuffs.forEach((buff, index) => {
      const key = `${buff?.robotId ?? 'global'}:${buff?.id ?? buff?.type ?? index}`;
      nextByKey.set(key, buff);
    });
  }
  incomingBuffs.forEach((buff, index) => {
    if (!buff || typeof buff !== 'object') return;
    const key = `${buff.robotId ?? 'global'}:${buff.id ?? buff.type ?? index}`;
    nextByKey.set(key, buff);
  });
  return Array.from(nextByKey.values());
}

function mergeFortressMemory(prev, incoming) {
  const previous = prev.fortress ?? {};
  const next = { ...previous };
  const outposts = incoming.outposts ?? {};

  ['left', 'right'].forEach((side) => {
    const outpost = outposts[side];
    const wasDestroyed = Boolean(previous?.[side]?.outpostEverDestroyed);
    const hp = Number(outpost?.hp);
    const state = Number(outpost?.state);
    const destroyedNow = (Number.isFinite(hp) && hp <= 0)
      || (Number.isFinite(state) && DESTROYED_OUTPOST_STATES.has(state));
    if (wasDestroyed || destroyedNow) {
      next[side] = {
        ...(previous?.[side] ?? {}),
        outpostEverDestroyed: true,
      };
    }
  });

  return next;
}

function pruneRadarTargets(targets, now = Date.now()) {
  if (!Array.isArray(targets)) return [];
  return targets.filter((target) => {
    const timestamp = Number(target?.timestamp);
    return Number.isFinite(timestamp) && now - timestamp <= RADAR_TARGET_TTL_MS;
  });
}

function mergeHudState(prev, incoming) {
  const adjustedIncoming = { ...incoming };
  if (incoming.robots) {
    adjustedIncoming.robots = mergeRobotMax(prev.robots, incoming.robots);
  }
  const merged = deepMerge(prev, adjustedIncoming);
  if (adjustedIncoming.robots) {
    merged.robots = adjustedIncoming.robots;
  }
  merged.fortress = mergeFortressMemory(prev, adjustedIncoming);
  if (Array.isArray(incoming.radarTargets)) {
    merged.radarTargets = pruneRadarTargets(mergeRadarTargets(prev.radarTargets, incoming.radarTargets));
  } else {
    merged.radarTargets = pruneRadarTargets(merged.radarTargets);
  }
  if (Array.isArray(incoming.boostBuffs)) {
    merged.boostBuffs = mergeBoostBuffs(prev.boostBuffs, incoming.boostBuffs);
  }
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
        const nextTargets = pruneRadarTargets(prev.radarTargets);
        if (nextTargets.length === (prev.radarTargets ?? []).length) return prev;
        return { ...prev, radarTargets: nextTargets };
      });
    }, 1000);

    return () => window.clearInterval(timer);
  }, []);

  return { uiState, setUiState };
}
