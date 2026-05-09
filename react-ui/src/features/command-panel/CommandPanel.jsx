import { useMemo, useState } from 'react';
import {
  Activity,
  Box,
  ChevronLeft,
  ChevronRight,
  Crosshair,
  Plane,
  RadioTower,
  RotateCw,
  Send,
  Shield,
  Target,
  Zap,
} from 'lucide-react';
import { emitGodotOperation } from '../../bridge/godot';

const ROLE_OPTIONS = [
  { role: 'infantry', label: '步兵', icon: Crosshair },
  { role: 'hero', label: '英雄', icon: Zap },
  { role: 'sentry', label: '哨兵', icon: RadioTower },
];

const DART_TARGETS = [
  { value: 1, label: '前哨站' },
  { value: 2, label: '基地固定' },
  { value: 3, label: '基地随机固定' },
  { value: 4, label: '基地随机移动' },
  { value: 5, label: '基地末端移动' },
];

const SENTRY_COMMANDS = [
  { commandId: 1, label: '补血点补弹' },
  { commandId: 2, label: '补给站补弹' },
  { commandId: 3, label: '远程补弹' },
  { commandId: 4, label: '远程回血' },
  { commandId: 5, label: '确认复活' },
  { commandId: 6, label: '金币复活' },
  { commandId: 8, label: '进攻姿态' },
  { commandId: 9, label: '防御姿态' },
];

