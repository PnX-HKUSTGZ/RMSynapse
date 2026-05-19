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

function trySendTransport(label, send, payload) {
  if (typeof send !== 'function') {
    return false;
  }

  try {
    send(payload);
    return true;
  } catch (error) {
    console.warn(`Godot IPC transport failed: ${label}`, error);
    return false;
  }
}

export function emitGodotOperation(operation, fallbackLabel, fallbackValue) {
  const ipcPayload = {
    channel: 'hudOperate',
    operation,
  };
  const payloadText = JSON.stringify(ipcPayload);
  const godotApi = window.godot ?? window.Godot ?? null;

  const stringTransports = [
    ['sendIpcMessage', window.sendIpcMessage],
    ['send_ipc_message', window.send_ipc_message],
    ['ipcRendererToGodot', window.ipcRendererToGodot],
    ['godot.sendIpcMessage', godotApi?.sendIpcMessage ? (payload) => godotApi.sendIpcMessage(payload) : null],
    ['godot.send_ipc_message', godotApi?.send_ipc_message ? (payload) => godotApi.send_ipc_message(payload) : null],
  ];

  for (const [label, send] of stringTransports) {
    if (trySendTransport(label, send, payloadText)) {
      return;
    }
  }

  if (trySendTransport('sendIpcData', window.sendIpcData, ipcPayload)) {
    return;
  }

  if (trySendTransport('send_ipc_data', window.send_ipc_data, ipcPayload)) {
    return;
  }

  if (trySendTransport('ipcDataRendererToGodot', window.ipcDataRendererToGodot, ipcPayload)) {
    return;
  }

  if (trySendTransport('godotOperate', window.godotOperate, operation)) {
    return;
  }

  if (typeof window.cefQuery === 'function') {
    try {
      window.cefQuery({ request: payloadText });
      return;
    } catch (error) {
      console.warn('Godot IPC transport failed: cefQuery', error);
    }
  }

  const message = fallbackValue === undefined ? [fallbackLabel] : [fallbackLabel, fallbackValue];
  console.log(...message);
  console.warn('No Godot IPC transport was available for operation:', operation);
}
