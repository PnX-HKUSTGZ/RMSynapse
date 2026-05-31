export const ENEMY_AUX_CMD_ECONOMY = 0x01;
export const ENEMY_AUX_CMD_AMMO = 0x02;
export const ENEMY_AUX_HEADER_LEN = 5;
export const ENEMY_AUX_ECONOMY_BYTES = 8;
export const ENEMY_AUX_AMMO_COUNT = 5;
export const ENEMY_AUX_AMMO_ELEMENT_BYTES = 4;
export const ENEMY_AUX_AMMO_BYTES = ENEMY_AUX_AMMO_COUNT * ENEMY_AUX_AMMO_ELEMENT_BYTES;
export const ENEMY_AUX_STALE_MS = 1500;
export const I32_INVALID = -1;

/**
 * @typedef {Object} EnemyAuxPacketV1
 * @property {number} receivedAtMs
 * @property {number | null} activeTimeMs
 * @property {boolean} validAmmo
 * @property {boolean} validEconomy
 * @property {{hero1: number | null, infantry3: number | null, infantry4: number | null, aerial6: number | null, sentry7: number | null}} enemyProjectile
 * @property {{coinsRemaining: number | null, coinsTotal: number | null}} enemyEconomy
 */

function toByteArray(data) {
  if (data == null) return null;
  if (data instanceof Uint8Array) return data;
  if (Array.isArray(data)) return Uint8Array.from(data.map((item) => Number(item) & 0xff));
  if (typeof data.length === 'number') return Uint8Array.from(Array.from(data));
  return null;
}

function nullableI32(value) {
  return value === I32_INVALID ? null : value;
}

function hasValidData(packet) {
  return Boolean(packet.validAmmo || packet.validEconomy);
}

function emptyPacket(receivedAtMs) {
  return {
    receivedAtMs,
    activeTimeMs: null,
    validAmmo: false,
    validEconomy: false,
    enemyProjectile: {
      hero1: null,
      infantry3: null,
      infantry4: null,
      aerial6: null,
      sentry7: null,
    },
    enemyEconomy: {
      coinsRemaining: null,
      coinsTotal: null,
    },
  };
}

function debugDrop(reason, context) {
  console.debug('[EnemyAux] stop parsing CustomByteBlock payload', { reason, ...context });
}

/**
 * Parse enemy ammo + economy payload carried by CustomByteBlock.data.
 *
 * The robot bridge record format is:
 *   uint8 cmd_id, int32 active_time_ms, load[fixed by cmd_id]
 *
 * @param {Uint8Array | number[]} data
 * @param {number} receivedAtMs
 * @returns {EnemyAuxPacketV1 | null}
 */
export function parseEnemyAuxPacketV1(data, receivedAtMs = Date.now()) {
  const bytes = toByteArray(data);
  if (!bytes || bytes.byteLength < ENEMY_AUX_HEADER_LEN) return null;

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const packet = emptyPacket(receivedAtMs);
  let offset = 0;

  while (offset < bytes.byteLength) {
    if (bytes.byteLength - offset < ENEMY_AUX_HEADER_LEN) {
      debugDrop('trailing header too short', { offset, remaining: bytes.byteLength - offset });
      break;
    }

    const recordOffset = offset;
    const cmdId = view.getUint8(offset);
    const activeTimeMs = view.getInt32(offset + 1, true);
    offset += ENEMY_AUX_HEADER_LEN;

    if (cmdId === ENEMY_AUX_CMD_ECONOMY) {
      if (bytes.byteLength - offset < ENEMY_AUX_ECONOMY_BYTES) {
        debugDrop('invalid economy record', {
          offset: recordOffset,
          activeTimeMs,
          remaining: bytes.byteLength - offset,
          required: ENEMY_AUX_ECONOMY_BYTES,
        });
        break;
      }
      packet.activeTimeMs = activeTimeMs;
      packet.validEconomy = true;
      packet.enemyEconomy = {
        coinsRemaining: view.getUint32(offset, true),
        coinsTotal: view.getUint32(offset + 4, true),
      };
      offset += ENEMY_AUX_ECONOMY_BYTES;
      continue;
    }

    if (cmdId === ENEMY_AUX_CMD_AMMO) {
      if (bytes.byteLength - offset < ENEMY_AUX_AMMO_BYTES) {
        debugDrop('invalid ammo record', {
          offset: recordOffset,
          activeTimeMs,
          remaining: bytes.byteLength - offset,
          required: ENEMY_AUX_AMMO_BYTES,
        });
        break;
      }
      packet.activeTimeMs = activeTimeMs;
      packet.validAmmo = true;
      packet.enemyProjectile = {
        hero1: nullableI32(view.getInt32(offset, true)),
        infantry3: nullableI32(view.getInt32(offset + 4, true)),
        infantry4: nullableI32(view.getInt32(offset + 8, true)),
        sentry7: nullableI32(view.getInt32(offset + 12, true)),
        aerial6: nullableI32(view.getInt32(offset + 16, true)),
      };
      offset += ENEMY_AUX_AMMO_BYTES;
      continue;
    }

    debugDrop('unknown cmd_id', { offset: recordOffset, cmdId, activeTimeMs });
    break;
  }

  return hasValidData(packet) ? packet : null;
}

export function buildMockEnemyAuxBridgePayload() {
  const bytes = new Uint8Array(
    ENEMY_AUX_HEADER_LEN + ENEMY_AUX_ECONOMY_BYTES
    + ENEMY_AUX_HEADER_LEN + ENEMY_AUX_AMMO_BYTES,
  );
  const view = new DataView(bytes.buffer);
  let offset = 0;

  view.setUint8(offset, ENEMY_AUX_CMD_ECONOMY);
  view.setInt32(offset + 1, 1000, true);
  offset += ENEMY_AUX_HEADER_LEN;
  view.setUint32(offset, 423, true);
  view.setUint32(offset + 4, 3175, true);
  offset += ENEMY_AUX_ECONOMY_BYTES;

  view.setUint8(offset, ENEMY_AUX_CMD_AMMO);
  view.setInt32(offset + 1, 1000, true);
  offset += ENEMY_AUX_HEADER_LEN;
  [26, I32_INVALID, 143, 182, 0].forEach((value, index) => {
    view.setInt32(offset + (index * ENEMY_AUX_AMMO_ELEMENT_BYTES), value, true);
  });

  return bytes;
}

export function buildMockEnemyAuxPacketV1() {
  return buildMockEnemyAuxBridgePayload();
}
