import {
  Activity,
  AlertTriangle,
  Cpu,
  Flag,
  HelpCircle,
  Lock,
  RadioTower,
  RefreshCcw,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Skull,
  Timer,
  Wifi,
  WifiOff,
  Zap,
} from 'lucide-react';
import { resolveUiSizing, toPercent } from '../../state';

const BASE_STATUS_META = {
  0: {
    label: '无敌',
    Icon: ShieldCheck,
    className: 'border-yellow-400/35 bg-yellow-400/10 text-yellow-300',
  },
  1: {
    label: '护甲未展开',
    Icon: Shield,
    className: 'border-white/15 bg-white/5 text-white/65',
  },
  2: {
    label: '护甲展开',
    Icon: ShieldAlert,
    className: 'border-orange-400/55 bg-orange-500/15 text-orange-300 shadow-[0_0_10px_rgba(251,146,60,0.28)]',
    pulse: true,
  },
};

const OUTPOST_STATUS_META = {
  0: {
    label: '无敌',
    Icon: ShieldCheck,
    className: 'border-yellow-400/35 bg-yellow-400/10 text-yellow-300',
  },
  1: {
    label: '旋转',
    Icon: RefreshCcw,
    className: 'border-emerald-400/35 bg-emerald-400/10 text-emerald-300',
    spin: true,
  },
  2: {
    label: '停转',
    Icon: AlertTriangle,
    className: 'border-red-500/55 bg-red-500/15 text-red-300 shadow-[0_0_10px_rgba(239,68,68,0.22)]',
    pulse: true,
  },
  3: {
    label: '已摧毁',
    Icon: Skull,
    className: 'border-neutral-700 bg-neutral-950/85 text-neutral-500',
  },
  4: {
    label: '可重建',
    Icon: Zap,
    className: 'border-yellow-400/45 bg-yellow-400/10 text-yellow-300',
  },
  5: {
    label: '重建中',
    Icon: Activity,
    className: 'border-cyan-400/40 bg-cyan-400/10 text-cyan-300',
    pulse: true,
  },
};

const DEFAULT_LINKS = [
  { name: 'MQTT', status: 'ok' },
  { name: 'VIDEO', status: 'ok' },
  { name: 'DATA', status: 'ok' },
];
const FORTRESS_CAPTURE_DURATION_SEC = 20;
const ROBOT_SLOT_ORDER = {
  red: [7, 6, 4, 3, 2, 1],
  blue: [1, 2, 3, 4, 6, 7],
};
const ROBOT_FALLBACK_MAX_HP = {
  1: 2000,
  2: 400,
  3: 400,
  4: 400,
  6: 500,
  7: 600,
};
const ENEMY_PROJECTILE_KEY_BY_ROBOT_ID = {
  1: 'hero1',
  3: 'infantry3',
  4: 'infantry4',
  6: 'aerial6',
  7: 'sentry7',
};

function resolveStatusMeta(type, state, configuredStates, fallbackStates) {
  const builtin = type === 'base' ? BASE_STATUS_META : OUTPOST_STATUS_META;
  const meta = builtin[state];
  if (meta) return meta;

  const configured = configuredStates?.[state] ?? fallbackStates?.[state] ?? configuredStates?.default ?? fallbackStates?.default;
  if (configured?.label) {
    return {
      label: configured.label,
      Icon: HelpCircle,
      className: 'border-neutral-600/70 bg-neutral-900/70 text-neutral-300',
      spin: !!configured.spin,
    };
  }

  return {
    label: '未知',
    Icon: HelpCircle,
    className: 'border-neutral-600/70 bg-neutral-900/70 text-neutral-300',
  };
}

function StateBadge({ type, state, states, fallbackStates }) {
  const meta = resolveStatusMeta(type, state, states, fallbackStates);
  const Icon = meta.Icon;

  return (
    <div
      className={`flex h-5 items-center gap-1 rounded border px-1.5 text-[9px] font-black leading-none tracking-wider whitespace-nowrap ${meta.className} ${meta.pulse ? 'animate-pulse' : ''}`}
    >
      <Icon size={11} className={meta.spin ? 'animate-spin' : ''} />
      <span>{meta.label}</span>
    </div>
  );
}


