import { deepMerge, isPlainObject, toFiniteNumber, toNonNegativeInt } from './utils';
import { DEFAULT_UI_STATE } from './defaults';

const HANDLED_PROTO_KEYS = [
  'GameStatus',
  'GlobalUnitStatus',
  'GlobalLogisticsStatus',
  'GlobalSpecialMechanism',
  'Event',
  'RobotInjuryStat',
  'RobotRespawnStatus',
  'RobotStaticStatus',
  'RobotDynamicStatus',
  'RobotModuleStatus',
  'RobotPosition',
  'Buff',
  'PenaltyInfo',
  'RobotPathPlanInfo',
  'RadarInfoToClient',
  'TechCoreMotionStateSync',
  'RobotPerformanceSelectionSync',
  'DeployModeStatusSync',
  'RuneStatusSync',
  'SentryStatusSync',
  'DartSelectTargetStatusSync',
  'SentryCtrlResult',
  'AirSupportStatusSync',
  'CustomByteBlock',
];

const STAGE_LABELS = {
  0: '未开始',
  1: '准备阶段',
  2: '自检阶段',
  3: '倒计时',
  4: '比赛中',
  5: '结算中',
};

const GLOBAL_UNIT_ROBOT_IDS = [1, 2, 3, 4, 7];

const BUFF_TYPE_META = {
  1: { type: 'attack', name: '攻击增益', value: '+20%' },
  2: { type: 'defense', name: '防御/易伤', value: '+150%' },
  3: { type: 'cooling', name: '射击热量冷却', value: '+5/s' },
  4: { type: 'power', name: '底盘功率' },
  5: { type: 'regen', name: '回血增益', value: '+10' },
  6: { type: 'ammo', name: '可兑换弹量' },
  7: { type: 'terrain', name: '地形跨越' },
};

function extractInts(value) {
  const matches = String(value ?? '').match(/-?\d+/g);
  if (!matches) return [];
  return matches
    .map((item) => Number.parseInt(item, 10))
    .filter((item) => Number.isFinite(item));
}

function getExistingRobotMax(defaultRobots, id) {
  const robot = defaultRobots.find((item) => Number(item.id) === Number(id));
  return toNonNegativeInt(robot?.max, 1) || 1;
}

function buildRobotSideFromHealth(healthValues, offset, defaultRobots) {
  return GLOBAL_UNIT_ROBOT_IDS.map((id, index) => ({
    id,
    hp: toNonNegativeInt(healthValues[offset + index]),
    max: getExistingRobotMax(defaultRobots, id),
  }));
}

function toBoolean(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes';
  }
  return Boolean(value);
}

function normalizeMechanismEffects(effects) {
  if (!Array.isArray(effects)) return [];
  return effects.map((item, index) => ({
    id: toNonNegativeInt(item?.id ?? item?.mechanism_id ?? index),
    remainingSec: toFiniteNumber(item?.remaining_sec ?? item?.remainingSec),
  }));
}

