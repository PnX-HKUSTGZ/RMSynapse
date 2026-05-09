import React from 'react';
import { 
  Wifi, WifiOff, Shield, ShieldAlert, ShieldCheck, Activity, 
  RefreshCcw, Zap, Lock, Cpu, AlertTriangle, Skull, HelpCircle 
} from 'lucide-react';

// === 通用组件：状态徽章 (直观显示建筑/赛事状态) ===
function StateBadge({ state }) {
  const map = {
    // 基地状态
    'invincible': { icon: <ShieldCheck size={12}/>, text: '无敌', color: 'text-yellow-400 bg-yellow-400/10 border-yellow-400/30' },
    'armor-open': { icon: <ShieldAlert size={12}/>, text: '护甲展开', color: 'text-orange-400 bg-orange-400/10 border-orange-400/50 animate-pulse drop-shadow-[0_0_3px_orange]' },
    'armor-closed': { icon: <Shield size={12}/>, text: '护甲未展开', color: 'text-white/60 bg-white/5 border-white/10' },
    // 前哨站状态
    'spinning': { icon: <RefreshCcw size={12} className="animate-spin duration-3000"/>, text: '正常旋转', color: 'text-green-400 bg-green-400/10 border-green-400/30' },
    'stopped': { icon: <AlertTriangle size={12}/>, text: '停转 (易伤)', color: 'text-red-400 bg-red-400/10 border-red-500/50 animate-pulse drop-shadow-[0_0_3px_red]' },
    'destroyed-unrebuildable': { icon: <Skull size={12}/>, text: '已被摧毁', color: 'text-neutral-500 bg-neutral-900 border-neutral-700' },
    'destroyed-rebuildable': { icon: <Zap size={12}/>, text: '可重建', color: 'text-yellow-500 bg-yellow-500/10 border-yellow-500/30' },
    'rebuilding': { icon: <Activity size={12}/>, text: '重建中', color: 'text-cyan-400 bg-cyan-400/10 border-cyan-400/30' }
  };
  const s = map[state] || { icon: <HelpCircle size={12}/>, text: '未知', color: 'text-neutral-400 bg-neutral-800 border-neutral-600' };

  return (
    <div className={`flex items-center gap-1 px-1.5 py-[2px] rounded border text-[10px] font-bold tracking-wider whitespace-nowrap ${s.color}`}>
      {s.icon} <span>{s.text}</span>
    </div>
  );
}

// === 通用组件：分块血条 (500HP一格) ===
function SegmentedBar({ value, maxValue, segmentSize = 500, colorClass, align = 'left', className = '' }) {
  const totalSegments = Math.ceil(maxValue / segmentSize);
  
  return (
    <div className={`flex w-full bg-black/60 border border-white/10 rounded-sm p-[1.5px] gap-[1.5px] ${align === 'right' ? 'flex-row-reverse' : 'flex-row'} ${className}`}>
      {Array.from({ length: totalSegments }).map((_, i) => {
        const segStart = i * segmentSize;
        const segEnd = (i + 1) * segmentSize;
        let fillPct = 0;
        if (value >= segEnd) fillPct = 100;
        else if (value > segStart) fillPct = ((value - segStart) / segmentSize) * 100;

        return (
          <div key={i} className="flex-1 bg-white/5 rounded-[1px] overflow-hidden relative">
            <div 
              className={`absolute top-0 bottom-0 ${align === 'left' ? 'left-0' : 'right-0'} ${colorClass} transition-all duration-300`}
              style={{ width: `${fillPct}%` }}
            />
          </div>
        );
      })}
    </div>
  );
}

// === 顶层：链路状态 ===
function LinkStatus({ name, status, outdated }) {
  const isOk = status === 'ok';
  return (
    <div className={`flex items-center gap-1.5 px-2 py-0.5 rounded text-[10px] font-bold tracking-wider uppercase border 
      ${isOk ? 'border-neutral-600 text-neutral-400 bg-transparent' : 'border-red-500 text-red-400 bg-red-950/50 animate-pulse'}
    `}>
      {isOk ? <Wifi size={10} /> : <WifiOff size={10} />}
      <span>{name}</span>
      {outdated && <span className="ml-1 text-[9px] text-yellow-500 bg-yellow-500/20 px-1 rounded">DELAY</span>}
    </div>
  );
}

