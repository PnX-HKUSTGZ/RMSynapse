import { useMemo, useState } from 'react';
import {
  Activity,
  Box,
  ChevronLeft,
  ChevronRight,
  Crosshair,
  RotateCw,
  Send,
  Shield,
  Target,
  Zap,
} from 'lucide-react';
import { emitGodotOperation } from '../../bridge/godot';
import {
  DEFAULT_RESOURCE_QUANTITIES,
  buildResourceActionState,
  floorToStep,
  formatCost,
  isRobotDead,
  parseRobotLevel,
  toInt,
  toNumber,
} from './resourceActions';

const ROLE_META = {
  hero: { label: '英雄', icon: Zap },
  infantry: { label: '步兵', icon: Crosshair },
  engineer: { label: '工程', icon: Box },
  sentry: { label: '哨兵', icon: Shield },
  unknown: { label: '未知', icon: Target },
};

const ROBOT_ID_ROLE = {
  1: 'hero',
  2: 'engineer',
  3: 'infantry',
  4: 'infantry',
  5: 'infantry',
  7: 'sentry',
  101: 'hero',
  102: 'engineer',
  103: 'infantry',
  104: 'infantry',
  105: 'infantry',
  107: 'sentry',
};

const ROBOT_ID_NAME = {
  1: 'HERO R1',
  2: 'ENGINEER R2',
  3: 'INFANTRY R3',
  4: 'INFANTRY R4',
  5: 'INFANTRY R5',
  7: 'SENTRY R7',
  101: 'HERO B1',
  102: 'ENGINEER B2',
  103: 'INFANTRY B3',
  104: 'INFANTRY B4',
  105: 'INFANTRY B5',
  107: 'SENTRY B7',
};

function sendOperation(operation, label, value) {
  emitGodotOperation(operation, `[hudOperate] ${label}`, value);
}

function formatHotkeyCode(code) {
  if (code?.startsWith('Key')) return code.slice(3);
  if (code?.startsWith('Digit')) return code.slice(5);
  if (code?.startsWith('Numpad')) return `N${code.slice(6)}`;
  return String(code ?? '').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/\s+/g, '') || '';
}

function formatDoubleTapHint(hotkeys, action) {
  if (!hotkeys?.enabled) return '';
  const key = formatHotkeyCode(hotkeys?.[action]);
  if (!key) return '';
  return key.length === 1 ? `${key}${key}` : `${key}x2`;
}

function labelWithHotkey(label, hotkeyHint) {
  return hotkeyHint ? `${label} · ${hotkeyHint}` : label;
}

function resolveRobotContext(mecha, controls) {
  const rawId = mecha?.robotId ?? mecha?.robot_id;
  const numericId = Number(rawId);
  const rawName = String(mecha?.pilotId ?? mecha?.name ?? mecha?.robotName ?? '').trim();
  const upperName = rawName.toUpperCase();

  const idRole = Number.isFinite(numericId) ? ROBOT_ID_ROLE[numericId] : null;
  let role = idRole ?? controls?.activeRole ?? 'unknown';

  if (!idRole) {
    if (upperName.includes('HERO') || rawName.includes('英雄')) role = 'hero';
    else if (upperName.includes('ENGINEER') || rawName.includes('工程')) role = 'engineer';
    else if (upperName.includes('INFANTRY') || rawName.includes('步兵')) role = 'infantry';
    else if (upperName.includes('SENTRY') || rawName.includes('哨兵')) role = 'sentry';
  }

  const displayName = (Number.isFinite(numericId) && ROBOT_ID_NAME[numericId]) || upperName || String(rawId ?? 'UNKNOWN').toUpperCase();
  return { role, displayName, supported: role === 'hero' || role === 'infantry' || role === 'engineer' };
}

