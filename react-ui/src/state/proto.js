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
const RADAR_ROBOT_IDS = [101, 102, 103, 104, 106, 107, 1, 2, 3, 4, 6, 7];

const BUFF_TYPE_META = {
  1: { type: 'attack', name: '攻击增益', value: '+20%' },
  2: { type: 'defense', name: '防御/易伤', value: '+150%' },
  3: { type: 'cooling', name: '射击热量冷却', value: '+5/s' },
  4: { type: 'power', name: '底盘功率' },
  5: { type: 'regen', name: '回血增益', value: '+10' },
  6: { type: 'ammo', name: '可兑换弹量' },
  7: { type: 'terrain', name: '地形跨越' },
};

const ASSEMBLY_RESULT_META = {
  0: { text: '装配成功', type: 'success' },
  1: { text: '装配失败：能量单元被拔出', type: 'error' },
  2: { text: '装配失败：超时', type: 'error' },
  3: { text: '装配失败：离开装配区过久', type: 'error' },
  4: { text: '装配失败：工程战亡', type: 'error' },
  5: { text: '装配失败：四级难度未满足完成协作时限', type: 'error' },
  6: { text: '装配取消：主动退出', type: 'cancel' },
  7: { text: '装配失败：结算时未检测到能量单元', type: 'error' },
  8: { text: '装配失败：缓冲期到期强制结束', type: 'error' },
};

const ROBOT_ID_LABELS = {
  1: '红方英雄',
  2: '红方工程',
  3: '红方步兵3',
  4: '红方步兵4',
  5: '红方步兵5',
  6: '红方空中',
  7: '红方哨兵',
  8: '红方飞镖',
  9: '红方雷达',
  10: '红方前哨站',
  11: '红方基地',
  101: '蓝方英雄',
  102: '蓝方工程',
  103: '蓝方步兵103',
  104: '蓝方步兵104',
  105: '蓝方步兵105',
  106: '蓝方空中',
  107: '蓝方哨兵',
  108: '蓝方飞镖',
  109: '蓝方雷达',
  110: '蓝方前哨站',
  111: '蓝方基地',
};

const EVENT_CATEGORY_META = {
  combat: { title: '战斗事件', level: 'important' },
  objective: { title: '目标事件', level: 'critical' },
  mechanism: { title: '机制事件', level: 'normal' },
  support: { title: '支援事件', level: 'important' },
  assembly: { title: '工程装配', level: 'important' },
  system: { title: '系统事件', level: 'normal' },
};

const DART_TARGET_LABELS = {
  1: '前哨站',
  2: '基地固定目标',
  3: '基地随机固定目标',
  4: '基地随机移动目标',
  5: '基地末端移动目标',
};

const MAP_PROTOCOL_MAX = DEFAULT_UI_STATE.miniMap.protocolCoordinateMax || 1000;

let eventMessageSeq = 0;

function extractInts(value) {
  const matches = String(value ?? '').match(/-?\d+/g);
  if (!matches) return [];
  return matches
    .map((item) => Number.parseInt(item, 10))
    .filter((item) => Number.isFinite(item));
}

function extractNumbers(value) {
  const matches = String(value ?? '').match(/-?\d+(?:\.\d+)?/g);
  if (!matches) return [];
  return matches
    .map((item) => Number.parseFloat(item))
    .filter((item) => Number.isFinite(item));
}

function robotLabel(id) {
  return ROBOT_ID_LABELS[id] ?? `机器人${id}`;
}

function sideLabel(side) {
  switch (Number(side)) {
    case 1:
      return '红方';
    case 2:
      return '蓝方';
    default:
      return `未知方${side}`;
  }
}

function getExistingRobotMax(defaultRobots, id) {
  const robot = defaultRobots.find((item) => Number(item.id) === Number(id));
  return toNonNegativeInt(robot?.max, 1) || 1;
}

function getExistingRobotLevel(defaultRobots, id) {
  const robot = defaultRobots.find((item) => Number(item.id) === Number(id));
  return toNonNegativeInt(robot?.level, 0);
}

function getRobotSideKey(robotId) {
  const numericId = Number(robotId);
  if (!Number.isFinite(numericId) || numericId <= 0) return null;
  return numericId >= 100 ? 'blue' : 'red';
}

function getRobotDisplayId(robotId) {
  const numericId = Number(robotId);
  if (!Number.isFinite(numericId) || numericId <= 0) return 0;
  return numericId >= 100 ? numericId - 100 : numericId;
}

