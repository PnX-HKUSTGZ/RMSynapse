import {
  Activity,
  AlertTriangle,
  Battery,
  CheckCircle2,
  ChevronsRight,
  Crosshair,
  Heart,
  Wifi,
  Wrench,
  Zap,
} from 'lucide-react';
import { resolveBoostBuffs, resolveMechaState, resolveUiSizing, toPercent } from '../../state';
import StatusBuffList from '../buffs/StatusBuffList';

export default function MechaHUD({ mecha, maxValues, uiSizing, boostBuffs }) {
  const mergedMecha = resolveMechaState(mecha);
  const mergedSizing = resolveUiSizing(uiSizing);
  const mergedBoostBuffs = resolveBoostBuffs(boostBuffs);

  const mechaHudScale = mergedSizing.mechaHudScale > 0 ? mergedSizing.mechaHudScale : 1;
  const maxHp = maxValues?.mechaHp ?? 1;
  const maxBoost = maxValues?.mechaBoost ?? 1;
  const maxPower = maxValues?.mechaPower ?? 1;
  const safeMaxHp = maxHp > 0 ? maxHp : 1;
  const safeMaxBoost = maxBoost > 0 ? maxBoost : 1;
  const safeMaxPower = maxPower > 0 ? maxPower : 1;

  const hp = mergedMecha.hp ?? 0;
  const boost = mergedMecha.boost ?? 0;
  const energy = mergedMecha.energy ?? 0;
  const ammo = mergedMecha.ammo ?? 0;
  const inCombat = !!mergedMecha.inCombat;
  const combatTimer = mergedMecha.combatTimer ?? 0;
  const remoteHealReady = !!mergedMecha.remoteHealReady;
  const remoteAmmoReady = !!mergedMecha.remoteAmmoReady;

  const hpColor = hp / safeMaxHp > 0.3 ? 'bg-emerald-500' : 'bg-red-500';
  const boostColor = boost / safeMaxBoost > 0.2 ? 'bg-cyan-400' : 'bg-red-500';
  const energyColor = energy / safeMaxPower > 0.2 ? 'bg-amber-400' : 'bg-red-500';

  return (
    <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden font-mono select-none">
      <div
        className="absolute bottom-12 left-8 z-10 flex w-[420px] flex-col gap-2 drop-shadow-lg"
        style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom left' }}
      >
        <div className="flex items-end justify-between px-2 text-emerald-400 drop-shadow-[0_2px_2px_rgba(0,0,0,0.8)]">
          <div className="flex items-center gap-3">
            <span className="text-xl font-bold tracking-wider drop-shadow-[0_0_5px_rgba(52,211,153,0.8)]">
              {mergedMecha.pilotId}
            </span>
            <div className="flex items-center gap-1 border border-emerald-500/30 bg-emerald-900/60 px-2 py-0.5 skew-x-[-15deg] backdrop-blur-sm">
              <span className="text-xs font-bold text-emerald-300 skew-x-[15deg]">
                {mergedMecha.pilotLevel}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 text-[10px] font-bold tracking-widest text-emerald-300/80">
            <Wifi size={12} className="animate-pulse" />
            <span>{mergedMecha.linkState}</span>
          </div>
        </div>

        <div className="relative">
          <div className="mb-0.5 flex justify-between px-1 text-xs text-emerald-200 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1">
              <Heart size={12} />
              {mergedMecha.hpLabel}
            </span>
            <span className="text-sm font-bold text-white">
              {Math.round(hp)}
              <span className="text-xs text-emerald-500/90"> / {maxHp}</span>
            </span>
          </div>
          <div className="h-5 w-full border-l-4 border-emerald-500 bg-slate-900/60 p-0.5 shadow-[0_4px_10px_rgba(0,0,0,0.5)] skew-x-[-10deg] backdrop-blur-md">
            <div
              className={`h-full ${hpColor} shadow-[0_0_10px_rgba(52,211,153,0.3)] transition-all duration-300 ease-out`}
              style={{ width: `${toPercent(hp, maxHp)}%` }}
            />
          </div>
        </div>

        <div className="flex items-end gap-3">
          <div className="relative flex-1">
            <div className="mb-0.5 flex justify-between px-1 text-[10px] text-amber-200/90 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="flex items-center gap-1">
                <Zap size={10} />
                {mergedMecha.powerLabel}
              </span>
              <span className="font-bold">
                {Math.round(energy)}
                <span className="text-[9px] text-amber-400/70"> kW</span>
              </span>
            </div>
            <div className="h-2 w-full border-l-2 border-amber-500 bg-slate-900/60 p-[1px] shadow-[0_2px_5px_rgba(0,0,0,0.5)] skew-x-[-10deg] backdrop-blur-md">
              <div
                className={`h-full ${energyColor} transition-all duration-100 ease-linear`}
                style={{ width: `${toPercent(energy, maxPower)}%` }}
              />
            </div>
          </div>

          <div className="border border-slate-500/50 bg-slate-900/60 px-2 py-0.5 shadow-[0_2px_5px_rgba(0,0,0,0.5)] skew-x-[-10deg] backdrop-blur-md">
            <div className="flex items-baseline gap-1 skew-x-[10deg] drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="text-[9px] text-slate-300">{mergedMecha.currentMaxLabel}</span>
              <span className="text-xs font-bold text-amber-400">{maxPower}</span>
            </div>
          </div>
        </div>

        <div className="mt-1 flex gap-2 drop-shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
          <div className="flex flex-1 items-center justify-between border-l-2 border-slate-500 bg-slate-900/60 px-3 py-1 skew-x-[-10deg] backdrop-blur-md">
            <div className="flex items-center gap-2 skew-x-[10deg]">
              {inCombat ? (
                <span className="flex animate-pulse items-center gap-1 text-[11px] font-bold text-red-500 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <AlertTriangle size={12} />
                  {mergedMecha.statusEngaged}
                </span>
              ) : combatTimer > 0 ? (
                <span className="flex items-center gap-1 text-[11px] font-bold text-amber-400 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <Activity size={12} className="animate-spin-slow" />
                  {mergedMecha.cooldownPrefix}
                  {combatTimer.toFixed(1)}
                  {mergedMecha.cooldownSuffix}
                </span>
              ) : (
                <span className="flex items-center gap-1 text-[11px] font-bold text-cyan-400 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <CheckCircle2 size={12} />
                  {mergedMecha.statusSafe}
                </span>
              )}
            </div>

            <div className="flex items-center gap-1 text-[11px] font-bold tracking-wider text-slate-200 skew-x-[10deg] drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <Crosshair size={12} />
              {mergedMecha.ammoLabel}: {ammo.toLocaleString()}
            </div>
          </div>

          <div className="flex items-center border-r-2 border-slate-500 bg-slate-900/60 px-3 py-1 skew-x-[-10deg] backdrop-blur-md">
            <div className="flex gap-3 skew-x-[10deg]">
              <Wrench size={14} className={remoteHealReady ? 'text-emerald-400 drop-shadow-[0_0_3px_rgba(52,211,153,0.8)]' : 'text-slate-600'} />
              <Battery size={14} className={remoteAmmoReady ? 'text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]' : 'text-slate-600'} />
            </div>
          </div>
        </div>
      </div>

      <div className="absolute bottom-12 left-1/2 z-10 -translate-x-1/2 drop-shadow-lg">
        <div
          className="flex w-[400px] flex-col items-center"
          style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom center' }}
        >
          <div className="relative w-full">
            <StatusBuffList
              buffs={mergedBoostBuffs}
              size="lg"
              className="absolute bottom-full left-1/2 mb-5 w-max max-w-none -translate-x-1/2 px-2"
            />

            <div className="absolute -top-5 flex w-full justify-between px-2 text-xs font-bold text-cyan-300 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="flex items-center gap-1 drop-shadow-[0_0_2px_rgba(34,211,238,0.8)]">
                <ChevronsRight size={14} />
                {mergedMecha.boostLabel}
              </span>
              <span className="text-white drop-shadow-[0_0_2px_#fff]">
                {Math.round(boost)}
                <span className="text-cyan-500/90"> / {maxBoost}</span>
              </span>
            </div>

            <div className="h-4 w-full filter drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)]">
              <div className="h-full w-full border border-cyan-500/60 bg-slate-900/60 p-0.5 skew-x-[-15deg] backdrop-blur-md">
                <div
                  className={`h-full ${boostColor} transition-all duration-100 ease-out`}
                  style={{ width: `${toPercent(boost, maxBoost)}%` }}
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
