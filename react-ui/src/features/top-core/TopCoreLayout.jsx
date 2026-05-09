import {
  Activity,
  AlertTriangle,
  Cpu,
  HelpCircle,
  Lock,
  RadioTower,
  RefreshCcw,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Skull,
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

function LinkStatus({ name, status = 'ok', outdated = false }) {
  const isOk = status === 'ok' && !outdated;
  const isWarning = status === 'warning' || outdated;
  const Icon = isOk ? Wifi : WifiOff;
  const className = isOk
    ? 'border-neutral-600/70 bg-black/20 text-neutral-400'
    : isWarning
      ? 'border-yellow-500/50 bg-yellow-500/10 text-yellow-300'
      : 'border-red-500/60 bg-red-500/12 text-red-300 animate-pulse';

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
  const teamText = isRed ? 'text-red-300' : 'text-blue-300';
  const teamFill = isRed ? 'bg-red-500' : 'bg-blue-500';
  const widthClass = type === 'base' ? 'w-[245px]' : 'w-[160px]';
  const hpSegmentSize = type === 'base' ? 500 : (Number(maxHp) <= 1000 ? 250 : 500);

  return (
    <div
      className={`flex h-[62px] flex-col justify-between rounded-lg border border-white/10 bg-neutral-950/70 px-2.5 py-2 shadow-[0_8px_18px_rgba(0,0,0,0.28)] backdrop-blur-md ${widthClass} ${align === 'right' ? 'items-end' : 'items-start'}`}
    >
      <div className={`flex w-full items-center justify-between gap-2 ${align === 'right' ? 'flex-row-reverse' : ''}`}>
        <div className={`flex min-w-0 items-center gap-1.5 ${align === 'right' ? 'flex-row-reverse' : ''}`}>
          <span className="whitespace-nowrap text-[9px] font-black tracking-[0.18em] text-white/45 uppercase">{label}</span>
          <StateBadge type={type} state={state} states={stateMeta} fallbackStates={fallbackStateMeta} />
        </div>
        <span className={`font-orbitron text-[20px] font-black leading-none ${teamText}`}>
          {Math.max(0, Number(hp) || 0)}
        </span>
      </div>

      <div className="flex w-full flex-col gap-[3px]">
        {type === 'base' && Number(maxShield) > 0 && (
          <div className={`flex items-center gap-2 ${align === 'right' ? 'flex-row-reverse' : ''}`}>
            <span className="w-8 text-[7px] font-black leading-none tracking-wider text-cyan-300">SHIELD</span>
            <SegmentedBar
              value={shield}
              maxValue={maxShield}
              segmentSize={500}
              colorClass="bg-cyan-400 shadow-[0_0_6px_rgba(34,211,238,0.45)]"
              align={align}
              className="h-[7px]"
            />
          </div>
        )}
        <div className={`flex items-center gap-2 ${align === 'right' ? 'flex-row-reverse' : ''}`}>
          <span className="w-8 text-[7px] font-black leading-none tracking-wider text-white/35">
            {type === 'base' ? 'ARMOR' : 'HP'}
          </span>
          <SegmentedBar
            value={hp}
            maxValue={maxHp}
            segmentSize={hpSegmentSize}
            colorClass={`${teamFill} shadow-[0_0_5px_currentColor]`}
            align={align}
            className={type === 'base' ? 'h-[12px]' : 'h-[10px]'}
          />
        </div>
      </div>
    </div>
  );
}

function ScoreTimeCore({ roundLabel, match, timeLeft, scores }) {
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
            {minutesText}
            <span className={paused ? 'text-orange-400' : 'text-cyan-300'}>:</span>
            {secondsText}
          </div>
        </div>
        <span className="font-orbitron text-[34px] font-black leading-none text-blue-500 drop-shadow-[0_0_8px_rgba(59,130,246,0.28)]">
          {scores.right}
        </span>
      </div>
    </div>
  );
}

