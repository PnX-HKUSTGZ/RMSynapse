import { useEffect, useRef, useState } from 'react';
import { parseGodotPayload } from '../bridge/godot';
import {
  DEFAULT_UI_STATE,
  applyMapPatch,
  createDefaultMapDebugState,
  mergePendingPatch,
  normalizeIncomingData,
  pickMapPatch,
} from '../state';

export function useMapDebugState() {
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
      const data = parseGodotPayload(payload, 'godotMapPush');
      if (!data) return;

      const normalizedData = normalizeIncomingData(data);
      const patch = pickMapPatch(normalizedData);
      if (!patch) return;

      pendingPatchRef.current = mergePendingPatch(pendingPatchRef.current, patch);

      if (rafIdRef.current == null) {
        rafIdRef.current = window.requestAnimationFrame(flushStateUpdate);
      }
    };

    window.godotMapPush = handler;

    return () => {
      delete window.godotMapPush;

      if (rafIdRef.current != null) {
        window.cancelAnimationFrame(rafIdRef.current);
        rafIdRef.current = null;
      }

      pendingPatchRef.current = null;
    };
  }, [mapUpdateIntervalMs]);

  return state;
}
