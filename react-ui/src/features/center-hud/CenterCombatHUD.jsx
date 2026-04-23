import { Shield, Sword } from 'lucide-react';
import { resolveCenterHudState, resolveUiSizing } from '../../state';

export default function CenterCombatHUD({ centerHud, uiSizing }) {
  const hud = resolveCenterHudState(centerHud);
  const mergedSizing = resolveUiSizing(uiSizing);
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
    <div className="pointer-events-none absolute left-1/2 top-1/2 z-20 -translate-x-1/2 -translate-y-1/2">
      <div
        className="relative flex h-[300px] w-[400px] items-center justify-center"
        style={{ transform: `scale(${centerHudScale})`, transformOrigin: 'center center' }}
      >
        <div className="absolute z-10 flex items-center justify-center">
          <div className="pointer-events-none absolute flex items-center justify-center">
            <svg
              width="80"
              height="80"
              className="transform -rotate-90 transition-all duration-75"
              style={{ opacity: isShooting ? 0.6 : 1 }}
            >
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
              <div className="absolute top-[-35px] animate-pulse text-[10px] font-bold tracking-widest text-red-500 drop-shadow-[0_0_5px_red]">
                {hud.overheatLabel}
              </div>
            )}
          </div>

          <div className={`relative flex items-center justify-center transition-all duration-75 ${isShooting ? 'scale-125 opacity-70' : 'scale-100 opacity-100'}`}>
            <div className="h-1 w-1 rounded-full bg-cyan-400 shadow-[0_0_5px_#22d3ee]" />
            <div className={`absolute top-[-10px] h-[6px] w-[2px] bg-cyan-400 ${isShooting ? '-translate-y-1' : ''} transition-transform`} />
            <div className={`absolute bottom-[-10px] h-[6px] w-[2px] bg-cyan-400 ${isShooting ? 'translate-y-1' : ''} transition-transform`} />
            <div className={`absolute left-[-10px] h-[2px] w-[6px] bg-cyan-400 ${isShooting ? '-translate-x-1' : ''} transition-transform`} />
            <div className={`absolute right-[-10px] h-[2px] w-[6px] bg-cyan-400 ${isShooting ? 'translate-x-1' : ''} transition-transform`} />
          </div>
        </div>

        <div className="absolute right-[110px] top-1/2 flex -translate-y-1/2 items-center">
          <span className={`text-2xl font-black italic tracking-tighter ${isLowAmmo ? 'animate-pulse text-red-500 drop-shadow-[0_0_8px_rgba(239,68,68,0.8)]' : 'text-cyan-400 drop-shadow-[0_0_8px_rgba(34,211,238,0.5)]'}`}>
            {Math.max(0, Math.min(ammo, maxAmmo)).toString().padStart(2, '0')}
          </span>
        </div>

        <div className="absolute left-[130px] top-1/2 flex -translate-y-1/2 flex-col gap-2">
          {attackBuffTime > 0 && (
            <div
              className="flex items-center justify-center rounded border border-orange-500/30 bg-slate-900/60 p-1.5 backdrop-blur-sm transition-opacity duration-75"
              style={{ opacity: attackBuffTime <= 5 && Math.floor(attackBuffTime * 4) % 2 === 0 ? 0.2 : 1 }}
            >
              <Sword size={18} className="text-orange-400 drop-shadow-[0_0_5px_rgba(249,115,22,0.8)]" />
            </div>
          )}

          {defenseBuffTime > 0 && (
            <div
              className="flex items-center justify-center rounded border border-blue-500/30 bg-slate-900/60 p-1.5 backdrop-blur-sm transition-opacity duration-75"
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
