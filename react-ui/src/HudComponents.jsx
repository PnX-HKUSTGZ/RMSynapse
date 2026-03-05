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
  Shield,
  Snowflake,
  HeartPlus,
  Mountain
} from 'lucide-react';
import { DEFAULT_UI_STATE, deepMerge, toPercent } from './uiState';

const BUFF_ICON_MAP = {
  sword: Sword,
  shield: Shield,
  snowflake: Snowflake,
  zap: Zap,
  heartPlus: HeartPlus,
  crosshair: Crosshair,
  mountain: Mountain
};

const BUFF_COLOR_MAP = {
  rose: { border: 'border-rose-500/60', text: 'text-rose-400', glow: 'drop-shadow-[0_0_3px_rgba(244,63,94,0.8)]' },
  blue: { border: 'border-blue-500/60', text: 'text-blue-400', glow: 'drop-shadow-[0_0_3px_rgba(59,130,246,0.8)]' },
  cyan: { border: 'border-cyan-500/60', text: 'text-cyan-400', glow: 'drop-shadow-[0_0_3px_rgba(34,211,238,0.8)]' },
  amber: { border: 'border-amber-500/60', text: 'text-amber-400', glow: 'drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]' },
  emerald: { border: 'border-emerald-500/60', text: 'text-emerald-400', glow: 'drop-shadow-[0_0_3px_rgba(16,185,129,0.8)]' },
  violet: { border: 'border-violet-500/60', text: 'text-violet-400', glow: 'drop-shadow-[0_0_3px_rgba(139,92,246,0.8)]' },
  stone: { border: 'border-stone-500/60', text: 'text-stone-400', glow: 'drop-shadow-[0_0_3px_rgba(168,162,158,0.8)]' }
};