// === 中层：基地卡片 ===
function BaseCard({ team, hp, maxHp, shield, maxShield, state }) {
  const isRed = team === 'red';
  const align = isRed ? 'left' : 'right';
  const themeText = isRed ? 'text-red-400' : 'text-blue-400';
  const themeBg = isRed ? 'bg-red-500' : 'bg-blue-500';

  return (
    <div className={`flex flex-col gap-1.5 w-[260px] p-2.5 bg-neutral-900/80 border border-white/10 rounded-lg backdrop-blur-md ${align === 'right' ? 'items-end' : 'items-start'}`}>
      <div className={`flex items-center justify-between w-full ${align === 'right' ? 'flex-row-reverse' : ''}`}>
        <div className={`flex items-center gap-2 ${align === 'right' ? 'flex-row-reverse' : ''}`}>
          <span className="text-[11px] font-black text-white/50 tracking-widest uppercase">Base</span>
          <StateBadge state={state} />
        </div>
        <div className="flex flex-col items-end">
          <span className={`font-mono text-2xl font-black leading-none ${themeText}`}>{hp}</span>
        </div>
      </div>
      
      <div className="flex flex-col w-full gap-[3px]">
        {/* 护盾条 (不分块或单独配置) */}
        {maxShield > 0 && (
          <div className="flex items-center gap-2 w-full">
            <span className="text-[8px] font-bold text-cyan-400 w-8 text-right">SHIELD</span>
            <SegmentedBar value={shield} maxValue={maxShield} segmentSize={maxShield} colorClass="bg-cyan-400" align={align} className="h-1.5" />
          </div>
        )}
        {/* 基地血条 (500/块) */}
        <div className="flex items-center gap-2 w-full">
          <span className="text-[8px] font-bold text-white/40 w-8 text-right">ARMOR</span>
          <SegmentedBar value={hp} maxValue={maxHp} segmentSize={500} colorClass={themeBg} align={align} className="h-3" />
        </div>
      </div>
    </div>
  );
}

// === 中层：前哨站卡片 ===
function OutpostCard({ team, hp, maxHp, state }) {
  const isRed = team === 'red';
  const align = isRed ? 'left' : 'right';
  const themeText = isRed ? 'text-red-300' : 'text-blue-300';
  const themeBg = isRed ? 'bg-red-500' : 'bg-blue-500';

  return (
    <div className={`flex flex-col justify-between w-[160px] p-2 bg-neutral-900/80 border border-white/10 rounded-lg backdrop-blur-md ${align === 'right' ? 'items-end' : 'items-start'}`}>
      <div className={`flex items-center justify-between w-full mb-2 ${align === 'right' ? 'flex-row-reverse' : ''}`}>
        <span className="text-[10px] font-black text-white/50 tracking-widest uppercase">Outpost</span>
        <StateBadge state={state} />
      </div>
      
      <div className={`flex items-end gap-2 w-full ${align === 'right' ? 'flex-row-reverse' : ''}`}>
        <span className={`font-mono text-lg font-bold leading-none ${themeText}`}>{hp}</span>
        <SegmentedBar value={hp} maxValue={maxHp} segmentSize={500} colorClass={themeBg} align={align} className="h-2.5 mb-[2px]" />
      </div>
    </div>
  );
}

