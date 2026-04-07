const isPlainObject = (value) => value != null && typeof value === 'object' && !Array.isArray(value);

function deepMerge(base, patch) {
  if (!isPlainObject(base) || !isPlainObject(patch)) {
    return patch;
  }

  const result = { ...base };
  for (const [key, value] of Object.entries(patch)) {
    if (value == null) continue;

    const prev = base[key];
    if (isPlainObject(prev) && isPlainObject(value)) {
      result[key] = deepMerge(prev, value);
      continue;
    }

    result[key] = value;
  }

  return result;
}

function toPercent(value, max) {
  if (!max || max <= 0) return 0;
  return Math.max(0, Math.min(100, (value / max) * 100));
}

const HANDLED_PROTO_KEYS = [
  'GameStatus',
  'GlobalUnitStatus',
  'GlobalLogisticsStatus',
  'Event',
  'RobotRespawnStatus',
  'RobotStaticStatus',
  'RobotDynamicStatus'
];

function toFiniteNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function toNonNegativeInt(value, fallback = 0) {
  return Math.max(0, Math.trunc(toFiniteNumber(value, fallback)));
}

function extractInts(value) {
  const matches = String(value ?? '').match(/-?\d+/g);
  if (!matches) return [];
  return matches.map((item) => Number.parseInt(item, 10)).filter((item) => Number.isFinite(item));
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
    const s = data.GameStatus;
    const currentRound = toNonNegativeInt(s.current_round);
    const totalRounds = toNonNegativeInt(s.total_rounds);
    patch.timeLeft = toNonNegativeInt(s.stage_countdown_sec);
    patch.scores = {
      left: toNonNegativeInt(s.red_score),
      right: toNonNegativeInt(s.blue_score)
    };
    if (totalRounds > 0) {
      patch.roundLabel = `Round ${currentRound}/${totalRounds}`;
    }
  }

  if (isPlainObject(data.GlobalUnitStatus)) {
    const s = data.GlobalUnitStatus;
    patch.bases = {
      left: {
        hp: toNonNegativeInt(s.ally_base?.health),
        shield: toNonNegativeInt(s.ally_base?.shield),
        state: toNonNegativeInt(s.ally_base?.status)
      },
      right: {
        hp: toNonNegativeInt(s.enemy_base?.health),
        shield: toNonNegativeInt(s.enemy_base?.shield),
        state: toNonNegativeInt(s.enemy_base?.status)
      }
    };
    patch.outposts = {
      left: {
        hp: toNonNegativeInt(s.ally_outpost?.health),
        state: toNonNegativeInt(s.ally_outpost?.status)
      },
      right: {
        hp: toNonNegativeInt(s.enemy_outpost?.health),
        state: toNonNegativeInt(s.enemy_outpost?.status)
      }
    };
  }

  if (isPlainObject(data.GlobalLogisticsStatus)) {
    const s = data.GlobalLogisticsStatus;
    patch.stats = {
      eco: toNonNegativeInt(s.remaining_economy),
      totalEco: toNonNegativeInt(s.total_economy_obtained),
      tech: toNonNegativeInt(s.tech_level),
      radar: toNonNegativeInt(s.encryption_level)
    };
  }

  if (isPlainObject(data.RobotStaticStatus)) {
    const s = data.RobotStaticStatus;
    patch.maxValues = {
      mechaHp: toNonNegativeInt(s.max_health),
      mechaBoost: toNonNegativeInt(s.max_buffer_energy),
      mechaPower: toNonNegativeInt(s.max_power)
    };
    patch.mecha = {
      pilotId: String(s.robot_id ?? 'HERO'),
      pilotLevel: `LV.${toNonNegativeInt(s.level)}`
    };
    patch.centerHud = {
      maxHeat: toNonNegativeInt(s.max_heat)
    };
  }

  if (isPlainObject(data.RobotDynamicStatus)) {
    const s = data.RobotDynamicStatus;
    patch.mecha = {
      hp: toNonNegativeInt(s.current_health),
      boost: toNonNegativeInt(s.current_buffer_energy),
      energy: toNonNegativeInt(s.current_chassis_energy),
      ammo: toNonNegativeInt(s.remaining_ammo),
      inCombat: !Boolean(s.is_out_of_combat),
      combatTimer: toFiniteNumber(s.out_of_combat_countdown),
      remoteHealReady: Boolean(s.can_remote_heal),
      remoteAmmoReady: Boolean(s.can_remote_ammo)
    };
    patch.centerHud = {
      ammo: toNonNegativeInt(s.remaining_ammo),
      heat: toFiniteNumber(s.current_heat)
    };
  }

  if (isPlainObject(data.RobotRespawnStatus)) {
    const s = data.RobotRespawnStatus;
    const total = toNonNegativeInt(s.total_respawn_progress);
    const current = toNonNegativeInt(s.current_respawn_progress);
    patch.respawn = {
      isDead: Boolean(s.is_pending_respawn),
      countdown: Math.max(total - current, 0),
      reviveCost: toNonNegativeInt(s.gold_cost_for_respawn)
    };
  }

  if (isPlainObject(data.Event)) {
    const s = data.Event;
    const eventId = toFiniteNumber(s.event_id, -1);
    const param = String(s.param ?? '').trim();
    const timestamp = Date.now();
    patch.messageCenter = {
      items: [
        {
          id: `event-${timestamp}-${eventId}`,
          tag: `event-${eventId}`,
          level: eventId === 16 ? 'critical' : 'important',
          text: buildEventMessageText(eventId, param),
          duration: 3500,
          timestamp
        }
      ]
    };
  }

  return patch;
}