function FieldValue({ label, value, accent = 'text-cyan-200' }) {
  return (
    <div className="rounded border border-slate-700 bg-slate-950/60 px-2 py-1">
      <div className="text-[10px] font-black uppercase tracking-wider text-slate-500">{label}</div>
      <div className={`mt-0.5 font-mono text-xs font-bold ${accent}`}>{value}</div>
    </div>
  );
}

function IconButton({ active, onClick, icon: Icon, children, disabled = false }) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={`flex min-h-9 items-center justify-center gap-1 rounded border px-2 text-xs font-bold transition-colors ${
        active
          ? 'border-cyan-400 bg-cyan-500/18 text-cyan-100'
          : 'border-slate-700 bg-slate-900/86 text-slate-300 hover:border-slate-500 hover:bg-slate-800'
      } ${disabled ? 'cursor-not-allowed opacity-45' : ''}`}
    >
      {Icon && <Icon size={13} />}
      <span>{children}</span>
    </button>
  );
}

function NumberInput({ value, min, step, onChange, onBlur }) {
  return (
    <input
      className="rounded border border-slate-700 bg-slate-950 px-2 text-center font-mono text-xs text-slate-100 disabled:cursor-not-allowed disabled:opacity-45"
      type="number"
      inputMode="numeric"
      min={min}
      step={step}
      value={value}
      onChange={(event) => onChange(event.target.value)}
      onBlur={onBlur}
    />
  );
}

function PanelSection({ title, icon: Icon, children }) {
  return (
    <section className="border-t border-slate-800 pt-3 first:border-t-0 first:pt-0">
      <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-wider text-slate-400">
        {Icon && <Icon size={14} className="text-cyan-300" />}
        <span>{title}</span>
      </div>
      {children}
    </section>
  );
}

function getTechCoreNumber(techCore, camelKey, snakeKey, fallback = 0) {
  return toInt(techCore?.[camelKey] ?? techCore?.[snakeKey], fallback);
}

function usePerformanceDefaults(controls) {
  return useMemo(() => ({
    infantry: {
      chassis: controls?.infantrySettings?.chassis ?? 'hp',
      firing: controls?.infantrySettings?.firing ?? 'burst',
    },
    hero: {
      chassis: controls?.heroSettings?.chassis ?? 'hp',
      firing: controls?.heroSettings?.firing ?? 'melee',
    },
    sentry: {
      mode: controls?.sentrySettings?.mode ?? 'auto',
    },
  }), [controls]);
}

function PerformanceControls({ activeRole, controls, performance }) {
  const defaults = usePerformanceDefaults(controls);
  const [infantry, setInfantry] = useState(defaults.infantry);
  const [hero, setHero] = useState(defaults.hero);

  const submit = () => {
    const current = activeRole === 'hero' ? hero : infantry;
    sendOperation({
      type: 'performanceSelection',
      role: activeRole,
      firing: current.firing,
      chassis: current.chassis,
    }, 'performanceSelection');
  };

  return (
    <PanelSection title="性能体系" icon={Zap}>
      <div className="grid grid-cols-3 gap-2">
        <FieldValue label="SHOOTER" value={performance?.shooter ?? 0} />
        <FieldValue label="CHASSIS" value={performance?.chassis ?? 0} />
        <FieldValue label="SENTRY" value={performance?.sentryControl ?? 0} />
      </div>

      {activeRole === 'infantry' && (
        <div className="mt-3 space-y-2">
          <div className="grid grid-cols-2 gap-2">
            <IconButton active={infantry.chassis === 'hp'} onClick={() => setInfantry((prev) => ({ ...prev, chassis: 'hp' }))} icon={Shield}>血量</IconButton>
            <IconButton active={infantry.chassis === 'power'} onClick={() => setInfantry((prev) => ({ ...prev, chassis: 'power' }))} icon={Zap}>功率</IconButton>
            <IconButton active={infantry.firing === 'cooldown'} onClick={() => setInfantry((prev) => ({ ...prev, firing: 'cooldown' }))} icon={Activity}>冷却</IconButton>
            <IconButton active={infantry.firing === 'burst'} onClick={() => setInfantry((prev) => ({ ...prev, firing: 'burst' }))} icon={Zap}>爆发</IconButton>
          </div>
        </div>
      )}

      {activeRole === 'hero' && (
        <div className="mt-3 space-y-2">
          <div className="grid grid-cols-2 gap-2">
            <IconButton active={hero.chassis === 'hp'} onClick={() => setHero((prev) => ({ ...prev, chassis: 'hp' }))} icon={Shield}>血量</IconButton>
            <IconButton active={hero.chassis === 'power'} onClick={() => setHero((prev) => ({ ...prev, chassis: 'power' }))} icon={Zap}>功率</IconButton>
            <IconButton active={hero.firing === 'melee'} onClick={() => setHero((prev) => ({ ...prev, firing: 'melee' }))} icon={Target}>近战</IconButton>
            <IconButton active={hero.firing === 'ranged'} onClick={() => setHero((prev) => ({ ...prev, firing: 'ranged' }))} icon={Crosshair}>远程</IconButton>
          </div>
        </div>
      )}

      <button
        type="button"
        onClick={submit}
        className="mt-3 flex w-full items-center justify-center gap-2 rounded border border-cyan-400/60 bg-cyan-500/18 py-2 text-xs font-black text-cyan-100 transition-colors hover:bg-cyan-500/28"
      >
        <Send size={14} />
        确认发送
      </button>
    </PanelSection>
  );
}

