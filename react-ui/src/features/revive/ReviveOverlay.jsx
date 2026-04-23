import { useState } from 'react';
import { clamp, DEFAULT_UI_STATE } from '../../state';

function normalizeCountdown(value) {
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) return 0;
  return Math.max(0, Math.floor(seconds));
}

export default function ReviveOverlay({
  isDead,
  countdown,
  eco,
  reviveCost,
  scale = 1,
  minScale,
  maxScale,
  texts,
  onNormalRevive,
  onBuyRevive,
}) {
  const respawnDefaults = DEFAULT_UI_STATE.respawn ?? {};
  const defaultTexts = respawnDefaults.texts ?? {};
  const mergedTexts = { ...defaultTexts, ...(texts ?? {}) };
  const [isConfirmingBuy, setIsConfirmingBuy] = useState(false);

  const safeCountdown = normalizeCountdown(countdown);
  const safeEco = Number.isFinite(Number(eco)) ? Number(eco) : 0;
  const safeDefaultReviveCost = Number(respawnDefaults.reviveCost) > 0
    ? Number(respawnDefaults.reviveCost)
    : 500;
  const safeReviveCost = Number.isFinite(Number(reviveCost)) && Number(reviveCost) > 0
    ? Number(reviveCost)
    : safeDefaultReviveCost;
  const safeMinScale = Number(minScale) > 0
    ? Number(minScale)
    : (Number(respawnDefaults.minScale) > 0 ? Number(respawnDefaults.minScale) : 0.4);
  const safeMaxScale = Number(maxScale) > safeMinScale
    ? Number(maxScale)
    : (Number(respawnDefaults.maxScale) > safeMinScale ? Number(respawnDefaults.maxScale) : 3);
  const safeScale = clamp(Number(scale) || 1, safeMinScale, safeMaxScale);
  const canNormalRevive = safeCountdown === 0;
  const canBuyRevive = safeEco >= safeReviveCost;

  const handleBuyReviveContextMenu = (event) => {
    event.preventDefault();
    if (!canBuyRevive) return;
    setIsConfirmingBuy((prev) => !prev);
  };

  const handleBuyReviveClick = () => {
    if (!isConfirmingBuy || !canBuyRevive) return;
    onBuyRevive?.({ cost: safeReviveCost });
    setIsConfirmingBuy(false);
  };

  const handleNormalReviveClick = () => {
    if (!canNormalRevive) return;
    onNormalRevive?.();
  };

  if (!isDead) return null;

  return (
    <div
      className="absolute bottom-[15%] left-1/2 z-40 flex -translate-x-1/2 flex-col items-center rounded-2xl border border-gray-700/80 bg-gray-900/90 p-8 shadow-[0_0_40px_rgba(0,0,0,0.8)]"
      style={{ transform: `translateX(-50%) scale(${safeScale})`, transformOrigin: 'bottom center' }}
    >
      <div className="mb-6 flex flex-col items-center">
        <span className="mb-1 text-base font-bold tracking-widest text-red-500 drop-shadow-[0_0_8px_rgba(239,68,68,0.8)]">
          {mergedTexts.rebootTitle}
        </span>
        <span className="text-4xl font-black tracking-tighter text-white drop-shadow-[0_0_10px_rgba(255,255,255,0.5)]">
          {canNormalRevive ? mergedTexts.ready : `00:${safeCountdown.toString().padStart(2, '0')}`}
        </span>
      </div>

      <div className="mb-3 flex items-center rounded border border-yellow-500/40 bg-yellow-900/20 px-3 py-1 text-xs font-bold text-yellow-300">
        {mergedTexts.ecoLabel}: {safeEco}
      </div>

      <div className="flex space-x-6">
        <button
          onClick={handleNormalReviveClick}
          disabled={!canNormalRevive}
          className={`relative flex w-48 flex-col items-center justify-center rounded-xl border-2 py-4 transition-all duration-300 ${
            canNormalRevive
              ? 'cursor-pointer border-cyan-400 bg-cyan-900/60 text-cyan-300 hover:bg-cyan-600/60 hover:shadow-[0_0_20px_rgba(34,211,238,0.6)]'
              : 'cursor-not-allowed border-gray-600 bg-gray-800 text-gray-500 opacity-80'
          }`}
        >
          <span className="mb-1 text-xl font-bold">{mergedTexts.normalReviveTitle}</span>
          <span className="text-sm font-medium">
            {canNormalRevive
              ? mergedTexts.normalReviveReadyHint
              : `${mergedTexts.normalReviveCoolingPrefix} (${safeCountdown}s)`}
          </span>
        </button>

        <button
          onClick={handleBuyReviveClick}
          onContextMenu={handleBuyReviveContextMenu}
          className={`relative flex w-56 flex-col items-center justify-center rounded-xl border-2 py-4 transition-all duration-300 ${
            !canBuyRevive
              ? 'cursor-not-allowed border-red-900/50 bg-gray-800/90 opacity-80'
              : isConfirmingBuy
                ? 'cursor-pointer border-green-400 bg-green-900/80 text-green-300 ring-2 ring-green-400/50 shadow-[0_0_25px_rgba(74,222,128,0.7)]'
                : 'cursor-pointer border-amber-500 bg-amber-900/60 text-amber-400 hover:bg-amber-700/60 hover:shadow-[0_0_20px_rgba(245,158,11,0.6)]'
          }`}
        >
          {!isConfirmingBuy ? (
            <>
              <span className={`mb-1 text-xl font-bold ${!canBuyRevive ? 'text-red-400' : ''}`}>
                {!canBuyRevive ? mergedTexts.noEcoTitle : mergedTexts.buyReviveTitle}
              </span>
              <div className="mt-1 flex items-center space-x-2 text-sm">
                <span className={`rounded border px-2 py-0.5 font-bold ${
                  !canBuyRevive
                    ? 'border-red-800/50 bg-red-950/80 text-red-300'
                    : 'border-amber-700/50 bg-amber-950/80 text-amber-200'
                }`}>
                  {safeReviveCost}
                </span>
                <span className={`border-l pl-2 ${
                  !canBuyRevive ? 'border-red-800/50 text-red-300/50' : 'border-amber-700/50 text-amber-100/70'
                }`}>
                  {mergedTexts.buyTriggerHint}
                </span>
              </div>
            </>
          ) : (
            <>
              <span className="mb-1 text-xl font-bold text-green-400">{mergedTexts.confirmBuyTitle}</span>
              <div className="mt-1 flex items-center space-x-2 text-xs font-bold">
                <span className="rounded border border-green-700/50 bg-green-950/80 px-2 py-1 text-green-200">{mergedTexts.confirmHint}</span>
                <span className="rounded border border-red-800/50 bg-red-950/80 px-2 py-1 text-red-300">{mergedTexts.cancelHint}</span>
              </div>
            </>
          )}
        </button>
      </div>
    </div>
  );
}