function normalizeIncomingData(data) {
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

const DEFAULT_MINI_MAP_PLAYERS = [
  { id: 'red-1', team: 'red', number: 1, x: 12, y: 15, rotation: 90 },
  { id: 'red-2', team: 'red', number: 2, x: 12, y: 29, rotation: 90 },
  { id: 'red-3', team: 'red', number: 3, x: 12, y: 43, rotation: 90 },
  { id: 'red-4', team: 'red', number: 4, x: 12, y: 57, rotation: 90 },
  { id: 'red-6', team: 'red', number: 6, x: 12, y: 71, rotation: 90 },
  { id: 'red-7', team: 'red', number: 7, x: 12, y: 85, rotation: 90 },
  { id: 'blue-1', team: 'blue', number: 1, x: 88, y: 15, rotation: 270 },
  { id: 'blue-2', team: 'blue', number: 2, x: 88, y: 29, rotation: 270 },
  { id: 'blue-3', team: 'blue', number: 3, x: 88, y: 43, rotation: 270 },
  { id: 'blue-4', team: 'blue', number: 4, x: 88, y: 57, rotation: 270 },
  { id: 'blue-6', team: 'blue', number: 6, x: 88, y: 71, rotation: 270 },
  { id: 'blue-7', team: 'blue', number: 7, x: 88, y: 85, rotation: 270 }
];

// 默认 UI 数据（当 Godot 还没推送任何数据时使用）
const DEFAULT_UI_STATE = {
  forceBlackBg: true,
  uiSizing: {
    topCoreScale: 1,
    centerHudScale: 1,
    mechaHudScale: 1,
    miniMapScale: 0.75,
    miniMapWidth: 420,
    miniMapHeight: 236,
    miniMapMarkerSize: 24,
    miniMapBottom: 16,
    miniMapRight: 16
  },
  roundLabel: 'Round 2/5',
  labels: {
    outpost: '前哨站',
    eco: 'ECO',
    tech: 'TECH',
    radar: 'RADAR'
  },
  baseStateMeta: {
    0: { icon: '🛡️', label: '无敌' },
    1: { icon: '⚠️', label: '接敌' },
    2: { icon: '💠', label: '护甲' }
  },
  outpostStateMeta: {
    0: { icon: '🔒', spin: false },
    1: { icon: '🔄', spin: true },
    2: { icon: '⏸️', spin: false },
    3: { icon: '❌', spin: false },
    4: { icon: '🔧', spin: false },
    5: { icon: '⏳', spin: true },
    default: { icon: '❓', spin: false }
  },
  maxValues: {
    baseHp: 5000,
    baseShield: 1500,
    outpostHp: 750,
    mechaHp: 2000,
    mechaBoost: 500,
    mechaPower: 3500,
    techLevel: 4,
    radarLevel: 5
  },
  timeLeft: 420,
  scores: { left: 0, right: 0 },
  bases: {
    left: { hp: 4200, shield: 800, state: 0 },
    right: { hp: 5000, shield: 1500, state: 0 }
  },
  outposts: {
    left: { hp: 530, state: 1 },
    right: { hp: 0, state: 3 }
  },
  stats: {
    eco: 100,
    totalEco: 450,
    tech: 4,
    radar: 5
  },
  messageCenter: {
    enabled: true,
    topPercent: 25,
    scale: 0.7,
    minScale: 0.5,
    maxScale: 2,
    maxVisible: 8,
    defaultDurationMs: 5000,
    leaveAnimationMs: 300,
    priorityMap: {
      critical: 1,
      important: 2,
      normal: 3
    },
    levels: {
      critical: {
        title: 'CRITICAL ALERT',
        colorClass: 'text-red-500',
        borderClass: 'border-red-600',
        bgClass: 'bg-red-950/40',
        iconBg: 'bg-red-900/60',
        glowClass: 'shadow-[0_0_25px_rgba(220,38,38,0.7)] ring-1 ring-red-500/50',
        icon: '⚠️',
        extraAnim: 'animate-pulse'
      },
      important: {
        title: 'TACTICAL EVENT',
        colorClass: 'text-amber-400',
        borderClass: 'border-amber-500',
        bgClass: 'bg-amber-950/28',
        iconBg: 'bg-amber-900/38',
        glowClass: 'shadow-[0_0_15px_rgba(245,158,11,0.5)]',
        icon: '⚔️',
        extraAnim: ''
      },
      normal: {
        title: 'SYSTEM LOG',
        colorClass: 'text-emerald-400',
        borderClass: 'border-emerald-500',
        bgClass: 'bg-emerald-950/20',
        iconBg: 'bg-emerald-900/28',
        glowClass: 'shadow-[0_0_10px_rgba(16,185,129,0.3)]',
        icon: '⚡',
        extraAnim: ''
      }
    },
    items: [
      {
        id: 'msg-test-critical-1',
        tag: 'base-shield-broken',
        level: 'critical',
        text: '测试：基地护盾崩溃，进入高危状态',
        duration: 8000,
        timestamp: 1
      },
      {
        id: 'msg-test-important-1',
        tag: 'kill-streak',
        level: 'important',
        text: '测试：我方完成关键击杀，获得战术优势',
        duration: 6000,
        timestamp: 2
      },
      {
        id: 'msg-test-normal-1',
        tag: 'buff-activated',
        level: 'normal',
        text: '测试：系统提示，增益模块已激活',
        duration: 4500,
        timestamp: 3
      }
    ]
  },
  controls: {
    activeRole: 'infantry',
    isLocked: false,
    infantrySettings: { chassis: 'hp', firing: 'burst' },
    heroSettings: { chassis: 'hp', firing: 'melee' },
    sentrySettings: { mode: 'auto' },
    dartTarget: '1',
    gateOpen: false,
    toastDurationMs: 2500,
    costs: {
      remoteHeal: 200
    },
    ammoStore: {
      infantry: {
        normal: { title: '步兵弹药', unitPrice: 1, step: 10, desc: '10金币/10发' },
        airdrop: { title: '步兵弹药(空投)', unitPrice: 1.5, step: 10, desc: '15金币/10发' }
      },
      hero: {
        normal: { title: '英雄弹药', unitPrice: 10, step: 1, desc: '10金币/1发' },
        airdrop: { title: '英雄弹药(空投)', unitPrice: 15, step: 1, desc: '15金币/1发' }
      }
    }
  },
  robots: {
    left: [
      { id: 7, hp: 600, max: 600 },
      { id: 6, hp: 500, max: 500 },
      { id: 4, hp: 200, max: 400 },
      { id: 3, hp: 400, max: 400 },
      { id: 2, hp: 150, max: 400 },
      { id: 1, hp: 2000, max: 2000 }
    ],
    right: [
      { id: 1, hp: 1800, max: 2000 },
      { id: 2, hp: 400, max: 400 },
      { id: 3, hp: 0, max: 400 },
      { id: 4, hp: 400, max: 400 },
      { id: 6, hp: 500, max: 500 },
      { id: 7, hp: 600, max: 600 }
    ]
  },
  mecha: {
    pilotId: 'HERO',
    pilotLevel: 'LV.6',
    linkState: 'LINKED',
    hpLabel: 'CORE HP',
    powerLabel: 'ENG PWR',
    boostLabel: 'BOOST',
    currentMaxLabel: 'CUR MAX',
    ammoLabel: 'AMMO',
    cooldownPrefix: '[CD: ',
    cooldownSuffix: 's]',
    statusEngaged: '[ENGAGED]',
    statusSafe: '[SAFE]',
    hp: 1650,
    boost: 400,
    energy: 2850,
    ammo: 12450,
    inCombat: false,
    combatTimer: 5.0,
    remoteHealReady: true,
    remoteAmmoReady: false
  },
  respawn: {
    isDead: false,
    countdown: 10,
    reviveCost: 500,
    scale: 0.8,
    minScale: 0.4,
    maxScale: 3,
    texts: {
      rebootTitle: 'SYSTEM REBOOT IN',
      ready: 'READY',
      ecoLabel: '当前金币(ECO)',
      normalReviveTitle: '普通复活',
      normalReviveReadyHint: '点击左键复活',
      normalReviveCoolingPrefix: '冷却中',
      buyReviveTitle: '立刻复活',
      noEcoTitle: '金币不足',
      buyTriggerHint: '右键触发',
      confirmBuyTitle: '确认购买？',
      confirmHint: '左键 确认',
      cancelHint: '右键 取消'
    }
  },
  centerHud: {
    ammo: 300,
    maxAmmo: 300,
    heat: 0,
    maxHeat: 100,
    isOverheated: false,
    attackBuffTime: 10,
    defenseBuffTime: 10,
    isShooting: false,
    overheatLabel: 'OVERHEAT'
  },
  boostBuffs: [
    { id: 1, type: 'attack', name: '攻击', time: 15, icon: 'sword', color: 'rose' },
    { id: 2, type: 'defense', name: '防御', time: 8, icon: 'shield', color: 'blue' },
    { id: 3, type: 'cooling', name: '冷却', time: 22, icon: 'snowflake', color: 'cyan' },
    { id: 4, type: 'power', name: '功率', time: 5, icon: 'zap', color: 'amber' },
    { id: 5, type: 'regen', name: '回血', time: 12, icon: 'heartPlus', color: 'emerald' },
    { id: 6, type: 'ammo', name: '弹量', time: 30, icon: 'crosshair', color: 'violet' },
    { id: 7, type: 'terrain', name: '跨越', time: 0, icon: 'mountain', color: 'stone' }
  ],
  miniMap: {
    title: '小地图',
    imageSrc: './map.png',
    imageAlt: 'RoboMaster Map',
    interactive: true,
    currentPlayerId: 'red-1',
    players: DEFAULT_MINI_MAP_PLAYERS
  },
  mapDebug: {
    updateIntervalMs: 33,
    miniMapTitle: '地图',
    uiSizing: {
      miniMapScale: 1,
      miniMapWidth: 560,
      miniMapHeight: 315,
      miniMapMarkerSize: 28,
      miniMapBottom: 20,
      miniMapRight: 20
    }
  }
};

export { DEFAULT_MINI_MAP_PLAYERS, DEFAULT_UI_STATE, deepMerge, normalizeIncomingData, toPercent };
