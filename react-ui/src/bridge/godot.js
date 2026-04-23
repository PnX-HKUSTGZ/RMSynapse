export function parseGodotPayload(payload, sourceName) {
  if (typeof payload !== 'string') {
    return payload;
  }

  try {
    return JSON.parse(payload);
  } catch (error) {
    console.error(`${sourceName} payload is not valid JSON:`, error);
    return null;
  }
}

export function emitGodotOperation(operation, fallbackLabel, fallbackValue) {
  if (typeof window.godotOperate === 'function') {
    window.godotOperate(operation);
    return;
  }

  if (fallbackValue === undefined) {
    console.log(fallbackLabel);
    return;
  }

  console.log(fallbackLabel, fallbackValue);
}
