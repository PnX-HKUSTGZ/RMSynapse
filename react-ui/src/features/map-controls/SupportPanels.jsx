import {
  AlertTriangle,
  Coins,
  Cpu,
  MapPin,
  Navigation,
  Plane,
  ShieldAlert,
  ShoppingCart,
  Target,
} from 'lucide-react';
import AmmoStoreItem from './AmmoStoreItem';
import { DART_TARGET_OPTIONS } from './constants';
import { CommandButton, SectionPanel } from './MapControlPrimitives';

export function ResourceHeader({ eco }) {
  return (
    <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-300">
      <div className="flex items-center rounded border border-yellow-500/30 bg-yellow-500/10 px-2 py-1 font-bold text-yellow-300">
        <Coins size={12} className="mr-1" />
        {eco}
      </div>
    </div>
  );
}

export function AmmoPurchasePanel({ activeRole, ammoStore, eco, onBuyAmmo, onRemoteHeal, remoteHealCost }) {
  if (activeRole !== 'infantry' && activeRole !== 'hero') {
    return null;
  }

  const roleKey = activeRole === 'infantry' ? 'infantry' : 'hero';

  return (
    <SectionPanel title="物资购买" icon={ShoppingCart} accentClass="bg-emerald-500" minWidth="min-w-[510px]">
      <div className="grid grid-cols-2 gap-2.5">
        <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-2">
          <div className="mb-2 flex items-center text-xs font-bold text-emerald-300">
            <MapPin size={14} className="mr-1.5" />
            普通购买
          </div>
          <AmmoStoreItem
            title={ammoStore[roleKey].normal.title}
            unitPrice={ammoStore[roleKey].normal.unitPrice}
            step={ammoStore[roleKey].normal.step}
            desc={ammoStore[roleKey].normal.desc}
            eco={eco}
            onBuy={onBuyAmmo}
          />
        </div>

        <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-2">
          <div className="mb-2 flex items-center text-xs font-bold text-violet-300">
            <Navigation size={14} className="mr-1.5" />
            空投购买
          </div>
          <AmmoStoreItem
            title={ammoStore[roleKey].airdrop.title}
            unitPrice={ammoStore[roleKey].airdrop.unitPrice}
            step={ammoStore[roleKey].airdrop.step}
            desc={ammoStore[roleKey].airdrop.desc}
            eco={eco}
            onBuy={onBuyAmmo}
          />
          <button
            onClick={onRemoteHeal}
            className="mt-2 w-full rounded-md border border-red-500/40 bg-red-500/10 px-2 py-1.5 text-left text-xs text-red-300 transition-colors hover:bg-red-500/20"
          >
            生命值恢复 {remoteHealCost}金币/次
          </button>
        </div>
      </div>
    </SectionPanel>
  );
}

export function DartControlPanel({ activeRole, dartTarget, setDartTarget, gateOpen, setGateOpen, onFire }) {
  if (activeRole !== 'sentry') return null;

  return (
    <SectionPanel title="飞镖系统" icon={Target} accentClass="bg-orange-500" minWidth="min-w-[350px]">
      <div className="space-y-2.5 text-xs">
        <div>
          <div className="mb-1 text-slate-400">目标 ID</div>
          <select
            value={dartTarget}
            onChange={(event) => setDartTarget(event.target.value)}
            className="w-full rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-slate-100"
          >
            {DART_TARGET_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div>
          <div className="mb-1 text-slate-400">闸门控制</div>
          <div className="flex gap-2">
            <button
              onClick={() => setGateOpen(true)}
              className={`flex-1 rounded-md border py-1.5 ${
                gateOpen ? 'border-orange-500 bg-orange-500/20 text-orange-300' : 'border-slate-700 bg-slate-800 text-slate-300'
              }`}
            >
              开
            </button>
            <button
              onClick={() => setGateOpen(false)}
              className={`flex-1 rounded-md border py-1.5 ${
                !gateOpen ? 'border-orange-500 bg-orange-500/20 text-orange-300' : 'border-slate-700 bg-slate-800 text-slate-300'
              }`}
            >
              关
            </button>
          </div>
        </div>

        <button
          onClick={onFire}
          disabled={!gateOpen}
          className={`w-full rounded-md py-2 text-xs font-bold text-white ${
            gateOpen
              ? 'bg-red-600 shadow-lg shadow-red-900/40 hover:bg-red-500'
              : 'cursor-not-allowed border border-slate-700 bg-slate-700 text-slate-400'
          }`}
        >
          确认发射
        </button>
      </div>
    </SectionPanel>
  );
}

export function SentryCommandPanel({ activeRole, onAction }) {
  if (activeRole !== 'sentry') return null;

  return (
    <SectionPanel title="哨兵控制台" icon={Cpu} accentClass="bg-purple-500" minWidth="min-w-[420px]">
      <div className="grid grid-cols-3 gap-2">
        <CommandButton num="1" text="补血点补弹" onClick={() => onAction('补血点补弹')} />
        <CommandButton num="2" text="补给站补弹" onClick={() => onAction('补给站实体补弹')} />
        <CommandButton num="3" text="远程补弹" onClick={() => onAction('远程补弹')} />
        <CommandButton num="4" text="远程回血" onClick={() => onAction('远程回血')} />
        <CommandButton num="5" text="确认复活" onClick={() => onAction('确认复活')} color="border-green-500/60 hover:bg-green-500/20 text-green-300" />
        <CommandButton num="6" text="金币复活" onClick={() => onAction('确认花费金币复活')} color="border-yellow-500/60 hover:bg-yellow-500/20 text-yellow-300" />
        <div className="rounded-lg border border-slate-800" />
        <CommandButton num="8" text="进攻姿态" onClick={() => onAction('切换为进攻姿态')} color="border-red-500/60 hover:bg-red-500/20 text-red-300" />
        <CommandButton num="9" text="防御姿态" onClick={() => onAction('切换为防御姿态')} color="border-blue-500/60 hover:bg-blue-500/20 text-blue-300" />
      </div>
    </SectionPanel>
  );
}

export function AirSupportPanel({ activeRole, onAction }) {
  if (activeRole !== 'sentry') return null;

  return (
    <SectionPanel title="空中支援" icon={Plane} accentClass="bg-sky-500" minWidth="min-w-[280px]">
      <div className="space-y-2 text-xs">
        <button
          onClick={() => onAction('免费呼叫空中支援')}
          className="w-full rounded-md border border-sky-500/40 bg-sky-500/10 px-2 py-2 text-sky-200 transition-colors hover:bg-sky-500/20"
        >
          免费呼叫支援
        </button>
        <button
          onClick={() => onAction('金币呼叫空中支援')}
          className="w-full rounded-md border border-yellow-500/40 bg-yellow-500/10 px-2 py-2 text-yellow-200 transition-colors hover:bg-yellow-500/20"
        >
          金币呼叫支援
        </button>
        <button
          onClick={() => onAction('中断空中支援')}
          className="flex w-full items-center justify-center rounded-md border border-red-500/40 bg-red-500/10 px-2 py-2 text-red-300 transition-colors hover:bg-red-500/20"
        >
          <ShieldAlert size={13} className="mr-1.5" />
          中断空中支援
        </button>
      </div>
    </SectionPanel>
  );
}

export function SentryHint({ activeRole }) {
  if (activeRole !== 'sentry') return null;

  return (
    <div className="mt-1 flex items-center gap-1 text-[11px] text-amber-300">
      <AlertTriangle size={12} />
      <span>哨兵模式下可在右侧卡片进行飞镖/姿态/空中支援控制。</span>
    </div>
  );
}