function normalizeRadarTarget(source) {
  return {
    robotId: toNonNegativeInt(source.target_robot_id),
    x: toFiniteNumber(source.target_pos_x),
    y: toFiniteNumber(source.target_pos_y),
    angle: toFiniteNumber(source.torward_angle),
    highlighted: toBoolean(source.is_high_light),
    timestamp: toNonNegativeInt(source.last_update_msec, Date.now()),
  };
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
    const currentStage = toNonNegativeInt(source.current_stage);

    patch.timeLeft = toNonNegativeInt(source.stage_countdown_sec);
    patch.match = {
      currentStage,
      stageLabel: STAGE_LABELS[currentStage] ?? `阶段 ${currentStage}`,
      stageElapsedSec: toNonNegativeInt(source.stage_elapsed_sec),
      isPaused: Boolean(source.is_paused),
    };
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

    if (Array.isArray(source.robot_health) && source.robot_health.length >= GLOBAL_UNIT_ROBOT_IDS.length * 2) {
      patch.robots = {
        left: buildRobotSideFromHealth(source.robot_health, 0, DEFAULT_UI_STATE.robots.left),
        right: buildRobotSideFromHealth(source.robot_health, GLOBAL_UNIT_ROBOT_IDS.length, DEFAULT_UI_STATE.robots.right),
      };
    }
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

  if (isPlainObject(data.GlobalSpecialMechanism)) {
    const source = data.GlobalSpecialMechanism;
    patch.mechanisms = {
      effects: normalizeMechanismEffects(source.effects),
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

  if (isPlainObject(data.RobotModuleStatus)) {
    const source = data.RobotModuleStatus;
    patch.modules = {
      powerManager: toNonNegativeInt(source.power_manager),
      rfid: toNonNegativeInt(source.rfid),
      lightStrip: toNonNegativeInt(source.light_strip),
      smallShooter: toNonNegativeInt(source.small_shooter),
      bigShooter: toNonNegativeInt(source.big_shooter),
      uwb: toNonNegativeInt(source.uwb),
      armor: toNonNegativeInt(source.armor),
      videoTransmission: toNonNegativeInt(source.video_transmission),
      capacitor: toNonNegativeInt(source.capacitor),
      mainController: toNonNegativeInt(source.main_controller),
      laserDetectionModule: toNonNegativeInt(source.laser_detection_module),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.RobotPosition)) {
    const source = data.RobotPosition;
    patch.miniMap = {
      currentPosition: {
        x: toFiniteNumber(source.x),
        y: toFiniteNumber(source.y),
        z: toFiniteNumber(source.z),
        yaw: toFiniteNumber(source.yaw),
        lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
      },
    };
  }

  if (isPlainObject(data.Buff)) {
    const source = data.Buff;
    const buffType = toNonNegativeInt(source.buff_type);
    const meta = BUFF_TYPE_META[buffType] ?? {
      type: `buff-${buffType}`,
      name: `BUFF ${buffType}`,
    };

    patch.boostBuffs = [
      {
        id: buffType,
        ...meta,
        time: toFiniteNumber(source.buff_left_time),
        maxTime: toFiniteNumber(source.buff_max_time),
        level: toNonNegativeInt(source.buff_level),
        robotId: toNonNegativeInt(source.robot_id),
      },
    ];
  }

  if (isPlainObject(data.PenaltyInfo)) {
    const source = data.PenaltyInfo;
    patch.penalty = {
      type: toNonNegativeInt(source.penalty_type),
      effectSec: toNonNegativeInt(source.penalty_effect_sec),
      totalCount: toNonNegativeInt(source.total_penalty_num),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };

    if (patch.penalty.type > 0) {
      const timestamp = Date.now();
      patch.messageCenter = {
        items: [
          {
            id: `penalty-${timestamp}-${patch.penalty.type}`,
            tag: `penalty-${patch.penalty.type}`,
            level: patch.penalty.type >= 2 ? 'critical' : 'important',
            text: `判罚提示：类型 ${patch.penalty.type}，影响 ${patch.penalty.effectSec}s，累计 ${patch.penalty.totalCount}`,
            duration: 5000,
            timestamp,
          },
        ],
      };
    }
  }

  if (isPlainObject(data.RobotPathPlanInfo)) {
    const source = data.RobotPathPlanInfo;
    patch.pathPlan = {
      intention: toNonNegativeInt(source.intention),
      start: {
        x: toFiniteNumber(source.start_pos_x),
        y: toFiniteNumber(source.start_pos_y),
      },
      offsets: Array.isArray(source.offsets) ? source.offsets : [],
      senderId: toNonNegativeInt(source.sender_id),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.RadarInfoToClient)) {
    patch.radarTargets = [normalizeRadarTarget(data.RadarInfoToClient)];
  }

  if (isPlainObject(data.TechCoreMotionStateSync)) {
    const source = data.TechCoreMotionStateSync;
    patch.mechanisms = {
      techCore: {
        maximumDifficultyLevel: toNonNegativeInt(source.maximum_difficulty_level),
        status: toNonNegativeInt(source.status),
        enemyCoreStatus: toNonNegativeInt(source.enemy_core_status),
        remainTimeAll: toNonNegativeInt(source.remain_time_all),
        remainTimeStep: toNonNegativeInt(source.remain_time_step),
        lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
      },
    };
  }

  if (isPlainObject(data.RobotPerformanceSelectionSync)) {
    const source = data.RobotPerformanceSelectionSync;
    patch.performance = {
      shooter: toNonNegativeInt(source.shooter),
      chassis: toNonNegativeInt(source.chassis),
      sentryControl: toNonNegativeInt(source.sentry_control),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.DeployModeStatusSync)) {
    const source = data.DeployModeStatusSync;
    patch.heroDeploy = {
      status: toNonNegativeInt(source.status),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.RuneStatusSync)) {
    const source = data.RuneStatusSync;
    patch.rune = {
      status: toNonNegativeInt(source.rune_status),
      activatedArms: toNonNegativeInt(source.activated_arms),
      averageRings: toFiniteNumber(source.average_rings),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.SentryStatusSync)) {
    const source = data.SentryStatusSync;
    patch.sentry = {
      postureId: toNonNegativeInt(source.posture_id),
      isWeakened: toBoolean(source.is_weakened),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.DartSelectTargetStatusSync)) {
    const source = data.DartSelectTargetStatusSync;
    patch.dart = {
      targetId: toNonNegativeInt(source.target_id, 1),
      open: toBoolean(source.open),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.SentryCtrlResult)) {
    const source = data.SentryCtrlResult;
    patch.sentry = {
      lastResult: {
        commandId: toNonNegativeInt(source.command_id),
        resultCode: toNonNegativeInt(source.result_code),
        lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
      },
    };
  }

  if (isPlainObject(data.AirSupportStatusSync)) {
    const source = data.AirSupportStatusSync;
    patch.airSupport = {
      status: toNonNegativeInt(source.airsupport_status),
      leftTime: toNonNegativeInt(source.left_time),
      costCoins: toNonNegativeInt(source.cost_coins),
      isBeingTargeted: toBoolean(source.is_being_targeted),
      shooterStatus: toNonNegativeInt(source.shooter_status),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
    };
  }

  if (isPlainObject(data.CustomByteBlock)) {
    const source = data.CustomByteBlock;
    patch.customByteBlock = {
      data: Array.isArray(source.data) ? source.data : [],
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec, Date.now()),
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

  if (isPlainObject(data.RobotInjuryStat)) {
    const source = data.RobotInjuryStat;
    patch.injury = {
      totalDamage: toNonNegativeInt(source.total_damage),
      collisionDamage: toNonNegativeInt(source.collision_damage),
      smallProjectileDamage: toNonNegativeInt(source.small_projectile_damage),
      largeProjectileDamage: toNonNegativeInt(source.large_projectile_damage),
      dartSplashDamage: toNonNegativeInt(source.dart_splash_damage),
      moduleOfflineDamage: toNonNegativeInt(source.module_offline_damage),
      offlineDamage: toNonNegativeInt(source.offline_damage),
      penaltyDamage: toNonNegativeInt(source.penalty_damage),
      serverKillDamage: toNonNegativeInt(source.server_kill_damage),
      killerId: toNonNegativeInt(source.killer_id),
      lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
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
