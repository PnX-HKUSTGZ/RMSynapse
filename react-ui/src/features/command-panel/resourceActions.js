export const DEFAULT_RESOURCE_QUANTITIES = {
  qty17: 10,
  qty42: 5,
};

export function toNumber(value, fallback = 0) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

export function toInt(value, fallback = 0) {
  return Math.max(0, Math.trunc(toNumber(value, fallback)));
}

export function floorToStep(value, step) {
  const safeStep = Math.max(1, step);
  return Math.max(0, Math.floor(toInt(value) / safeStep) * safeStep);
}

export function ceilByUnit(value, unit) {
  const safeUnit = Math.max(1, unit);
  return Math.ceil(Math.max(0, value) / safeUnit);
}

export function parseRobotLevel(mecha) {
  const direct = Number(mecha?.level);
  if (Number.isFinite(direct)) return Math.max(0, Math.trunc(direct));
  const match = String(mecha?.pilotLevel ?? '').match(/\d+/);
  return match ? Number(match[0]) : 0;
}

export function isRobotDead(mecha, respawn) {
  const aliveState = toInt(mecha?.aliveState ?? mecha?.alive_state, 1);
  const health = toNumber(mecha?.currentHealth ?? mecha?.current_health ?? mecha?.hp, 1);
  return Boolean(respawn?.isDead) || aliveState === 2 || health <= 0;
}

export function formatCost(cost) {
  return `${Math.max(0, Math.trunc(cost))} 金币`;
}

export function buildCommonCommand(command, param = 0) {
  return { type: 'commonCommand', command, param };
}

export function buildResourceActionState({
  activeRole,
  stats,
  mecha,
  respawn,
  timeLeft,
  quantities = DEFAULT_RESOURCE_QUANTITIES,
}) {
  const eco = toInt(stats?.eco);
  const isHero = activeRole === 'hero';
  const normalized17 = floorToStep(quantities?.qty17 ?? DEFAULT_RESOURCE_QUANTITIES.qty17, 10);
  const normalized42 = floorToStep(quantities?.qty42 ?? DEFAULT_RESOURCE_QUANTITIES.qty42, 5);
  const activeQty = isHero ? normalized42 : normalized17;
  const remoteMin = isHero ? 10 : 100;
  const directCost = isHero ? activeQty * 10 : activeQty;
  const remoteCost = ceilByUnit(activeQty, remoteMin) * 150;
  const dead = isRobotDead(mecha, respawn);
  const elapsedSec = Math.max(0, 420 - toNumber(timeLeft, 420));
  const healCost = 50 + Math.ceil((elapsedSec / 60) * 20);
  const reviveCost = Math.ceil(elapsedSec / 60) * 80 + parseRobotLevel(mecha) * 20;
  const supported = activeRole === 'hero' || activeRole === 'infantry';
  const directCommand = isHero ? 'exchange42mm' : 'exchange17mm';

  return {
    supported,
    isHero,
    eco,
    normalized17,
    normalized42,
    activeQty,
    remoteMin,
    directCost,
    remoteCost,
    dead,
    healCost,
    reviveCost,
    canDirectAmmo: supported && activeQty > 0 && directCost <= eco,
    canRemoteAmmo: supported && activeQty >= remoteMin && remoteCost <= eco,
    canHeal: supported && !dead && healCost <= eco,
    canRevive: supported && dead && reviveCost <= eco,
    directAmmoOperation: buildCommonCommand(directCommand, activeQty),
    remoteAmmoOperation: buildCommonCommand('remoteBuyAmmo', activeQty),
    healOperation: buildCommonCommand('remoteBuyHp'),
    reviveOperation: buildCommonCommand('buyRespawn', reviveCost),
  };
}
