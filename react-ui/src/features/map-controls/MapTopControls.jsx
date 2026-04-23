import { memo, useEffect, useRef, useState } from 'react';
import { resolveControlsState } from '../../state';
import { ROLE_OPTIONS } from './constants';
import { ResourceHeader, AmmoPurchasePanel, DartControlPanel, SentryCommandPanel, AirSupportPanel, SentryHint } from './SupportPanels';
import { RoleTab, ToastBanner } from './MapControlPrimitives';
import RoleSettingsPanel from './RoleSettingsPanel';

function useToast(timeoutMs) {
  const [message, setMessage] = useState('');
  const timerRef = useRef(null);

  useEffect(() => () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }
  }, []);

  const showToast = (nextMessage) => {
    setMessage(nextMessage);
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }
    timerRef.current = setTimeout(() => {
      setMessage('');
      timerRef.current = null;
    }, timeoutMs);
  };

  return { message, showToast };
}

function MapTopControlsPanel({ eco, controlsConfig, remoteHealCost }) {
  const toastDurationMs = Number(controlsConfig.toastDurationMs) > 0 ? Number(controlsConfig.toastDurationMs) : 2500;
  const [activeRole, setActiveRole] = useState(() => controlsConfig.activeRole ?? 'infantry');
  const [isLocked, setIsLocked] = useState(() => !!controlsConfig.isLocked);
  const [infantrySettings, setInfantrySettings] = useState(() => controlsConfig.infantrySettings);
  const [heroSettings, setHeroSettings] = useState(() => controlsConfig.heroSettings);
  const [sentrySettings, setSentrySettings] = useState(() => controlsConfig.sentrySettings);
  const [dartTarget, setDartTarget] = useState(() => controlsConfig.dartTarget ?? '1');
  const [gateOpen, setGateOpen] = useState(() => !!controlsConfig.gateOpen);
  const { message, showToast } = useToast(toastDurationMs);

  const handleAction = (actionName) => {
    showToast(`已执行: ${actionName}`);
  };

  const handleBuyAmmo = (title, qty, cost) => {
    showToast(`已购买 ${title} ${qty}发 (花费 ${cost} 金币)`);
  };

  return (
    <div className="pointer-events-none absolute left-3 right-3 top-3 z-40">
      <ToastBanner message={message} />

      <div className="pointer-events-auto rounded-xl border border-slate-700 bg-slate-950/92 p-3">
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-700 pb-2">
          <div className="flex flex-wrap items-center gap-1.5">
            {ROLE_OPTIONS.map((option) => (
              <RoleTab
                key={option.role}
                role={option.role}
                label={option.label}
                icon={option.icon}
                activeRole={activeRole}
                onSelect={(role) => {
                  setActiveRole(role);
                  setIsLocked(false);
                }}
              />
            ))}
          </div>
          <ResourceHeader eco={eco} />
        </div>

        <div className="mt-3 flex gap-3 overflow-x-auto pb-1">
          <RoleSettingsPanel
            activeRole={activeRole}
            isLocked={isLocked}
            onToggleLocked={() => setIsLocked((prev) => !prev)}
            infantrySettings={infantrySettings}
            setInfantrySettings={setInfantrySettings}
            heroSettings={heroSettings}
            setHeroSettings={setHeroSettings}
            sentrySettings={sentrySettings}
            setSentrySettings={setSentrySettings}
          />

          <AmmoPurchasePanel
            activeRole={activeRole}
            ammoStore={controlsConfig.ammoStore}
            eco={eco}
            onBuyAmmo={handleBuyAmmo}
            remoteHealCost={remoteHealCost}
            onRemoteHeal={() => {
              if (eco >= remoteHealCost) {
                handleAction('远程买血');
              } else {
                showToast('金币不足，无法买血');
              }
            }}
          />

          <DartControlPanel
            activeRole={activeRole}
            dartTarget={dartTarget}
            setDartTarget={setDartTarget}
            gateOpen={gateOpen}
            setGateOpen={setGateOpen}
            onFire={() => handleAction(`发射飞镖(目标:${dartTarget})`)}
          />

          <SentryCommandPanel activeRole={activeRole} onAction={handleAction} />
          <AirSupportPanel activeRole={activeRole} onAction={handleAction} />
        </div>

        <SentryHint activeRole={activeRole} />
      </div>
    </div>
  );
}

function MapTopControls({ eco, controls }) {
  const controlsConfig = resolveControlsState(controls);
  const remoteHealCost = Number(controlsConfig.costs?.remoteHeal) > 0
    ? Number(controlsConfig.costs.remoteHeal)
    : 200;
  const resetKey = JSON.stringify({
    activeRole: controlsConfig.activeRole,
    isLocked: controlsConfig.isLocked,
    infantrySettings: controlsConfig.infantrySettings,
    heroSettings: controlsConfig.heroSettings,
    sentrySettings: controlsConfig.sentrySettings,
    dartTarget: controlsConfig.dartTarget,
    gateOpen: controlsConfig.gateOpen,
  });

  return (
    <MapTopControlsPanel
      key={resetKey}
      eco={eco}
      controlsConfig={controlsConfig}
      remoteHealCost={remoteHealCost}
    />
  );
}

export default memo(MapTopControls);