// === 底层：机器名单兵槽位 ===
function RobotSlot({ robot, team }) {
  const isRed = team === 'red';
  const themeBg = isRed ? 'bg-red-500' : 'bg-blue-500';
  
  const isDead = robot.hp === 0;
  const isOffline = robot.hp === null || robot.hp === undefined;
  const isLow = !isDead && !isOffline && (robot.hp / robot.maxHp < 0.3);
  const hpPct = isOffline ? 0 : Math.min((robot.hp / robot.maxHp) * 100, 100);

  // 状态样式计算
  let cardStyle = "bg-neutral-900/80 border-white/10";
  let textStyle = "text-white/90";
  
  if (isDead) {
    cardStyle = "bg-neutral-950 border-neutral-800 opacity-80";
  } else if (isOffline) {
    cardStyle = "bg-neutral-900/50 border-neutral-700 opacity-80";
  } else if (isLow) {
    cardStyle = "bg-red-950/40 border-red-500/80 animate-pulse drop-shadow-[0_0_5px_rgba(239,68,68,0.5)]";
    textStyle = "text-red-400";
  }

  return (
    <div className={`relative flex flex-col justify-between w-[84px] h-[54px] rounded border p-1.5 overflow-hidden transition-all duration-300 ${cardStyle}`}>
      
      <div className="flex justify-between items-start z-10">
        <span className={`font-black text-sm leading-none ${isDead ? 'text-neutral-600' : 'text-white/60'}`}>
          {robot.id}
        </span>
        {/* 状态标签 */}
        <div className="flex flex-col gap-[2px] items-end">
          {robot.tags?.map((tag, idx) => (
            <span key={idx} className="px-1 py-[1px] rounded bg-white/10 text-[8px] leading-none text-white/80">{tag}</span>
          ))}
          {robot.outdated && <span className="px-1 py-[1px] rounded bg-yellow-500/20 text-[8px] leading-none text-yellow-400">OLD</span>}
        </div>
      </div>

      <div className="flex flex-col justify-end z-10 mt-auto">
        {isDead ? (
          <div className="flex items-center justify-end gap-1 text-neutral-500">
            <Skull size={12} /> <span className="font-mono text-sm font-bold">DEAD</span>
          </div>
        ) : isOffline ? (
          <div className="flex items-center justify-end text-neutral-500">
            <span className="font-mono text-sm font-bold">OFFLINE</span>
          </div>
        ) : (
          <span className={`font-mono text-lg font-bold leading-none text-right ${textStyle}`}>
            {robot.hp}
          </span>
        )}
      </div>

      {/* 底部细血条 */}
      {!isDead && !isOffline && (
        <div className="absolute bottom-0 left-0 w-full h-[3px] bg-black/50">
          <div className={`h-full ${themeBg}`} style={{ width: `${hpPct}%` }} />
        </div>
      )}
    </div>
  );
}

