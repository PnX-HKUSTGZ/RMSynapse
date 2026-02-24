import React, { useState, useEffect } from 'react';
import { 
  Heart, Shield, Zap, Crosshair, 
  Wifi, Activity, Battery, Wrench, 
  AlertTriangle, CheckCircle2, ChevronsRight
} from 'lucide-react';

const BASE_MAX_HP = 5000;
const BASE_MAX_SHIELD = 1500;
const OUTPOST_MAX_HP = 750;
// 背景强制控制开关（true = 纯黑背景，false = 透明背景）
const FORCE_BLACK_BG = false;

// 默认 UI 数据（当 Godot 还没推送任何数据时使用）
export const DEFAULT_UI_STATE = {
  timeLeft: 420,
  scores: { left: 0, right: 0 },
  bases: {
    left: { hp: 4200, shield: 800, state: 0 },
    right: { hp: 5000, shield: 1500, state: 0 }
  },
  outposts: {
    left: { hp: 530, state: 1 },
    right: { hp: 0, state: 3 }
  },
  stats: {
    left: { eco: 50, totalEco: 300, tech: 2, radar: 3 },
    right: { eco: 120, totalEco: 450, tech: 4, radar: 5 }
  },
  robots: {
    left: [
      { id: 7, hp: 600, max: 600 },
      { id: 6, hp: 500, max: 500 },
      { id: 4, hp: 200, max: 400 },
      { id: 3, hp: 400, max: 400 },
      { id: 2, hp: 150, max: 400 },
      { id: 1, hp: 2000, max: 2000 }
    ],
    right: [
      { id: 1, hp: 1800, max: 2000 },
      { id: 2, hp: 400, max: 400 },
      { id: 3, hp: 0, max: 400 },
      { id: 4, hp: 400, max: 400 },
      { id: 6, hp: 500, max: 500 },
      { id: 7, hp: 600, max: 600 }
    ]
  }
};