function SegmentedBar({
  value,
  maxValue,
  segmentSize = 500,
  colorClass,
  align = 'left',
  className = '',
}) {
  const safeMax = Number(maxValue) > 0 ? Number(maxValue) : 1;
  const safeSegment = Number(segmentSize) > 0 ? Number(segmentSize) : safeMax;
  const segmentCount = Math.max(1, Math.ceil(safeMax / safeSegment));
  const safeValue = Math.max(0, Number(value) || 0);

  return (
    <div
      className={`flex w-full gap-[2px] rounded-sm border border-white/10 bg-black/60 p-[2px] ${align === 'right' ? 'flex-row-reverse' : 'flex-row'} ${className}`}
    >
      {Array.from({ length: segmentCount }).map((_, index) => {
        const segmentStart = index * safeSegment;
        const segmentEnd = Math.min((index + 1) * safeSegment, safeMax);
        let fill = 0;
        if (safeValue >= segmentEnd) fill = 100;
        else if (safeValue > segmentStart) fill = ((safeValue - segmentStart) / (segmentEnd - segmentStart)) * 100;

        return (
          <div key={index} className="relative min-w-[4px] flex-1 overflow-hidden rounded-[1px] bg-white/7">
            <div
              className={`absolute inset-y-0 ${align === 'right' ? 'right-0' : 'left-0'} ${colorClass} transition-all duration-300`}
              style={{ width: `${fill}%` }}
            />
          </div>
        );
      })}
    </div>
  );
}

