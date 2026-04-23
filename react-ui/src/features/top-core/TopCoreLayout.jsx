import { resolveUiSizing, toPercent } from '../../state';

function BaseStateIcon({ state, team, states, fallbackStates }) {
  const isRed = team === 'red';
  const color = isRed
    ? 'text-red-300 border-red-500/30 bg-red-950/40'
    : 'text-blue-300 border-blue-500/30 bg-blue-950/40';
  const stateMeta = states?.[state] ?? fallbackStates[state] ?? { icon: '❓', label: '未知' };

  return (
    <div className={`flex flex-col items-center justify-center gap-[2px] rounded-sm border px-1.5 py-[2px] backdrop-blur-sm whitespace-nowrap ${color}`}>
      <span className="text-[11px] leading-none drop-shadow-md">{stateMeta.icon}</span>
      <span className="text-[7px] font-bold tracking-widest leading-none">{stateMeta.label}</span>
    </div>
  );
}

function OutpostStateIcon({ state, team, states, fallbackStates }) {
  const isRed = team === 'red';
  const color = isRed
    ? 'text-red-300 bg-red-950/40 border-red-500/30'
    : 'text-blue-300 bg-blue-950/40 border-blue-500/30';
  const stateMeta = states?.[state] ?? states?.default ?? fallbackStates[state] ?? fallbackStates.default;

  return (
    <div className={`flex h-6 w-6 items-center justify-center rounded border text-xs backdrop-blur-sm ${color}`}>
      <div className={stateMeta.spin ? 'animate-spin' : ''}>{stateMeta.icon}</div>
    </div>
  );
}

function LevelIndicator({ label, level, max, team }) {
  const isRed = team === 'red';
  const filledColor = isRed ? 'bg-red-400 shadow-[0_0_3px_red]' : 'bg-blue-400 shadow-[0_0_3px_blue]';

  return (
    <div className="flex w-full items-center justify-between">
      <span className={`text-[7px] font-bold tracking-wider leading-none ${isRed ? 'text-red-200' : 'text-blue-200'}`}>{label}</span>
      <div className="flex gap-[1.5px]">
        {Array.from({ length: max }).map((_, index) => (
          <div
            key={`${label}-${index}`}
            className={`h-[5px] w-[6px] border-[0.5px] border-black/50 transition-colors duration-300 ${index < level ? filledColor : 'bg-white/10'}`}
          />
        ))}
      </div>
    </div>
  );
}

