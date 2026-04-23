import {
  Activity,
  Lock,
  Shield,
  Swords,
  Target,
  Unlock,
  Zap,
} from 'lucide-react';
import { SENTRY_MODE_OPTIONS } from './constants';
import { SectionPanel, SelectionButton } from './MapControlPrimitives';

function ModeSelector({ title, leftOption, rightOption, value, disabled, onChange }) {
  return (
    <div>
      <div className="mb-1 text-xs font-semibold text-slate-400">{title}</div>
      <div className="flex gap-2">
        <SelectionButton active={value === leftOption.value} disabled={disabled} onClick={() => onChange(leftOption.value)}>
          <leftOption.icon className="mb-0.5 mr-1 inline h-3.5 w-3.5" />
          {leftOption.label}
        </SelectionButton>
        <SelectionButton active={value === rightOption.value} disabled={disabled} onClick={() => onChange(rightOption.value)}>
          <rightOption.icon className="mb-0.5 mr-1 inline h-3.5 w-3.5" />
          {rightOption.label}
        </SelectionButton>
      </div>
    </div>
  );
}

export default function RoleSettingsPanel({
  activeRole,
  isLocked,
  onToggleLocked,
  infantrySettings,
  setInfantrySettings,
  heroSettings,
  setHeroSettings,
  sentrySettings,
  setSentrySettings,
}) {
  return (
    <SectionPanel title="性能体系与控制方式" icon={Zap} accentClass="bg-cyan-500" minWidth="min-w-[420px]">
      <div className="mb-2 flex justify-end">
        <button
          onClick={onToggleLocked}
          className={`flex items-center gap-1 rounded-md border px-2.5 py-1.5 text-xs font-bold transition-colors ${
            isLocked
              ? 'border-red-500/60 bg-red-500/15 text-red-300 hover:bg-red-500/25'
              : 'border-cyan-500/60 bg-cyan-500/20 text-cyan-200 hover:bg-cyan-500/30'
          }`}
        >
          {isLocked ? <Lock size={13} /> : <Unlock size={13} />}
          <span>{isLocked ? '已锁死' : '确认锁死'}</span>
        </button>
      </div>

      {activeRole === 'infantry' && (
        <div className="space-y-3">
          <ModeSelector
            title="底盘性能 (Chassis)"
            leftOption={{ value: 'hp', label: '血量优先', icon: Shield }}
            rightOption={{ value: 'power', label: '功率优先', icon: Zap }}
            value={infantrySettings.chassis}
            disabled={isLocked}
            onChange={(value) => setInfantrySettings((prev) => ({ ...prev, chassis: value }))}
          />
          <ModeSelector
            title="发射性能 (Firing)"
            leftOption={{ value: 'burst', label: '爆发优先', icon: Zap }}
            rightOption={{ value: 'cooldown', label: '冷却优先', icon: Activity }}
            value={infantrySettings.firing}
            disabled={isLocked}
            onChange={(value) => setInfantrySettings((prev) => ({ ...prev, firing: value }))}
          />
        </div>
      )}

      {activeRole === 'hero' && (
        <div className="space-y-3">
          <ModeSelector
            title="底盘性能 (Chassis)"
            leftOption={{ value: 'hp', label: '血量优先', icon: Shield }}
            rightOption={{ value: 'power', label: '功率优先', icon: Zap }}
            value={heroSettings.chassis}
            disabled={isLocked}
            onChange={(value) => setHeroSettings((prev) => ({ ...prev, chassis: value }))}
          />
          <ModeSelector
            title="发射性能 (Firing)"
            leftOption={{ value: 'melee', label: '近战优先', icon: Swords }}
            rightOption={{ value: 'ranged', label: '远程优先', icon: Target }}
            value={heroSettings.firing}
            disabled={isLocked}
            onChange={(value) => setHeroSettings((prev) => ({ ...prev, firing: value }))}
          />
        </div>
      )}

      {activeRole === 'sentry' && (
        <div>
          <div className="mb-1 text-xs font-semibold text-slate-400">控制方式 (Control Mode)</div>
          <div className="flex flex-col gap-2">
            {SENTRY_MODE_OPTIONS.map((option) => (
              <SelectionButton
                key={option.value}
                active={sentrySettings.mode === option.value}
                disabled={isLocked}
                onClick={() => setSentrySettings({ mode: option.value })}
              >
                <option.icon className="mb-0.5 mr-1 inline h-3.5 w-3.5" />
                {option.label}
              </SelectionButton>
            ))}
          </div>
        </div>
      )}
    </SectionPanel>
  );
}
