import { useState } from 'react';

function normalizeCountdown(value) {
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) return 0;
  return Math.max(0, Math.floor(seconds));
}

function normalizeScale(value) {
  const scale = Number(value);
  if (!Number.isFinite(scale)) return 1;
  return Math.min(3, Math.max(0.4, scale));
}

export default function ReviveOverlay({
  isDead,
  countdown,
  eco,
  reviveCost = 500,
  scale = 1,
  onNormalRevive,
  onBuyRevive,
}) {
  const [isConfirmingBuy, setIsConfirmingBuy] = useState(false);

  const safeCountdown = normalizeCountdown(countdown);
  const safeEco = Number.isFinite(Number(eco)) ? Number(eco) : 0;
  const safeReviveCost = Number.isFinite(Number(reviveCost)) && Number(reviveCost) > 0
    ? Number(reviveCost)
    : 500;
  const safeScale = normalizeScale(scale);
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
      className="absolute bottom-[15%] left-1/2 z-40 flex flex-col items-center rounded-2xl border border-gray-700/80 bg-gray-900/90 p-8 shadow-[0_0_40px_rgba(0,0,0,0.8)]"
      style={{ transform: `translateX(-50%) scale(${safeScale})`, transformOrigin: 'bottom center' }}
    >
      <div className="mb-6 flex flex-col items-center">
        <span className="mb-1 text-base font-bold tracking-widest text-red-500 drop-shadow-[0_0_8px_rgba(239,68,68,0.8)]">
          SYSTEM REBOOT IN
        </span>
        <span className="text-4xl font-black tracking-tighter text-white drop-shadow-[0_0_10px_rgba(255,255,255,0.5)]">
          {canNormalRevive ? 'READY' : `00:${safeCountdown.toString().padStart(2, '0')}`}
        </span>
      </div>

      <div className="mb-3 flex items-center rounded border border-yellow-500/40 bg-yellow-900/20 px-3 py-1 text-xs font-bold text-yellow-300">
        当前金币(ECO): {safeEco}
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
          <span className="mb-1 text-xl font-bold">普通复活</span>
          <span className="text-sm font-medium">
            {canNormalRevive ? '点击左键复活' : `冷却中 (${safeCountdown}s)`}
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
                {!canBuyRevive ? '金币不足' : '立刻复活'}
              </span>
              <div className="mt-1 flex items-center space-x-2 text-sm">
                <span className={`rounded border px-2 py-0.5 font-bold ${
                  !canBuyRevive
                    ? 'border-red-800/50 bg-red-950/80 text-red-300'
                    : 'border-amber-700/50 bg-amber-950/80 text-amber-200'
                }`}
                >
                  {safeReviveCost}
                </span>
                <span className={`border-l pl-2 ${
                  !canBuyRevive ? 'border-red-800/50 text-red-300/50' : 'border-amber-700/50 text-amber-100/70'
                }`}
                >
                  右键触发
                </span>
              </div>
            </>
          ) : (
            <>
              <span className="mb-1 text-xl font-bold text-green-400">确认购买？</span>
              <div className="mt-1 flex items-center space-x-2 text-xs font-bold">
                <span className="rounded border border-green-700/50 bg-green-950/80 px-2 py-1 text-green-200">左键 确认</span>
                <span className="rounded border border-red-800/50 bg-red-950/80 px-2 py-1 text-red-300">右键 取消</span>
              </div>
            </>
          )}
        </button>
      </div>
    </div>
  );
}
