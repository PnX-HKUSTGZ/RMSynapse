import { deepMerge, isPlainObject, toFiniteNumber, toNonNegativeInt } from './utils';

const HANDLED_PROTO_KEYS = [
  'GameStatus',
  'GlobalUnitStatus',
  'GlobalLogisticsStatus',
  'Event',
  'RobotRespawnStatus',
  'RobotStaticStatus',
  'RobotDynamicStatus',
];

function extractInts(value) {
  const matches = String(value ?? '').match(/-?\d+/g);
  if (!matches) return [];
  return matches
    .map((item) => Number.parseInt(item, 10))
    .filter((item) => Number.isFinite(item));
}

function getDartTargetLabel(targetId) {
  switch (targetId) {
    case 1:
      return '前哨站';
    case 2:
      return '基地固定目标';
    case 3:
      return '基地随机固定目标';
    case 4:
      return '基地随机移动目标';
    case 5:
      return '基地末端移动目标';
    default:
      return `未知目标(${targetId})`;
  }
}

function getSideLabel(side) {
  switch (side) {
    case 1:
      return '己方';
    case 2:
      return '对方';
    case 3:
      return '双方';
    default:
      return `未知方(${side})`;
  }
}

function buildEventMessageText(eventId, param) {
  const textParam = String(param ?? '').trim();
  const ints = extractInts(textParam);

  switch (eventId) {
    case 1: {
      const killerId = ints[0] ?? -1;
      const victimId = ints[1] ?? -1;
      return `击杀事件：机器人 ${killerId} 击毁了机器人 ${victimId}`;
    }
    case 2: {
      const targetId = ints[0] ?? -1;
      return `基地/前哨站被摧毁：目标 ID ${targetId}`;
    }
    case 3: {
      const count = ints[0] ?? 0;
      return `能量机关可激活次数变化：剩余 ${count} 次`;
    }
    case 4:
      return '能量机关当前可进入激活状态';
    case 5: {
      const armsCount = ints[0] ?? 0;
      const avgRings = ints[1] ?? 0;
      return `能量机关激活进度：成功灯臂 ${armsCount}，平均环数 ${avgRings}`;
    }
    case 6:
      return `能量机关被激活：类型 ${textParam || '未知'}`;
    case 7:
      return '己方英雄进入部署模式';
    case 8: {
      const damage = ints[0] ?? 0;
      return `己方英雄造成狙击伤害：累计 ${damage}`;
    }
    case 9: {
      const damage = ints[0] ?? 0;
      return `对方英雄造成狙击伤害：累计 ${damage}`;
    }
    case 10:
      return '己方呼叫空中支援';
    case 11: {
      const remaining = ints[0] ?? 0;
      return `己方空中支援被打断：对方剩余可打断次数 ${remaining}`;
    }
    case 12:
      return '对方呼叫空中支援';
    case 13: {
      const remaining = ints[0] ?? 0;
      return `对方空中支援被打断：己方剩余可打断次数 ${remaining}`;
    }
    case 14: {
      const target = ints[0] ?? 0;
      return `飞镖命中：${getDartTargetLabel(target)}`;
    }
    case 15: {
      const side = ints[0] ?? 0;
      return `飞镖闸门开启：${getSideLabel(side)}`;
    }
    case 16:
      return '己方基地遭到攻击';
    case 17: {
      const side = ints[0] ?? 0;
      return `前哨站停转：${getSideLabel(side)}`;
    }
    case 18: {
      const side = ints[0] ?? 0;
      return `基地护甲展开：${getSideLabel(side)}`;
    }
    default:
      return `Event #${eventId}${textParam ? ` (${textParam})` : ''}`;
  }
}

