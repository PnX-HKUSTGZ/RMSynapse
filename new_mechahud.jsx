import React, { useState, useEffect } from 'react';
import {
  Activity,
  AlertTriangle,
  Battery,
  Box,
  Check,
  Cpu,
  Crosshair,
  Heart,
  Radio,
  ShieldAlert,
  Signal,
  Video,
  Wifi,
  WifiOff,
  Zap,
  Lock,
  Unlock
} from 'lucide-react';

// ============================================================================
// 1. 辅助函数
// ============================================================================
const toPercent = (current, max) => {
  if (!max || max <= 0) return 0;
  return Math.min(100, Math.max(0, (current / max) * 100));
};

const translateRobotId = (id) => {
  if (!id) return 'UNKNOWN';
  return id
    .replace('英雄', 'HERO')
    .replace('步兵', 'INFANTRY')
    .replace('工程', 'ENGINEER')
    .replace('哨兵', 'SENTRY')
    .replace('飞镖', 'DART')
    .replace('空中', 'AERIAL');
};

// ============================================================================
// 2. 纯展示组件：MechaHUD 
// ============================================================================
function MechaHUD({ mecha = {}, uiSizing = {} }) {
  const {
    robot_id = 'HERO R1',
    level = 1,
    is_level_event_triggered = false, // 新增：等级锁事件触发状态
    connection_state = 1,
    field_state = 0,
    alive_state = 1,
    
    current_health = 0,
    max_health = 500,
    
    current_chassis_energy = 0,
    max_chassis_energy = 20000,
    
    is_out_of_combat = true,
    can_remote_heal = false,
    can_remote_ammo = false,
    
    total_projectiles_fired = 0,
    last_projectile_fire_rate = 0,
    current_experience = 0,
    experience_for_upgrade = 100,
    
    modules = {
      rfid: 1, uwb: 1, armor: 1, video_transmission: 1, main_controller: 1, capacitor: 1,
    }
  } = mecha;

  // 状态推导
  const mechaHudScale = uiSizing?.mechaHudScale > 0 ? uiSizing.mechaHudScale : 1;
  const hpPercent = toPercent(current_health, max_health);
  const expPercent = toPercent(current_experience, experience_for_upgrade);
  const isHpLow = hpPercent < 30;
  const displayId = translateRobotId(robot_id);

  // 等级锁计算逻辑
  const maxAllowedLevel = is_level_event_triggered ? 10 : 5;
  const displayLevel = Math.min(level, maxAllowedLevel);

  const moduleConfigs = [
    { key: 'rfid', label: 'RFID', status: modules.rfid, icon: Radio },
    { key: 'uwb', label: 'UWB', status: modules.uwb, icon: Signal },
    { key: 'armor', label: 'ARMOR', status: modules.armor, icon: ShieldAlert },
    { key: 'video_transmission', label: 'VIDEO', status: modules.video_transmission, icon: Video },
    { key: 'main_controller', label: 'MAIN', status: modules.main_controller, icon: Cpu },
    { key: 'capacitor', label: 'CAP', status: modules.capacitor, icon: Zap },
  ];

  return (
    <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden font-mono select-none">
      <div
        className="absolute bottom-12 left-12 z-10 flex w-[480px] flex-col gap-2 drop-shadow-xl"
        style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom left' }}
      >
        {/* Row 1: 身份与连接状态 */}
        <div className="flex items-end justify-between px-2 drop-shadow-[0_2px_2px_rgba(0,0,0,0.8)]">
          <div className="flex items-center gap-3">
            <span className="text-2xl font-black italic tracking-wider text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.6)]">
              {displayId}
            </span>
            <div className="flex items-center gap-1 border-l-2 border-emerald-500 bg-emerald-900/60 px-2.5 py-0.5 skew-x-[-15deg] backdrop-blur-sm">
              <span className="flex items-center gap-0.5 text-sm font-bold text-emerald-300 skew-x-[15deg]">
                Lv.{displayLevel}
                {/* 动态显示等级锁状态 */}
                {!is_level_event_triggered ? (
                  <Lock size={10} className="text-emerald-500/60" />
                ) : (
                  <Unlock size={10} className="text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]" />
                )}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 text-xs font-bold tracking-wider">
            {connection_state === 0 ? (
              <span className="flex animate-pulse items-center gap-1 border border-red-500 bg-red-500/20 px-1.5 py-0.5 text-red-400">
                <WifiOff size={12} /> OFFLINE
              </span>
            ) : (
              <span className="flex items-center gap-1 text-emerald-500/60">
                <Wifi size={12} /> ONLINE
              </span>
            )}
            {field_state === 1 && (
              <span className="border border-amber-500 bg-amber-500/20 px-1.5 py-0.5 text-amber-400">
                NOT FIELD
              </span>
            )}
            {alive_state === 2 ? (
              <span className="animate-pulse border border-red-500 bg-red-500/20 px-1.5 py-0.5 text-red-400">
                DEAD
              </span>
            ) : alive_state === 1 ? (
              <span className="text-emerald-500/60">ALIVE</span>
            ) : (
              <span className="text-slate-500">UNKNOWN</span>
            )}
          </div>
        </div>

        {/* Row 2: 主血量 (带25%刻度) */}
        <div className="relative mt-0.5">
          <div className="mb-1 flex items-end justify-between px-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1.5 text-sm font-bold text-emerald-300">
              <Heart size={14} className={isHpLow ? 'animate-pulse text-red-400' : ''} />
              HP
            </span>
            <span className="text-lg font-black tracking-wider text-white">
              {Math.round(current_health)}
              <span className="text-sm text-slate-400"> / {max_health}</span>
            </span>
          </div>
          
          <div className="relative h-8 w-full overflow-hidden border-l-4 border-emerald-500 bg-slate-900/80 p-0.5 shadow-[0_4px_10px_rgba(0,0,0,0.5)] skew-x-[-15deg] backdrop-blur-md">
            <div
              className={`relative z-0 h-full transition-all duration-300 ease-out ${
                isHpLow ? 'bg-red-500 shadow-[0_0_15px_rgba(239,68,68,0.5)]' : 'bg-emerald-500 shadow-[0_0_15px_rgba(52,211,153,0.3)]'
              }`}
              style={{ width: `${hpPercent}%` }}
            />
            <div className="pointer-events-none absolute bottom-0 left-[25%] top-0 z-10 w-0.5 bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[50%] top-0 z-10 w-[3px] bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[75%] top-0 z-10 w-0.5 bg-slate-900/90" />
          </div>
        </div>

        {/* Row 3: EXP (已扩容)、战术状态(已压缩)与射击数据 */}
        <div className="mt-1 flex items-stretch gap-1.5 drop-shadow-[0_2px_5px_rgba(0,0,0,0.5)]">
          
          {/* EXP 已大幅增加空间比例 flex-[1.4] */}
          <div className="relative flex flex-[1.4] items-center overflow-hidden border-l-2 border-purple-500 bg-slate-900/80 px-2 py-1 skew-x-[-15deg] backdrop-blur-md">
            <div className="absolute bottom-0 left-0 top-0 bg-purple-500/30 transition-all duration-300" style={{ width: `${expPercent}%` }} />
            
            {/* EXP 25% 分割线 */}
            <div className="pointer-events-none absolute bottom-0 left-[25%] top-0 z-0 w-px bg-slate-900/80" />
            <div className="pointer-events-none absolute bottom-0 left-[50%] top-0 z-0 w-[2px] bg-slate-900/80" />
            <div className="pointer-events-none absolute bottom-0 left-[75%] top-0 z-0 w-px bg-slate-900/80" />

            <div className="relative z-10 flex w-full items-center justify-between text-[10px] skew-x-[15deg]">
              <span className="font-bold text-purple-300">EXP</span>
              <span className="font-bold text-white">{Math.round(current_experience)}</span>
            </div>
          </div>

          {/* 压缩版的战术面板 (去除了冗长文字，全靠图标与颜色表达) flex-[1] */}
          <div className="flex flex-[1] items-center justify-between bg-slate-900/80 px-2 py-1 skew-x-[-15deg] backdrop-blur-md">
            <div className="flex w-full items-center justify-between skew-x-[15deg]">
              {!is_out_of_combat ? (
                <span className="flex animate-pulse items-center gap-0.5 text-[11px] font-black text-red-500 drop-shadow-[0_0_5px_rgba(239,68,68,0.8)]">
                  <AlertTriangle size={10} /> COMBAT
                </span>
              ) : (
                <span className="flex items-center gap-0.5 text-[11px] font-bold text-slate-400">
                  <Check size={10} /> SAFE
                </span>
              )}

              {/* 远程补给仅用图标明暗表示 */}
              <div className="flex gap-2">
                <Heart size={12} className={can_remote_heal ? 'text-emerald-400 drop-shadow-[0_0_3px_rgba(52,211,153,0.8)]' : 'text-slate-600'} />
                <Box size={12} className={can_remote_ammo ? 'text-amber-400 drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]' : 'text-slate-600'} />
              </div>
            </div>
          </div>

          <div className="flex w-[100px] items-center justify-center border-r-2 border-slate-500 bg-slate-900/80 px-2 py-1 skew-x-[-15deg] backdrop-blur-md">
            <div className="flex w-full items-center justify-between text-[10px] font-bold text-slate-300 skew-x-[15deg]">
              <span className="flex items-center gap-0.5" title="累计发弹量">
                <Crosshair size={10} className="text-cyan-400" />
                {total_projectiles_fired}
              </span>
              <span className="flex items-center gap-0.5" title="上一次射速">
                <Activity size={10} className="text-amber-400" />
                {last_projectile_fire_rate.toFixed(1)}
              </span>
            </div>
          </div>
        </div>

        {/* Row 4: 底盘能量 */}
        <div className="relative mt-0.5">
          <div className="mb-0.5 flex justify-between px-1 text-[11px] drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
            <span className="flex items-center gap-1 font-bold text-cyan-300">
              <Battery size={12} /> ENERGY
            </span>
            <span className="font-bold text-white">
              {Math.round(current_chassis_energy)}
              <span className="text-[10px] text-slate-400"> / {max_chassis_energy}</span>
            </span>
          </div>
          <div className="relative h-4 w-full overflow-hidden border-l-2 border-cyan-500 bg-slate-900/80 p-[1px] shadow-[0_2px_5px_rgba(0,0,0,0.5)] skew-x-[-15deg] backdrop-blur-md">
            <div
              className="relative z-0 h-full bg-cyan-400 shadow-[0_0_8px_rgba(34,211,238,0.4)] transition-all duration-300 ease-out"
              style={{ width: `${toPercent(current_chassis_energy, max_chassis_energy)}%` }}
            />
            {/* Energy 25% 分割线 */}
            <div className="pointer-events-none absolute bottom-0 left-[25%] top-0 z-10 w-px bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[50%] top-0 z-10 w-[2px] bg-slate-900/90" />
            <div className="pointer-events-none absolute bottom-0 left-[75%] top-0 z-10 w-px bg-slate-900/90" />
          </div>
        </div>

        {/* Row 5: 底盘关键模块自检 (极致压缩空间，保证6个模块同时异常也不溢出) */}
        <div className="mt-1 flex w-full flex-nowrap items-center justify-start gap-1">
          {moduleConfigs.map((mod) => {
            const isNormal = mod.status === 1;
            const isOffline = mod.status === 0;
            
            if (!isNormal) {
              return (
                <div 
                  key={mod.key}
                  className="shrink-0 flex animate-pulse items-center border border-red-500/80 bg-red-900/40 px-1.5 py-0.5 skew-x-[-15deg] backdrop-blur-md shadow-[0_0_10px_rgba(239,68,68,0.5)] transition-all"
                >
                  <div className="flex items-center whitespace-nowrap gap-0.5 text-[9px] font-black tracking-tight text-red-400 skew-x-[15deg]">
                    <mod.icon size={10} />
                    {mod.label} {isOffline ? 'OFF' : 'ERR'}
                  </div>
                </div>
              );
            }

            return (
              <div 
                key={mod.key}
                className="shrink-0 flex items-center bg-slate-900/60 px-1.5 py-0.5 border-l border-emerald-500/30 skew-x-[-15deg] transition-all"
              >
                <div className="flex items-center whitespace-nowrap gap-0.5 text-[9px] font-bold tracking-tight text-slate-400 skew-x-[15deg]">
                  {mod.label} <span className="text-emerald-500">✓</span>
                </div>
              </div>
            );
          })}
        </div>

      </div>
    </div>
  );
}