function ResourceControls({
  activeRole,
  stats,
  mecha,
  respawn,
  timeLeft,
  resourceQuantities,
  onResourceQuantitiesChange,
  hotkeys,
}) {
  const quantities = resourceQuantities ?? DEFAULT_RESOURCE_QUANTITIES;
  const {
    directCost,
    remoteCost,
    dead,
    healCost,
    reviveCost,
    canDirectAmmo,
    canRemoteAmmo,
    canHeal,
    canRevive,
    directAmmoOperation,
    remoteAmmoOperation,
    healOperation,
    reviveOperation,
  } = buildResourceActionState({
    activeRole,
    stats,
    mecha,
    respawn,
    timeLeft,
    quantities,
  });

  const updateQuantity = (key, fallback, nextValueOrUpdater) => {
    onResourceQuantitiesChange?.((prev) => {
      const source = prev ?? DEFAULT_RESOURCE_QUANTITIES;
      const previousValue = source[key] ?? fallback;
      const nextValue = typeof nextValueOrUpdater === 'function'
        ? nextValueOrUpdater(previousValue)
        : nextValueOrUpdater;
      return {
        ...source,
        [key]: nextValue,
      };
    });
  };

  const qty17 = quantities.qty17 ?? DEFAULT_RESOURCE_QUANTITIES.qty17;
  const qty42 = quantities.qty42 ?? DEFAULT_RESOURCE_QUANTITIES.qty42;
  const setQty17 = (value) => updateQuantity('qty17', DEFAULT_RESOURCE_QUANTITIES.qty17, value);
  const setQty42 = (value) => updateQuantity('qty42', DEFAULT_RESOURCE_QUANTITIES.qty42, value);

  const normalizeQty17 = () => setQty17((prev) => floorToStep(prev, 10));
  const normalizeQty42 = () => setQty42((prev) => floorToStep(prev, 5));
  const directAmmoHint = formatDoubleTapHint(hotkeys, 'directAmmo');
  const remoteAmmoHint = formatDoubleTapHint(hotkeys, 'remoteAmmo');
  const healHint = formatDoubleTapHint(hotkeys, 'heal');
  const reviveHint = formatDoubleTapHint(hotkeys, 'revive');

  const sendDirectAmmo = () => {
    if (!canDirectAmmo) return;
    sendOperation(directAmmoOperation, directAmmoOperation.command, directAmmoOperation.param);
  };

  const sendRemoteAmmo = () => {
    if (!canRemoteAmmo) return;
    sendOperation(remoteAmmoOperation, remoteAmmoOperation.command, remoteAmmoOperation.param);
  };

  return (
    <PanelSection title="资源与复活" icon={Box}>
      <div className="grid grid-cols-3 gap-2">
        <FieldValue label="ECO" value={stats?.eco ?? 0} accent="text-yellow-300" />
        <FieldValue label="AMMO" value={mecha?.ammo ?? 0} />
        <FieldValue label="REVIVE" value={respawn?.countdown ?? 0} />
      </div>

      <div className="mt-3 grid grid-cols-[1fr_72px] gap-2">
        {activeRole === 'infantry' ? (
          <>
            <IconButton disabled={!canDirectAmmo} onClick={sendDirectAmmo} icon={Crosshair}>
              {labelWithHotkey(`17mm兑换 · ${formatCost(directCost)}`, directAmmoHint)}
            </IconButton>
            <NumberInput value={qty17} min={10} step={10} onChange={setQty17} onBlur={normalizeQty17} />
          </>
        ) : (
          <>
            <IconButton disabled={!canDirectAmmo} onClick={sendDirectAmmo} icon={Crosshair}>
              {labelWithHotkey(`42mm兑换 · ${formatCost(directCost)}`, directAmmoHint)}
            </IconButton>
            <NumberInput value={qty42} min={5} step={5} onChange={setQty42} onBlur={normalizeQty42} />
          </>
        )}
      </div>

      <div className="mt-2 grid grid-cols-2 gap-2">
        <IconButton disabled={!canRemoteAmmo} onClick={sendRemoteAmmo} icon={Send}>
          {labelWithHotkey(`远程补弹 · ${formatCost(remoteCost)}`, remoteAmmoHint)}
        </IconButton>
        <IconButton disabled={!canHeal} onClick={() => sendOperation(healOperation, healOperation.command)} icon={Shield}>
          {labelWithHotkey(`买血 · ${formatCost(healCost)}`, healHint)}
        </IconButton>
        <IconButton disabled={!dead} onClick={() => sendOperation({ type: 'commonCommand', command: 'confirmRespawn', param: 0 }, 'confirmRespawn')} icon={RotateCw}>确认复活</IconButton>
        <IconButton disabled={!canRevive} onClick={() => sendOperation(reviveOperation, reviveOperation.command, reviveOperation.param)} icon={Zap}>
          {labelWithHotkey(`立即复活 · ${formatCost(reviveCost)}`, reviveHint)}
        </IconButton>
      </div>
    </PanelSection>
  );
}

