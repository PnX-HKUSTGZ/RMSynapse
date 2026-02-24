import { useEffect, useState } from 'react';
import { BaseStateIcon, CenterCombatHUD, LevelIndicator, MechaHUD, OutpostStateIcon } from './HudComponents';
import { DEFAULT_UI_STATE, deepMerge, normalizeIncomingData, toPercent } from './uiState';

// ============================================================================
// 主组件：App (包含顶层全局 HUD，以及挂载 MechaHUD)
// ============================================================================
export default function App() {
  const [uiState, setUiState] = useState(DEFAULT_UI_STATE);

  // Debug: last message timestamp
  const [lastMsg, setLastMsg] = useState('');

  // ================= 与 Godot 通信入口 =================
  useEffect(() => {
    window.godotPush = (payload) => {
      let data = payload;
      if (typeof payload === 'string') {
        try {
          data = JSON.parse(payload);
        } catch (error) {
          console.error('godotPush payload is not valid JSON:', error);
          return;
        }
      }

      const normalizedData = normalizeIncomingData(data);
      const now = new Date();
      setLastMsg(now.toLocaleTimeString() + '.' + String(now.getMilliseconds()).padStart(3, '0'));

      setUiState((prev) => deepMerge(prev, normalizedData));
    };

    return () => {
      delete window.godotPush;
    };
  }, []);

  const {
    forceBlackBg,
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
    robots,
    mecha,
    centerHud
  } = uiState;

  const leftRobots = Array.isArray(robots?.left) ? robots.left : DEFAULT_UI_STATE.robots.left;
  const rightRobots = Array.isArray(robots?.right) ? robots.right : DEFAULT_UI_STATE.robots.right;

  const time = {
    m: Math.floor(timeLeft / 60).toString().padStart(2, '0'),
    s: (timeLeft % 60).toString().padStart(2, '0')
  };

  return (
    <div className={`min-h-screen ${forceBlackBg ? 'bg-black' : 'bg-transparent'} flex flex-col items-center pt-2 relative overflow-hidden font-sans text-white select-none`}>
      <div className="absolute top-1 left-1 z-50 text-[10px] text-white/70 bg-black/30 px-2 py-1 rounded">
        lastMsg: {lastMsg || '—'}
      </div>

      {/* ================= 自定义 CSS ================= */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@500;700;900&display=swap');
        .font-orbitron { font-family: 'Orbitron', sans-serif; }

        .clip-trapezoid { clip-path: polygon(15px 0, calc(100% - 15px) 0, 100% 100%, 0 100%); }
        .clip-trapezoid-top { clip-path: polygon(10px 0, calc(100% - 10px) 0, 100% 100%, 0 100%); }
        
        .scanline-bg {
          background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.4) 2px, rgba(0,0,0,0.4) 4px);
        }

        /* 透明 HUD 玻璃面板 */
        .glass-panel {
          background: linear-gradient(180deg, rgba(15,20,25,0.3) 0%, rgba(5,10,15,0.5) 100%);
          backdrop-filter: blur(8px);
        }
        
        /* 极致透明框 */
        .ultra-glass {
          background: rgba(0, 0, 0, 0.25);
          backdrop-filter: blur(6px);
        }
      `}</style>

      {/* ================= 顶层核心布局 ================= */}
      <div className="relative z-10 w-full max-w-[1700px] flex flex-col items-center mt-2 pointer-events-auto">
        
        {/* === 第一排：前哨站 - 基地 - 分数 - 时间 - 分数 - 基地 - 前哨站 === */}
        <div className="flex items-center justify-center w-full gap-[2px]">
          
          {/* 【左侧：前哨站 (红)】 */}
          <div 
            className="w-[120px] h-9 glass-panel border-t border-b border-red-500/40 skew-x-[-20deg] flex flex-col relative overflow-hidden shadow-lg transition-colors"
          >
            <div className="absolute inset-0 flex justify-end opacity-50">
              <div className="bg-red-500 h-full transition-all duration-300" style={{ width: `${toPercent(outposts.left.hp, maxValues.outpostHp)}%` }} />
            </div>
            {/* 修复：增加不对称 padding (pl-3 pr-5) 避开右下角锐角的裁切 */}
            <div className="skew-x-[20deg] absolute inset-0 flex items-center justify-between pl-3 pr-5">
              <OutpostStateIcon state={outposts.left.state} team="red" states={outpostStateMeta} />
              <div className="flex flex-col items-end">
                 <span className="text-[10px] text-white/80 font-bold leading-none mb-0.5 whitespace-nowrap">{labels.outpost}</span>
                 <span className="font-orbitron text-xs font-bold leading-none text-red-200">{outposts.left.hp}</span>
              </div>
            </div>
          </div>

          {/* 【左侧：基地 (红血 + 绿盾)】 */}
          <div 
            className="w-[24vw] max-w-[400px] h-11 glass-panel skew-x-[-20deg] flex items-center relative overflow-hidden shadow-[0_0_15px_rgba(220,38,38,0.15)] border-t border-b border-red-500/50"
          >
            {/* 修复：解耦盾值和血条。血条铺满底层，盾值条作为独立层悬浮在内侧最上方 */}
            <div className="absolute inset-0 scanline-bg opacity-40"></div>
            {/* 主血条 (红) - 独立计算百分比 */}
            <div className="absolute bottom-0 right-0 bg-red-600/80 shadow-[0_0_10px_red] transition-all duration-300 h-full" style={{ width: `${toPercent(bases.left.hp, maxValues.baseHp)}%` }} />
            {/* 独立护盾条 (绿) - 悬浮顶部，独立计算百分比 */}
            <div className="absolute top-0 right-0 bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300 h-[4px]" style={{ width: `${toPercent(bases.left.shield, maxValues.baseShield)}%` }} />
            
            <div className="skew-x-[20deg] absolute inset-0 w-full z-10 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
              {/* 状态靠外 (左) */}
              <div className="absolute left-3 top-1/2 -translate-y-1/2 flex-shrink-0">
                <BaseStateIcon state={bases.left.state} team="red" states={baseStateMeta} />
              </div>
              {/* 血量与盾值靠内 (右) - 加入 pt-1 稍微下沉防止与上方的绿色盾条重叠 */}
              <div className="absolute right-14 top-1/2 -translate-y-1/2 flex flex-col items-end justify-center pt-1">
                {bases.left.shield > 0 && <span className="text-green-400 text-[10px] font-orbitron font-bold drop-shadow-[0_0_5px_#22c55e] tracking-wide leading-none mb-0.5">{bases.left.shield}</span>}
                <span className="text-white text-2xl font-orbitron font-bold drop-shadow-[0_0_5px_red] tracking-wide leading-none">{bases.left.hp}</span>
              </div>
            </div>
          </div>

          {/* 【左侧：比分】 */}
          <div className="w-16 h-11 ultra-glass border-t border-b border-white/20 skew-x-[-20deg] flex items-center justify-center z-10 shadow-lg ml-1">
            <div className="skew-x-[20deg] text-white font-orbitron text-3xl font-bold">{scores.left}</div>
          </div>

          {/* ================= 【中央：时间与回合】 ================= */}
          <div className="relative mx-1 z-10 w-40 h-12 flex flex-col justify-end">
            <div className="absolute -top-4 left-1/2 -translate-x-1/2 w-24 h-5 ultra-glass clip-trapezoid-top flex items-center justify-center border-t border-cyan-400/50">
              <span className="text-[10px] text-cyan-200 font-bold tracking-wider drop-shadow-md">{roundLabel}</span>
            </div>
            <div className="w-full h-12 glass-panel border-t-2 border-b-2 border-cyan-400/60 clip-trapezoid flex items-center justify-center shadow-[0_5px_15px_rgba(34,211,238,0.15)] relative">
              <div className="flex items-center gap-1.5 font-orbitron text-[28px] font-bold text-white tracking-widest mt-1 drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]">
                <span>{time.m}</span>
                <div className="flex flex-col gap-1.5 pb-1">
                  <div className="w-1.5 h-1.5 bg-cyan-400 shadow-[0_0_5px_cyan]"></div>
                  <div className={`w-1.5 h-1.5 bg-cyan-400 shadow-[0_0_5px_cyan] transition-opacity ${timeLeft % 2 === 0 ? 'opacity-100' : 'opacity-40'}`}></div>
                </div>
                <span>{time.s}</span>
              </div>
            </div>
          </div>

          {/* 【右侧：比分】 */}
          <div className="w-16 h-11 ultra-glass border-t border-b border-white/20 skew-x-[20deg] flex items-center justify-center z-10 shadow-lg mr-1">
            <div className="skew-x-[-20deg] text-white font-orbitron text-3xl font-bold">{scores.right}</div>
          </div>

          {/* 【右侧：基地 (蓝血 + 绿盾)】 */}
          <div 
            className="w-[24vw] max-w-[400px] h-11 glass-panel skew-x-[20deg] flex items-center relative overflow-hidden shadow-[0_0_15px_rgba(59,130,246,0.15)] border-t border-b border-blue-500/50"
          >
            {/* 修复：解耦盾值和血条。血条铺满底层，盾值条作为独立层悬浮在内侧最上方 */}
            <div className="absolute inset-0 scanline-bg opacity-40"></div>
            {/* 主血条 (蓝) - 独立计算百分比 */}
            <div className="absolute bottom-0 left-0 bg-blue-600/80 shadow-[0_0_10px_blue] transition-all duration-300 h-full" style={{ width: `${toPercent(bases.right.hp, maxValues.baseHp)}%` }} />
            {/* 独立护盾条 (绿) - 悬浮顶部，独立计算百分比 */}
            <div className="absolute top-0 left-0 bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300 h-[4px]" style={{ width: `${toPercent(bases.right.shield, maxValues.baseShield)}%` }} />
            
            <div className="skew-x-[-20deg] absolute inset-0 w-full z-10 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
              {/* 血量与盾值靠内 (左) - 加入 pt-1 稍微下沉防止与上方的绿色盾条重叠 */}
              <div className="absolute left-14 top-1/2 -translate-y-1/2 flex flex-col items-start justify-center pt-1">
                {bases.right.shield > 0 && <span className="text-green-400 text-[10px] font-orbitron font-bold drop-shadow-[0_0_5px_#22c55e] tracking-wide leading-none mb-0.5">{bases.right.shield}</span>}
                <span className="text-white text-2xl font-orbitron font-bold drop-shadow-[0_0_5px_blue] tracking-wide leading-none">{bases.right.hp}</span>
              </div>
              {/* 状态靠外 (右) */}
              <div className="absolute right-3 top-1/2 -translate-y-1/2 flex-shrink-0">
                <BaseStateIcon state={bases.right.state} team="blue" states={baseStateMeta} />
              </div>
            </div>
          </div>

          {/* 【右侧：前哨站 (蓝)】 */}
          <div 
            className="w-[120px] h-9 glass-panel border-t border-b border-blue-500/40 skew-x-[20deg] flex flex-col relative overflow-hidden shadow-lg transition-colors"
          >
            <div className="absolute inset-0 flex justify-start opacity-50">
              <div className="bg-blue-500 h-full transition-all duration-300" style={{ width: `${toPercent(outposts.right.hp, maxValues.outpostHp)}%` }} />
            </div>
            {/* 修复：增加不对称 padding (pl-5 pr-3) */}
            <div className="skew-x-[-20deg] absolute inset-0 flex items-center justify-between pl-5 pr-3">
              <div className="flex flex-col items-start">
                 <span className="text-[10px] text-white/80 font-bold leading-none mb-0.5 whitespace-nowrap">{labels.outpost}</span>
                 <span className="font-orbitron text-xs font-bold leading-none text-blue-200">{outposts.right.hp}</span>
              </div>
              <OutpostStateIcon state={outposts.right.state} team="blue" states={outpostStateMeta} />
            </div>
          </div>

        </div>

        {/* === 第二排：战车血条与经济 === */}
        <div className="flex justify-between items-start w-full px-[4%] mt-2 relative z-10">
          
          {/* 左侧：红方战车组 */}
          <div className="flex flex-1 justify-between mr-2">
            {leftRobots.map(robot => {
              const hpPct = toPercent(robot.hp, robot.max);
              const isDead = robot.hp === 0;
              return (
                <div key={robot.id} className={`flex-1 h-[40px] mx-1 ultra-glass skew-x-[-20deg] border-b-[2px] ${isDead ? 'border-neutral-600' : 'border-red-500/80'} relative overflow-hidden shadow-md group`}>
                   {/* 底部血量填充 */}
                   <div className={`absolute bottom-0 left-0 h-full ${isDead ? 'bg-neutral-600/30' : 'bg-red-500/30'} transition-all duration-300`} style={{ width: `${hpPct}%` }} />
                   
                   {/* 内容：ID 与 真实HP数值 */}
                   <div className="skew-x-[20deg] absolute inset-0">
                     <span className={`absolute top-0.5 left-2 font-orbitron font-black text-[13px] ${isDead ? 'text-neutral-500' : 'text-white'} drop-shadow-md`}>{robot.id}</span>
                     {/* 修复：扩大右侧偏移量防止战车血量数值被边缘斜切 */}
                     <span className={`absolute bottom-0 right-2.5 font-orbitron font-bold text-[8px] ${isDead ? 'text-neutral-500' : 'text-red-200'} drop-shadow-sm transition-all`}>{robot.hp}</span>
                   </div>
                </div>
              );
            })}
          </div>

          {/* 中央：我方(蓝方)状态栏 - 取消倾斜，保持绝对中心对称 */}
          <div className="flex justify-center mt-[1px] px-2">
            <div className="w-[85px] h-[30px] ultra-glass border-l border-r border-blue-400/40 flex items-center justify-center relative shadow-[0_0_10px_rgba(59,130,246,0.1)] hover:bg-blue-900/20 transition-colors">
              <div className="flex flex-col gap-[2px] w-full px-2">
                
                {/* 经济 */}
                <div className="flex items-center justify-between w-full cursor-pointer hover:opacity-80 transition-opacity">
                  <span className="text-[7px] text-blue-200 font-bold tracking-wider leading-none">{labels.eco}</span>
                  <div className="font-orbitron font-bold flex items-baseline gap-[1px] leading-none">
                    <span className="text-[10px] text-blue-300 drop-shadow-[0_0_3px_rgba(96,165,250,0.8)]">{stats.right.eco}</span>
                    <span className="text-[7px] text-white/40">/</span>
                    <span className="text-[7px] text-blue-200/50">{stats.right.totalEco}</span>
                  </div>
                </div>

                {/* 科技与雷达 */}
                <LevelIndicator label={labels.tech} level={stats.right.tech} max={maxValues.techLevel} team="blue" />
                <LevelIndicator label={labels.radar} level={stats.right.radar} max={maxValues.radarLevel} team="blue" />
                
              </div>
            </div>
          </div>

          {/* 右侧：蓝方战车组 (镜像排版：HP在左下，ID在右上) */}
          <div className="flex flex-1 justify-between ml-2">
            {rightRobots.map(robot => {
              const hpPct = toPercent(robot.hp, robot.max);
              const isDead = robot.hp === 0;
              return (
                <div key={robot.id} className={`flex-1 h-[40px] mx-1 ultra-glass skew-x-[20deg] border-b-[2px] ${isDead ? 'border-neutral-600' : 'border-blue-500/80'} relative overflow-hidden shadow-md group`}>
                   {/* 底部血量填充 */}
                   <div className={`absolute bottom-0 right-0 h-full ${isDead ? 'bg-neutral-600/30' : 'bg-blue-500/30'} transition-all duration-300`} style={{ width: `${hpPct}%` }} />
                   
                   {/* 内容：真实HP数值 与 ID */}
                   <div className="skew-x-[-20deg] absolute inset-0">
                     {/* 修复：扩大左侧偏移量防止战车血量数值被边缘斜切 */}
                     <span className={`absolute bottom-0 left-2.5 font-orbitron font-bold text-[8px] ${isDead ? 'text-neutral-500' : 'text-blue-200'} drop-shadow-sm transition-all`}>{robot.hp}</span>
                     <span className={`absolute top-0.5 right-2 font-orbitron font-black text-[13px] ${isDead ? 'text-neutral-500' : 'text-white'} drop-shadow-md`}>{robot.id}</span>
                   </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* ================= 挂载底层机甲面板 HUD ================= */}
      <CenterCombatHUD centerHud={centerHud} />
      <MechaHUD mecha={mecha} maxValues={maxValues} />
      
    </div>
  );
}