function RobotSlot({ robot, team }) {
  const isRed = team === 'red';
  const maxHp = Number(robot.max ?? robot.maxHp) > 0 ? Number(robot.max ?? robot.maxHp) : 1;
  const hasHp = robot.hp != null && Number.isFinite(Number(robot.hp));
  const hp = hasHp ? Number(robot.hp) : null;
  const hpPercent = hasHp ? toPercent(hp, maxHp) : 0;
  const isDead = hp === 0 || robot.aliveState === 2 || robot.status === 'dead';
  const isOffline = !hasHp || robot.isOffline || robot.status === 'offline';
  const isLow = hasHp && !isDead && hpPercent < 30;
  const tags = Array.isArray(robot.tags) ? robot.tags : [];
  const fillClass = isRed ? 'bg-red-500' : 'bg-blue-500';

  const cardClass = isDead
    ? 'border-neutral-800 bg-neutral-950/85 text-neutral-500'
    : isOffline
      ? 'border-neutral-700 bg-neutral-950/60 text-neutral-500'
      : isLow
        ? 'border-red-500/75 bg-red-950/40 text-red-300 shadow-[0_0_12px_rgba(239,68,68,0.24)]'
        : 'border-white/10 bg-neutral-950/72 text-white/90';

  return (
    <div className={`relative h-[46px] min-w-[70px] flex-1 overflow-hidden rounded-md border px-1.5 py-1.5 backdrop-blur-md transition-colors ${cardClass}`}>
      <div className="relative z-10 flex items-start justify-between gap-1">
        <span className="font-orbitron text-[13px] font-black leading-none text-white/70">{robot.id}</span>
        <div className="flex max-w-[48px] flex-col items-end gap-[2px]">
          {robot.outdated && <span className="rounded bg-yellow-500/20 px-1 text-[7px] font-black leading-none text-yellow-300">OLD</span>}
          {tags.slice(0, 2).map((tag) => (
            <span key={tag} className="rounded bg-white/10 px-1 text-[7px] font-black leading-none text-white/70">
              {tag}
            </span>
          ))}
        </div>
      </div>

      <div className="relative z-10 mt-1 flex justify-end">
        {isDead ? (
          <span className="flex items-center gap-1 font-orbitron text-[11px] font-black text-neutral-500">
            <Skull size={11} />
            DEAD
          </span>
        ) : isOffline ? (
          <span className="font-orbitron text-[11px] font-black text-neutral-500">OFFLINE</span>
        ) : (
          <span className={`font-orbitron text-[18px] font-black leading-none ${isLow ? 'text-red-300 animate-pulse' : 'text-white'}`}>
            {hp}
          </span>
        )}
      </div>

      {!isDead && !isOffline && (
        <div className="absolute inset-x-0 bottom-0 h-[3px] bg-black/60">
          <div className={`h-full ${fillClass}`} style={{ width: `${hpPercent}%` }} />
        </div>
      )}
    </div>
  );
}

function RobotStrip({ robots, team }) {
  return (
    <div className={`flex min-w-0 flex-1 gap-2 ${team === 'blue' ? 'justify-end' : 'justify-start'}`}>
      {robots.map((robot) => (
        <RobotSlot key={`${team}-${robot.id}`} robot={robot} team={team} />
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

function EcoHub({ labels, stats, maxValues }) {
  return (
    <div className="flex h-[46px] min-w-[260px] items-center justify-center gap-4 rounded-lg border border-white/10 bg-neutral-950/72 px-4 shadow-[0_8px_18px_rgba(0,0,0,0.28)] backdrop-blur-md">
      <div className="flex flex-col items-center">
        <span className="mb-0.5 text-[8px] font-black tracking-[0.18em] text-white/40">{labels.eco}</span>
        <div className="flex items-baseline gap-1 font-orbitron">
          <span className="text-[15px] font-black text-yellow-300">{stats.eco}</span>
          <span className="text-[9px] font-bold text-white/30">/ {stats.totalEco}</span>
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
  leftRobots,
  rightRobots,
  uiSizing,
  match,
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
        <RobotStrip robots={leftRobots} team="red" />
        <EcoHub labels={labels} stats={stats} maxValues={maxValues} />
        <RobotStrip robots={rightRobots} team="blue" />
      </div>
    </div>
  );
}
