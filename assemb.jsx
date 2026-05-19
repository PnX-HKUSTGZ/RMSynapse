import React, { useState, useEffect } from 'react';
import { 
  CheckCircle2, XCircle, AlertTriangle, Play, Check, X, 
  Settings2, Activity, Cpu, RotateCcw, ArrowRight, ShieldAlert,
  TerminalSquare
} from 'lucide-react';

const EVENT_15_RESULTS = {
  "0": { text: "装配成功", type: "success" },
  "1": { text: "装配失败：能量单元被拔出", type: "error" },
  "2": { text: "装配失败：超时", type: "error" },
  "3": { text: "装配失败：离开装配区过久", type: "error" },
  "4": { text: "装配失败：工程战亡", type: "error" },
  "5": { text: "装配失败：四级难度未满足完成协作时限", type: "error" },
  "6": { text: "装配取消：主动退出", type: "cancel" },
  "7": { text: "装配失败：未检测到能量单元", type: "error" },
  "8": { text: "装配失败：缓冲期到期强制结束", type: "error" }
};

const BASIC_STATES = {
  1: "初始位置",
  2: "运动中",
  3: "已到达对应位姿"
};

export default function EngineeringAssemblyUI() {
  // --- Server Mock State (TechCoreMotionStateSync) ---
  const [serverState, setServerState] = useState({
    maximum_difficulty_level: 3, // Default to 3 for testing
    basic_state: 1, // 1: Initial, 2: Moving, 3: Reached
    putin_state: 0,
    move_state: 0,
    rotate_state: 0,
    enemy_core_status: 0,
  });

  // --- Local UI State ---
  const [selectedLevel, setSelectedLevel] = useState(1); // Pending selection
  const [activeLevel, setActiveLevel] = useState(null); // Actually started
  const [phase, setPhase] = useState("idle"); // "idle" | "started" | "waiting_result" | "finished" | "cancelled"
  const [resultMsg, setResultMsg] = useState(null);
  const [warningMsg, setWarningMsg] = useState(null);
  const [logs, setLogs] = useState([]);

  const addLog = (msg) => {
    setLogs(prev => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev].slice(0, 5));
  };

  const checkCanConfirm = () => {
    if (phase !== "started") return false;
    if (serverState.basic_state !== 3) return false;

    if (activeLevel === 1) return serverState.putin_state === 1;
    if (activeLevel === 2) return serverState.putin_state === 1 && serverState.move_state === 1;
    if (activeLevel === 3) return serverState.putin_state === 1 && serverState.move_state === 1 && serverState.rotate_state === 1;
    
    return false;
  };

  const handleStart = () => {
    setActiveLevel(selectedLevel);
    setPhase("started");
    setResultMsg(null);
    setWarningMsg(null);
    addLog(`发送指令: Start Assembly (Level ${selectedLevel})`);
  };

  const handleConfirm = () => {
    setPhase("waiting_result");
    addLog(`发送指令: Confirm Assembly (Level ${activeLevel})`);
  };

  const handleCancel = () => {
    setPhase("cancelled");
    setResultMsg({ text: "已主动取消装配", type: "cancel" });
    addLog(`发送指令: Cancel Assembly (Level ${activeLevel})`);
  };

  const updateServerState = (key, value) => {
    setServerState(prev => ({ ...prev, [key]: Number(value) }));
  };

  const triggerEvent14 = () => {
    setWarningMsg("对方请求四级装配，当前装配进入强制退出缓冲期！");
    addLog("接收事件: Event 14 (Force Exit Warning)");
    setTimeout(() => setWarningMsg(null), 8000); // Auto clear after 8s
  };

  const triggerEvent15 = (param) => {
    const result = EVENT_15_RESULTS[param];
    setResultMsg(result);
    setPhase(result.type === "success" ? "finished" : "cancelled");
    addLog(`接收事件: Event 15 (${result.text})`);
  };

  const resetAll = () => {
    setPhase("idle");
    setActiveLevel(null);
    setResultMsg(null);
    setWarningMsg(null);
    setServerState({
      maximum_difficulty_level: 3,
      basic_state: 1, putin_state: 0, move_state: 0, rotate_state: 0, enemy_core_status: 0
    });
    addLog("系统重置");
  };

  const canConfirm = checkCanConfirm();

  const getStepStatus = (isActive, name) => {
    if (isActive) return <span className="flex items-center text-emerald-400 font-bold text-sm"><CheckCircle2 className="w-4 h-4 mr-1.5" /> {name}：已完成</span>;
    return <span className="flex items-center text-slate-400 text-sm"><RotateCcw className="w-4 h-4 mr-1.5 opacity-50" /> {name}：未完成</span>;
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-200 p-4 font-sans flex flex-col lg:flex-row gap-6 selection:bg-cyan-900">
      
      {/* Left Main UI Area */}
      <div className="flex-1 flex flex-col gap-4">
        
        {/* Top Status Bar */}
        <div className="bg-slate-900 border border-slate-700/50 rounded-xl p-4 flex flex-wrap items-center justify-between shadow-lg shadow-black/50">
          <div className="flex items-center gap-4">
            <div className="bg-cyan-950/50 border border-cyan-800 text-cyan-400 px-4 py-2 rounded-lg flex items-center font-bold tracking-wider">
              <Cpu className="w-5 h-5 mr-2" /> ENGINEER / ID 2
            </div>
            <div className="flex items-center gap-2">
              <span className="text-slate-400 text-sm">系统状态</span>
              {phase === "idle" && <span className="text-slate-300 font-semibold bg-slate-800 px-3 py-1 rounded-md">待机中</span>}
              {phase === "started" && <span className="text-amber-400 font-semibold bg-amber-950/30 border border-amber-900/50 px-3 py-1 rounded-md flex items-center"><Activity className="w-4 h-4 mr-1 animate-pulse" /> 装配中</span>}
              {phase === "waiting_result" && <span className="text-cyan-400 font-semibold bg-cyan-950/30 px-3 py-1 rounded-md animate-pulse">等待结算...</span>}
              {(phase === "finished" || phase === "cancelled") && <span className="text-slate-400 font-semibold bg-slate-800 px-3 py-1 rounded-md">已结束</span>}
            </div>
          </div>
          <div className="flex items-center gap-6 mt-4 md:mt-0">
             <div className="text-sm">
                <span className="text-slate-400">最高可用等级: </span>
                <span className="text-cyan-400 font-bold text-lg ml-1">Lv.{serverState.maximum_difficulty_level}</span>
             </div>
             <div className="text-sm bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-700 flex items-center gap-2">
                <span className="text-slate-400">科技核心状态:</span>
                <span className={`font-bold ${serverState.basic_state === 3 ? 'text-emerald-400' : serverState.basic_state === 2 ? 'text-amber-400' : 'text-slate-300'}`}>
                  {BASIC_STATES[serverState.basic_state]}
                </span>
             </div>
          </div>
        </div>

        {/* Global Warning Banner */}
        {warningMsg && (
          <div className="bg-rose-950/80 border border-rose-500/50 text-rose-200 p-4 rounded-xl flex items-center animate-pulse shadow-lg shadow-rose-900/20">
            <ShieldAlert className="w-6 h-6 mr-3 text-rose-500" />
            <span className="font-bold text-lg">{warningMsg}</span>
          </div>
        )}

        {/* Central Control Area */}
        <div className="bg-slate-900 border border-slate-700/50 rounded-xl p-6 shadow-lg shadow-black/50">
          <h2 className="text-lg font-bold text-slate-300 mb-4 flex items-center"><Settings2 className="w-5 h-5 mr-2" /> 装配控制台</h2>
          
          <div className="grid grid-cols-4 gap-3 mb-5">
            {[1, 2, 3, 4].map(level => {
              const isDisabled = level > serverState.maximum_difficulty_level || level === 4 || phase !== "idle";
              const isSelected = selectedLevel === level;
              return (
                <button
                  key={level}
                  disabled={isDisabled}
                  onClick={() => setSelectedLevel(level)}
                  className={`
                    py-3 rounded-xl border-2 font-bold text-lg transition-all duration-200
                    ${isDisabled ? 'opacity-30 cursor-not-allowed border-slate-800 bg-slate-900/50' : ''}
                    ${!isDisabled && isSelected ? 'border-cyan-500 bg-cyan-900/20 text-cyan-300 shadow-[0_0_15px_rgba(6,182,212,0.3)]' : ''}
                    ${!isDisabled && !isSelected ? 'border-slate-700 bg-slate-800 hover:border-slate-500 hover:bg-slate-700' : ''}
                  `}
                >
                  Lv.{level}
                  {level === 4 && <div className="text-xs font-normal text-slate-500 mt-1">暂不支持</div>}
                </button>
              )
            })}
          </div>

          <button 
            onClick={handleStart}
            disabled={phase !== "idle"}
            className={`w-full py-3.5 rounded-xl font-bold text-lg flex items-center justify-center transition-all ${phase === 'idle' ? 'bg-cyan-600 hover:bg-cyan-500 text-white shadow-lg shadow-cyan-900/50' : 'bg-slate-800 text-slate-500 cursor-not-allowed'}`}
          >
            <Play className="w-6 h-6 mr-2" /> 开始装配
          </button>
        </div>

        {/* Bottom Info Panel */}
        {activeLevel && (
          <div className="bg-slate-900 border border-slate-700/50 rounded-xl p-4 shadow-lg shadow-black/50 flex flex-col gap-4">
             {/* Header */}
             <div className="flex justify-between items-center pb-3 border-b border-slate-800">
                <div>
                  <div className="text-xs text-slate-400 mb-1">当前执行任务</div>
                  <div className="text-xl font-black text-cyan-400 tracking-wider">装配等级 Lv.{activeLevel}</div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-slate-400 mb-1">核心位姿状态</div>
                  <div className={`text-lg font-bold ${serverState.basic_state === 3 ? 'text-emerald-400' : 'text-amber-400'}`}>
                    {BASIC_STATES[serverState.basic_state]}
                  </div>
                </div>
             </div>

             {/* Steps Monitor (Horizontal layout for compactness) */}
             <div>
                <h3 className="text-slate-400 text-xs mb-2">装配步骤监测</h3>
                <div className="flex flex-wrap items-center gap-3 bg-slate-950/50 p-3 rounded-lg border border-slate-800/50">
                  {getStepStatus(serverState.putin_state === 1, "放入单元")}
                  
                  {activeLevel >= 2 && <ArrowRight className="w-4 h-4 text-slate-700" />}
                  {activeLevel >= 2 && getStepStatus(serverState.move_state === 1, "平移对齐")}
                  
                  {activeLevel >= 3 && <ArrowRight className="w-4 h-4 text-slate-700" />}
                  {activeLevel >= 3 && getStepStatus(serverState.rotate_state === 1, "旋转锁定")}
                </div>
             </div>

             {/* Action Buttons inside Task Card */}
             <div className="flex gap-3 mt-1">
                <button 
                  onClick={handleConfirm}
                  disabled={!canConfirm}
                  className={`flex-1 py-3 rounded-lg font-bold text-base flex items-center justify-center transition-all ${canConfirm ? 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-900/50' : 'bg-slate-800 text-slate-500 cursor-not-allowed'}`}
                >
                  <Check className="w-5 h-5 mr-2" /> 确认装配
                </button>
                <button 
                  onClick={handleCancel}
                  disabled={phase === "idle" || phase === "cancelled" || phase === "finished"}
                  className={`flex-1 py-3 rounded-lg font-bold text-base flex items-center justify-center transition-all ${phase !== 'idle' && phase !== 'cancelled' && phase !== 'finished' ? 'bg-rose-900/50 hover:bg-rose-800 border border-rose-800 text-rose-200' : 'bg-slate-800 text-slate-500 border border-slate-800 cursor-not-allowed'}`}
                >
                  <X className="w-5 h-5 mr-2" /> 取消装配
                </button>
             </div>

             {/* Result Banner */}
             <div>
                {resultMsg ? (
                  <div className={`p-3 rounded-lg flex items-center text-base font-bold border ${resultMsg.type === 'success' ? 'bg-emerald-950/40 border-emerald-500/50 text-emerald-400' : resultMsg.type === 'error' ? 'bg-rose-950/40 border-rose-500/50 text-rose-400' : 'bg-slate-800 border-slate-600 text-slate-300'}`}>
                    {resultMsg.type === 'success' ? <CheckCircle2 className="w-5 h-5 mr-3" /> : resultMsg.type === 'error' ? <XCircle className="w-5 h-5 mr-3" /> : <AlertTriangle className="w-5 h-5 mr-3" />}
                    {resultMsg.text}
                  </div>
                ) : (
                  <div className="p-3 rounded-lg flex items-center text-sm font-bold border bg-slate-800/50 border-slate-700 text-slate-400">
                    <Activity className="w-5 h-5 mr-3 animate-spin-slow opacity-50" />
                    {phase === "waiting_result" ? "已发送确认，等待裁判系统判定..." : canConfirm ? "步骤已完成，请点击上方 [确认装配]" : "等待所有前置步骤完成..."}
                  </div>
                )}
             </div>
          </div>
        )}
      </div>

      {/* Right Simulation Panel */}
      <div className="w-full lg:w-96 bg-black/40 border-l-4 border-l-purple-600 rounded-r-xl p-4 flex flex-col gap-4 font-mono text-sm h-full max-h-screen overflow-y-auto">
        <div className="flex items-center justify-between mb-2">
          <h2 className="text-purple-400 font-bold text-lg flex items-center"><TerminalSquare className="w-5 h-5 mr-2" /> SIMULATION DBG</h2>
          <button onClick={resetAll} className="bg-slate-800 hover:bg-slate-700 text-slate-300 px-3 py-1 rounded text-xs border border-slate-600">RESET</button>
        </div>

        <div className="space-y-4">
          {/* Max Difficulty */}
          <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
            <label className="block text-slate-400 mb-2">Maximum Difficulty (1-4)</label>
            <select 
              className="w-full bg-slate-950 text-purple-300 border border-slate-700 rounded p-1"
              value={serverState.maximum_difficulty_level}
              onChange={(e) => updateServerState('maximum_difficulty_level', e.target.value)}
            >
              {[1, 2, 3, 4].map(v => <option key={v} value={v}>Level {v}</option>)}
            </select>
          </div>

          {/* Basic State */}
          <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
            <label className="block text-slate-400 mb-2">Basic State</label>
            <div className="flex flex-col gap-2">
              {[1, 2, 3].map(val => (
                <label key={val} className="flex items-center cursor-pointer">
                  <input type="radio" name="basic_state" value={val} checked={serverState.basic_state === val} onChange={(e) => updateServerState('basic_state', e.target.value)} className="mr-2 accent-purple-500" />
                  <span className={serverState.basic_state === val ? 'text-purple-300' : 'text-slate-500'}>{val} - {BASIC_STATES[val]}</span>
                </label>
              ))}
            </div>
          </div>

          {/* Operation States Toggles */}
          <div className="bg-slate-900 p-3 rounded-lg border border-slate-800 grid grid-cols-2 gap-2">
            {[
              { key: 'putin_state', label: '放入状态 (putin)' },
              { key: 'move_state', label: '平移状态 (move)' },
              { key: 'rotate_state', label: '旋转状态 (rotate)' }
            ].map(item => (
              <button
                key={item.key}
                onClick={() => updateServerState(item.key, serverState[item.key] === 0 ? 1 : 0)}
                className={`col-span-2 text-left px-3 py-2 rounded flex justify-between border ${serverState[item.key] === 1 ? 'bg-purple-900/30 border-purple-500/50 text-purple-300' : 'bg-slate-950 border-slate-800 text-slate-500'}`}
              >
                <span>{item.label}</span>
                <span>{serverState[item.key]}</span>
              </button>
            ))}
          </div>

          {/* Events Dispatch */}
          <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
            <label className="block text-slate-400 mb-2">Trigger Events</label>
            <button onClick={triggerEvent14} className="w-full mb-2 bg-rose-950/50 hover:bg-rose-900 border border-rose-800 text-rose-300 py-1.5 rounded text-xs">
              Trigger Event 14 (LV4 Warning)
            </button>
            
            <div className="grid grid-cols-2 gap-1 mt-3">
              <div className="col-span-2 text-xs text-slate-500 mb-1">Event 15 (Results)</div>
              {Object.entries(EVENT_15_RESULTS).map(([code, result]) => (
                <button
                  key={code}
                  onClick={() => triggerEvent15(code)}
                  className={`text-xs p-1.5 rounded border truncate ${code === '0' ? 'bg-emerald-950/30 border-emerald-800 text-emerald-400' : 'bg-slate-950 border-slate-800 text-slate-400 hover:bg-slate-800'}`}
                  title={result.text}
                >
                  [{code}] {result.text.split('：')[0]}
                </button>
              ))}
            </div>
          </div>

          {/* Action Logs */}
          <div className="bg-black/50 p-3 rounded-lg border border-slate-800/50 flex-1 min-h-[120px]">
             <div className="text-xs text-slate-500 mb-2 border-b border-slate-800 pb-1">COMMAND LOGS</div>
             <div className="space-y-1 text-xs text-slate-400 font-mono">
               {logs.length === 0 ? <span className="opacity-50">No commands issued.</span> : logs.map((l, i) => <div key={i} className={i===0?'text-purple-300':''}>{l}</div>)}
             </div>
          </div>
        </div>
      </div>
    </div>
  );
}