function RespawnControls({ stats, mecha, respawn, timeLeft }) {
  const eco = toInt(stats?.eco);
  const dead = isRobotDead(mecha, respawn);
  const elapsedSec = Math.max(0, 420 - toNumber(timeLeft, 420));
  const reviveCost = Math.ceil(elapsedSec / 60) * 80 + parseRobotLevel(mecha) * 20;
  const canRevive = dead && reviveCost <= eco;

  const sendCommon = (command, param = 0) => {
    sendOperation({ type: 'commonCommand', command, param }, command, param);
  };

  return (
    <PanelSection title="复活" icon={RotateCw}>
      <div className="grid grid-cols-3 gap-2">
        <FieldValue label="ECO" value={eco} accent="text-yellow-300" />
        <FieldValue label="STATE" value={dead ? '待复活' : '存活'} accent={dead ? 'text-red-300' : 'text-emerald-300'} />
        <FieldValue label="REVIVE" value={respawn?.countdown ?? 0} />
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <IconButton disabled={!dead} onClick={() => sendCommon('confirmRespawn')} icon={RotateCw}>确认复活</IconButton>
        <IconButton disabled={!canRevive} onClick={() => sendCommon('buyRespawn', reviveCost)} icon={Zap}>
          立即复活 · {formatCost(reviveCost)}
        </IconButton>
      </div>
    </PanelSection>
  );
}