function buildProtoPatch(data) {
  const patch = {};

  if (isPlainObject(data.GameStatus)) {
    const source = data.GameStatus;
    const currentRound = toNonNegativeInt(source.current_round);
    const totalRounds = toNonNegativeInt(source.total_rounds);

    patch.timeLeft = toNonNegativeInt(source.stage_countdown_sec);
    patch.scores = {
      left: toNonNegativeInt(source.red_score),
      right: toNonNegativeInt(source.blue_score),
    };

    if (totalRounds > 0) {
      patch.roundLabel = `Round ${currentRound}/${totalRounds}`;
    }
  }

  if (isPlainObject(data.GlobalUnitStatus)) {
    const source = data.GlobalUnitStatus;
    patch.bases = {
      left: {
        hp: toNonNegativeInt(source.ally_base?.health),
        shield: toNonNegativeInt(source.ally_base?.shield),
        state: toNonNegativeInt(source.ally_base?.status),
      },
      right: {
        hp: toNonNegativeInt(source.enemy_base?.health),
        shield: toNonNegativeInt(source.enemy_base?.shield),
        state: toNonNegativeInt(source.enemy_base?.status),
      },
    };
    patch.outposts = {
      left: {
        hp: toNonNegativeInt(source.ally_outpost?.health),
        state: toNonNegativeInt(source.ally_outpost?.status),
      },
      right: {
        hp: toNonNegativeInt(source.enemy_outpost?.health),
        state: toNonNegativeInt(source.enemy_outpost?.status),
      },
    };
  }

  if (isPlainObject(data.GlobalLogisticsStatus)) {
    const source = data.GlobalLogisticsStatus;
    patch.stats = {
      eco: toNonNegativeInt(source.remaining_economy),
      totalEco: toNonNegativeInt(source.total_economy_obtained),
      tech: toNonNegativeInt(source.tech_level),
      radar: toNonNegativeInt(source.encryption_level),
    };
  }

  if (isPlainObject(data.RobotStaticStatus)) {
    const source = data.RobotStaticStatus;
    patch.maxValues = {
      mechaHp: toNonNegativeInt(source.max_health),
      mechaBoost: toNonNegativeInt(source.max_buffer_energy),
      mechaPower: toNonNegativeInt(source.max_power),
    };
    patch.mecha = {
      pilotId: String(source.robot_id ?? 'HERO'),
      pilotLevel: `LV.${toNonNegativeInt(source.level)}`,
    };
    patch.centerHud = {
      maxHeat: toNonNegativeInt(source.max_heat),
    };
  }

  if (isPlainObject(data.RobotDynamicStatus)) {
    const source = data.RobotDynamicStatus;
    patch.mecha = {
      hp: toNonNegativeInt(source.current_health),
      boost: toNonNegativeInt(source.current_buffer_energy),
      energy: toNonNegativeInt(source.current_chassis_energy),
      ammo: toNonNegativeInt(source.remaining_ammo),
      inCombat: !source.is_out_of_combat,
      combatTimer: toFiniteNumber(source.out_of_combat_countdown),
      remoteHealReady: Boolean(source.can_remote_heal),
      remoteAmmoReady: Boolean(source.can_remote_ammo),
    };
    patch.centerHud = {
      ammo: toNonNegativeInt(source.remaining_ammo),
      heat: toFiniteNumber(source.current_heat),
    };
  }

  if (isPlainObject(data.RobotRespawnStatus)) {
    const source = data.RobotRespawnStatus;
    const total = toNonNegativeInt(source.total_respawn_progress);
    const current = toNonNegativeInt(source.current_respawn_progress);
    patch.respawn = {
      isDead: Boolean(source.is_pending_respawn),
      countdown: Math.max(total - current, 0),
      reviveCost: toNonNegativeInt(source.gold_cost_for_respawn),
    };
  }

  if (isPlainObject(data.Event)) {
    const source = data.Event;
    const eventId = toFiniteNumber(source.event_id, -1);
    const param = String(source.param ?? '').trim();
    const timestamp = Date.now();
    patch.messageCenter = {
      items: [
        {
          id: `event-${timestamp}-${eventId}`,
          tag: `event-${eventId}`,
          level: eventId === 16 ? 'critical' : 'important',
          text: buildEventMessageText(eventId, param),
          duration: 3500,
          timestamp,
        },
      ],
    };
  }

  return patch;
}

export function normalizeIncomingData(data) {
  if (!isPlainObject(data)) return {};

  const incoming = { ...data };
  if (incoming.blackBg != null && incoming.forceBlackBg == null) {
    incoming.forceBlackBg = incoming.blackBg;
  }
  delete incoming.blackBg;

  const protoPatch = buildProtoPatch(incoming);
  const normalized = { ...incoming };
  HANDLED_PROTO_KEYS.forEach((key) => {
    delete normalized[key];
  });

  return deepMerge(normalized, protoPatch);
}
