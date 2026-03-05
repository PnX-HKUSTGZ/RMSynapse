import React, { useState, useEffect } from 'react';
import { 
  ChevronsRight, 
  Sword, 
  Shield, 
  Snowflake, 
  Zap, 
  HeartPlus, 
  Crosshair, 
  Mountain 
} from 'lucide-react';

// 模拟外部传入的变量和函数，确保代码可运行
const mechaHudScale = 1;
const mergedMecha = { boostLabel: 'BOOST SYSTEM' };
const maxBoost = 1000;
const boostColor = 'bg-cyan-400';
const toPercent = (val, max) => Math.max(0, Math.min(100, (val / max) * 100));

export default function App() {
  const [boost, setBoost] = useState(850);

  // 1. 定义增益数据状态
  // 包含了你列出的 7 种增益状态
  const [buffs, setBuffs] = useState([
    { id: 1, type: 'attack', name: '攻击', time: 15, icon: Sword, color: 'rose' },
    { id: 2, type: 'defense', name: '防御', time: 8, icon: Shield, color: 'blue' },
    { id: 3, type: 'cooling', name: '冷却', time: 22, icon: Snowflake, color: 'cyan' },
    { id: 4, type: 'power', name: '功率', time: 5, icon: Zap, color: 'amber' },
    { id: 5, type: 'regen', name: '回血', time: 12, icon: HeartPlus, color: 'emerald' },
    { id: 6, type: 'ammo', name: '弹量', time: 30, icon: Crosshair, color: 'violet' },
    { id: 7, type: 'terrain', name: '跨越', time: 0, icon: Mountain, color: 'stone' }, // 预备，时间为0时不显示
  ]);

  // 模拟增益时间倒计时
  useEffect(() => {
    const timer = setInterval(() => {
      setBuffs(prev => 
        prev.map(buff => ({
          ...buff,
          time: Math.max(0, buff.time - 1)
        }))
      );
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // 颜色映射辅助函数 (Tailwind需要完整类名)
  const getColorClasses = (color) => {
    const map = {
      rose: { border: 'border-rose-500/60', text: 'text-rose-400', glow: 'drop-shadow-[0_0_3px_rgba(244,63,94,0.8)]' },
      blue: { border: 'border-blue-500/60', text: 'text-blue-400', glow: 'drop-shadow-[0_0_3px_rgba(59,130,246,0.8)]' },
      cyan: { border: 'border-cyan-500/60', text: 'text-cyan-400', glow: 'drop-shadow-[0_0_3px_rgba(34,211,238,0.8)]' },
      amber: { border: 'border-amber-500/60', text: 'text-amber-400', glow: 'drop-shadow-[0_0_3px_rgba(251,191,36,0.8)]' },
      emerald: { border: 'border-emerald-500/60', text: 'text-emerald-400', glow: 'drop-shadow-[0_0_3px_rgba(16,185,129,0.8)]' },
      violet: { border: 'border-violet-500/60', text: 'text-violet-400', glow: 'drop-shadow-[0_0_3px_rgba(139,92,246,0.8)]' },
      stone: { border: 'border-stone-500/60', text: 'text-stone-400', glow: 'drop-shadow-[0_0_3px_rgba(168,162,158,0.8)]' },
    };
    return map[color] || map.cyan;
  };

  // 过滤出当前激活的增益（时间大于0）
  const activeBuffs = buffs.filter(b => b.time > 0);

  return (
    <div className="w-full h-screen bg-neutral-950 flex items-center justify-center relative overflow-hidden bg-[url('https://www.transparenttextures.com/patterns/cubes.png')]">
      
      {/* 核心 UI 部分 开始 */}
      <div className="absolute bottom-12 left-1/2 -translate-x-1/2 z-10 drop-shadow-lg">
        <div
          className="flex flex-col items-center w-[400px]"
          style={{ transform: `scale(${mechaHudScale})`, transformOrigin: 'bottom center' }}
        >
          <div className="w-full relative">
            
            {/* ====== 新增：增益状态显示区 (Buffs) - 紧凑版 ====== */}
            <div className="absolute bottom-full mb-5 w-full flex justify-center flex-wrap gap-1.5 px-2">
              {activeBuffs.map((buff) => {
                const colors = getColorClasses(buff.color);
                return (
                  <div 
                    key={buff.id} 
                    className={`h-[22px] px-1.5 flex items-center justify-center bg-slate-900/80 border ${colors.border} skew-x-[-15deg] backdrop-blur-md shadow-sm ${colors.glow} transition-all duration-300`}
                  >
                    {/* 内部容器反向倾斜，保持内容方正且紧密排列 */}
                    <div className="flex items-center gap-1 skew-x-[15deg]">
                      <buff.icon size={12} className={`${colors.text}`} />
                      <span className={`text-[10px] font-bold ${colors.text} leading-none pt-[1px] ${colors.glow} drop-shadow-[0_1px_1px_rgba(0,0,0,1)]`}>
                        {buff.time}s
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
            {/* ====== 新增结束 ====== */}

            {/* 原有：标签和数值 */}
            <div className="absolute -top-5 w-full flex justify-between px-2 text-xs font-bold text-cyan-300 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">
              <span className="flex items-center gap-1 drop-shadow-[0_0_2px_rgba(34,211,238,0.8)]">
                <ChevronsRight size={14}/> {mergedMecha.boostLabel}
              </span>
              <span className="text-white drop-shadow-[0_0_2px_#fff]">
                {Math.round(boost)} <span className="text-cyan-500/90">/ {maxBoost}</span>
              </span>
            </div>

            {/* 原有：进度条 */}
            <div className="w-full h-4 filter drop-shadow-[0_2px_8px_rgba(0,0,0,0.6)] mt-1">
              <div className="w-full h-full bg-slate-900/60 border border-cyan-500/60 p-0.5 skew-x-[-15deg] backdrop-blur-md">
                <div
                  className={`h-full ${boostColor} transition-all duration-100 ease-out`}
                  style={{ width: `${toPercent(boost, maxBoost)}%` }}
                />
              </div>
            </div>

          </div>
        </div>
      </div>
      {/* 核心 UI 部分 结束 */}

    </div>
  );
}