// === 底层：经济与科技中心 ===
function EcoHub({ eco, totalEco, tech, maxTech, crypto, maxCrypto }) {
  return (
    <div className="flex items-center gap-5 bg-neutral-900/80 border border-white/10 rounded-lg px-5 py-2 backdrop-blur-md">
      <div className="flex flex-col items-center">
        <span className="text-[9px] text-white/40 font-bold tracking-widest mb-1">ECONOMY</span>
        <div className="flex items-baseline gap-1">
          <span className="font-mono text-base font-bold text-yellow-400">{eco}</span>
          <span className="font-mono text-[10px] text-white/30">/ {totalEco}</span>
        </div>
      </div>
      
      <div className="w-[1px] h-6 bg-white/10" />

      <div className="flex flex-col gap-1.5">
        <div className="flex items-center gap-2">
          <Cpu size={12} className="text-cyan-400" />
          <div className="flex gap-1">
            {Array.from({ length: maxTech }).map((_, i) => (
              <div key={`tech-${i}`} className={`w-3.5 h-1.5 rounded-sm ${i < tech ? 'bg-cyan-400 shadow-[0_0_5px_rgba(34,211,238,0.5)]' : 'bg-black/50'}`} />
            ))}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Lock size={12} className="text-purple-400" />
          <div className="flex gap-1">
            {Array.from({ length: maxCrypto }).map((_, i) => (
              <div key={`cryp-${i}`} className={`w-3.5 h-1.5 rounded-sm ${i < crypto ? 'bg-purple-400 shadow-[0_0_5px_rgba(168,85,247,0.5)]' : 'bg-black/50'}`} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// === 主布局组件 ===
export default function TopCoreLayout() {
  // --- 测试数据：覆盖了各种正常/异常状态供预览 ---
  const matchData = {
    roundLabel: "BO5 G1",
    stageZh: "比赛中",
    timeLeft: 165,
    isPaused: false, // 尝试改为 true 查看中间变化
    scores: { red: 2, blue: 1 }
  };

  const links = [
    { name: "MQTT", status: "ok" },
    { name: "VIDEO", status: "ok" },
    { name: "DATA", status: "error", outdated: true }
  ];

  const bases = {
    // 红方基地正常，护盾满
    red: { hp: 4500, maxHp: 5000, shield: 500, maxShield: 500, state: 'armor-closed' },
    // 蓝方基地受到攻击，护甲展开警报
    blue: { hp: 2800, maxHp: 5000, shield: 0, maxShield: 500, state: 'armor-open' }
  };

  const outposts = {
    // 红方前哨正常旋转
    red: { hp: 1500, maxHp: 1500, state: 'spinning' },
    // 蓝方前哨停转警报
    blue: { hp: 450, maxHp: 1500, state: 'stopped' }
  };

  const ecoData = { eco: 1250, totalEco: 3400, tech: 3, maxTech: 5, crypto: 2, maxCrypto: 4 };

  const robotsLeft = [
    { id: 1, hp: 2000, maxHp: 2000 },
    { id: 2, hp: 400, maxHp: 1500, tags: ['易伤'] },  // 低血
    { id: 3, hp: 380, maxHp: 1500, tags: ['被锁'] },  // 低血
    { id: 4, hp: 0, maxHp: 1500 },                    // 死亡
    { id: 7, hp: 530, maxHp: 600 }
  ];

  const robotsRight = [
    { id: 1, hp: 1800, maxHp: 2000 },
    { id: 2, hp: null, maxHp: 1500 },                 // 离线/无数据
    { id: 3, hp: 1200, maxHp: 1500, outdated: true }, // 数据过期
    { id: 4, hp: 0, maxHp: 1500 },                    // 死亡
    { id: 7, hp: 600, maxHp: 600, tags: ['复活中'] }
  ];

  const formatTime = (seconds) => {
    const m = Math.floor(seconds / 60).toString().padStart(2, '0');
    const s = (seconds % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };

  return (
    <div className="min-h-screen bg-black flex flex-col items-center pt-3 font-sans select-none overflow-hidden">
      
      {/* ===== Layer 1: 顶层状态与链路 (居中对称) ===== */}
      <div className="w-full max-w-[1500px] flex justify-between items-start px-6 mb-3">
        <div className="flex gap-2 w-[200px]">
          {links.slice(0, 2).map(l => <LinkStatus key={l.name} {...l} />)}
        </div>
        
        <div className="flex items-center gap-4 bg-neutral-900/80 border border-white/10 px-6 py-1.5 rounded-full backdrop-blur-md">
          <span className="text-[11px] font-bold text-white/60">{matchData.roundLabel}</span>
          <div className="w-1 h-1 bg-white/20 rounded-full" />
          <span className={`text-[11px] font-bold tracking-widest ${matchData.isPaused ? 'text-orange-400 animate-pulse' : 'text-cyan-400'}`}>
            {matchData.isPaused ? 'MATCH PAUSED' : matchData.stageZh}
          </span>
        </div>

        <div className="flex gap-2 w-[200px] justify-end">
          {links.slice(2).map(l => <LinkStatus key={l.name} {...l} />)}
        </div>
      </div>

      {/* ===== Layer 2: 战略建筑与核心数据 (绝对镜像对称) ===== */}
      <div className="w-full max-w-[1500px] flex justify-between items-center px-6">
        
        {/* 左侧：红方 基地 -> 前哨 */}
        <div className="flex items-center gap-3 flex-1">
          <BaseCard team="red" {...bases.red} />
          <OutpostCard team="red" {...outposts.red} />
        </div>

        {/* 中央：比分与时间 */}
        <div className="flex items-center justify-center gap-6 px-8 flex-shrink-0">
          <div className="text-4xl font-black text-red-500 font-mono">{matchData.scores.red}</div>
          <div className={`flex justify-center items-center w-[130px] h-[54px] bg-neutral-900/80 border ${matchData.isPaused ? 'border-orange-500/50' : 'border-white/10'} rounded-lg`}>
            <div className={`font-mono text-4xl font-black tracking-widest ${matchData.isPaused ? 'text-orange-400' : 'text-white'}`}>
              {formatTime(matchData.timeLeft)}
            </div>
          </div>
          <div className="text-4xl font-black text-blue-500 font-mono">{matchData.scores.blue}</div>
        </div>

        {/* 右侧：蓝方 前哨 <- 基地 (严格镜像排版) */}
        <div className="flex items-center gap-3 flex-1 justify-end">
          <OutpostCard team="blue" {...outposts.blue} />
          <BaseCard team="blue" {...bases.blue} />
        </div>
      </div>

      {/* ===== Layer 3: 战术级单兵矩阵与经济 (平铺对称) ===== */}
      <div className="w-full max-w-[1500px] flex justify-between items-center px-6 mt-4">
        
        {/* 左侧：红方机器人 */}
        <div className="flex gap-2 flex-1">
          {robotsLeft.map(robot => (
            <RobotSlot key={`red-${robot.id}`} robot={robot} team="red" />
          ))}
        </div>

        {/* 中央：经济科技雷达 */}
        <div className="flex-shrink-0 px-4">
          <EcoHub {...ecoData} />
        </div>

        {/* 右侧：蓝方机器人 */}
        <div className="flex gap-2 flex-1 justify-end">
          {robotsRight.map(robot => (
            <RobotSlot key={`blue-${robot.id}`} robot={robot} team="blue" />
          ))}
        </div>

      </div>

    </div>
  );
}