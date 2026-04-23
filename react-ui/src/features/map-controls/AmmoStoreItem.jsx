import { useState } from 'react';

export default function AmmoStoreItem({ title, unitPrice, step, desc, eco, onBuy }) {
  const maxAffordableQty = Math.floor(eco / unitPrice / step) * step;
  const maxQty = Math.max(step, maxAffordableQty);
  const [qty, setQty] = useState(step);
  const safeQty = Math.min(Math.max(step, qty), maxQty);

  const cost = Math.ceil(safeQty * unitPrice);
  const canBuy = eco >= cost && safeQty > 0;
  const canBuyAll = maxAffordableQty >= step;

  const adjustQty = (delta) => {
    setQty((prev) => {
      const next = prev + delta;
      if (next < step) return step;
      if (next > maxQty) return maxQty;
      return next;
    });
  };

  const handleBuy = () => {
    if (!canBuy) return;
    onBuy(title, safeQty, cost);
    setQty(step);
  };

  const handleBuyAll = () => {
    if (!canBuyAll) return;
    const totalCost = Math.ceil(maxAffordableQty * unitPrice);
    onBuy(title, maxAffordableQty, totalCost);
    setQty(step);
  };

  return (
    <div className="rounded-lg border border-slate-700 bg-slate-800/80 p-2">
      <div className="mb-1.5 flex items-center justify-between gap-2 text-xs">
        <span className="text-slate-200">{title}</span>
        <span className="rounded border border-yellow-500/20 bg-yellow-500/10 px-1.5 py-0.5 font-mono text-[10px] text-yellow-400">
          {desc}
        </span>
      </div>

      <div className="mb-1.5 flex justify-between text-[10px] text-slate-400">
        <span>{step}发</span>
        <span className="font-bold text-cyan-300">{safeQty}发</span>
        <span>{maxQty}发</span>
      </div>

      <div className="mb-1.5 flex items-center gap-1 text-[10px]">
        {[-10, -5, -1, 1, 5, 10].map((delta) => (
          <button
            key={`${title}-${delta}`}
            onClick={() => adjustQty(delta)}
            className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
          >
            {delta > 0 ? `+${delta}` : delta}
          </button>
        ))}
      </div>

      <input
        type="range"
        min={step}
        max={maxQty}
        step={1}
        value={safeQty}
        onChange={(event) => setQty(Number(event.target.value))}
        className="mb-2 h-1.5 w-full cursor-pointer accent-emerald-500"
      />

      <div className="flex items-center justify-between border-t border-slate-700 pt-2 text-xs">
        <span>
          花费:
          <span className={canBuy ? 'font-bold text-yellow-400' : 'font-bold text-red-400'}>
            {' '}
            {cost}
          </span>
        </span>
        <div className="flex gap-1.5">
          <button
            onClick={handleBuyAll}
            disabled={!canBuyAll}
            className="rounded border border-yellow-500/30 bg-yellow-500/15 px-1.5 py-1 text-[10px] text-yellow-400 transition-colors hover:bg-yellow-500/25 disabled:cursor-not-allowed disabled:opacity-40"
          >
            全买
          </button>
          <button
            onClick={handleBuy}
            disabled={!canBuy}
            className="rounded bg-emerald-600 px-2 py-1 text-[11px] font-bold text-white transition-colors hover:bg-emerald-500 disabled:cursor-not-allowed disabled:bg-slate-600 disabled:opacity-50"
          >
            购买
          </button>
        </div>
      </div>
    </div>
  );
}