// ============================================================================
// 3. 动态调试主应用容器 (包含等级锁逻辑测试)
// ============================================================================
export default function App() {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setTick((t) => t + 1), 100);
    return () => clearInterval(timer);
  }, []);

  const phaseTick = tick % 150;
  const phase = Math.floor(phaseTick / 30); // 0, 1, 2, 3, 4

  // 基础初始属性：我们将真实等级(level)跟时间挂钩，持续自动上升
  // phaseTick 最大为 150，除以 15 最大为 10，真实等级平滑从 1 升至 10
  const realLevel = Math.min(10, Math.floor(phaseTick / 15) + 1);

  let mechaState = {
    robot_id: '英雄 R1',
    level: realLevel, 
    is_level_event_triggered: false, // 默认未触发等级解锁事件
    max_health: 500,
    max_chassis_energy: 20000,
    experience_for_upgrade: 100,
    
    current_health: 500,
    current_chassis_energy: 20000,
    current_experience: (tick * 2) % 100,
    total_projectiles_fired: Math.floor(tick / 2),
    last_projectile_fire_rate: 0,
    is_out_of_combat: true,
    alive_state: 1,
    connection_state: 1,
    field_state: 0,
    can_remote_heal: true,
    can_remote_ammo: true,
    modules: { rfid: 1, uwb: 1, armor: 1, video_transmission: 1, main_controller: 1, capacitor: 1 },
  };

  let phaseDescription = '';
  let phaseTitle = '';

  if (phase === 0) {
    phaseTitle = '阶段 1：系统正常 (Lv锁死)';
    phaseDescription = `脱战巡逻。真实等级 Lv.${realLevel}，因未触发事件锁定最高 Lv.5`;
    mechaState.current_health = 500;
    mechaState.current_chassis_energy = 20000;
    
  } else if (phase === 1) {
    phaseTitle = '阶段 2：接敌开火 (Lv锁死)';
    phaseDescription = `进入战斗。真实等级 Lv.${realLevel}，UI界面依然锁死在 Lv.5`;
    mechaState.is_out_of_combat = false;
    mechaState.last_projectile_fire_rate = 14.5 + Math.random() * 2;
    mechaState.current_health = 500 - (phaseTick - 30) * 10; 
    mechaState.current_chassis_energy = 20000 - (phaseTick - 30) * 300;

  } else if (phase === 2) {
    phaseTitle = '阶段 3：装甲危急 (Lv锁死)';
    phaseDescription = `血量跌破30%。真实等级已达 Lv.${realLevel}，界面仍然锁死在 Lv.5 且金锁未开`;
    mechaState.is_out_of_combat = false;
    mechaState.last_projectile_fire_rate = 16.0 + Math.random() * 1;
    mechaState.can_remote_heal = false;
    mechaState.current_health = 140 - (phaseTick - 60) * 2;
    mechaState.current_chassis_energy = 11000;

  } else if (phase === 3) {
    phaseTitle = '阶段 4：事件触发！(全线崩溃)';
    phaseDescription = `触发等级上限解锁事件！同时测试极端情况：6个核心模块全部发生严重故障！`;
    mechaState.is_level_event_triggered = true; // 触发解锁！
    mechaState.is_out_of_combat = false;
    mechaState.current_health = 80;
    mechaState.current_chassis_energy = 10000;
    // 强制 6 个模块同时报错，测试单行是否被挤出去
    mechaState.modules.rfid = 0; 
    mechaState.modules.uwb = 0; 
    mechaState.modules.armor = 2; 
    mechaState.modules.video_transmission = 0; 
    mechaState.modules.main_controller = 0; 
    mechaState.modules.capacitor = 0; 

  } else if (phase === 4) {
    phaseTitle = '阶段 5：机体阵亡';
    phaseDescription = '失联，主控离线。';
    mechaState.is_level_event_triggered = true; 
    mechaState.is_out_of_combat = true; 
    mechaState.current_health = 0;
    mechaState.current_chassis_energy = 0;
    mechaState.alive_state = 2; 
    mechaState.connection_state = 0; 
    mechaState.can_remote_ammo = false;
    mechaState.can_remote_heal = false;
    mechaState.modules.main_controller = 0;
    mechaState.modules.video_transmission = 0;
    mechaState.modules.armor = 0;
  }

  return (
    <div className="relative h-screen w-full overflow-hidden bg-neutral-950 font-sans">
      <div className="absolute inset-0 bg-[radial-gradient(#333_1px,transparent_1px)] [background-size:20px_20px] opacity-30" />

      <div className="absolute left-1/2 top-10 flex -translate-x-1/2 flex-col items-center gap-2 z-20">
        <div className="rounded border border-emerald-500/50 bg-emerald-950/80 px-6 py-2 backdrop-blur shadow-[0_0_15px_rgba(16,185,129,0.2)]">
          <h2 className="text-xl font-bold tracking-widest text-emerald-400">
            {phaseTitle}
          </h2>
        </div>
        <p className="text-sm font-mono text-slate-400 max-w-md text-center">
          {phaseDescription}
        </p>
        
        <div className="mt-4 flex w-64 h-1.5 bg-neutral-800 rounded-full overflow-hidden">
          <div 
            className="h-full bg-emerald-500 transition-all duration-100 ease-linear"
            style={{ width: `${(phaseTick / 150) * 100}%` }}
          />
        </div>
      </div>

      <MechaHUD mecha={mechaState} uiSizing={{ mechaHudScale: 1.1 }} />
    </div>
  );
}