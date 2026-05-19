import {
  Activity,
  AlertTriangle,
  Battery,
  Box,
  Check,
  Cpu,
  Crosshair,
  Heart,
  Lock,
  Radio,
  ShieldAlert,
  Signal,
  Unlock,
  Video,
  Wifi,
  WifiOff,
  Zap,
} from 'lucide-react';
import { resolveBoostBuffs, resolveMechaState, resolveUiSizing, toPercent } from '../../state';
import StatusBuffList from '../buffs/StatusBuffList';

const ROBOT_ID_LABELS = {
  1: 'HERO',
  2: 'ENGINEER',
  3: 'INFANTRY',
  4: 'INFANTRY',
  5: 'INFANTRY',
  6: 'AERIAL',
  7: 'SENTRY',
  101: 'HERO',
  102: 'ENGINEER',
  103: 'INFANTRY',
  104: 'INFANTRY',
  105: 'INFANTRY',
  106: 'AERIAL',
  107: 'SENTRY',
};

function pickNumber(...values) {
  for (const value of values) {
    const numberValue = Number(value);
    if (Number.isFinite(numberValue)) return numberValue;
  }
  return 0;
}

function parseLevel(level, fallback = 1) {
  const direct = Number(level);
  if (Number.isFinite(direct)) return direct;

  const match = String(level ?? '').match(/\d+/);
  return match ? Number(match[0]) : fallback;
}

function translateRobotId(id, robotType) {
  const numericId = Number(id);
  const typeLabel = Number.isFinite(numericId) ? ROBOT_ID_LABELS[numericId] : null;
  if (typeLabel) return numericId >= 100 ? `${typeLabel} B${numericId - 100}` : `${typeLabel} R${numericId}`;

  const raw = String(id ?? robotType ?? 'UNKNOWN').trim();
  if (!raw) return 'UNKNOWN';

  return raw
    .replace('英雄', 'HERO')
    .replace('步兵', 'INFANTRY')
    .replace('工程', 'ENGINEER')
    .replace('哨兵', 'SENTRY')
    .replace('飞镖', 'DART')
    .replace('空中', 'AERIAL')
    .toUpperCase();
}

function normalizeModules(modules) {
  const source = modules ?? {};
  return {
    rfid: pickNumber(source.rfid, 1),
    uwb: pickNumber(source.uwb, 1),
    armor: pickNumber(source.armor, 1),
    videoTransmission: pickNumber(source.videoTransmission, source.video_transmission, 1),
    mainController: pickNumber(source.mainController, source.main_controller, 1),
    capacitor: pickNumber(source.capacitor, 1),
  };
}

