import { useEffect, useState } from 'react';
import { parseGodotPayload } from '../bridge/godot';
import { DEFAULT_UI_STATE, deepMerge, normalizeIncomingData } from '../state';

export function useHudState() {
  const [uiState, setUiState] = useState(DEFAULT_UI_STATE);

  useEffect(() => {
    const handler = (payload) => {
      const data = parseGodotPayload(payload, 'godotPush');
      if (!data) return;

      const normalizedData = normalizeIncomingData(data);
      setUiState((prev) => deepMerge(prev, normalizedData));
    };

    window.godotPush = handler;

    return () => {
      delete window.godotPush;
    };
  }, []);

  return { uiState, setUiState };
}
