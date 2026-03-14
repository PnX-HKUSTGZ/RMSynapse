import { createElement, memo, useEffect, useRef, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  Coins,
  Cpu,
  Crosshair,
  Lock,
  MapPin,
  Navigation,
  Plane,
  Shield,
  ShieldAlert,
  ShoppingCart,
  Swords,
  Target,
  Unlock,
  Zap,
} from 'lucide-react';
import { DEFAULT_UI_STATE } from './uiState';

function resolveControlsConfig(controls) {
  const defaults = DEFAULT_UI_STATE.controls ?? {};
  const mergedControls = { ...defaults, ...(controls ?? {}) };

  mergedControls.infantrySettings = {
    ...(defaults.infantrySettings ?? {}),
    ...(controls?.infantrySettings ?? {}),
  };
  mergedControls.heroSettings = {
    ...(defaults.heroSettings ?? {}),
    ...(controls?.heroSettings ?? {}),
  };
  mergedControls.sentrySettings = {
    ...(defaults.sentrySettings ?? {}),
    ...(controls?.sentrySettings ?? {}),
  };
  mergedControls.costs = {
    ...(defaults.costs ?? {}),
    ...(controls?.costs ?? {}),
  };
  mergedControls.ammoStore = {
    infantry: {
      normal: {
        ...(defaults.ammoStore?.infantry?.normal ?? {}),
        ...(controls?.ammoStore?.infantry?.normal ?? {}),
      },
      airdrop: {
        ...(defaults.ammoStore?.infantry?.airdrop ?? {}),
        ...(controls?.ammoStore?.infantry?.airdrop ?? {}),
      },
    },
    hero: {
      normal: {
        ...(defaults.ammoStore?.hero?.normal ?? {}),
        ...(controls?.ammoStore?.hero?.normal ?? {}),
      },
      airdrop: {
        ...(defaults.ammoStore?.hero?.airdrop ?? {}),
        ...(controls?.ammoStore?.hero?.airdrop ?? {}),
      },
    },
  };

  return mergedControls;
}

function RoleTab({ role, label, icon, activeRole, onSelect }) {
  return (
    <button
      onClick={() => onSelect(role)}
      className={`flex items-center gap-2 rounded-md border px-3 py-1.5 text-xs font-bold transition-colors ${
        activeRole === role
          ? 'border-cyan-400 bg-cyan-500/15 text-cyan-300'
          : 'border-slate-700 bg-slate-900/70 text-slate-300 hover:bg-slate-800'
      }`}
    >
      {createElement(icon, { size: 14 })}
      <span>{label}</span>
    </button>
  );
}

function SelectionButton({ active, onClick, disabled, children }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`flex-1 rounded-md border px-2 py-1.5 text-xs font-medium transition-colors ${
        disabled ? 'cursor-not-allowed opacity-60' : 'hover:bg-slate-700'
      } ${active ? 'border-cyan-500 bg-cyan-500/15 text-cyan-300' : 'border-slate-700 bg-slate-800 text-slate-300'}`}
    >
      {children}
    </button>
  );
}