// ============================================================================
// 子组件：MechaHUD 玩家视角的底层信息 (原 App1.jsx)
// ============================================================================
const MechaHUD = () => {
  // --- 状态模拟 ---
  const [hp, setHp] = useState(1650);
  const maxHp = 2000;
  
  const [boost, setBoost] = useState(400); // 冲刺/体力
  const maxBoost = 500;
  
  const [energy, setEnergy] = useState(2850); // 真实数值
  const [maxPower, setMaxPower] = useState(3500); // 当前最大功率
  
  const [ammo, setAmmo] = useState(12450);
  
  const [inCombat, setInCombat] = useState(false);
  const [combatTimer, setCombatTimer] = useState(5.0);
  
  const [remoteHealReady, setRemoteHealReady] = useState(true);
  const [remoteAmmoReady, setRemoteAmmoReady] = useState(false);

  // 模拟数据跳动、体力恢复和脱战倒计时
  useEffect(() => {
    const interval = setInterval(() => {
      setEnergy(prev => Math.max(0, Math.min(maxPower, prev + (Math.random() * 20 - 10))));
      setBoost(prev => Math.min(maxBoost, prev + 2)); // 体力自动恢复
      
      if (!inCombat && combatTimer > 0) {
        setCombatTimer(prev => Math.max(0, prev - 0.1));
      }
    }, 100);
    return () => clearInterval(interval);
  }, [inCombat, combatTimer, maxPower]);


  const hpColor = hp / maxHp > 0.3 ? 'bg-emerald-500' : 'bg-red-500';
  const boostColor = boost / maxBoost > 0.2 ? 'bg-cyan-400' : 'bg-red-500';
  const energyColor = energy / maxPower > 0.2 ? 'bg-amber-400' : 'bg-red-500';

  return (
    // 使用 absolute inset-0 和 pointer-events-none 让它作为叠加层存在，不阻挡背景和其他操作
    <div className="absolute inset-0 pointer-events-none overflow-hidden font-mono select-none z-0">

      {/* ==================== 左下角区域 (高密度整合) ==================== */}
      <div className="absolute bottom-12 left-8 flex flex-col gap-2 w-[420px] z-10 drop-shadow-lg">
        
        {/* Row 1：ID、连接状态、等级 */}
        <div className="flex items-end justify-between px-2 text-emerald-400 drop-shadow-[0_2px_2px_rgba(0,0,0,0.8)]">
          <div className="flex items-center gap-3">
            <span className="text-xl font-bold tracking-wider drop-shadow-[0_0_5px_rgba(52,211,153,0.8)]">
              RBT-79[X]
            </span>
            <div className="flex items-center gap-1 bg-emerald-900/60 px-2 py-0.5 border border-emerald-500/30 skew-x-[-15deg] backdrop-blur-sm">
              <span className="skew-x-[15deg] text-xs font-bold text-emerald-300">LV.42</span>
            </div>
          </div>
          <div className="flex items-center gap-2 text-[10px] font-bold tracking-widest text-emerald-300/80">
            <Wifi size={12} className="animate-pulse" />
            <span>LINKED</span>
          </div>
        </div>

        {/* Row 2：主血量条 */}
        <div className="relative">
          <div className="flex justify-between text-xs text-emerald-200 mb-0.5 px-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1"><Heart size={12}/> CORE HP</span>
            <span className="font-bold text-white text-sm">
              {Math.round(hp)} <span className="text-emerald-500/90 text-xs">/ {maxHp}</span>
            </span>
          </div>
          <div className="h-5 w-full bg-slate-900/60 border-l-4 border-emerald-500 p-0.5 skew-x-[-10deg] backdrop-blur-md shadow-[0_4px_10px_rgba(0,0,0,0.5)]">
            <div 
              className={`h-full ${hpColor} transition-all duration-300 ease-out shadow-[0_0_10px_rgba(52,211,153,0.3)]`}
              style={{ width: `${(hp / maxHp) * 100}%` }}
            />
          </div>
        </div>

        {/* Row 3：底盘能量 & 最大功率 */}
        <div className="flex gap-3 items-end">
          <div className="flex-1 relative">
            <div className="flex justify-between text-[10px] text-amber-200/90 mb-0.5 px-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="flex items-center gap-1"><Zap size={10}/> ENG PWR</span>
              <span className="font-bold">{Math.round(energy)} <span className="text-[9px] text-amber-400/70">kW</span></span>
            </div>
            <div className="h-2 w-full bg-slate-900/60 border-l-2 border-amber-500 p-[1px] skew-x-[-10deg] backdrop-blur-md shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
              <div 
                className={`h-full ${energyColor} transition-all duration-100 ease-linear`}
                style={{ width: `${(energy / maxPower) * 100}%` }}
              />
            </div>
          </div>
          <div className="bg-slate-900/60 border border-slate-500/50 px-2 py-0.5 skew-x-[-10deg] backdrop-blur-md shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
            <div className="skew-x-[10deg] flex items-baseline gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="text-[9px] text-slate-300">CUR MAX</span>
              <span className="text-amber-400 font-bold text-xs">{maxPower}</span>
            </div>
          </div>
        </div>

        {/* Row 4：状态、弹药、支援模块 */}
        <div className="flex gap-2 mt-1 drop-shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
          {/* 战斗状态与弹药 */}
          <div className="flex-1 bg-slate-900/60 border-l-2 border-slate-500 px-3 py-1 flex items-center justify-between skew-x-[-10deg] backdrop-blur-md">
            <div className="skew-x-[10deg] flex items-center gap-2">
              {inCombat ? (
                <span className="text-[11px] text-red-500 font-bold animate-pulse flex items-center gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <AlertTriangle size={12}/> [ENGAGED]
                </span>
              ) : combatTimer > 0 ? (
                <span className="text-[11px] text-amber-400 font-bold flex items-center gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <Activity size={12} className="animate-spin-slow"/> [CD: {combatTimer.toFixed(1)}s]
                </span>
              ) : (
                <span className="text-[11px] text-cyan-400 font-bold flex items-center gap-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
                  <CheckCircle2 size={12}/> [SAFE]
                </span>
              )}
            </div>
            <div className="skew-x-[10deg] flex items-center gap-1 text-[11px] text-slate-200 font-bold tracking-wider drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <Crosshair size={12}/> AMMO: {ammo.toLocaleString()}
            </div>
          </div>
          {/* 远程支援状态灯 */}
          <div className="bg-slate-900/60 border-r-2 border-slate-500 px-3 py-1 flex items-center skew-x-[-10deg] backdrop-blur-md">
            <div className="skew-x-[10deg] flex gap-3">
              <Wrench size={14} className={remoteHealReady ? "text-emerald-400 drop-shadow-[0_0_3px_rgba(52,211,153,0.8)]" : "text-slate-600"} />
              <Battery size={14} className={remoteAmmoReady ? "text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]" : "text-slate-600"} />
            </div>
          </div>
        </div>

      </div>

      {/* ==================== 中下区域 (极简冲刺/体力条) ==================== */}
      <div className="absolute bottom-12 left-1/2 -translate-x-1/2 flex flex-col items-center w-[400px] z-10 drop-shadow-lg">
        <div className="w-full relative">
          {/* 体力数值 */}
          <div className="absolute -top-5 w-full flex justify-between px-2 text-xs font-bold text-cyan-300 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1 drop-shadow-[0_0_2px_rgba(34,211,238,0.8)]">
              <ChevronsRight size={14}/> BOOST
            </span>
            <span className="text-white drop-shadow-[0_0_2px_#fff]">
              {Math.round(boost)} <span className="text-cyan-500/90">/ {maxBoost}</span>
            </span>
          </div>
          
          {/* 体力条本体 */}
          <div className="w-full h-4 filter drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)]">
             <div className="w-full h-full bg-slate-900/60 border border-cyan-500/60 p-0.5 skew-x-[-15deg] backdrop-blur-md">
                 <div 
                   className={`h-full ${boostColor} transition-all duration-100 ease-out`}
                   style={{ width: `${(boost / maxBoost) * 100}%` }}
                 />
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};


// ============================================================================
// 主组件：App (包含顶层全局 HUD，以及挂载 MechaHUD)
// ============================================================================
export default function App() {
  // --- 比赛状态 ---
  const [timeLeft, setTimeLeft] = useState(DEFAULT_UI_STATE.timeLeft);
  const [scores, setScores] = useState(DEFAULT_UI_STATE.scores);

  // Debug: last message timestamp
  const [lastMsg, setLastMsg] = useState('');
  // 背景由代码常量控制
  const [blackBg] = useState(FORCE_BLACK_BG);

  // 队伍状态数据
  const [bases, setBases] = useState(DEFAULT_UI_STATE.bases);
  const [outposts, setOutposts] = useState(DEFAULT_UI_STATE.outposts);

  // 经济与科技状态
  const [stats, setStats] = useState(DEFAULT_UI_STATE.stats);

  // 新增：战车详细状态数据 (包含具体血量)
  const [robots, setRobots] = useState(DEFAULT_UI_STATE.robots);

  // ================= 与 Godot 通信入口 =================
  useEffect(() => {
    window.godotPush = (payload) => {
      const data = typeof payload === "string" ? JSON.parse(payload) : payload;
      const now = new Date();
      setLastMsg(now.toLocaleTimeString() + '.' + String(now.getMilliseconds()).padStart(3, '0'));
      // Debug: verify we are receiving bases updates
      if (data.bases) console.log('bases update', data.bases);

      if (data.timeLeft != null) {
        setTimeLeft(data.timeLeft);
      }

      if (data.scores) {
        setScores(prev => ({ ...prev, ...data.scores }));
      }

      if (data.stats) {
        setStats(prev => ({
          left: { ...prev.left, ...data.stats.left },
          right: { ...prev.right, ...data.stats.right }
        }));
      }

      if (data.bases) {
        setBases(prev => ({
          left: { ...prev.left, ...data.bases.left },
          right: { ...prev.right, ...data.bases.right }
        }));
      }

      if (data.outposts) {
        setOutposts(prev => ({
          left: { ...prev.left, ...data.outposts.left },
          right: { ...prev.right, ...data.outposts.right }
        }));
      }

      if (data.robots) {
        setRobots(prev => ({
          left: data.robots.left ?? prev.left,
          right: data.robots.right ?? prev.right
        }));
      }
    };

    return () => {
      delete window.godotPush;
    };
  }, []);


  const time = {
    m: Math.floor(timeLeft / 60).toString().padStart(2, '0'),
    s: (timeLeft % 60).toString().padStart(2, '0')
  };

  return (
    <div className={`min-h-screen ${blackBg ? 'bg-black' : 'bg-transparent'} flex flex-col items-center pt-2 relative overflow-hidden font-sans text-white select-none`}>
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
              <div className="bg-red-500 h-full transition-all duration-300" style={{ width: `${(outposts.left.hp / OUTPOST_MAX_HP) * 100}%` }} />
            </div>
            {/* 修复：增加不对称 padding (pl-3 pr-5) 避开右下角锐角的裁切 */}
            <div className="skew-x-[20deg] absolute inset-0 flex items-center justify-between pl-3 pr-5">
              <OutpostStateIcon state={outposts.left.state} team="red" />
              <div className="flex flex-col items-end">
                 <span className="text-[10px] text-white/80 font-bold leading-none mb-0.5 whitespace-nowrap">前哨站</span>
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
            <div className="absolute bottom-0 right-0 bg-red-600/80 shadow-[0_0_10px_red] transition-all duration-300 h-full" style={{ width: `${(bases.left.hp / BASE_MAX_HP) * 100}%` }} />
            {/* 独立护盾条 (绿) - 悬浮顶部，独立计算百分比 */}
            <div className="absolute top-0 right-0 bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300 h-[4px]" style={{ width: `${(bases.left.shield / BASE_MAX_SHIELD) * 100}%` }} />
            
            <div className="skew-x-[20deg] absolute inset-0 w-full z-10 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
              {/* 状态靠外 (左) */}
              <div className="absolute left-3 top-1/2 -translate-y-1/2 flex-shrink-0">
                <BaseStateIcon state={bases.left.state} team="red" />
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
              <span className="text-[10px] text-cyan-200 font-bold tracking-wider drop-shadow-md">Round 2/5</span>
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
            <div className="absolute bottom-0 left-0 bg-blue-600/80 shadow-[0_0_10px_blue] transition-all duration-300 h-full" style={{ width: `${(bases.right.hp / BASE_MAX_HP) * 100}%` }} />
            {/* 独立护盾条 (绿) - 悬浮顶部，独立计算百分比 */}
            <div className="absolute top-0 left-0 bg-green-500 shadow-[0_0_10px_#22c55e] transition-all duration-300 h-[4px]" style={{ width: `${(bases.right.shield / BASE_MAX_SHIELD) * 100}%` }} />
            
            <div className="skew-x-[-20deg] absolute inset-0 w-full z-10 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
              {/* 血量与盾值靠内 (左) - 加入 pt-1 稍微下沉防止与上方的绿色盾条重叠 */}
              <div className="absolute left-14 top-1/2 -translate-y-1/2 flex flex-col items-start justify-center pt-1">
                {bases.right.shield > 0 && <span className="text-green-400 text-[10px] font-orbitron font-bold drop-shadow-[0_0_5px_#22c55e] tracking-wide leading-none mb-0.5">{bases.right.shield}</span>}
                <span className="text-white text-2xl font-orbitron font-bold drop-shadow-[0_0_5px_blue] tracking-wide leading-none">{bases.right.hp}</span>
              </div>
              {/* 状态靠外 (右) */}
              <div className="absolute right-3 top-1/2 -translate-y-1/2 flex-shrink-0">
                <BaseStateIcon state={bases.right.state} team="blue" />
              </div>
            </div>
          </div>

          {/* 【右侧：前哨站 (蓝)】 */}
          <div 
            className="w-[120px] h-9 glass-panel border-t border-b border-blue-500/40 skew-x-[20deg] flex flex-col relative overflow-hidden shadow-lg transition-colors"
          >
            <div className="absolute inset-0 flex justify-start opacity-50">
              <div className="bg-blue-500 h-full transition-all duration-300" style={{ width: `${(outposts.right.hp / OUTPOST_MAX_HP) * 100}%` }} />
            </div>
            {/* 修复：增加不对称 padding (pl-5 pr-3) */}
            <div className="skew-x-[-20deg] absolute inset-0 flex items-center justify-between pl-5 pr-3">
              <div className="flex flex-col items-start">
                 <span className="text-[10px] text-white/80 font-bold leading-none mb-0.5 whitespace-nowrap">前哨站</span>
                 <span className="font-orbitron text-xs font-bold leading-none text-blue-200">{outposts.right.hp}</span>
              </div>
              <OutpostStateIcon state={outposts.right.state} team="blue" />
            </div>
          </div>

        </div>

        {/* === 第二排：战车血条与经济 === */}
        <div className="flex justify-between items-start w-full px-[4%] mt-2 relative z-10">
          
          {/* 左侧：红方战车组 */}
          <div className="flex flex-1 justify-between mr-2">
            {robots.left.map(robot => {
              const hpPct = (robot.hp / robot.max) * 100;
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
                  <span className="text-[7px] text-blue-200 font-bold tracking-wider leading-none">ECO</span>
                  <div className="font-orbitron font-bold flex items-baseline gap-[1px] leading-none">
                    <span className="text-[10px] text-blue-300 drop-shadow-[0_0_3px_rgba(96,165,250,0.8)]">{stats.right.eco}</span>
                    <span className="text-[7px] text-white/40">/</span>
                    <span className="text-[7px] text-blue-200/50">{stats.right.totalEco}</span>
                  </div>
                </div>

                {/* 科技与雷达 */}
                <LevelIndicator label="TECH" level={stats.right.tech} max={4} team="blue" />
                <LevelIndicator label="RADAR" level={stats.right.radar} max={5} team="blue" />
                
              </div>
            </div>
          </div>

          {/* 右侧：蓝方战车组 (镜像排版：HP在左下，ID在右上) */}
          <div className="flex flex-1 justify-between ml-2">
            {robots.right.map(robot => {
              const hpPct = (robot.hp / robot.max) * 100;
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
      <MechaHUD />
      
    </div>
  );
}

// ============================================================================
// 子组件：基地状态图标 (修复为竖排微缩版)
// ============================================================================
function BaseStateIcon({ state, team }) {
  const isRed = team === 'red';
  const color = isRed ? 'text-red-300 border-red-500/30 bg-red-950/40' : 'text-blue-300 border-blue-500/30 bg-blue-950/40';
  
  let icon, label;
  if (state === 0) { icon = "🛡️"; label = "无敌"; }
  if (state === 1) { icon = "⚠️"; label = "接敌"; }
  if (state === 2) { icon = "💠"; label = "护甲"; }

  return (
    <div className={`flex flex-col items-center justify-center gap-[2px] px-1.5 py-[2px] border rounded-sm ${color} backdrop-blur-sm whitespace-nowrap`}>
      <span className="text-[11px] drop-shadow-md leading-none">{icon}</span>
      <span className="text-[7px] font-bold tracking-widest leading-none">{label}</span>
    </div>
  );
}

// ============================================================================
// 子组件：前哨站状态图标 (6种状态)
// ============================================================================
function OutpostStateIcon({ state, team }) {
  const isRed = team === 'red';
  const color = isRed ? 'text-red-300 bg-red-950/40 border-red-500/30' : 'text-blue-300 bg-blue-950/40 border-blue-500/30';
  
  let icon = "";
  let spin = false;
  
  switch(state) {
    case 0: icon = "🔒"; break; 
    case 1: icon = "🔄"; spin = true; break; 
    case 2: icon = "⏸️"; break; 
    case 3: icon = "❌"; break; 
    case 4: icon = "🔧"; break; 
    case 5: icon = "⏳"; spin = true; break; 
    default: icon = "❓";
  }

  return (
    <div className={`w-6 h-6 rounded flex items-center justify-center text-xs border backdrop-blur-sm ${color}`}>
      <div className={spin ? 'animate-spin' : ''}>{icon}</div>
    </div>
  );
}

// ============================================================================
// 子组件：科技/雷达等级指示器 (阵列光格)
// ============================================================================
function LevelIndicator({ label, level, max, team }) {
  const isRed = team === 'red';
  const color = isRed ? 'bg-red-400 shadow-[0_0_3px_red]' : 'bg-blue-400 shadow-[0_0_3px_blue]';
  const emptyColor = 'bg-white/10';
  
  return (
    <div className="flex items-center justify-between w-full">
      <span className={`text-[7px] font-bold tracking-wider leading-none ${isRed ? 'text-red-200' : 'text-blue-200'}`}>{label}</span>
      <div className="flex gap-[1.5px]">
        {Array.from({ length: max }).map((_, i) => (
          <div 
            key={i} 
            /* 移除倾斜，保持正方形阵列 */
            className={`w-[6px] h-[5px] border-[0.5px] border-black/50 transition-colors duration-300 ${i < level ? color : emptyColor}`} 
          />
        ))}
      </div>
    </div>
  );
}