export default function MechaHUD({ mecha, maxValues, uiSizing, modules, boostBuffs, isEngineer = false }) {
  const mergedMecha = resolveMechaState(mecha);
  const mergedSizing = resolveUiSizing(uiSizing);
  const mergedBoostBuffs = resolveBoostBuffs(boostBuffs).filter((buff) => {
    if (!isEngineer) return true;
    return buff?.type !== 'attack' && buff?.type !== 'cooling';
  });
  const mechaHudScale = mergedSizing.mechaHudScale > 0 ? mergedSizing.mechaHudScale : 1;

  const robotId = mergedMecha.robotId ?? mergedMecha.robot_id ?? mergedMecha.pilotId;
  const robotType = mergedMecha.robotType ?? mergedMecha.robot_type;
  const level = parseLevel(mergedMecha.level ?? mergedMecha.pilotLevel, 1);
  const levelUnlocked = Boolean(mergedMecha.isLevelEventTriggered ?? mergedMecha.is_level_event_triggered ?? level > 5);
  const maxAllowedLevel = levelUnlocked ? 10 : 5;
  const displayLevel = Math.min(level, maxAllowedLevel);

  const maxHealth = pickNumber(mergedMecha.maxHealth, mergedMecha.max_health, maxValues?.mechaHp, 1);
  const currentHealth = pickNumber(mergedMecha.currentHealth, mergedMecha.current_health, mergedMecha.hp);
  const maxChassisEnergy = pickNumber(
    mergedMecha.maxChassisEnergy,
    mergedMecha.max_chassis_energy,
    maxValues?.mechaChassisEnergy,
    maxValues?.mechaPower,
    1,
  );
  const maxBoost = pickNumber(mergedMecha.maxBufferEnergy, mergedMecha.max_buffer_energy, maxValues?.mechaBoost, 1);
  const currentBoost = pickNumber(mergedMecha.currentBufferEnergy, mergedMecha.current_buffer_energy, mergedMecha.boost);
  const maxPower = pickNumber(mergedMecha.maxPower, mergedMecha.max_power, maxValues?.mechaPower);
  const currentChassisEnergy = pickNumber(mergedMecha.currentChassisEnergy, mergedMecha.current_chassis_energy, mergedMecha.energy);
  const currentExperience = pickNumber(mergedMecha.currentExperience, mergedMecha.current_experience);
  const experienceForUpgrade = pickNumber(mergedMecha.experienceForUpgrade, mergedMecha.experience_for_upgrade, 1);
  const totalProjectilesFired = pickNumber(mergedMecha.totalProjectilesFired, mergedMecha.total_projectiles_fired);
  const lastProjectileFireRate = pickNumber(mergedMecha.lastProjectileFireRate, mergedMecha.last_projectile_fire_rate);
  const connectionState = pickNumber(mergedMecha.connectionState, mergedMecha.connection_state, mergedMecha.linkState === 'OFFLINE' ? 0 : 1);
  const fieldState = pickNumber(mergedMecha.fieldState, mergedMecha.field_state);
  const aliveState = pickNumber(mergedMecha.aliveState, mergedMecha.alive_state, currentHealth <= 0 ? 2 : 1);
  const isOutOfCombat = Boolean(mergedMecha.isOutOfCombat ?? mergedMecha.is_out_of_combat ?? !mergedMecha.inCombat);
  const canRemoteHeal = Boolean(mergedMecha.canRemoteHeal ?? mergedMecha.can_remote_heal ?? mergedMecha.remoteHealReady);
  const canRemoteAmmo = Boolean(mergedMecha.canRemoteAmmo ?? mergedMecha.can_remote_ammo ?? mergedMecha.remoteAmmoReady);

  const normalizedModules = normalizeModules(modules ?? mergedMecha.modules);
  const hpPercent = toPercent(currentHealth, maxHealth);
  const expPercent = toPercent(currentExperience, experienceForUpgrade);
  const isHpLow = hpPercent < 30;
  const displayId = translateRobotId(robotId, robotType);

  const moduleConfigs = [
    ...(!isEngineer ? [{ key: 'rfid', label: 'RFID', status: normalizedModules.rfid, icon: Radio }] : []),
    { key: 'uwb', label: 'UWB', status: normalizedModules.uwb, icon: Signal },
    { key: 'armor', label: 'ARMOR', status: normalizedModules.armor, icon: ShieldAlert },
    { key: 'videoTransmission', label: 'VIDEO', status: normalizedModules.videoTransmission, icon: Video },
    { key: 'mainController', label: 'MAIN', status: normalizedModules.mainController, icon: Cpu },
    { key: 'capacitor', label: 'CAP', status: normalizedModules.capacitor, icon: Zap },
  ];

  return (
    <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden font-mono select-none">
      <div
        className="absolute bottom-12 left-12 z-10 flex w-[432px] flex-col gap-1.5 drop-shadow-xl"
        style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom left' }}
      >
        <div className="flex flex-nowrap items-end justify-between gap-2 px-2 drop-shadow-[0_2px_2px_rgba(0,0,0,0.8)]">
          <div className="flex min-w-0 flex-1 flex-nowrap items-center gap-2">
            <span className="shrink-0 whitespace-nowrap text-[20px] font-black italic leading-none tracking-wide text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.6)]">
              {displayId}
            </span>
            {!isEngineer && (
              <div className="flex shrink-0 items-center gap-1 border-l-2 border-emerald-500 bg-emerald-900/60 px-2 py-0.5 skew-x-[-15deg] backdrop-blur-sm">
                <span className="flex items-center gap-0.5 whitespace-nowrap text-[13px] font-bold leading-none text-emerald-300 skew-x-[15deg]">
                  Lv.{displayLevel}
                  {levelUnlocked ? (
                    <Unlock size={10} className="text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]" />
                  ) : (
                    <Lock size={10} className="text-emerald-500/60" />
                  )}
                </span>
              </div>
            )}
          </div>

          <div className="flex shrink-0 flex-nowrap items-center gap-1.5 whitespace-nowrap text-[11px] font-bold leading-none tracking-wider">
            {connectionState === 0 ? (
              <span className="flex shrink-0 animate-pulse items-center gap-1 whitespace-nowrap border border-red-500 bg-red-500/20 px-1.5 py-0.5 text-red-400">
                <WifiOff size={12} /> OFFLINE
              </span>
            ) : (
              <span className="flex shrink-0 items-center gap-1 whitespace-nowrap text-emerald-500/60">
                <Wifi size={12} /> ONLINE
              </span>
            )}
            {fieldState === 1 && (
              <span className="shrink-0 whitespace-nowrap border border-amber-500 bg-amber-500/20 px-1.5 py-0.5 text-amber-400">
                NOT FIELD
              </span>
            )}
            {aliveState === 2 ? (
              <span className="shrink-0 animate-pulse whitespace-nowrap border border-red-500 bg-red-500/20 px-1.5 py-0.5 text-red-400">
                DEAD
              </span>
            ) : aliveState === 1 ? (
              <span className="shrink-0 whitespace-nowrap text-emerald-500/60">ALIVE</span>
            ) : (
              <span className="shrink-0 whitespace-nowrap text-slate-500">UNKNOWN</span>
            )}
          </div>
        </div>

        <div className="relative">
          <div className="mb-1 flex items-end justify-between px-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1.5 text-sm font-bold text-emerald-300">
              <Heart size={14} className={isHpLow ? 'animate-pulse text-red-400' : ''} />
              HP
            </span>
            <span className="text-[15px] font-black tracking-wider text-white">
              {Math.round(currentHealth)}
              <span className="text-sm text-slate-400"> / {maxHealth}</span>
            </span>
          </div>

          <div className="relative h-7 w-full overflow-hidden border-l-4 border-emerald-500 bg-slate-900/80 p-0.5 shadow-[0_4px_10px_rgba(0,0,0,0.5)] skew-x-[-15deg] backdrop-blur-md">
            <div
              className={`relative z-0 h-full transition-all duration-300 ease-out ${
                isHpLow ? 'bg-red-500 shadow-[0_0_15px_rgba(239,68,68,0.5)]' : 'bg-emerald-500 shadow-[0_0_15px_rgba(52,211,153,0.3)]'
              }`}
              style={{ width: `${hpPercent}%` }}
            />
            <div className="pointer-events-none absolute bottom-0 left-[25%] top-0 z-10 w-0.5 bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[50%] top-0 z-10 w-[3px] bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[75%] top-0 z-10 w-0.5 bg-slate-900/90" />
          </div>
        </div>

        <div className="mt-0.5 flex items-stretch gap-1.5 drop-shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
          {!isEngineer && (
            <div className="relative flex flex-[1.4] items-center overflow-hidden border-l-2 border-purple-500 bg-slate-900/80 px-2 py-1 skew-x-[-15deg] backdrop-blur-md">
              <div className="absolute bottom-0 left-0 top-0 bg-purple-500/30 transition-all duration-300" style={{ width: `${expPercent}%` }} />
              <div className="pointer-events-none absolute bottom-0 left-[25%] top-0 z-0 w-px bg-slate-900/80" />
              <div className="pointer-events-none absolute bottom-0 left-[50%] top-0 z-0 w-[2px] bg-slate-900/80" />
              <div className="pointer-events-none absolute bottom-0 left-[75%] top-0 z-0 w-px bg-slate-900/80" />

              <div className="relative z-10 flex w-full items-center justify-between text-[10px] skew-x-[15deg]">
                <span className="font-bold text-purple-300">EXP</span>
                <span className="font-bold text-white">{Math.round(currentExperience)}</span>
              </div>
            </div>
          )}

          <div className="flex flex-[1] items-center justify-between bg-slate-900/80 px-2 py-1 skew-x-[-15deg] backdrop-blur-md">
            <div className="flex w-full items-center justify-between skew-x-[15deg]">
              {!isOutOfCombat ? (
                <span className="flex animate-pulse items-center gap-0.5 text-[11px] font-black text-red-500 drop-shadow-[0_0_5px_rgba(239,68,68,0.8)]">
                  <AlertTriangle size={10} /> COMBAT
                </span>
              ) : (
                <span className="flex items-center gap-0.5 text-[11px] font-bold text-slate-400">
                  <Check size={10} /> SAFE
                </span>
              )}

              {!isEngineer && (
                <div className="flex gap-2">
                  <Heart size={12} className={canRemoteHeal ? 'text-emerald-400 drop-shadow-[0_0_3px_rgba(52,211,153,0.8)]' : 'text-slate-600'} />
                  <Box size={12} className={canRemoteAmmo ? 'text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]' : 'text-slate-600'} />
                </div>
              )}
            </div>
          </div>

          {!isEngineer && (
            <div className="flex w-[92px] items-center justify-center border-r-2 border-slate-500 bg-slate-900/80 px-2 py-1 skew-x-[-15deg] backdrop-blur-md">
              <div className="flex w-full items-center justify-between text-[10px] font-bold text-slate-300 skew-x-[15deg]">
                <span className="flex items-center gap-0.5" title="累计发弹量">
                  <Crosshair size={10} className="text-cyan-400" />
                  {Math.round(totalProjectilesFired)}
                </span>
                <span className="flex items-center gap-0.5" title="上一次射速">
                  <Activity size={10} className="text-amber-400" />
                  {lastProjectileFireRate.toFixed(1)}
                </span>
              </div>
            </div>
          )}
        </div>

        <div className="relative">
          <div className="mb-0.5 flex justify-between px-1 text-[11px] drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1 font-bold text-cyan-300">
              <Battery size={12} /> ENERGY
            </span>
            <span className="font-bold text-white">
              {Math.round(currentChassisEnergy)}
              <span className="text-[10px] text-slate-400"> / {maxChassisEnergy}</span>
            </span>
          </div>
          <div className="relative h-3.5 w-full overflow-hidden border-l-2 border-cyan-500 bg-slate-900/80 p-[1px] shadow-[0_2px_5px_rgba(0,0,0,0.5)] skew-x-[-15deg] backdrop-blur-md">
            <div
              className="relative z-0 h-full bg-cyan-400 shadow-[0_0_8px_rgba(34,211,238,0.4)] transition-all duration-300 ease-out"
              style={{ width: `${toPercent(currentChassisEnergy, maxChassisEnergy)}%` }}
            />
            <div className="pointer-events-none absolute bottom-0 left-[25%] top-0 z-10 w-px bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[50%] top-0 z-10 w-[2px] bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[75%] top-0 z-10 w-px bg-slate-900/90" />
          </div>
        </div>

        <div className="mt-0.5 flex w-full flex-nowrap items-center justify-start gap-1">
          {moduleConfigs.map((mod) => {
            const Icon = mod.icon;
            const isNormal = mod.status === 1;
            const isOffline = mod.status === 0;

            if (!isNormal) {
              return (
                <div
                  key={mod.key}
                  className="flex shrink-0 animate-pulse items-center border border-red-500/80 bg-red-900/40 px-1.5 py-0.5 skew-x-[-15deg] shadow-[0_0_10px_rgba(239,68,68,0.5)] backdrop-blur-md transition-all"
                >
                  <div className="flex items-center gap-0.5 whitespace-nowrap text-[9px] font-black tracking-tight text-red-400 skew-x-[15deg]">
                    <Icon size={10} />
                    {mod.label} {isOffline ? 'OFF' : 'ERR'}
                  </div>
                </div>
              );
            }

            return (
              <div
                key={mod.key}
                className="flex shrink-0 items-center border-l border-emerald-500/30 bg-slate-900/60 px-1.5 py-0.5 skew-x-[-15deg] transition-all"
              >
                <div className="flex items-center gap-0.5 whitespace-nowrap text-[9px] font-bold tracking-tight text-slate-400 skew-x-[15deg]">
                  {mod.label} <span className="text-emerald-500">OK</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="absolute bottom-12 left-1/2 z-10 -translate-x-1/2 drop-shadow-lg">
        <div
          className="flex w-[388px] flex-col items-center"
          style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom center' }}
        >
          <div className="relative w-full">
            <StatusBuffList
              buffs={mergedBoostBuffs}
              size="md"
              className="absolute bottom-full left-1/2 mb-5 w-max max-w-none -translate-x-1/2 px-2"
            />

            <div className="absolute -top-5 flex w-full justify-between px-2 text-xs font-bold text-cyan-300 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="flex items-center gap-1 drop-shadow-[0_0_2px_rgba(34,211,238,0.8)]">
                <Zap size={14} />
                BOOST
              </span>
              <span className="text-white drop-shadow-[0_0_2px_#fff]">
                {Math.round(currentBoost)}
                <span className="text-cyan-500/90"> / {maxBoost}</span>
              </span>
            </div>

            <div className="flex items-center gap-2">
              <div className="h-4 flex-1 filter drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)]">
                <div className="h-full w-full border border-cyan-500/60 bg-slate-900/60 p-0.5 skew-x-[-15deg] backdrop-blur-md">
                  <div
                    className="h-full bg-cyan-400 transition-all duration-100 ease-out"
                    style={{ width: `${toPercent(currentBoost, maxBoost)}%` }}
                  />
                </div>
              </div>

              <div className="flex h-6 items-center border-r-2 border-amber-500 bg-slate-900/75 px-2 skew-x-[-15deg] backdrop-blur-md">
                <div className="flex items-baseline gap-1 text-[10px] font-black tracking-wider skew-x-[15deg]">
                  <span className="text-amber-300">PWR</span>
                  <span className="text-white">{Math.round(maxPower)}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
