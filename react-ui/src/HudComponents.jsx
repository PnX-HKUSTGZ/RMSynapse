import {
  Heart,
  Zap,
  Crosshair,
  Wifi,
  Activity,
  Battery,
  Wrench,
  AlertTriangle,
  CheckCircle2,
  ChevronsRight,
  Sword,
  Shield
} from 'lucide-react';
import { DEFAULT_UI_STATE, deepMerge, toPercent } from './uiState';

function MechaHUD({ mecha, maxValues }) {
  const mergedMecha = deepMerge(DEFAULT_UI_STATE.mecha, mecha ?? {});
  const maxHp = maxValues?.mechaHp ?? DEFAULT_UI_STATE.maxValues.mechaHp;
  const maxBoost = maxValues?.mechaBoost ?? DEFAULT_UI_STATE.maxValues.mechaBoost;
  const maxPower = maxValues?.mechaPower ?? DEFAULT_UI_STATE.maxValues.mechaPower;
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
    <div className="absolute inset-0 pointer-events-none overflow-hidden font-mono select-none z-0">
      <div className="absolute bottom-12 left-8 flex flex-col gap-2 w-[420px] z-10 drop-shadow-lg">
        <div className="flex items-end justify-between px-2 text-emerald-400 drop-shadow-[0_2px_2px_rgba(0,0,0,0.8)]">
          <div className="flex items-center gap-3">
            <span className="text-xl font-bold tracking-wider drop-shadow-[0_0_5px_rgba(52,211,153,0.8)]">
              {mergedMecha.pilotId}
            </span>
            <div className="flex items-center gap-1 bg-emerald-900/60 px-2 py-0.5 border border-emerald-500/30 skew-x-[-15deg] backdrop-blur-sm">
              <span className="skew-x-[15deg] text-xs font-bold text-emerald-300">{mergedMecha.pilotLevel}</span>
            </div>
          </div>
          <div className="flex items-center gap-2 text-[10px] font-bold tracking-widest text-emerald-300/80">
            <Wifi size={12} className="animate-pulse" />
            <span>{mergedMecha.linkState}</span>
          </div>
        </div>

        <div className="relative">
          <div className="flex justify-between text-xs text-emerald-200 mb-0.5 px-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1"><Heart size={12}/> {mergedMecha.hpLabel}</span>
            <span className="font-bold text-white text-sm">
              {Math.round(hp)} <span className="text-emerald-500/90 text-xs">/ {maxHp}</span>
            </span>
          </div>
          <div className="h-5 w-full bg-slate-900/60 border-l-4 border-emerald-500 p-0.5 skew-x-[-10deg] backdrop-blur-md shadow-[0_4px_10px_rgba(0,0,0,0.5)]">
            <div
              className={`h-full ${hpColor} transition-all duration-300 ease-out shadow-[0_0_10px_rgba(52,211,153,0.3)]`}
              style={{ width: `${toPercent(hp, maxHp)}%` }}
            />
          </div>
        </div>

        <div className="flex gap-3 items-end">
          <div className="flex-1 relative">
            <div className="flex justify-between text-[10px] text-amber-200/90 mb-0.5 px-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="flex items-center gap-1"><Zap size={10}/> {mergedMecha.powerLabel}</span>
              <span className="font-bold">{Math.round(energy)} <span className="text-[9px] text-amber-400/70">kW</span></span>
            </div>
            <div className="h-2 w-full bg-slate-900/60 border-l-2 border-amber-500 p-[1px] skew-x-[-10deg] backdrop-blur-md shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
              <div
                className={`h-full ${energyColor} transition-all duration-100 ease-linear`}
                style={{ width: `${toPercent(energy, maxPower)}%` }}
              />
            </div>
          </div>
          <div className="bg-slate-900/60 border border-slate-500/50 px-2 py-0.5 skew-x-[-10deg] backdrop-blur-md shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
            <div className="skew-x-[10deg] flex items-baseline gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="text-[9px] text-slate-300">{mergedMecha.currentMaxLabel}</span>
              <span className="text-amber-400 font-bold text-xs">{maxPower}</span>
            </div>
          </div>
        </div>

        <div className="flex gap-2 mt-1 drop-shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
          <div className="flex-1 bg-slate-900/60 border-l-2 border-slate-500 px-3 py-1 flex items-center justify-between skew-x-[-10deg] backdrop-blur-md">
            <div className="skew-x-[10deg] flex items-center gap-2">
              {inCombat ? (
                <span className="text-[11px] text-red-500 font-bold animate-pulse flex items-center gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <AlertTriangle size={12}/> {mergedMecha.statusEngaged}
                </span>
              ) : combatTimer > 0 ? (
                <span className="text-[11px] text-amber-400 font-bold flex items-center gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <Activity size={12} className="animate-spin-slow"/> {mergedMecha.cooldownPrefix}{combatTimer.toFixed(1)}{mergedMecha.cooldownSuffix}
                </span>
              ) : (
                <span className="text-[11px] text-cyan-400 font-bold flex items-center gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <CheckCircle2 size={12}/> {mergedMecha.statusSafe}
                </span>
              )}
            </div>
            <div className="skew-x-[10deg] flex items-center gap-1 text-[11px] text-slate-200 font-bold tracking-wider drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <Crosshair size={12}/> {mergedMecha.ammoLabel}: {ammo.toLocaleString()}
            </div>
          </div>
          <div className="bg-slate-900/60 border-r-2 border-slate-500 px-3 py-1 flex items-center skew-x-[-10deg] backdrop-blur-md">
            <div className="skew-x-[10deg] flex gap-3">
              <Wrench size={14} className={remoteHealReady ? 'text-emerald-400 drop-shadow-[0_0_3px_rgba(52,211,153,0.8)]' : 'text-slate-600'} />
              <Battery size={14} className={remoteAmmoReady ? 'text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]' : 'text-slate-600'} />
            </div>
          </div>
        </div>
      </div>

      <div className="absolute bottom-12 left-1/2 -translate-x-1/2 flex flex-col items-center w-[400px] z-10 drop-shadow-lg">
        <div className="w-full relative">
          <div className="absolute -top-5 w-full flex justify-between px-2 text-xs font-bold text-cyan-300 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1 drop-shadow-[0_0_2px_rgba(34,211,238,0.8)]">
              <ChevronsRight size={14}/> {mergedMecha.boostLabel}
            </span>
            <span className="text-white drop-shadow-[0_0_2px_#fff]">
              {Math.round(boost)} <span className="text-cyan-500/90">/ {maxBoost}</span>
            </span>
          </div>

          <div className="w-full h-4 filter drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)]">
            <div className="w-full h-full bg-slate-900/60 border border-cyan-500/60 p-0.5 skew-x-[-15deg] backdrop-blur-md">
              <div
                className={`h-full ${boostColor} transition-all duration-100 ease-out`}
                style={{ width: `${toPercent(boost, maxBoost)}%` }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function CenterCombatHUD({ centerHud }) {
  const hud = deepMerge(DEFAULT_UI_STATE.centerHud, centerHud ?? {});

  const ammo = hud.ammo ?? 0;
  const maxAmmo = hud.maxAmmo > 0 ? hud.maxAmmo : 1;
  const heat = Math.max(0, Math.min(hud.heat ?? 0, hud.maxHeat ?? 100));
  const maxHeat = hud.maxHeat > 0 ? hud.maxHeat : 100;
  const isOverheated = !!hud.isOverheated;
  const attackBuffTime = hud.attackBuffTime ?? 0;
  const defenseBuffTime = hud.defenseBuffTime ?? 0;
  const isShooting = !!hud.isShooting;
  const isLowAmmo = ammo <= 5;

  const getHeatColor = () => {
    if (isOverheated) return '#ef4444';
    if (heat > 75) return '#f97316';
    if (heat > 50) return '#facc15';
    return '#22d3ee';
  };

  const radius = 30;
  const circumference = 2 * Math.PI * radius;
  const heatOffset = circumference - (heat / maxHeat) * circumference;

  return (
    <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-20 pointer-events-none">
      <div className="relative w-[400px] h-[300px] flex items-center justify-center">
        <div className="absolute z-10 flex items-center justify-center">
          <div className="absolute flex items-center justify-center pointer-events-none">
            <svg width="80" height="80" className="transform -rotate-90 transition-all duration-75" style={{ opacity: isShooting ? 0.6 : 1 }}>
              <circle cx="40" cy="40" r={radius} fill="none" stroke="rgba(30, 41, 59, 0.5)" strokeWidth="3" />
              <circle
                cx="40"
                cy="40"
                r={radius}
                fill="none"
                stroke={getHeatColor()}
                strokeWidth="3"
                strokeDasharray={circumference}
                strokeDashoffset={heatOffset}
                strokeLinecap="round"
                className="transition-all duration-75 ease-linear"
                style={{ filter: `drop-shadow(0 0 4px ${getHeatColor()})` }}
              />
            </svg>
            {isOverheated && (
              <div className="absolute top-[-35px] text-[10px] text-red-500 font-bold animate-pulse tracking-widest drop-shadow-[0_0_5px_red]">
                {hud.overheatLabel}
              </div>
            )}
          </div>

          <div className={`relative flex items-center justify-center transition-all duration-75 ${isShooting ? 'scale-125 opacity-70' : 'scale-100 opacity-100'}`}>
            <div className="w-1 h-1 bg-cyan-400 rounded-full shadow-[0_0_5px_#22d3ee]"></div>
            <div className={`absolute top-[-10px] w-[2px] h-[6px] bg-cyan-400 ${isShooting ? '-translate-y-1' : ''} transition-transform`}></div>
            <div className={`absolute bottom-[-10px] w-[2px] h-[6px] bg-cyan-400 ${isShooting ? 'translate-y-1' : ''} transition-transform`}></div>
            <div className={`absolute left-[-10px] w-[6px] h-[2px] bg-cyan-400 ${isShooting ? '-translate-x-1' : ''} transition-transform`}></div>
            <div className={`absolute right-[-10px] w-[6px] h-[2px] bg-cyan-400 ${isShooting ? 'translate-x-1' : ''} transition-transform`}></div>
          </div>
        </div>

        <div className="absolute right-[110px] top-1/2 -translate-y-1/2 flex items-center">
          <span className={`text-2xl font-black italic tracking-tighter ${isLowAmmo ? 'text-red-500 animate-pulse drop-shadow-[0_0_8px_rgba(239,68,68,0.8)]' : 'text-cyan-400 drop-shadow-[0_0_8px_rgba(34,211,238,0.5)]'}`}>
            {Math.max(0, Math.min(ammo, maxAmmo)).toString().padStart(2, '0')}
          </span>
        </div>

        <div className="absolute left-[130px] top-1/2 -translate-y-1/2 flex flex-col gap-2">
          {attackBuffTime > 0 && (
            <div
              className="flex items-center justify-center bg-slate-900/60 p-1.5 rounded border border-orange-500/30 backdrop-blur-sm transition-opacity duration-75"
              style={{ opacity: attackBuffTime <= 5 && Math.floor(attackBuffTime * 4) % 2 === 0 ? 0.2 : 1 }}
            >
              <Sword size={18} className="text-orange-400 drop-shadow-[0_0_5px_rgba(249,115,22,0.8)]" />
            </div>
          )}

          {defenseBuffTime > 0 && (
            <div
              className="flex items-center justify-center bg-slate-900/60 p-1.5 rounded border border-blue-500/30 backdrop-blur-sm transition-opacity duration-75"
              style={{ opacity: defenseBuffTime <= 5 && Math.floor(defenseBuffTime * 4) % 2 === 0 ? 0.2 : 1 }}
            >
              <Shield size={18} className="text-blue-400 drop-shadow-[0_0_5px_rgba(59,130,246,0.8)]" />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function BaseStateIcon({ state, team, states }) {
  const isRed = team === 'red';
  const color = isRed ? 'text-red-300 border-red-500/30 bg-red-950/40' : 'text-blue-300 border-blue-500/30 bg-blue-950/40';

  const stateMeta = states?.[state] ?? DEFAULT_UI_STATE.baseStateMeta[state] ?? { icon: '❓', label: '未知' };
  const icon = stateMeta.icon;
  const label = stateMeta.label;

  return (
    <div className={`flex flex-col items-center justify-center gap-[2px] px-1.5 py-[2px] border rounded-sm ${color} backdrop-blur-sm whitespace-nowrap`}>
      <span className="text-[11px] drop-shadow-md leading-none">{icon}</span>
      <span className="text-[7px] font-bold tracking-widest leading-none">{label}</span>
    </div>
  );
}

function OutpostStateIcon({ state, team, states }) {
  const isRed = team === 'red';
  const color = isRed ? 'text-red-300 bg-red-950/40 border-red-500/30' : 'text-blue-300 bg-blue-950/40 border-blue-500/30';

  const stateMeta = states?.[state] ?? states?.default ?? DEFAULT_UI_STATE.outpostStateMeta[state] ?? DEFAULT_UI_STATE.outpostStateMeta.default;
  const icon = stateMeta.icon;
  const spin = !!stateMeta.spin;

  return (
    <div className={`w-6 h-6 rounded flex items-center justify-center text-xs border backdrop-blur-sm ${color}`}>
      <div className={spin ? 'animate-spin' : ''}>{icon}</div>
    </div>
  );
}

function LevelIndicator({ label, level, max, team }) {
  const isRed = team === 'red';
  const color = isRed ? 'bg-red-400 shadow-[0_0_3px_red]' : 'bg-blue-400 shadow-[0_0_3px_blue]';
  const emptyColor = 'bg-white/10';

  return (
    <div className="flex items-center justify-between w-full">
      <span className={`text-[7px] font-bold tracking-wider leading-none ${isRed ? 'text-red-200' : 'text-blue-200'}`}>{label}</span>
      <div className="flex gap-[1.5px]">
        {Array.from({ length: max }).map((_, i) => (
          <div
            key={i}
            className={`w-[6px] h-[5px] border-[0.5px] border-black/50 transition-colors duration-300 ${i < level ? color : emptyColor}`}
          />
        ))}
      </div>
    </div>
  );
}

export { MechaHUD, CenterCombatHUD, BaseStateIcon, OutpostStateIcon, LevelIndicator };