function EngineerControls({ stats, mecha, respawn, timeLeft, mechanisms, onAssemblyStart }) {
  const techCore = mechanisms?.techCore ?? {};
  const maxDifficulty = Math.max(0, Math.min(4, getTechCoreNumber(techCore, 'maximumDifficultyLevel', 'maximum_difficulty_level')));
  const [difficulty, setDifficulty] = useState(1);
  const selectedAvailable = difficulty > 0 && difficulty <= maxDifficulty;

  const startAssembly = () => {
    if (!selectedAvailable) return;
    onAssemblyStart?.(difficulty);
  };

  return (
    <>
      <RespawnControls stats={stats} mecha={mecha} respawn={respawn} timeLeft={timeLeft} />

      <PanelSection title="工程装配" icon={Box}>
        <div className="grid grid-cols-4 gap-2">
          {[1, 2, 3, 4].map((level) => {
            const available = level <= maxDifficulty;
            const selected = difficulty === level;
            return (
              <button
                type="button"
                key={level}
                disabled={!available}
                onClick={() => setDifficulty(level)}
                className={`flex min-h-10 items-center justify-center rounded border px-2 text-xs font-black transition-colors ${
                  !available
                    ? 'cursor-not-allowed border-slate-800 bg-slate-950/60 text-slate-600'
                    : selected
                      ? 'border-cyan-300 bg-cyan-500/24 text-cyan-50 shadow-[0_0_16px_rgba(34,211,238,0.18)]'
                      : 'border-cyan-500/45 bg-cyan-500/10 text-cyan-200 hover:bg-cyan-500/18'
                }`}
              >
                {level}级
              </button>
            );
          })}
        </div>

        <button
          type="button"
          disabled={!selectedAvailable}
          onClick={startAssembly}
          className={`mt-3 flex w-full items-center justify-center gap-2 rounded border py-2 text-xs font-black transition-colors ${
            selectedAvailable
              ? 'border-cyan-400/60 bg-cyan-500/18 text-cyan-100 hover:bg-cyan-500/28'
              : 'cursor-not-allowed border-slate-700 bg-slate-900/70 text-slate-500'
          }`}
        >
          <Send size={14} />
          确定开始装配
        </button>
      </PanelSection>
    </>
  );
}

function MechanismControls({ activeRole, heroDeploy, rune, mechanisms }) {
  const deployActive = Boolean(heroDeploy?.status);
  return (
    <PanelSection title="机制" icon={Activity}>
      {activeRole === 'hero' ? (
        <div className="grid grid-cols-2 gap-2">
          <FieldValue label="DEPLOY" value={deployActive ? '部署中' : '未部署'} accent={deployActive ? 'text-emerald-300' : 'text-slate-300'} />
          <FieldValue label="CORE" value={mechanisms?.techCore?.status ?? 0} />
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-2">
          <FieldValue label="RUNE" value={rune?.status ?? 0} />
          <FieldValue label="CORE" value={mechanisms?.techCore?.status ?? 0} />
        </div>
      )}

      <div className="mt-3 grid grid-cols-1 gap-2">
        {activeRole === 'hero' ? (
          <IconButton
            onClick={() => sendOperation({ type: 'heroDeploy', mode: deployActive ? 0 : 1 }, 'heroDeploy')}
            icon={Target}
          >
            切换部署
          </IconButton>
        ) : (
          <IconButton onClick={() => sendOperation({ type: 'runeActivate' }, 'runeActivate')} icon={Zap}>激活能量机关</IconButton>
        )}
      </div>
    </PanelSection>
  );
}