function MechaHUD({ mecha, maxValues, uiSizing, boostBuffs }) {
  const mergedMecha = deepMerge(DEFAULT_UI_STATE.mecha, mecha ?? {});
  const mergedSizing = { ...DEFAULT_UI_STATE.uiSizing, ...(uiSizing ?? {}) };
  const mergedBoostBuffs = Array.isArray(boostBuffs) ? boostBuffs : DEFAULT_UI_STATE.boostBuffs;
  const activeBoostBuffs = mergedBoostBuffs.filter((buff) => (Number(buff?.time) || 0) > 0);
  const mechaHudScale = mergedSizing.mechaHudScale > 0 ? mergedSizing.mechaHudScale : 1;
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
      <div
        className="absolute bottom-12 left-8 flex flex-col gap-2 w-[420px] z-10 drop-shadow-lg"
        style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom left' }}
      >
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

      <div className="absolute bottom-12 left-1/2 -translate-x-1/2 z-10 drop-shadow-lg">
        <div
          className="flex flex-col items-center w-[400px]"
          style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom center' }}
        >
          <div className="w-full relative">
            <div className="absolute bottom-full mb-5 w-full flex justify-center flex-wrap gap-1.5 px-2">
              {activeBoostBuffs.map((buff) => {
                const IconComponent = BUFF_ICON_MAP[buff.icon] ?? Snowflake;
                const colors = BUFF_COLOR_MAP[buff.color] ?? BUFF_COLOR_MAP.cyan;
                const timeLeft = Math.max(0, Math.ceil(Number(buff.time) || 0));

                return (
                  <div
                    key={buff.id}
                    className={`h-[22px] px-1.5 flex items-center justify-center bg-slate-900/80 border ${colors.border} skew-x-[-15deg] backdrop-blur-md shadow-sm ${colors.glow} transition-all duration-300`}
                  >
                    <div className="flex items-center gap-1 skew-x-[15deg]">
                      <IconComponent size={12} className={colors.text} />
                      <span className={`text-[10px] font-bold ${colors.text} leading-none pt-[1px] ${colors.glow} drop-shadow-[0_1px_1px_rgba(0,0,0,1)]`}>
                        {timeLeft}s
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>

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
    </div>
  );
}

function CenterCombatHUD({ centerHud, uiSizing }) {
  const hud = deepMerge(DEFAULT_UI_STATE.centerHud, centerHud ?? {});
  const mergedSizing = { ...DEFAULT_UI_STATE.uiSizing, ...(uiSizing ?? {}) };
  const centerHudScale = mergedSizing.centerHudScale > 0 ? mergedSizing.centerHudScale : 1;

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
      <div className="relative w-[400px] h-[300px] flex items-center justify-center" style={{ transform: `scale(${centerHudScale})`, transformOrigin: 'center center' }}>
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

function TopCoreLayout({
  roundLabel,
  labels,
  baseStateMeta,
  outpostStateMeta,
  maxValues,
  timeLeft,
  scores,
  bases,
  outposts,
  stats,
  leftRobots,
  rightRobots,
  uiSizing
}) {
  const mergedSizing = { ...DEFAULT_UI_STATE.uiSizing, ...(uiSizing ?? {}) };
  const topCoreScale = mergedSizing.topCoreScale > 0 ? mergedSizing.topCoreScale : 1;
  const time = {
    m: Math.floor(timeLeft / 60).toString().padStart(2, '0'),
    s: (timeLeft % 60).toString().padStart(2, '0')
  };

  return (
    <div
      className="relative z-10 w-full max-w-[1700px] flex flex-col items-center mt-2 pointer-events-auto"
      style={{ transform: `scale(${topCoreScale})`, transformOrigin: 'top center' }}
    >
      <div className="flex items-center justify-center w-full gap-[2px]">
        <div className="w-[120px] h-9 glass-panel border-t border-b border-red-500/40 skew-x-[-20deg] flex flex-col relative overflow-hidden shadow-lg transition-colors">
          <div className="absolute inset-0 flex justify-end opacity-50">
            <div className="bg-red-500 h-full transition-all duration-300" style={{ width: `${toPercent(outposts.left.hp, maxValues.outpostHp)}%` }} />
          </div>
          <div className="skew-x-[20deg] absolute inset-0 flex items-center justify-between pl-3 pr-5">
            <OutpostStateIcon state={outposts.left.state} team="red" states={outpostStateMeta} />
            <div className="flex flex-col items-end">
              <span className="text-[10px] text-white/80 font-bold leading-none mb-0.5 whitespace-nowrap">{labels.outpost}</span>
              <span className="font-orbitron text-xs font-bold leading-none text-red-200">{outposts.left.hp}</span>
            </div>
          </div>
        </div>

        <div className="w-[24vw] max-w-[400px] h-11 glass-panel skew-x-[-20deg] flex items-center relative overflow-hidden shadow-[0_0_15px_rgba(220,38,38,0.15)] border-t border-b border-red-500/50">
          <div className="absolute inset-0 scanline-bg opacity-40"></div>
          <div className="absolute bottom-0 right-0 bg-red-600/80 shadow-[0_0_10px_red] transition-all duration-300 h-full" style={{ width: `${toPercent(bases.left.hp, maxValues.baseHp)}%` }} />
          <div className="absolute top-0 right-0 bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300 h-[4px]" style={{ width: `${toPercent(bases.left.shield, maxValues.baseShield)}%` }} />

          <div className="skew-x-[20deg] absolute inset-0 w-full z-10 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
            <div className="absolute left-3 top-1/2 -translate-y-1/2 flex-shrink-0">
              <BaseStateIcon state={bases.left.state} team="red" states={baseStateMeta} />
            </div>
            <div className="absolute right-14 top-1/2 -translate-y-1/2 flex flex-col items-end justify-center pt-1">
              {bases.left.shield > 0 && <span className="text-green-400 text-[10px] font-orbitron font-bold drop-shadow-[0_0_5px_#22c55e] tracking-wide leading-none mb-0.5">{bases.left.shield}</span>}
              <span className="text-white text-2xl font-orbitron font-bold drop-shadow-[0_0_5px_red] tracking-wide leading-none">{bases.left.hp}</span>
            </div>
          </div>
        </div>

        <div className="w-16 h-11 ultra-glass border-t border-b border-white/20 skew-x-[-20deg] flex items-center justify-center z-10 shadow-lg ml-1">
          <div className="skew-x-[20deg] text-white font-orbitron text-3xl font-bold">{scores.left}</div>
        </div>

        <div className="relative mx-1 z-10 w-40 h-12 flex flex-col justify-end">
          <div className="absolute -top-4 left-1/2 -translate-x-1/2 w-24 h-5 ultra-glass clip-trapezoid-top flex items-center justify-center border-t border-cyan-400/50">
            <span className="text-[10px] text-cyan-200 font-bold tracking-wider drop-shadow-md">{roundLabel}</span>
          </div>
          <div className="w-full h-12 glass-panel border-t-2 border-b-2 border-cyan-400/60 clip-trapezoid flex items-center justify-center shadow-[0_5px_15px_rgba(34,211,238,0.15)] relative">
            <div className="flex items-center gap-1.5 font-orbitron text-[28px] font-bold text-white tracking-widest mt-1 drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]">
              <span>{time.m}</span>
              <div className="flex flex-col gap-1.5 pb-1">
                <div className="w-1.5 h-1.5 bg-cyan-400 shadow-[0_0_5px_cyan]"></div>
                <div className={`w-1.5 h-1.5 bg-cyan-400 shadow-[0_0_5px_cyan] transition-opacity ${timeLeft % 2 === 0 ? 'opacity-100' : 'opacity-40'}`}></div>
              </div>
              <span>{time.s}</span>
            </div>
          </div>
        </div>

        <div className="w-16 h-11 ultra-glass border-t border-b border-white/20 skew-x-[20deg] flex items-center justify-center z-10 shadow-lg mr-1">
          <div className="skew-x-[-20deg] text-white font-orbitron text-3xl font-bold">{scores.right}</div>
        </div>

        <div className="w-[24vw] max-w-[400px] h-11 glass-panel skew-x-[20deg] flex items-center relative overflow-hidden shadow-[0_0_15px_rgba(59,130,246,0.15)] border-t border-b border-blue-500/50">
          <div className="absolute inset-0 scanline-bg opacity-40"></div>
          <div className="absolute bottom-0 left-0 bg-blue-600/80 shadow-[0_0_10px_blue] transition-all duration-300 h-full" style={{ width: `${toPercent(bases.right.hp, maxValues.baseHp)}%` }} />
          <div className="absolute top-0 left-0 bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300 h-[4px]" style={{ width: `${toPercent(bases.right.shield, maxValues.baseShield)}%` }} />

          <div className="skew-x-[-20deg] absolute inset-0 w-full z-10 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
            <div className="absolute left-14 top-1/2 -translate-y-1/2 flex flex-col items-start justify-center pt-1">
              {bases.right.shield > 0 && <span className="text-green-400 text-[10px] font-orbitron font-bold drop-shadow-[0_0_5px_#22c55e] tracking-wide leading-none mb-0.5">{bases.right.shield}</span>}
              <span className="text-white text-2xl font-orbitron font-bold drop-shadow-[0_0_5px_blue] tracking-wide leading-none">{bases.right.hp}</span>
            </div>
            <div className="absolute right-3 top-1/2 -translate-y-1/2 flex-shrink-0">
              <BaseStateIcon state={bases.right.state} team="blue" states={baseStateMeta} />
            </div>
          </div>
        </div>

        <div className="w-[120px] h-9 glass-panel border-t border-b border-blue-500/40 skew-x-[20deg] flex flex-col relative overflow-hidden shadow-lg transition-colors">
          <div className="absolute inset-0 flex justify-start opacity-50">
            <div className="bg-blue-500 h-full transition-all duration-300" style={{ width: `${toPercent(outposts.right.hp, maxValues.outpostHp)}%` }} />
          </div>
          <div className="skew-x-[-20deg] absolute inset-0 flex items-center justify-between pl-5 pr-3">
            <div className="flex flex-col items-start">
              <span className="text-[10px] text-white/80 font-bold leading-none mb-0.5 whitespace-nowrap">{labels.outpost}</span>
              <span className="font-orbitron text-xs font-bold leading-none text-blue-200">{outposts.right.hp}</span>
            </div>
            <OutpostStateIcon state={outposts.right.state} team="blue" states={outpostStateMeta} />
          </div>
        </div>
      </div>

      <div className="flex justify-between items-start w-full px-[4%] mt-2 relative z-10">
        <div className="flex flex-1 justify-between mr-2">
          {leftRobots.map((robot) => {
            const hpPct = toPercent(robot.hp, robot.max);
            const isDead = robot.hp === 0;
            return (
              <div key={robot.id} className={`flex-1 h-[40px] mx-1 ultra-glass skew-x-[-20deg] border-b-[2px] ${isDead ? 'border-neutral-600' : 'border-red-500/80'} relative overflow-hidden shadow-md group`}>
                <div className={`absolute bottom-0 left-0 h-full ${isDead ? 'bg-neutral-600/30' : 'bg-red-500/30'} transition-all duration-300`} style={{ width: `${hpPct}%` }} />
                <div className="skew-x-[20deg] absolute inset-0">
                  <span className={`absolute top-0.5 left-2 font-orbitron font-black text-[13px] ${isDead ? 'text-neutral-500' : 'text-white'} drop-shadow-md`}>{robot.id}</span>
                  <span className={`absolute bottom-0 right-2.5 font-orbitron font-bold text-[8px] ${isDead ? 'text-neutral-500' : 'text-red-200'} drop-shadow-sm transition-all`}>{robot.hp}</span>
                </div>
              </div>
            );
          })}
        </div>

        <div className="flex justify-center mt-[1px] px-2">
          <div className="w-[85px] h-[30px] ultra-glass border-l border-r border-blue-400/40 flex items-center justify-center relative shadow-[0_0_10px_rgba(59,130,246,0.1)] hover:bg-blue-900/20 transition-colors">
            <div className="flex flex-col gap-[2px] w-full px-2">
              <div className="flex items-center justify-between w-full cursor-pointer hover:opacity-80 transition-opacity">
                <span className="text-[7px] text-blue-200 font-bold tracking-wider leading-none">{labels.eco}</span>
                <div className="font-orbitron font-bold flex items-baseline gap-[1px] leading-none">
                  <span className="text-[10px] text-blue-300 drop-shadow-[0_0_3px_rgba(96,165,250,0.8)]">{stats.right.eco}</span>
                  <span className="text-[7px] text-white/40">/</span>
                  <span className="text-[7px] text-blue-200/50">{stats.right.totalEco}</span>
                </div>
              </div>
              <LevelIndicator label={labels.tech} level={stats.right.tech} max={maxValues.techLevel} team="blue" />
              <LevelIndicator label={labels.radar} level={stats.right.radar} max={maxValues.radarLevel} team="blue" />
            </div>
          </div>
        </div>

        <div className="flex flex-1 justify-between ml-2">
          {rightRobots.map((robot) => {
            const hpPct = toPercent(robot.hp, robot.max);
            const isDead = robot.hp === 0;
            return (
              <div key={robot.id} className={`flex-1 h-[40px] mx-1 ultra-glass skew-x-[20deg] border-b-[2px] ${isDead ? 'border-neutral-600' : 'border-blue-500/80'} relative overflow-hidden shadow-md group`}>
                <div className={`absolute bottom-0 right-0 h-full ${isDead ? 'bg-neutral-600/30' : 'bg-blue-500/30'} transition-all duration-300`} style={{ width: `${hpPct}%` }} />
                <div className="skew-x-[-20deg] absolute inset-0">
                  <span className={`absolute bottom-0 left-2.5 font-orbitron font-bold text-[8px] ${isDead ? 'text-neutral-500' : 'text-blue-200'} drop-shadow-sm transition-all`}>{robot.hp}</span>
                  <span className={`absolute top-0.5 right-2 font-orbitron font-black text-[13px] ${isDead ? 'text-neutral-500' : 'text-white'} drop-shadow-md`}>{robot.id}</span>
                </div>
              </div>
            );
          })}
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

export { MechaHUD, CenterCombatHUD, TopCoreLayout, BaseStateIcon, OutpostStateIcon, LevelIndicator };