function CommandBtn({ num, text, onClick, color = 'border-slate-700 hover:bg-slate-700 text-slate-300' }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-lg border bg-slate-800 p-2 transition-colors ${color}`}
    >
      <div className="mb-1 text-[10px] font-mono opacity-60">[{num}]</div>
      <div className="text-xs font-bold leading-tight">{text}</div>
    </button>
  );
}

function AmmoStoreItem({ title, unitPrice, step, desc, eco, onBuy }) {
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
        <button
          onClick={() => adjustQty(-10)}
          className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
        >
          -10
        </button>
        <button
          onClick={() => adjustQty(-5)}
          className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
        >
          -5
        </button>
        <button
          onClick={() => adjustQty(-1)}
          className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
        >
          -1
        </button>
        <button
          onClick={() => adjustQty(1)}
          className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
        >
          +1
        </button>
        <button
          onClick={() => adjustQty(5)}
          className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
        >
          +5
        </button>
        <button
          onClick={() => adjustQty(10)}
          className="rounded border border-cyan-500/40 bg-cyan-500/10 px-1.5 py-0.5 text-cyan-300 transition-colors hover:bg-cyan-500/20"
        >
          +10
        </button>
      </div>
      <input
        type="range"
        min={step}
        max={maxQty}
        step={1}
        value={safeQty}
        onChange={(e) => setQty(Number(e.target.value))}
        className="mb-2 h-1.5 w-full cursor-pointer accent-emerald-500"
      />

      <div className="flex items-center justify-between border-t border-slate-700 pt-2 text-xs">
        <span>
          花费: <span className={canBuy ? 'font-bold text-yellow-400' : 'font-bold text-red-400'}>{cost}</span>
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

function Panel({ title, icon, accentClass = 'bg-cyan-500', children, minWidth = 'min-w-[360px]' }) {
  return (
    <section className={`${minWidth} rounded-xl border border-slate-700 bg-slate-900/92 p-3`}>
      <div className="mb-2.5 flex items-center gap-2 text-sm font-bold text-white">
        <span className={`h-4 w-1 rounded-full ${accentClass}`} />
        {createElement(icon, { size: 16, className: 'text-slate-300' })}
        <span>{title}</span>
      </div>
      {children}
    </section>
  );
}

function MapTopControls({ eco, controls }) {
  const controlsConfig = resolveControlsConfig(controls);
  const toastDurationMs = Number(controlsConfig.toastDurationMs) > 0 ? Number(controlsConfig.toastDurationMs) : 2500;
  const remoteHealCost = Number(controlsConfig.costs?.remoteHeal) > 0 ? Number(controlsConfig.costs.remoteHeal) : 200;

  const [activeRole, setActiveRole] = useState(() => controlsConfig.activeRole ?? 'infantry');
  const [toastMsg, setToastMsg] = useState('');

  const [isLocked, setIsLocked] = useState(() => !!controlsConfig.isLocked);
  const [infantrySettings, setInfantrySettings] = useState(() => controlsConfig.infantrySettings);
  const [heroSettings, setHeroSettings] = useState(() => controlsConfig.heroSettings);
  const [sentrySettings, setSentrySettings] = useState(() => controlsConfig.sentrySettings);

  const [dartTarget, setDartTarget] = useState(() => controlsConfig.dartTarget ?? '1');
  const [gateOpen, setGateOpen] = useState(() => !!controlsConfig.gateOpen);
  const toastTimerRef = useRef(null);

  useEffect(() => () => {
    if (toastTimerRef.current) {
      clearTimeout(toastTimerRef.current);
    }
  }, []);

  const showToast = (msg) => {
    setToastMsg(msg);
    if (toastTimerRef.current) {
      clearTimeout(toastTimerRef.current);
    }
    toastTimerRef.current = setTimeout(() => {
      setToastMsg('');
      toastTimerRef.current = null;
    }, toastDurationMs);
  };

  const handleAction = (actionName) => {
    showToast(`已执行: ${actionName}`);
  };

  const handleBuyAmmo = (title, qty, cost) => {
    showToast(`已购买 ${title} ${qty}发 (花费 ${cost} 金币)`);
  };

  return (
    <div className="pointer-events-none absolute top-3 right-3 left-3 z-40">
      {toastMsg && (
        <div className="pointer-events-none fixed top-4 left-1/2 z-[60] -translate-x-1/2 rounded-full border border-cyan-500 bg-cyan-900/90 px-4 py-2 text-sm text-cyan-50 shadow-lg shadow-cyan-900/30">
          <div className="flex items-center gap-2">
            <Activity size={14} />
            <span>{toastMsg}</span>
          </div>
        </div>
      )}

      <div className="pointer-events-auto rounded-xl border border-slate-700 bg-slate-950/92 p-3">
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-700 pb-2">
          <div className="flex flex-wrap items-center gap-1.5">
            <RoleTab
              role="infantry"
              label="步兵"
              icon={Crosshair}
              activeRole={activeRole}
              onSelect={(role) => {
                setActiveRole(role);
                setIsLocked(false);
              }}
            />
            <RoleTab
              role="hero"
              label="英雄"
              icon={Zap}
              activeRole={activeRole}
              onSelect={(role) => {
                setActiveRole(role);
                setIsLocked(false);
              }}
            />
            <RoleTab
              role="sentry"
              label="哨兵"
              icon={Target}
              activeRole={activeRole}
              onSelect={(role) => {
                setActiveRole(role);
                setIsLocked(false);
              }}
            />
          </div>

          <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-300">
            <div className="flex items-center rounded border border-yellow-500/30 bg-yellow-500/10 px-2 py-1 font-bold text-yellow-300">
              <Coins size={12} className="mr-1" />
              {eco}
            </div>
          </div>
        </div>

        <div className="mt-3 flex gap-3 overflow-x-auto pb-1">
          <Panel title="性能体系与控制方式" icon={Cpu} accentClass="bg-cyan-500" minWidth="min-w-[420px]">
            <div className="mb-2 flex justify-end">
              <button
                onClick={() => setIsLocked((prev) => !prev)}
                className={`flex items-center gap-1 rounded-md border px-2.5 py-1.5 text-xs font-bold transition-colors ${
                  isLocked
                    ? 'border-red-500/60 bg-red-500/15 text-red-300 hover:bg-red-500/25'
                    : 'border-cyan-500/60 bg-cyan-500/20 text-cyan-200 hover:bg-cyan-500/30'
                }`}
              >
                {isLocked ? <Lock size={13} /> : <Unlock size={13} />}
                <span>{isLocked ? '已锁死' : '确认锁死'}</span>
              </button>
            </div>
            {activeRole === 'infantry' && (
              <div className="space-y-3">
                <div>
                  <div className="mb-1 text-xs font-semibold text-slate-400">底盘性能 (Chassis)</div>
                  <div className="flex gap-2">
                    <SelectionButton
                      active={infantrySettings.chassis === 'hp'}
                      disabled={isLocked}
                      onClick={() => setInfantrySettings((prev) => ({ ...prev, chassis: 'hp' }))}
                    >
                      <Shield className="mb-0.5 mr-1 inline h-3.5 w-3.5" />血量优先
                    </SelectionButton>
                    <SelectionButton
                      active={infantrySettings.chassis === 'power'}
                      disabled={isLocked}
                      onClick={() => setInfantrySettings((prev) => ({ ...prev, chassis: 'power' }))}
                    >
                      <Zap className="mb-0.5 mr-1 inline h-3.5 w-3.5" />功率优先
                    </SelectionButton>
                  </div>
                </div>
                <div>
                  <div className="mb-1 text-xs font-semibold text-slate-400">发射性能 (Firing)</div>
                  <div className="flex gap-2">
                    <SelectionButton
                      active={infantrySettings.firing === 'burst'}
                      disabled={isLocked}
                      onClick={() => setInfantrySettings((prev) => ({ ...prev, firing: 'burst' }))}
                    >
                      <Crosshair className="mb-0.5 mr-1 inline h-3.5 w-3.5" />爆发优先
                    </SelectionButton>
                    <SelectionButton
                      active={infantrySettings.firing === 'cooldown'}
                      disabled={isLocked}
                      onClick={() => setInfantrySettings((prev) => ({ ...prev, firing: 'cooldown' }))}
                    >
                      <Activity className="mb-0.5 mr-1 inline h-3.5 w-3.5" />冷却优先
                    </SelectionButton>
                  </div>
                </div>
              </div>
            )}

            {activeRole === 'hero' && (
              <div className="space-y-3">
                <div>
                  <div className="mb-1 text-xs font-semibold text-slate-400">底盘性能 (Chassis)</div>
                  <div className="flex gap-2">
                    <SelectionButton
                      active={heroSettings.chassis === 'hp'}
                      disabled={isLocked}
                      onClick={() => setHeroSettings((prev) => ({ ...prev, chassis: 'hp' }))}
                    >
                      <Shield className="mb-0.5 mr-1 inline h-3.5 w-3.5" />血量优先
                    </SelectionButton>
                    <SelectionButton
                      active={heroSettings.chassis === 'power'}
                      disabled={isLocked}
                      onClick={() => setHeroSettings((prev) => ({ ...prev, chassis: 'power' }))}
                    >
                      <Zap className="mb-0.5 mr-1 inline h-3.5 w-3.5" />功率优先
                    </SelectionButton>
                  </div>
                </div>
                <div>
                  <div className="mb-1 text-xs font-semibold text-slate-400">发射性能 (Firing)</div>
                  <div className="flex gap-2">
                    <SelectionButton
                      active={heroSettings.firing === 'melee'}
                      disabled={isLocked}
                      onClick={() => setHeroSettings((prev) => ({ ...prev, firing: 'melee' }))}
                    >
                      <Swords className="mb-0.5 mr-1 inline h-3.5 w-3.5" />近战优先
                    </SelectionButton>
                    <SelectionButton
                      active={heroSettings.firing === 'ranged'}
                      disabled={isLocked}
                      onClick={() => setHeroSettings((prev) => ({ ...prev, firing: 'ranged' }))}
                    >
                      <Target className="mb-0.5 mr-1 inline h-3.5 w-3.5" />远程优先
                    </SelectionButton>
                  </div>
                </div>
              </div>
            )}

            {activeRole === 'sentry' && (
              <div>
                <div className="mb-1 text-xs font-semibold text-slate-400">控制方式 (Control Mode)</div>
                <div className="flex flex-col gap-2">
                  <SelectionButton
                    active={sentrySettings.mode === 'auto'}
                    disabled={isLocked}
                    onClick={() => setSentrySettings({ mode: 'auto' })}
                  >
                    <Cpu className="mb-0.5 mr-1 inline h-3.5 w-3.5" />自动
                  </SelectionButton>
                  <SelectionButton
                    active={sentrySettings.mode === 'semi'}
                    disabled={isLocked}
                    onClick={() => setSentrySettings({ mode: 'semi' })}
                  >
                    <Navigation className="mb-0.5 mr-1 inline h-3.5 w-3.5" />半自动
                  </SelectionButton>
                </div>
              </div>
            )}
          </Panel>

          {(activeRole === 'infantry' || activeRole === 'hero') && (
            <Panel title="物资购买" icon={ShoppingCart} accentClass="bg-emerald-500" minWidth="min-w-[510px]">
              <div className="grid grid-cols-2 gap-2.5">
                <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-2">
                  <div className="mb-2 flex items-center text-xs font-bold text-emerald-300">
                    <MapPin size={14} className="mr-1.5" />普通购买
                  </div>
                  {activeRole === 'infantry' ? (
                    <AmmoStoreItem
                      title={controlsConfig.ammoStore.infantry.normal.title}
                      unitPrice={controlsConfig.ammoStore.infantry.normal.unitPrice}
                      step={controlsConfig.ammoStore.infantry.normal.step}
                      desc={controlsConfig.ammoStore.infantry.normal.desc}
                      eco={eco}
                      onBuy={handleBuyAmmo}
                    />
                  ) : (
                    <AmmoStoreItem
                      title={controlsConfig.ammoStore.hero.normal.title}
                      unitPrice={controlsConfig.ammoStore.hero.normal.unitPrice}
                      step={controlsConfig.ammoStore.hero.normal.step}
                      desc={controlsConfig.ammoStore.hero.normal.desc}
                      eco={eco}
                      onBuy={handleBuyAmmo}
                    />
                  )}
                </div>

                <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-2">
                  <div className="mb-2 flex items-center text-xs font-bold text-violet-300">
                    <Navigation size={14} className="mr-1.5" />空投购买
                  </div>
                  {activeRole === 'infantry' ? (
                    <AmmoStoreItem
                      title={controlsConfig.ammoStore.infantry.airdrop.title}
                      unitPrice={controlsConfig.ammoStore.infantry.airdrop.unitPrice}
                      step={controlsConfig.ammoStore.infantry.airdrop.step}
                      desc={controlsConfig.ammoStore.infantry.airdrop.desc}
                      eco={eco}
                      onBuy={handleBuyAmmo}
                    />
                  ) : (
                    <AmmoStoreItem
                      title={controlsConfig.ammoStore.hero.airdrop.title}
                      unitPrice={controlsConfig.ammoStore.hero.airdrop.unitPrice}
                      step={controlsConfig.ammoStore.hero.airdrop.step}
                      desc={controlsConfig.ammoStore.hero.airdrop.desc}
                      eco={eco}
                      onBuy={handleBuyAmmo}
                    />
                  )}
                  <button
                    onClick={() => {
                      if (eco >= remoteHealCost) {
                        handleAction('远程买血');
                      } else {
                        showToast('金币不足，无法买血');
                      }
                    }}
                    className="mt-2 w-full rounded-md border border-red-500/40 bg-red-500/10 px-2 py-1.5 text-left text-xs text-red-300 transition-colors hover:bg-red-500/20"
                  >
                    生命值恢复 {remoteHealCost}金币/次
                  </button>
                </div>
              </div>
            </Panel>
          )}

          {activeRole === 'sentry' && (
            <Panel title="飞镖系统" icon={Target} accentClass="bg-orange-500" minWidth="min-w-[350px]">
              <div className="space-y-2.5 text-xs">
                <div>
                  <div className="mb-1 text-slate-400">目标 ID</div>
                  <select
                    value={dartTarget}
                    onChange={(e) => setDartTarget(e.target.value)}
                    className="w-full rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-slate-100"
                  >
                    <option value="1">1 - 前哨站</option>
                    <option value="2">2 - 基地固定目标</option>
                    <option value="3">3 - 基地随机固定目标</option>
                    <option value="4">4 - 基地随机移动目标</option>
                    <option value="5">5 - 基地末端移动目标</option>
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
                  onClick={() => handleAction(`发射飞镖(目标:${dartTarget})`)}
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
            </Panel>
          )}

          {activeRole === 'sentry' && (
            <Panel title="哨兵控制台" icon={Cpu} accentClass="bg-purple-500" minWidth="min-w-[420px]">
              <div className="grid grid-cols-3 gap-2">
                <CommandBtn num="1" text="补血点补弹" onClick={() => handleAction('补血点补弹')} />
                <CommandBtn num="2" text="补给站补弹" onClick={() => handleAction('补给站实体补弹')} />
                <CommandBtn num="3" text="远程补弹" onClick={() => handleAction('远程补弹')} />
                <CommandBtn num="4" text="远程回血" onClick={() => handleAction('远程回血')} />
                <CommandBtn num="5" text="确认复活" onClick={() => handleAction('确认复活')} color="border-green-500/60 hover:bg-green-500/20 text-green-300" />
                <CommandBtn num="6" text="金币复活" onClick={() => handleAction('确认花费金币复活')} color="border-yellow-500/60 hover:bg-yellow-500/20 text-yellow-300" />
                <div className="rounded-lg border border-slate-800" />
                <CommandBtn num="8" text="进攻姿态" onClick={() => handleAction('切换为进攻姿态')} color="border-red-500/60 hover:bg-red-500/20 text-red-300" />
                <CommandBtn num="9" text="防御姿态" onClick={() => handleAction('切换为防御姿态')} color="border-blue-500/60 hover:bg-blue-500/20 text-blue-300" />
              </div>
            </Panel>
          )}

          {activeRole === 'sentry' && (
            <Panel title="空中支援" icon={Plane} accentClass="bg-sky-500" minWidth="min-w-[280px]">
              <div className="space-y-2 text-xs">
                <button
                  onClick={() => handleAction('免费呼叫空中支援')}
                  className="w-full rounded-md border border-sky-500/40 bg-sky-500/10 px-2 py-2 text-sky-200 transition-colors hover:bg-sky-500/20"
                >
                  免费呼叫支援
                </button>
                <button
                  onClick={() => handleAction('金币呼叫空中支援')}
                  className="w-full rounded-md border border-yellow-500/40 bg-yellow-500/10 px-2 py-2 text-yellow-200 transition-colors hover:bg-yellow-500/20"
                >
                  金币呼叫支援
                </button>
                <button
                  onClick={() => handleAction('中断空中支援')}
                  className="flex w-full items-center justify-center rounded-md border border-red-500/40 bg-red-500/10 px-2 py-2 text-red-300 transition-colors hover:bg-red-500/20"
                >
                  <ShieldAlert size={13} className="mr-1.5" />
                  中断空中支援
                </button>
              </div>
            </Panel>
          )}
        </div>

        {activeRole === 'sentry' && (
          <div className="mt-1 flex items-center gap-1 text-[11px] text-amber-300">
            <AlertTriangle size={12} />
            <span>哨兵模式下可在右侧卡片进行飞镖/姿态/空中支援控制。</span>
          </div>
        )}
      </div>
    </div>
  );
}

export default memo(MapTopControls);