export default function CommandPanel({
  commandPanel,
  uiScale = 1,
  onCommandPanelOpenChange,
  controls,
  stats,
  mecha,
  respawn,
  timeLeft,
  performance,
  heroDeploy,
  rune,
  mechanisms,
  commandStatus,
  onAssemblyStart,
  resourceQuantities,
  onResourceQuantitiesChange,
  hotkeys,
}) {
  const open = Boolean(commandPanel?.open);
  const safeUiScale = Number(uiScale) > 0 ? Number(uiScale) : 1;
  const statusState = commandStatus?.state ?? 'idle';
  const robotContext = useMemo(() => resolveRobotContext(mecha, controls), [mecha, controls]);
  const activeRole = robotContext.role;
  const roleMeta = ROLE_META[activeRole] ?? ROLE_META.unknown;
  const RoleIcon = roleMeta.icon;

  const toggleOpen = () => {
    const nextOpen = !open;
    onCommandPanelOpenChange?.(nextOpen);
    emitGodotOperation({ type: 'setCommandPanelOpen', open: nextOpen }, '[commandPanel] toggle');
  };

  return (
    <div
      className="pointer-events-none fixed right-4 top-1/2 z-50 flex -translate-y-1/2 items-center gap-3 font-sans text-white"
      style={{ transform: `scale(${safeUiScale})`, transformOrigin: 'center right' }}
    >
      {open && robotContext.supported && (
        <div className="pointer-events-auto max-h-[82vh] w-[390px] overflow-y-auto rounded-lg border border-slate-700 bg-slate-950/94 p-3 shadow-[0_0_34px_rgba(0,0,0,0.72)] backdrop-blur">
          <div className="mb-3 flex items-center justify-between gap-2 border-b border-slate-800 pb-3">
            <div className="flex min-w-0 items-center gap-2">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded border border-cyan-400/45 bg-cyan-500/12 text-cyan-200">
                <RoleIcon size={16} />
              </div>
              <div className="min-w-0">
                <div className="text-[10px] font-black uppercase tracking-wider text-slate-500">{roleMeta.label}</div>
                <div className="truncate font-mono text-xs font-black tracking-wider text-cyan-100">{robotContext.displayName}</div>
              </div>
            </div>
            <div className={`rounded border px-2 py-1 text-[10px] font-black uppercase tracking-wider ${
              statusState === 'failed' ? 'border-red-500/50 text-red-300' : statusState === 'success' ? 'border-emerald-500/50 text-emerald-300' : statusState === 'pending' ? 'border-yellow-500/50 text-yellow-300' : 'border-slate-700 text-slate-400'
            }`}>
              {statusState}
            </div>
          </div>

          {activeRole === 'engineer' ? (
            <div className="space-y-3">
              <EngineerControls
                stats={stats}
                mecha={mecha}
                respawn={respawn}
                timeLeft={timeLeft}
                mechanisms={mechanisms}
                onAssemblyStart={onAssemblyStart}
              />
            </div>
          ) : (
            <div className="space-y-3">
              <PerformanceControls activeRole={activeRole} controls={controls} performance={performance} />
              <ResourceControls
                activeRole={activeRole}
                stats={stats}
                mecha={mecha}
                respawn={respawn}
                timeLeft={timeLeft}
                resourceQuantities={resourceQuantities}
                onResourceQuantitiesChange={onResourceQuantitiesChange}
                hotkeys={hotkeys}
              />
              <MechanismControls activeRole={activeRole} heroDeploy={heroDeploy} rune={rune} mechanisms={mechanisms} />
            </div>
          )}
        </div>
      )}

      <button
        type="button"
        onClick={toggleOpen}
        className={`pointer-events-auto flex h-12 w-12 items-center justify-center rounded-full border border-cyan-400/45 text-cyan-100 shadow-[0_0_20px_rgba(34,211,238,0.14)] transition-colors ${
          open ? 'bg-slate-950/86 opacity-100 hover:bg-cyan-500/18' : 'bg-slate-950/28 opacity-35 hover:bg-slate-950/60 hover:opacity-80'
        }`}
        aria-label="toggle command panel"
      >
        {open ? <ChevronRight size={22} /> : <ChevronLeft size={22} />}
      </button>
    </div>
  );
}
