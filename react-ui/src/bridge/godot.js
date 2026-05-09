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
  const ipcPayload = {
    channel: 'hudOperate',
    operation,
  };

  if (typeof window.sendIpcMessage === 'function') {
    window.sendIpcMessage(JSON.stringify(ipcPayload));
    return;
  }

  if (typeof window.sendIpcData === 'function') {
    window.sendIpcData(JSON.stringify(ipcPayload));
    return;
  }

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