function BackgroundSegmentedBar({
  value,
  maxValue,
  segmentSize = 1000,
  team,
  align = 'left',
}) {
  const isRed = team === 'red';
  const safeMax = Number(maxValue) > 0 ? Number(maxValue) : 1;
  const safeSegment = Number(segmentSize) > 0 ? Number(segmentSize) : safeMax;
  const segmentCount = Math.max(1, Math.ceil(safeMax / safeSegment));
  const safeValue = Math.max(0, Number(value) || 0);
  const fillColor = isRed ? 'bg-red-600/35' : 'bg-blue-600/35';
  const edgeGlow = isRed
    ? 'bg-red-300 shadow-[0_0_12px_rgba(252,165,165,0.9)]'
    : 'bg-blue-300 shadow-[0_0_12px_rgba(147,197,253,0.9)]';

  return (
    <div className={`absolute inset-0 z-0 flex gap-[3px] bg-black/55 p-[3px] ${align === 'right' ? 'flex-row-reverse' : 'flex-row'}`}>
      {Array.from({ length: segmentCount }).map((_, index) => {
        const segmentStart = index * safeSegment;
        const segmentEnd = Math.min((index + 1) * safeSegment, safeMax);
        let fill = 0;
        if (safeValue >= segmentEnd) fill = 100;
        else if (safeValue > segmentStart) fill = ((safeValue - segmentStart) / (segmentEnd - segmentStart)) * 100;

        return (
          <div key={index} className="relative h-full flex-1 overflow-hidden rounded-[2px] bg-white/5">
            <div
              className={`absolute inset-y-0 ${align === 'right' ? 'right-0' : 'left-0'} ${fillColor} transition-all duration-300 ease-out`}
              style={{ width: `${fill}%` }}
            >
              {fill > 0 && fill < 100 && (
                <div className={`absolute inset-y-0 ${align === 'right' ? 'left-0' : 'right-0'} w-[3px] ${edgeGlow}`} />
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function formatNullableNumber(value) {
  const numeric = Number(value);
  return value == null || !Number.isFinite(numeric) ? '--' : `${Math.trunc(numeric)}`;
}

function formatPacketAge(lastUpdateMs) {
  const numeric = Number(lastUpdateMs);
  if (!Number.isFinite(numeric) || numeric <= 0) return '--';
  const ageSec = Math.max(0, (Date.now() - numeric) / 1000);
  return `${ageSec.toFixed(ageSec < 10 ? 1 : 0)}s`;
}

function isEnemyTeam(team, clientTeam) {
  return (clientTeam === 'red' && team === 'blue') || (clientTeam === 'blue' && team === 'red');
}

function resolveEnemyAmmo(robot, team, clientTeam, enemyAux) {
  if (!isEnemyTeam(team, clientTeam)) return undefined;
  const key = ENEMY_PROJECTILE_KEY_BY_ROBOT_ID[Number(robot?.id)];
  if (!key) return undefined;
  const packet = enemyAux?.lastPacket;
  if (!packet?.validAmmo) return null;
  return packet.enemyProjectile?.[key] ?? null;
}

function ensureRobotSlots(robots, team) {
  const order = ROBOT_SLOT_ORDER[team] ?? [];
  const sourceRobots = Array.isArray(robots) ? robots : [];
  const byId = new Map(sourceRobots.map((robot) => [Number(robot.id), robot]));
  const ordered = order.map((id) => {
    const robot = byId.get(id);
    if (robot) return robot;
    return {
      id,
      hp: null,
      max: ROBOT_FALLBACK_MAX_HP[id] ?? 1,
      isOffline: true,
    };
  });

  sourceRobots.forEach((robot) => {
    if (!order.includes(Number(robot.id))) ordered.push(robot);
  });

  return ordered;
}

function LinkStatus({ name, status = 'ok', outdated = false }) {
  const isOk = status === 'ok' && !outdated;
  const isWarning = status === 'warning' || outdated;
  const Icon = isOk ? Wifi : WifiOff;
  const className = isOk
    ? 'border-neutral-500/80 bg-neutral-950/75 text-neutral-300 shadow-[0_4px_12px_rgba(0,0,0,0.35)]'
    : isWarning
      ? 'border-yellow-500/65 bg-yellow-950/55 text-yellow-200 shadow-[0_4px_12px_rgba(113,63,18,0.32)]'
      : 'border-red-500/75 bg-red-950/60 text-red-200 shadow-[0_4px_12px_rgba(127,29,29,0.35)] animate-pulse';

  return (
    <div className={`flex h-5 items-center gap-1.5 rounded border px-2 text-[9px] font-black tracking-widest ${className}`}>
      <Icon size={10} />
      <span>{name}</span>
      {outdated && <span className="rounded bg-yellow-500/20 px-1 text-[8px] text-yellow-200">DELAY</span>}
    </div>
  );
}

function BuildingCard({
  type,
  team,
  label,
  hp,
  maxHp,
  shield,
  maxShield,
  state,
  stateMeta,
  fallbackStateMeta,
}) {
  const isRed = team === 'red';
  const align = isRed ? 'left' : 'right';
  const widthClass = type === 'base' ? 'min-w-[260px] flex-1' : 'w-[160px] shrink-0';
  const hpSegmentSize = type === 'base' ? 500 : 200;
  const safeShield = Math.max(0, Number(shield) || 0);
  const showShield = type === 'base' && safeShield > 0;
  const shieldPercent = showShield ? Math.min(100, (safeShield / Math.max(1, Number(maxShield) || 1)) * 100) : 0;

  return (
    <div
      className={`relative flex ${type === 'base' ? 'h-[66px] px-3' : 'h-[62px] px-2.5'} flex-col justify-center overflow-hidden rounded-lg border border-white/10 bg-neutral-950/80 py-0 shadow-[0_8px_18px_rgba(0,0,0,0.34)] backdrop-blur-md ${widthClass} ${align === 'right' ? 'items-end' : 'items-start'}`}
    >
      <BackgroundSegmentedBar
        value={hp}
        maxValue={maxHp}
        segmentSize={hpSegmentSize}
        team={team}
        align={align}
      />
      {showShield && (
        <div
          className={`absolute top-0 z-10 h-[5px] ${align === 'right' ? 'right-0' : 'left-0'} bg-cyan-400 shadow-[0_0_12px_rgba(34,211,238,0.95)] transition-all duration-300 ease-out`}
          style={{ width: `${shieldPercent}%` }}
        />
      )}
      <div className={`relative z-20 flex w-full items-center justify-between gap-2 ${type === 'base' ? 'px-0' : ''} ${align === 'right' ? 'flex-row-reverse' : ''}`}>
        <div className={`flex min-w-0 ${
          type === 'base'
            ? `items-center gap-1.5 ${align === 'right' ? 'flex-row-reverse' : ''}`
            : `flex-col gap-1 ${align === 'right' ? 'items-end' : 'items-start'}`
        }`}>
          <span className={`whitespace-nowrap font-black tracking-[0.18em] uppercase drop-shadow-[0_2px_4px_rgba(0,0,0,0.9)] ${type === 'base' ? 'text-[12px] text-white' : 'text-[10px] text-white/80'}`}>{label}</span>
          <StateBadge type={type} state={state} states={stateMeta} fallbackStates={fallbackStateMeta} />
        </div>
        <div className={`flex items-baseline gap-2 ${align === 'right' ? 'flex-row' : 'flex-row-reverse'}`}>
          <span className={`font-orbitron font-black leading-none drop-shadow-[0_3px_6px_rgba(0,0,0,0.9)] ${type === 'base' ? `text-[28px] ${isRed ? 'text-red-100' : 'text-blue-100'}` : `text-[22px] ${isRed ? 'text-red-100' : 'text-blue-100'}`}`}>
            {Math.max(0, Number(hp) || 0)}
          </span>
          {showShield && (
            <span className="font-orbitron text-[16px] font-black leading-none text-cyan-200 drop-shadow-[0_1px_3px_rgba(0,0,0,0.9)]">
              SH {safeShield}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

function ScoreTimeCore({ roundLabel, match, timeLeft, scores }) {
  const countdownValid = match?.countdownValid !== false;
  const seconds = Math.max(0, Number(timeLeft) || 0);
  const minutesText = Math.floor(seconds / 60).toString().padStart(2, '0');
  const secondsText = (seconds % 60).toString().padStart(2, '0');
  const paused = !!match?.isPaused;
  const stageLabel = paused ? '暂停' : (match?.stageLabel ?? '比赛中');

  return (
    <div className="flex min-w-[286px] flex-col items-center gap-1">
      <div className={`flex h-6 items-center gap-3 rounded-full border px-5 backdrop-blur-md ${paused ? 'border-orange-500/45 bg-orange-500/10 text-orange-300' : 'border-cyan-400/25 bg-neutral-950/70 text-cyan-300'}`}>
        <span className="text-[10px] font-black tracking-wider text-white/65">{roundLabel}</span>
        <span className="h-1 w-1 rounded-full bg-white/25" />
        <span className="text-[10px] font-black tracking-widest">{stageLabel}</span>
      </div>

      <div className="flex items-center justify-center gap-5">
        <span className="font-orbitron text-[34px] font-black leading-none text-red-500 drop-shadow-[0_0_8px_rgba(239,68,68,0.28)]">
          {scores.left}
        </span>
        <div className={`flex h-[50px] w-[135px] items-center justify-center rounded-lg border bg-neutral-950/78 shadow-[0_8px_18px_rgba(0,0,0,0.35)] backdrop-blur-md ${paused ? 'border-orange-500/45' : 'border-white/10'}`}>
          <div className={`font-orbitron text-[32px] font-black leading-none tracking-widest ${paused ? 'text-orange-300' : 'text-white'}`}>
            {countdownValid ? minutesText : '--'}
            <span className={paused ? 'text-orange-400' : 'text-cyan-300'}>:</span>
            {countdownValid ? secondsText : '--'}
          </div>
        </div>
        <span className="font-orbitron text-[34px] font-black leading-none text-blue-500 drop-shadow-[0_0_8px_rgba(59,130,246,0.28)]">
          {scores.right}
        </span>
      </div>
    </div>
  );
}

function effectTimeById(effects, effectId) {
  if (!Array.isArray(effects)) return 0;
  const effect = effects.find((item) => Number(item?.id) === Number(effectId));
  return Math.max(0, Number(effect?.remainingSec ?? effect?.remaining_sec) || 0);
}

function fortressTeamByMechanismId(mechanismId, clientTeam) {
  const ownTeam = clientTeam === 'blue' ? 'blue' : 'red';
  const enemyTeam = ownTeam === 'blue' ? 'red' : 'blue';
  if (Number(mechanismId) === 1) return ownTeam;
  if (Number(mechanismId) === 2) return enemyTeam;
  return null;
}

function FortressCard({ team, label, captureSec }) {
  const isRed = team === 'red';
  const progress = Math.max(
    0,
    Math.min(100, ((FORTRESS_CAPTURE_DURATION_SEC - captureSec) / FORTRESS_CAPTURE_DURATION_SEC) * 100),
  );
  const fillClass = isRed ? 'bg-red-400/70' : 'bg-blue-400/70';
  const toneClass = isRed
    ? 'border-red-400/45 bg-red-950/40 text-red-100 shadow-[0_0_16px_rgba(248,113,113,0.18)]'
    : 'border-blue-400/45 bg-blue-950/40 text-blue-100 shadow-[0_0_16px_rgba(96,165,250,0.18)]';

  return (
    <div className={`relative h-[42px] w-[190px] overflow-hidden rounded-md border px-3 py-2 backdrop-blur-md ${toneClass}`}>
      <div
        className={`absolute bottom-0 top-0 ${isRed ? 'left-0' : 'right-0'} opacity-25 transition-all duration-300 ${fillClass}`}
        style={{ width: `${progress}%` }}
      />
      <div className="relative z-10 flex h-full items-center justify-between gap-2">
        <div className="flex min-w-0 items-center gap-1.5">
          <Flag size={13} className={isRed ? 'text-red-300' : 'text-blue-300'} />
          <span className="truncate text-[10px] font-black tracking-[0.16em]">{label}</span>
        </div>
        <div className="flex shrink-0 items-center gap-1.5">
          <Timer size={12} className="text-yellow-200" />
          <span className="text-[9px] font-black tracking-wider text-yellow-100">占领中</span>
          <span className="font-orbitron text-[11px] font-black">{Math.ceil(captureSec)}s</span>
        </div>
      </div>
    </div>
  );
}

function FortressStatusRow({ mechanisms, clientTeam }) {
  const effects = mechanisms?.fortress?.effects ?? mechanisms?.effects;
  const fortressItems = [1, 2].reduce((items, mechanismId) => {
    const captureSec = effectTimeById(effects, mechanismId);
    const team = fortressTeamByMechanismId(mechanismId, clientTeam);
    if (!team || captureSec <= 0) return items;
    items.push({
      team,
      captureSec,
      label: team === 'red' ? '红方堡垒' : '蓝方堡垒',
    });
    return items;
  }, []).sort((left, right) => (left.team === right.team ? 0 : left.team === 'red' ? -1 : 1));

  if (fortressItems.length === 0) return null;

  return (
    <div className="mt-1.5 flex items-center justify-center gap-2">
      {fortressItems.map((item) => (
        <FortressCard
          key={item.team}
          team={item.team}
          label={item.label}
          captureSec={item.captureSec}
        />
      ))}
    </div>
  );
}

function RobotSlot({ robot, team, level, ammo, ammoStale = false }) {
  const isRed = team === 'red';
  const maxHp = Number(robot.max ?? robot.maxHp) > 0 ? Number(robot.max ?? robot.maxHp) : 1;
  const hasHp = robot.hp != null && Number.isFinite(Number(robot.hp));
  const hp = hasHp ? Number(robot.hp) : null;
  const hpPercent = hasHp ? toPercent(hp, maxHp) : 0;
  const isDead = hp === 0 || robot.aliveState === 2 || robot.status === 'dead';
  const isOffline = !hasHp || robot.isOffline || robot.status === 'offline';
  const isLow = hasHp && !isDead && hpPercent < 30;
  const isReviveHighlighted = !isDead && !isOffline && Number(robot.reviveHighlightUntil) > 0;
  const tags = Array.isArray(robot.tags) ? robot.tags : [];
  const safeLevel = Number(level ?? robot.level);
  const levelLabel = Number.isFinite(safeLevel) && safeLevel > 0 ? `LV.${Math.trunc(safeLevel)}` : 'LV.--';
  const fillClass = isRed ? 'bg-red-600/40' : 'bg-blue-600/40';
  const edgeGlow = isRed
    ? 'bg-red-400 shadow-[0_0_8px_rgba(248,113,113,0.95)]'
    : 'bg-blue-400 shadow-[0_0_8px_rgba(96,165,250,0.95)]';

  const cardClass = isDead
    ? 'border-neutral-800/80 bg-neutral-950/90 text-neutral-500 grayscale'
    : isOffline
      ? 'border-neutral-700 bg-neutral-950/70 text-neutral-500'
      : isLow
        ? 'border-red-500/80 bg-neutral-950/82 text-red-300 shadow-[0_0_12px_rgba(239,68,68,0.28)] animate-pulse'
        : 'border-white/10 bg-neutral-950/80 text-white/90';
  const reviveClass = isReviveHighlighted
    ? 'border-emerald-300/90 bg-emerald-950/45 text-emerald-100 shadow-[0_0_18px_rgba(52,211,153,0.45)] ring-1 ring-emerald-300/70 animate-pulse'
    : '';
  const showAmmo = ammo !== undefined;
  const ammoClass = ammoStale
    ? 'text-white/25'
    : isRed
      ? 'text-red-100/85'
      : 'text-blue-100/85';

  return (
    <div className={`relative h-[52px] min-w-[75px] flex-1 overflow-hidden rounded-md border backdrop-blur-md transition-all duration-300 ${cardClass} ${reviveClass}`}>
      {!isDead && !isOffline && (
        <div
          className={`absolute inset-y-0 left-0 z-0 transition-all duration-300 ease-out ${fillClass}`}
          style={{ width: `${hpPercent}%` }}
        >
          {hpPercent > 0 && hpPercent < 100 && (
            <div className={`absolute inset-y-0 right-0 w-[2px] ${edgeGlow}`} />
          )}
        </div>
      )}
      <div className="relative z-10 flex h-full flex-col justify-between px-2 py-1.5">
        <div className="flex items-start justify-between gap-1">
          <div className="flex items-center gap-1.5">
            <span className={`font-orbitron text-[14px] font-black leading-none drop-shadow-[0_2px_4px_rgba(0,0,0,0.75)] ${isDead || isOffline ? 'text-neutral-500' : 'text-white/80'}`}>
              {robot.id}
            </span>
            <span className={`rounded border px-1 py-[1px] font-orbitron text-[8px] font-black leading-none ${isDead || isOffline ? 'border-neutral-700 bg-black/35 text-neutral-500' : isRed ? 'border-red-300/30 bg-red-950/45 text-red-100' : 'border-blue-300/30 bg-blue-950/45 text-blue-100'}`}>
              {levelLabel}
            </span>
          </div>
          <div className="flex max-w-[52px] flex-col items-end gap-[2px]">
            {isDead && <Skull size={13} className="text-neutral-500" />}
            {robot.outdated && <span className="rounded bg-yellow-500/20 px-1 text-[7px] font-black leading-none text-yellow-300">OLD</span>}
            {tags.slice(0, 2).map((tag) => (
              <span key={tag} className="rounded bg-black/35 px-1 text-[7px] font-black leading-none text-white/75 shadow-[0_1px_3px_rgba(0,0,0,0.45)]">
                {tag}
              </span>
            ))}
          </div>
        </div>

        <div className="flex items-end justify-between gap-2">
          {showAmmo ? (
            <div className={`flex min-w-[26px] flex-col items-start font-orbitron leading-none ${ammoClass}`}>
              <span className="text-[6px] font-black tracking-[0.12em] text-white/35">AMMO</span>
              <span className="text-[11px] font-black">{formatNullableNumber(ammo)}</span>
            </div>
          ) : (
            <span />
          )}
          {isDead ? (
            <span className="font-orbitron text-[13px] font-black leading-none text-neutral-500">DEAD</span>
          ) : isOffline ? (
            <span className="font-orbitron text-[12px] font-black leading-none text-neutral-500">OFFLINE</span>
          ) : (
            <span className={`font-orbitron text-[20px] font-black leading-none drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)] ${isLow ? 'text-red-300 animate-pulse' : 'text-white'}`}>
              {hp}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

function RobotStrip({ robots, team, levels, enemyAux, clientTeam }) {
  const sideLevels = levels ?? {};
  const displayRobots = ensureRobotSlots(robots, team);

  return (
    <div className={`flex min-w-0 flex-1 gap-2 ${team === 'blue' ? 'justify-end' : 'justify-start'}`}>
      {displayRobots.map((robot) => (
        <RobotSlot
          key={`${team}-${robot.id}`}
          robot={robot}
          team={team}
          level={sideLevels[robot.id]}
          ammo={resolveEnemyAmmo(robot, team, clientTeam, enemyAux)}
          ammoStale={Boolean(enemyAux?.isStale)}
        />
      ))}
    </div>
  );
}

function LevelDots({ level, max, colorClass }) {
  const safeMax = Math.max(1, Number(max) || 1);
  const safeLevel = Math.max(0, Number(level) || 0);

  return (
    <div className="flex gap-1">
      {Array.from({ length: safeMax }).map((_, index) => (
        <div
          key={index}
          className={`h-1.5 w-3.5 rounded-sm ${index < safeLevel ? colorClass : 'bg-black/55'}`}
        />
      ))}
    </div>
  );
}

function EcoHub({ labels, stats, maxValues, enemyAux, clientTeam }) {
  const enemyPacket = enemyAux?.lastPacket;
  const enemyEconomy = enemyPacket?.validEconomy ? enemyPacket.enemyEconomy?.coinsRemaining : null;
  const redEco = clientTeam === 'blue' ? enemyEconomy : stats.eco;
  const blueEco = clientTeam === 'blue' ? stats.eco : enemyEconomy;
  const staleEnemyClass = enemyAux?.isStale ? 'text-white/25' : '';
  const redStale = clientTeam === 'blue' ? staleEnemyClass : '';
  const blueStale = clientTeam === 'red' ? staleEnemyClass : '';
  const ageLabel = formatPacketAge(enemyAux?.lastUpdateMs);

  return (
    <div className="flex h-[52px] min-w-[285px] items-center justify-center gap-4 rounded-lg border border-white/10 bg-neutral-950/72 px-4 shadow-[0_8px_18px_rgba(0,0,0,0.28)] backdrop-blur-md">
      <div className="flex flex-col items-center">
        <span className="mb-0.5 text-[8px] font-black tracking-[0.18em] text-white/40">{labels.eco}</span>
        <div className="flex items-baseline gap-1.5 font-orbitron">
          <span className={`text-[15px] font-black ${redStale || 'text-red-300'}`}>{formatNullableNumber(redEco)}</span>
          <span className="text-[9px] font-bold text-white/30">/</span>
          <span className={`text-[15px] font-black ${blueStale || 'text-blue-300'}`}>{formatNullableNumber(blueEco)}</span>
        </div>
        <div className="mt-0.5 font-orbitron text-[7px] font-bold tracking-[0.12em] text-white/30">
          UPDATE {ageLabel}
        </div>
      </div>

      <div className="h-7 w-px bg-white/10" />

      <div className="flex flex-col gap-1.5">
        <div className="flex items-center gap-2">
          <Cpu size={12} className="text-cyan-300" />
          <LevelDots level={stats.tech} max={maxValues.techLevel} colorClass="bg-cyan-400 shadow-[0_0_6px_rgba(34,211,238,0.45)]" />
        </div>
        <div className="flex items-center gap-2">
          <Lock size={12} className="text-violet-300" />
          <LevelDots level={stats.radar} max={maxValues.radarLevel} colorClass="bg-violet-400 shadow-[0_0_6px_rgba(167,139,250,0.45)]" />
        </div>
      </div>
    </div>
  );
}

export default function TopCoreLayout({
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
  enemyAux,
  leftRobots,
  rightRobots,
  robotLevels,
  uiSizing,
  match,
  mechanisms,
  clientTeam,
  links,
  fallbackBaseStateMeta,
  fallbackOutpostStateMeta,
}) {
  const mergedSizing = resolveUiSizing(uiSizing);
  const topCoreScale = mergedSizing.topCoreScale > 0 ? mergedSizing.topCoreScale : 1;
  const linkItems = Array.isArray(links) && links.length > 0 ? links : DEFAULT_LINKS;
  const normalizedScores = {
    left: Number(scores?.left) || 0,
    right: Number(scores?.right) || 0,
  };

  return (
    <div
      className="pointer-events-none relative z-10 mt-1 flex w-full max-w-[1700px] flex-col items-center px-4 font-sans select-none"
      style={{ transform: `scale(${topCoreScale})`, transformOrigin: 'top center' }}
    >
      <div className="mb-1 flex w-full items-center justify-between px-2">
        <div className="flex min-w-[230px] gap-2">
          {linkItems.slice(0, 2).map((link) => (
            <LinkStatus key={link.name} {...link} />
          ))}
        </div>

        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/35 px-3 py-0.5 text-[9px] font-black tracking-widest text-white/45 backdrop-blur-md">
          <RadioTower size={10} className="text-cyan-300/70" />
          <span>TOP CORE</span>
        </div>

        <div className="flex min-w-[230px] justify-end gap-2">
          {linkItems.slice(2).map((link) => (
            <LinkStatus key={link.name} {...link} />
          ))}
        </div>
      </div>

      <div className="flex w-full items-center justify-between gap-3">
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <BuildingCard
            type="base"
            team="red"
            label="BASE"
            hp={bases.left.hp}
            maxHp={maxValues.baseHp}
            shield={bases.left.shield}
            maxShield={maxValues.baseShield}
            state={bases.left.state}
            stateMeta={baseStateMeta}
            fallbackStateMeta={fallbackBaseStateMeta}
          />
          <BuildingCard
            type="outpost"
            team="red"
            label={labels.outpost}
            hp={outposts.left.hp}
            maxHp={maxValues.outpostHp}
            state={outposts.left.state}
            stateMeta={outpostStateMeta}
            fallbackStateMeta={fallbackOutpostStateMeta}
          />
        </div>

        <ScoreTimeCore
          roundLabel={roundLabel}
          match={match}
          timeLeft={timeLeft}
          scores={normalizedScores}
        />

        <div className="flex min-w-0 flex-1 items-center justify-end gap-3">
          <BuildingCard
            type="outpost"
            team="blue"
            label={labels.outpost}
            hp={outposts.right.hp}
            maxHp={maxValues.outpostHp}
            state={outposts.right.state}
            stateMeta={outpostStateMeta}
            fallbackStateMeta={fallbackOutpostStateMeta}
          />
          <BuildingCard
            type="base"
            team="blue"
            label="BASE"
            hp={bases.right.hp}
            maxHp={maxValues.baseHp}
            shield={bases.right.shield}
            maxShield={maxValues.baseShield}
            state={bases.right.state}
            stateMeta={baseStateMeta}
            fallbackStateMeta={fallbackBaseStateMeta}
          />
        </div>
      </div>

      <div className="mt-2 flex w-full items-center justify-between gap-4">
        <RobotStrip robots={leftRobots} team="red" levels={robotLevels?.red} enemyAux={enemyAux} clientTeam={clientTeam} />
        <EcoHub labels={labels} stats={stats} maxValues={maxValues} enemyAux={enemyAux} clientTeam={clientTeam} />
        <RobotStrip robots={rightRobots} team="blue" levels={robotLevels?.blue} enemyAux={enemyAux} clientTeam={clientTeam} />
      </div>

      <FortressStatusRow mechanisms={mechanisms} clientTeam={clientTeam} />
    </div>
  );
}
