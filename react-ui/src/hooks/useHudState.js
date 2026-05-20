import { useEffect, useState } from 'react';
import { parseGodotPayload } from '../bridge/godot';
import { DEFAULT_UI_STATE, deepMerge, mergeRadarTargets, normalizeIncomingData } from '../state';

function mergeHudState(prev, incoming) {
  const merged = deepMerge(prev, incoming);
  if (Array.isArray(incoming.radarTargets)) {
    merged.radarTargets = mergeRadarTargets(prev.radarTargets, incoming.radarTargets);
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

  return { uiState, setUiState };
}
