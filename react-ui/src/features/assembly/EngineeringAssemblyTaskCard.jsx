import {
  Activity,
  ArrowRight,
  Check,
  CheckCircle2,
  RotateCcw,
  Shield,
  X,
} from 'lucide-react';

const BASIC_STATES = {
  1: '初始位置',
  2: '运动中',
  3: '已到达对应位姿',
};

function toInt(value, fallback = 0) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(0, Math.trunc(numeric)) : fallback;
}

function getTechCoreNumber(techCore, camelKey, snakeKey, fallback = 0) {
  return toInt(techCore?.[camelKey] ?? techCore?.[snakeKey], fallback);
}

function getStepState(techCore) {
  return {
    basic: getTechCoreNumber(techCore, 'basicState', 'basic_state', getTechCoreNumber(techCore, 'status', 'status')),
    putin: getTechCoreNumber(techCore, 'putinState', 'putin_state'),
    move: getTechCoreNumber(techCore, 'moveState', 'move_state'),
    rotate: getTechCoreNumber(techCore, 'rotateState', 'rotate_state'),
  };
}

function canConfirm(activeLevel, techCore) {
  const level = toInt(activeLevel);
  const steps = getStepState(techCore);
  if (level <= 0 || steps.basic !== 3 || steps.putin !== 1) return false;
  if (level >= 2 && steps.move !== 1) return false;
  if (level >= 3 && steps.rotate !== 1) return false;
  return true;
}

function FieldValue({ label, value }) {
  return (
    <div className="rounded border border-slate-700 bg-slate-950/60 px-2 py-1">
      <div className="text-[9px] font-black uppercase tracking-wider text-slate-500">{label}</div>
      <div className="mt-0.5 font-mono text-[11px] font-bold text-cyan-200">{value}</div>
    </div>
  );
}

function Step({ done, label }) {
  return (
    <span className={`flex items-center gap-1 text-[11px] font-bold ${done ? 'text-emerald-300' : 'text-slate-500'}`}>
      {done ? <CheckCircle2 size={13} /> : <RotateCcw size={13} className="opacity-60" />}
      {label}
    </span>
  );
}

function IconButton({ disabled, onClick, icon: Icon, children }) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={`flex min-h-8 items-center justify-center gap-1 rounded border px-2 text-[11px] font-black transition-colors ${
        disabled
          ? 'cursor-not-allowed border-slate-800 bg-slate-950/70 text-slate-600'
          : 'border-cyan-400/55 bg-cyan-500/16 text-cyan-100 hover:bg-cyan-500/28'
      }`}
    >
      {Icon && <Icon size={13} />}
      {children}
    </button>
  );
}

export default function EngineeringAssemblyTaskCard({
  active = false,
  activeLevel,
  techCore,
  commandStatus,
  assembly,
  onConfirm,
  onCancel,
}) {
  const steps = getStepState(techCore);
  const currentLevel = toInt(activeLevel);
  const commandPending = active && commandStatus?.operationType === 'assembly' && commandStatus?.state === 'pending';
  const confirmReady = active && canConfirm(currentLevel, techCore);
  const enemyStatus = getTechCoreNumber(techCore, 'enemyCoreStatus', 'enemy_core_status');
  const remainAll = getTechCoreNumber(techCore, 'remainTimeAll', 'remain_time_all');
  const remainStep = getTechCoreNumber(techCore, 'remainTimeStep', 'remain_time_step');

  return (
    <div
      className={`pointer-events-auto w-[430px] rounded-lg border border-slate-700/70 bg-slate-950/88 p-3 font-mono text-white shadow-[0_0_24px_rgba(0,0,0,0.45)] backdrop-blur transition-opacity duration-300 ${
        active ? 'opacity-100' : 'opacity-40'
      }`}
    >
      <div className="flex items-center justify-between gap-3 border-b border-slate-800 pb-2">
        <div>
          <div className="text-[10px] font-black uppercase tracking-wider text-slate-500">当前执行任务</div>
          <div className={`mt-0.5 text-sm font-black tracking-wider ${active ? 'text-cyan-200' : 'text-slate-400'}`}>
            {active ? `装配等级 Lv.${currentLevel}` : '未开始装配'}
          </div>
        </div>
        <div className="text-right">
          <div className="text-[10px] font-black uppercase tracking-wider text-slate-500">核心位姿</div>
          <div className={`mt-0.5 text-xs font-black ${steps.basic === 3 ? 'text-emerald-300' : steps.basic === 2 ? 'text-amber-300' : 'text-slate-300'}`}>
            {BASIC_STATES[steps.basic] ?? `状态 ${steps.basic}`}
          </div>
        </div>
      </div>

      {assembly?.warning && active && (
        <div className="mt-2 flex items-center gap-2 rounded border border-rose-500/45 bg-rose-950/35 px-2 py-1.5 text-[11px] font-bold text-rose-200">
          <Shield size={13} className="shrink-0 text-rose-300" />
          <span>{assembly.warning}</span>
        </div>
      )}

      <div className="mt-3 rounded border border-slate-800 bg-slate-950/55 p-2">
        <div className="mb-2 text-[10px] font-black uppercase tracking-wider text-slate-500">装配步骤监测</div>
        <div className="flex flex-wrap items-center gap-2">
          <Step done={active && steps.putin === 1} label="放入单元" />
          {currentLevel >= 2 && <ArrowRight size={12} className="text-slate-700" />}
          {currentLevel >= 2 && <Step done={active && steps.move === 1} label="平移对齐" />}
          {currentLevel >= 3 && <ArrowRight size={12} className="text-slate-700" />}
          {currentLevel >= 3 && <Step done={active && steps.rotate === 1} label="旋转锁定" />}
        </div>
      </div>

      {(enemyStatus > 0 || remainAll > 0 || remainStep > 0) && (
        <div className="mt-2 grid grid-cols-3 gap-2">
          <FieldValue label="ENEMY" value={enemyStatus} />
          <FieldValue label="TOTAL" value={`${remainAll}s`} />
          <FieldValue label="STEP" value={`${remainStep}s`} />
        </div>
      )}

      <div className="mt-3 grid grid-cols-2 gap-2">
        <IconButton disabled={!confirmReady} onClick={onConfirm} icon={Check}>确认装配</IconButton>
        <IconButton disabled={!active} onClick={onCancel} icon={X}>取消装配</IconButton>
      </div>

      <div className="mt-2">
        <div className="flex items-center gap-2 rounded border border-slate-700 bg-slate-950/45 px-2 py-2 text-xs font-bold text-slate-400">
          <Activity size={14} className={commandPending ? 'animate-spin' : ''} />
          {active
            ? commandPending
              ? '命令已发送，等待 MQTT 状态回执...'
              : confirmReady
                ? '步骤已完成，请确认装配'
                : '等待所有前置步骤完成'
            : '未开始装配'}
        </div>
      </div>
    </div>
  );
}
