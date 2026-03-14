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

function normalizeIncomingData(data) {
  if (!isPlainObject(data)) return {};
  const normalized = { ...data };
  if (normalized.blackBg != null && normalized.forceBlackBg == null) {
    normalized.forceBlackBg = normalized.blackBg;
  }
  delete normalized.blackBg;
  return normalized;
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
  forceBlackBg: false,
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
    eco: 0,
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
    isDead: true,
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