function sendOperation(operation, label, value) {
  emitGodotOperation(operation, `[hudOperate] ${label}`, value);
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
  const [sentry, setSentry] = useState(defaults.sentry);

  const submit = () => {
    if (activeRole === 'sentry') {
      sendOperation({
        type: 'performanceSelection',
        role: 'sentry',
        sentryMode: sentry.mode,
      }, 'performanceSelection');
      return;
    }

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

      {activeRole === 'sentry' && (
        <div className="mt-3 grid grid-cols-2 gap-2">
          <IconButton active={sentry.mode === 'auto'} onClick={() => setSentry({ mode: 'auto' })} icon={RadioTower}>自动</IconButton>
          <IconButton active={sentry.mode === 'semi'} onClick={() => setSentry({ mode: 'semi' })} icon={Target}>半自动</IconButton>
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

function ResourceControls({ activeRole, stats, mecha, respawn }) {
  const [qty17, setQty17] = useState(10);
  const [qty42, setQty42] = useState(1);

  const sendCommon = (command, param = 0) => {
    sendOperation({ type: 'commonCommand', command, param }, command, param);
  };

  return (
    <PanelSection title="资源与复活" icon={Box}>
      <div className="grid grid-cols-3 gap-2">
        <FieldValue label="ECO" value={stats?.eco ?? 0} accent="text-yellow-300" />
        <FieldValue label="AMMO" value={mecha?.ammo ?? 0} />
        <FieldValue label="REVIVE" value={respawn?.countdown ?? 0} />
      </div>

      <div className="mt-3 grid grid-cols-[1fr_72px] gap-2">
        <IconButton onClick={() => sendCommon('exchange17mm', qty17)} icon={Crosshair}>17mm兑换</IconButton>
        <input className="rounded border border-slate-700 bg-slate-950 px-2 text-center font-mono text-xs text-slate-100" type="number" min="10" step="10" value={qty17} onChange={(event) => setQty17(Number(event.target.value))} />
        <IconButton onClick={() => sendCommon('exchange42mm', qty42)} icon={Crosshair}>42mm兑换</IconButton>
        <input className="rounded border border-slate-700 bg-slate-950 px-2 text-center font-mono text-xs text-slate-100" type="number" min="1" step="1" value={qty42} onChange={(event) => setQty42(Number(event.target.value))} />
      </div>

      <div className="mt-2 grid grid-cols-2 gap-2">
        <IconButton onClick={() => sendCommon('remoteBuyAmmo', activeRole === 'hero' ? 10 : 100)} icon={Send}>远程补弹</IconButton>
        <IconButton onClick={() => sendCommon('remoteBuyHp')} icon={Shield}>远程回血</IconButton>
        <IconButton onClick={() => sendCommon('confirmRespawn')} icon={RotateCw}>确认复活</IconButton>
        <IconButton onClick={() => sendCommon('buyRespawn')} icon={Zap}>立即复活</IconButton>
      </div>
    </PanelSection>
  );
}

function MechanismControls({ activeRole, heroDeploy, rune, mechanisms }) {
  return (
    <PanelSection title="机制" icon={Activity}>
      <div className="grid grid-cols-3 gap-2">
        <FieldValue label="DEPLOY" value={heroDeploy?.status ?? 0} />
        <FieldValue label="RUNE" value={rune?.status ?? 0} />
        <FieldValue label="CORE" value={mechanisms?.techCore?.status ?? 0} />
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <IconButton
          disabled={activeRole !== 'hero'}
          onClick={() => sendOperation({ type: 'heroDeploy', mode: heroDeploy?.status ? 0 : 1 }, 'heroDeploy')}
          icon={Target}
        >
          {heroDeploy?.status ? '退出部署' : '进入部署'}
        </IconButton>
        <IconButton onClick={() => sendOperation({ type: 'runeActivate' }, 'runeActivate')} icon={Zap}>激活能量机关</IconButton>
        <IconButton onClick={() => sendOperation({ type: 'assembly', operation: 1, difficulty: 1 }, 'assembly')} icon={Box}>装配确认</IconButton>
      </div>
    </PanelSection>
  );
}

function SentryAndAirControls({ sentry, dart, airSupport }) {
  const [dartTarget, setDartTarget] = useState(dart?.targetId ?? 1);

  const sendDart = (open, launchConfirm = false) => {
    sendOperation({
      type: 'dart',
      targetId: Number(dartTarget),
      open,
      launchConfirm,
    }, 'dart', dartTarget);
  };

  return (
    <>
      <PanelSection title="飞镖" icon={Target}>
        <div className="grid grid-cols-3 gap-2">
          <FieldValue label="TARGET" value={dart?.targetId ?? 1} />
          <FieldValue label="GATE" value={dart?.open ? 'OPEN' : 'CLOSED'} accent={dart?.open ? 'text-emerald-300' : 'text-slate-300'} />
          <FieldValue label="POSTURE" value={sentry?.postureId ?? 0} />
        </div>
        <select
          className="mt-3 w-full rounded border border-slate-700 bg-slate-950 px-2 py-2 text-xs text-slate-100"
          value={dartTarget}
          onChange={(event) => setDartTarget(Number(event.target.value))}
        >
          {DART_TARGETS.map((item) => (
            <option key={item.value} value={item.value}>{item.value} - {item.label}</option>
          ))}
        </select>
        <div className="mt-2 grid grid-cols-3 gap-2">
          <IconButton onClick={() => sendDart(true)} icon={ChevronRight}>开闸</IconButton>
          <IconButton onClick={() => sendDart(false)} icon={ChevronLeft}>关闸</IconButton>
          <IconButton onClick={() => sendDart(false, true)} icon={Send}>发射</IconButton>
        </div>
      </PanelSection>

      <PanelSection title="哨兵与空中支援" icon={Plane}>
        <div className="grid grid-cols-3 gap-2">
          <FieldValue label="AIR" value={airSupport?.status ?? 0} />
          <FieldValue label="FREE" value={`${airSupport?.leftTime ?? 0}s`} />
          <FieldValue label="COST" value={airSupport?.costCoins ?? 0} accent="text-yellow-300" />
        </div>
        <div className="mt-3 grid grid-cols-2 gap-2">
          {SENTRY_COMMANDS.map((item) => (
            <IconButton key={item.commandId} onClick={() => sendOperation({ type: 'sentryCommand', commandId: item.commandId }, 'sentryCommand', item.commandId)}>
              {item.commandId}. {item.label}
            </IconButton>
          ))}
          <IconButton onClick={() => sendOperation({ type: 'airSupport', commandId: 1 }, 'airSupport', 1)} icon={Plane}>免费支援</IconButton>
          <IconButton onClick={() => sendOperation({ type: 'airSupport', commandId: 2 }, 'airSupport', 2)} icon={Plane}>付费支援</IconButton>
          <IconButton onClick={() => sendOperation({ type: 'airSupport', commandId: 3 }, 'airSupport', 3)} icon={Shield}>中断支援</IconButton>
        </div>
      </PanelSection>
    </>
  );
}

export default function CommandPanel({
  controls,
  stats,
  mecha,
  respawn,
  performance,
  heroDeploy,
  rune,
  sentry,
  dart,
  airSupport,
  mechanisms,
  commandStatus,
}) {
  const [open, setOpen] = useState(false);
  const [activeRole, setActiveRole] = useState(controls?.activeRole ?? 'infantry');
  const statusState = commandStatus?.state ?? 'idle';

  return (
    <div className="pointer-events-none fixed right-4 top-1/2 z-50 flex -translate-y-1/2 items-center gap-3 font-sans text-white">
      {open && (
        <div className="pointer-events-auto max-h-[82vh] w-[390px] overflow-y-auto rounded-lg border border-slate-700 bg-slate-950/94 p-3 shadow-[0_0_34px_rgba(0,0,0,0.72)] backdrop-blur">
          <div className="mb-3 flex items-center justify-between gap-2 border-b border-slate-800 pb-3">
            <div className="flex gap-1.5">
              {ROLE_OPTIONS.map((item) => (
                <IconButton key={item.role} active={activeRole === item.role} onClick={() => setActiveRole(item.role)} icon={item.icon}>
                  {item.label}
                </IconButton>
              ))}
            </div>
            <div className={`rounded border px-2 py-1 text-[10px] font-black uppercase tracking-wider ${
              statusState === 'failed' ? 'border-red-500/50 text-red-300' : statusState === 'success' ? 'border-emerald-500/50 text-emerald-300' : statusState === 'pending' ? 'border-yellow-500/50 text-yellow-300' : 'border-slate-700 text-slate-400'
            }`}>
              {statusState}
            </div>
          </div>

          <div className="space-y-3">
            <PerformanceControls activeRole={activeRole} controls={controls} performance={performance} />
            <ResourceControls activeRole={activeRole} stats={stats} mecha={mecha} respawn={respawn} />
            <MechanismControls activeRole={activeRole} heroDeploy={heroDeploy} rune={rune} mechanisms={mechanisms} />
            {activeRole === 'sentry' && <SentryAndAirControls sentry={sentry} dart={dart} airSupport={airSupport} />}
          </div>
        </div>
      )}

      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        className="pointer-events-auto flex h-12 w-12 items-center justify-center rounded-full border border-cyan-400/55 bg-slate-950/86 text-cyan-100 shadow-[0_0_20px_rgba(34,211,238,0.18)] transition-colors hover:bg-cyan-500/18"
        aria-label="toggle command panel"
      >
        {open ? <ChevronRight size={22} /> : <ChevronLeft size={22} />}
      </button>
    </div>
  );
}