function TeamRobotStrip({ robots, side }) {
  const isRed = side === 'red';

  return robots.map((robot) => {
    const hpPct = toPercent(robot.hp, robot.max);
    const isDead = robot.hp === 0;

    return (
      <div
        key={`${side}-${robot.id}`}
        className={`group relative mx-1 flex-1 overflow-hidden border-b-[2px] shadow-md ultra-glass ${isRed ? 'skew-x-[-20deg]' : 'skew-x-[20deg]'} ${isDead ? 'border-neutral-600' : isRed ? 'border-red-500/80' : 'border-blue-500/80'} h-[40px]`}
      >
        <div
          className={`absolute bottom-0 h-full transition-all duration-300 ${isDead ? 'bg-neutral-600/30' : isRed ? 'bg-red-500/30' : 'bg-blue-500/30'} ${isRed ? 'left-0' : 'right-0'}`}
          style={{ width: `${hpPct}%` }}
        />
        <div className={`absolute inset-0 ${isRed ? 'skew-x-[20deg]' : 'skew-x-[-20deg]'}`}>
          <span className={`absolute top-0.5 font-orbitron text-[13px] font-black drop-shadow-md ${isDead ? 'text-neutral-500' : 'text-white'} ${isRed ? 'left-2' : 'right-2'}`}>
            {robot.id}
          </span>
          <span className={`absolute bottom-0 font-orbitron text-[8px] font-bold drop-shadow-sm transition-all ${isDead ? 'text-neutral-500' : isRed ? 'text-red-200' : 'text-blue-200'} ${isRed ? 'right-2.5' : 'left-2.5'}`}>
            {robot.hp}
          </span>
        </div>
      </div>
    );
  });
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
  fallbackBaseStateMeta,
  fallbackOutpostStateMeta,
}) {
  const mergedSizing = resolveUiSizing(uiSizing);
  const topCoreScale = mergedSizing.topCoreScale > 0 ? mergedSizing.topCoreScale : 1;
  const time = {
    m: Math.floor(timeLeft / 60).toString().padStart(2, '0'),
    s: (timeLeft % 60).toString().padStart(2, '0'),
  };

  return (
    <div
      className="relative z-10 mt-2 flex w-full max-w-[1700px] flex-col items-center pointer-events-auto"
      style={{ transform: `scale(${topCoreScale})`, transformOrigin: 'top center' }}
    >
      <div className="flex w-full items-center justify-center gap-[2px]">
        <div className="glass-panel relative flex h-9 w-[120px] flex-col overflow-hidden border-b border-t border-red-500/40 shadow-lg skew-x-[-20deg] transition-colors">
          <div className="absolute inset-0 flex justify-end opacity-50">
            <div className="h-full bg-red-500 transition-all duration-300" style={{ width: `${toPercent(outposts.left.hp, maxValues.outpostHp)}%` }} />
          </div>
          <div className="absolute inset-0 flex items-center justify-between pl-3 pr-5 skew-x-[20deg]">
            <OutpostStateIcon state={outposts.left.state} team="red" states={outpostStateMeta} fallbackStates={fallbackOutpostStateMeta} />
            <div className="flex flex-col items-end">
              <span className="mb-0.5 whitespace-nowrap text-[10px] font-bold leading-none text-white/80">{labels.outpost}</span>
              <span className="font-orbitron text-xs font-bold leading-none text-red-200">{outposts.left.hp}</span>
            </div>
          </div>
        </div>

        <div className="glass-panel relative flex h-11 w-[24vw] max-w-[400px] items-center overflow-hidden border-b border-t border-red-500/50 shadow-[0_0_15px_rgba(220,38,38,0.15)] skew-x-[-20deg]">
          <div className="scanline-bg absolute inset-0 opacity-40" />
          <div className="absolute bottom-0 right-0 h-full bg-red-600/80 shadow-[0_0_10px_red] transition-all duration-300" style={{ width: `${toPercent(bases.left.hp, maxValues.baseHp)}%` }} />
          <div className="absolute right-0 top-0 h-[4px] bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300" style={{ width: `${toPercent(bases.left.shield, maxValues.baseShield)}%` }} />

          <div className="absolute inset-0 z-10 w-full skew-x-[20deg] drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
            <div className="absolute left-3 top-1/2 flex-shrink-0 -translate-y-1/2">
              <BaseStateIcon state={bases.left.state} team="red" states={baseStateMeta} fallbackStates={fallbackBaseStateMeta} />
            </div>
            <div className="absolute right-14 top-1/2 flex -translate-y-1/2 flex-col items-end justify-center pt-1">
              {bases.left.shield > 0 && (
                <span className="mb-0.5 font-orbitron text-[10px] font-bold leading-none tracking-wide text-green-400 drop-shadow-[0_0_5px_#22c55e]">
                  {bases.left.shield}
                </span>
              )}
              <span className="font-orbitron text-2xl font-bold leading-none tracking-wide text-white drop-shadow-[0_0_5px_red]">
                {bases.left.hp}
              </span>
            </div>
          </div>
        </div>

        <div className="ultra-glass z-10 ml-1 flex h-11 w-16 items-center justify-center border-b border-t border-white/20 shadow-lg skew-x-[-20deg]">
          <div className="font-orbitron text-3xl font-bold text-white skew-x-[20deg]">{scores.left}</div>
        </div>

        <div className="relative z-10 mx-1 flex h-12 w-40 flex-col justify-end">
          <div className="ultra-glass clip-trapezoid-top absolute -top-4 left-1/2 flex h-5 w-24 -translate-x-1/2 items-center justify-center border-t border-cyan-400/50">
            <span className="text-[10px] font-bold tracking-wider text-cyan-200 drop-shadow-md">{roundLabel}</span>
          </div>
          <div className="glass-panel clip-trapezoid relative flex h-12 w-full items-center justify-center border-b-2 border-t-2 border-cyan-400/60 shadow-[0_5px_15px_rgba(34,211,238,0.15)]">
            <div className="mt-1 flex items-center gap-1.5 font-orbitron text-[28px] font-bold tracking-widest text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]">
              <span>{time.m}</span>
              <div className="flex flex-col gap-1.5 pb-1">
                <div className="h-1.5 w-1.5 bg-cyan-400 shadow-[0_0_5px_cyan]" />
                <div className={`h-1.5 w-1.5 bg-cyan-400 shadow-[0_0_5px_cyan] transition-opacity ${timeLeft % 2 === 0 ? 'opacity-100' : 'opacity-40'}`} />
              </div>
              <span>{time.s}</span>
            </div>
          </div>
        </div>

        <div className="ultra-glass z-10 mr-1 flex h-11 w-16 items-center justify-center border-b border-t border-white/20 shadow-lg skew-x-[20deg]">
          <div className="font-orbitron text-3xl font-bold text-white skew-x-[-20deg]">{scores.right}</div>
        </div>

        <div className="glass-panel relative flex h-11 w-[24vw] max-w-[400px] items-center overflow-hidden border-b border-t border-blue-500/50 shadow-[0_0_15px_rgba(59,130,246,0.15)] skew-x-[20deg]">
          <div className="scanline-bg absolute inset-0 opacity-40" />
          <div className="absolute bottom-0 left-0 h-full bg-blue-600/80 shadow-[0_0_10px_blue] transition-all duration-300" style={{ width: `${toPercent(bases.right.hp, maxValues.baseHp)}%` }} />
          <div className="absolute left-0 top-0 h-[4px] bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300" style={{ width: `${toPercent(bases.right.shield, maxValues.baseShield)}%` }} />

          <div className="absolute inset-0 z-10 w-full skew-x-[-20deg] drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
            <div className="absolute left-14 top-1/2 flex -translate-y-1/2 flex-col items-start justify-center pt-1">
              {bases.right.shield > 0 && (
                <span className="mb-0.5 font-orbitron text-[10px] font-bold leading-none tracking-wide text-green-400 drop-shadow-[0_0_5px_#22c55e]">
                  {bases.right.shield}
                </span>
              )}
              <span className="font-orbitron text-2xl font-bold leading-none tracking-wide text-white drop-shadow-[0_0_5px_blue]">
                {bases.right.hp}
              </span>
            </div>
            <div className="absolute right-3 top-1/2 flex-shrink-0 -translate-y-1/2">
              <BaseStateIcon state={bases.right.state} team="blue" states={baseStateMeta} fallbackStates={fallbackBaseStateMeta} />
            </div>
          </div>
        </div>

        <div className="glass-panel relative flex h-9 w-[120px] flex-col overflow-hidden border-b border-t border-blue-500/40 shadow-lg skew-x-[20deg] transition-colors">
          <div className="absolute inset-0 flex justify-start opacity-50">
            <div className="h-full bg-blue-500 transition-all duration-300" style={{ width: `${toPercent(outposts.right.hp, maxValues.outpostHp)}%` }} />
          </div>
          <div className="absolute inset-0 flex items-center justify-between pl-5 pr-3 skew-x-[-20deg]">
            <div className="flex flex-col items-start">
              <span className="mb-0.5 whitespace-nowrap text-[10px] font-bold leading-none text-white/80">{labels.outpost}</span>
              <span className="font-orbitron text-xs font-bold leading-none text-blue-200">{outposts.right.hp}</span>
            </div>
            <OutpostStateIcon state={outposts.right.state} team="blue" states={outpostStateMeta} fallbackStates={fallbackOutpostStateMeta} />
          </div>
        </div>
      </div>

      <div className="relative z-10 mt-2 flex w-full items-start justify-between px-[4%]">
        <div className="mr-2 flex flex-1 justify-between">
          <TeamRobotStrip robots={leftRobots} side="red" />
        </div>

        <div className="mt-[1px] flex justify-center px-2">
          <div className="ultra-glass relative flex h-[30px] w-[85px] items-center justify-center border-l border-r border-blue-400/40 shadow-[0_0_10px_rgba(59,130,246,0.1)] transition-colors hover:bg-blue-900/20">
            <div className="flex w-full flex-col gap-[2px] px-2">
              <div className="flex w-full cursor-pointer items-center justify-between transition-opacity hover:opacity-80">
                <span className="text-[7px] font-bold leading-none tracking-wider text-blue-200">{labels.eco}</span>
                <div className="font-orbitron flex items-baseline gap-[1px] font-bold leading-none">
                  <span className="text-[10px] text-blue-300 drop-shadow-[0_0_3px_rgba(96,165,250,0.8)]">{stats.eco}</span>
                  <span className="text-[7px] text-white/40">/</span>
                  <span className="text-[7px] text-blue-200/50">{stats.totalEco}</span>
                </div>
              </div>
              <LevelIndicator label={labels.tech} level={stats.tech} max={maxValues.techLevel} team="blue" />
              <LevelIndicator label={labels.radar} level={stats.radar} max={maxValues.radarLevel} team="blue" />
            </div>
          </div>
        </div>

        <div className="ml-2 flex flex-1 justify-between">
          <TeamRobotStrip robots={rightRobots} side="blue" />
        </div>
      </div>
    </div>
  );
}