function buildRobotSideFromHealth(healthValues, offset, defaultRobots) {
  return GLOBAL_UNIT_ROBOT_IDS.map((id, index) => ({
    id,
    hp: toNonNegativeInt(healthValues[offset + index]),
    max: getExistingRobotMax(defaultRobots, id),
    level: getExistingRobotLevel(defaultRobots, id),
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

function normalizeRadarTarget(source, index = 0) {
  return {
    robotId: toNonNegativeInt(source.target_robot_id ?? RADAR_ROBOT_IDS[index]),
    x: (toFiniteNumber(source.target_pos_x) / MAP_PROTOCOL_MAX) * 100,
    y: (toFiniteNumber(source.target_pos_y) / MAP_PROTOCOL_MAX) * 100,
    angle: toFiniteNumber(source.torward_angle ?? 0),
    highlighted: toBoolean(source.is_high_light),
    timestamp: toNonNegativeInt(source.last_update_msec, Date.now()),
  };
}

function normalizeMapPosition(source) {
  return {
    robotId: toNonNegativeInt(source.robot_id),
    x: (toFiniteNumber(source.x) / MAP_PROTOCOL_MAX) * 100,
    y: (toFiniteNumber(source.y) / MAP_PROTOCOL_MAX) * 100,
    z: toFiniteNumber(source.z),
    yaw: toFiniteNumber(source.yaw),
    lastUpdateMsec: toNonNegativeInt(source.last_update_msec),
  };
}

function buildEventMessageMeta(eventId, param) {
  const textParam = String(param ?? '').trim();
  const ints = extractInts(textParam);
  const numbers = extractNumbers(textParam);

  const fromCategory = (category, text, overrides = {}) => {
    const categoryMeta = EVENT_CATEGORY_META[category] ?? EVENT_CATEGORY_META.system;
    return {
      category,
      title: categoryMeta.title,
      level: categoryMeta.level,
      text,
      duration: 4200,
      tag: null,
      ...overrides,
    };
  };

  switch (eventId) {
    case 1: {
      const victimId = ints[0] ?? -1;
      const killerId = ints[1] ?? -1;
      return fromCategory('combat', `${robotLabel(killerId)} 击毁 ${robotLabel(victimId)}`, { duration: 3600 });
    }
    case 2: {
      const targetId = ints[0] ?? -1;
      return fromCategory('objective', `${robotLabel(targetId)} 被摧毁`, { duration: 6500 });
    }
    case 3: {
      const armsCount = ints[0] ?? 0;
      const avgRings = numbers[1] ?? 0;
      return fromCategory('mechanism', `大能量机关激活：成功灯臂 ${armsCount}，平均环数 ${avgRings}`, { tag: 'event-rune-arms' });
    }
    case 5: {
      const damage = ints[0] ?? 0;
      return fromCategory('combat', `己方英雄造成狙击伤害：累计 ${damage}`, { tag: 'event-ally-sniper' });
    }
    case 6: {
      const damage = ints[0] ?? 0;
      return fromCategory('combat', `对方英雄造成狙击伤害：累计 ${damage}`, { level: 'critical', tag: 'event-enemy-sniper' });
    }
    case 4: {
      const activateType = ints[0] ?? 0;
      const typeLabel = activateType === 1 ? '小能量机关' : activateType === 2 ? '大能量机关' : `未知类型${activateType}`;
      return fromCategory('mechanism', `能量机关进入已激活状态：${typeLabel}`, { tag: 'event-rune-active' });
    }
    case 7:
      return fromCategory('support', '对方呼叫空中支援', { level: 'critical', duration: 6500, tag: 'event-enemy-air-support' });
    case 8: {
      const remaining = ints[0] ?? 0;
      return fromCategory('support', `对方空中支援被反制：己方剩余反制次数 ${remaining}`, { tag: 'event-enemy-air-countered' });
    }
    case 9: {
      const hitSide = ints[0] ?? 0;
      const target = ints[1] ?? 0;
      const targetLabel = DART_TARGET_LABELS[target] ?? `未知目标${target}`;
      return fromCategory('objective', `${sideLabel(hitSide)}飞镖命中${targetLabel}`, { duration: 5600 });
    }
    case 10:
      return fromCategory('objective', '对方飞镖闸门开启', { level: 'important', tag: 'event-enemy-dart-gate' });
    case 11:
      return fromCategory('objective', '基地遭到攻击', { level: 'critical', duration: 6500, tag: 'event-base-under-attack' });
    case 12:
      return fromCategory('objective', '对方前哨站停转', { level: 'important', tag: 'event-enemy-outpost-stopped' });
    case 13:
      return fromCategory('objective', '对方基地护甲展开', { level: 'critical', tag: 'event-enemy-base-armor' });
    case 14:
      return fromCategory('assembly', '对方请求四级装配，进入强制退出缓冲期', { level: 'critical', duration: 6500, tag: 'event-assembly-force-buffer' });
    case 15: {
      const resultCode = ints[0] ?? 0;
      const result = ASSEMBLY_RESULT_META[resultCode];
      return fromCategory('assembly', result?.text ?? `装配结果：${resultCode}`, {
        level: result?.type === 'success' ? 'important' : 'critical',
        duration: 6500,
      });
    }
    default:
      return fromCategory('system', `Event #${eventId}${textParam ? ` (${textParam})` : ''}`);
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
    patch.globalUnit = {
      sideBasis: 'ally_enemy',
    };
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
    const robotId = toNonNegativeInt(source.robot_id);
    const robotLevel = toNonNegativeInt(source.level);
    const sideKey = getRobotSideKey(robotId);
    const displayId = getRobotDisplayId(robotId);

    patch.maxValues = {
      mechaHp: toNonNegativeInt(source.max_health),
      mechaBoost: toNonNegativeInt(source.max_buffer_energy),
      mechaPower: toNonNegativeInt(source.max_power),
      mechaChassisEnergy: toNonNegativeInt(source.max_chassis_energy),
    };
    patch.mecha = {
      pilotId: String(source.robot_id ?? 'HERO'),
      pilotLevel: `LV.${toNonNegativeInt(source.level)}`,
      robotId: toNonNegativeInt(source.robot_id),
      robotType: toNonNegativeInt(source.robot_type),
      level: toNonNegativeInt(source.level),
      connectionState: toNonNegativeInt(source.connection_state),
      fieldState: toNonNegativeInt(source.field_state),
      aliveState: toNonNegativeInt(source.alive_state),
      maxHealth: toNonNegativeInt(source.max_health),
      maxChassisEnergy: toNonNegativeInt(source.max_chassis_energy),
      maxBufferEnergy: toNonNegativeInt(source.max_buffer_energy),
      maxPower: toNonNegativeInt(source.max_power),
    };
    if (sideKey && displayId > 0) {
      patch.robotLevels = {
        [sideKey]: {
          [displayId]: robotLevel,
        },
      };
    }
    patch.centerHud = {
      maxHeat: toNonNegativeInt(source.max_heat),
    };
  }

  if (isPlainObject(data.RobotDynamicStatus)) {
    const source = data.RobotDynamicStatus;
    patch.mecha = {
      hp: toNonNegativeInt(source.current_health),
      currentHealth: toNonNegativeInt(source.current_health),
      boost: toNonNegativeInt(source.current_buffer_energy),
      currentBufferEnergy: toNonNegativeInt(source.current_buffer_energy),
      energy: toNonNegativeInt(source.current_chassis_energy),
      currentChassisEnergy: toNonNegativeInt(source.current_chassis_energy),
      ammo: toNonNegativeInt(source.remaining_ammo),
      remainingAmmo: toNonNegativeInt(source.remaining_ammo),
      currentExperience: toNonNegativeInt(source.current_experience),
      experienceForUpgrade: toNonNegativeInt(source.experience_for_upgrade),
      totalProjectilesFired: toNonNegativeInt(source.total_projectiles_fired),
      lastProjectileFireRate: toFiniteNumber(source.last_projectile_fire_rate),
      inCombat: !source.is_out_of_combat,
      isOutOfCombat: Boolean(source.is_out_of_combat),
      combatTimer: toFiniteNumber(source.out_of_combat_countdown),
      remoteHealReady: Boolean(source.can_remote_heal),
      canRemoteHeal: Boolean(source.can_remote_heal),
      remoteAmmoReady: Boolean(source.can_remote_ammo),
      canRemoteAmmo: Boolean(source.can_remote_ammo),
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
    patch.miniMap = {
      currentPosition: normalizeMapPosition(data.RobotPosition),
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
    const source = data.RadarInfoToClient;
    const targets = Array.isArray(source.targets)
      ? source.targets
      : Array.isArray(source.radar_single_robot_info)
        ? source.radar_single_robot_info
        : null;
    patch.radarTargets = targets
      ? targets.map((target, index) => normalizeRadarTarget(target, index))
      : [normalizeRadarTarget(source)];
  }

  if (isPlainObject(data.TechCoreMotionStateSync)) {
    const source = data.TechCoreMotionStateSync;
    const basicState = toNonNegativeInt(source.basic_state ?? source.status);
    patch.mechanisms = {
      techCore: {
        maximumDifficultyLevel: toNonNegativeInt(source.maximum_difficulty_level),
        basicState,
        status: basicState,
        putinState: toNonNegativeInt(source.putin_state),
        moveState: toNonNegativeInt(source.move_state),
        rotateState: toNonNegativeInt(source.rotate_state),
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
    eventMessageSeq += 1;
    const eventMeta = buildEventMessageMeta(eventId, param);
    patch.messageCenter = {
      items: [
        {
          id: `event-${timestamp}-${eventId}-${eventMessageSeq}`,
          tag: eventMeta.tag,
          level: eventMeta.level,
          title: eventMeta.title,
          category: eventMeta.category,
          text: eventMeta.text,
          duration: eventMeta.duration,
          timestamp,
        },
      ],
    };
    if (eventId === 14) {
      patch.assembly = {
        warning: '对方请求四级装配，当前装配进入强制退出缓冲期',
        result: null,
        lastEventId: eventId,
        lastEventParam: param,
        timestamp,
      };
    } else if (eventId === 15) {
      const resultCode = extractInts(param)[0] ?? 0;
      const result = ASSEMBLY_RESULT_META[resultCode] ?? {
        text: `装配结果：${resultCode}`,
        type: 'error',
      };
      patch.assembly = {
        warning: '',
        result: {
          code: resultCode,
          text: result.text,
          type: result.type,
        },
        lastEventId: eventId,
        lastEventParam: param,
        timestamp,
      };
    }
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
