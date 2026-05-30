import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { emitGodotOperation } from './bridge/godot';
import DesignCanvas from './components/DesignCanvas';
import CenterCombatHUD from './features/center-hud/CenterCombatHUD';
import CommandPanel from './features/command-panel/CommandPanel';
import MessageCenter from './features/message-center/MessageCenter';
import MechaHUD from './features/mecha-hud/MechaHUD';
import MiniMapHUD from './features/mini-map/MiniMapHUD';
import EscSettingsMenu from './features/settings/EscSettingsMenu';
import TopCoreLayout from './features/top-core/TopCoreLayout';
import {
  DEFAULT_RESOURCE_QUANTITIES,
  buildResourceActionState,
} from './features/command-panel/resourceActions';
import { useHudState } from './hooks/useHudState';
import {
  DEFAULT_UI_STATE,
  buildRobotHpById,
  resolveMiniMapState,
  resolveRespawnState,
  resolveRobotSides,
  resolveStatsState,
} from './state';
import {
  buildEffectiveUiSizing,
  loadHudSettings,
  normalizeHudSettings,
  saveHudSettings,
} from './state/settings';

function resolveClientTeam(clientId) {
  const numeric = Number(clientId);
  if (!Number.isFinite(numeric) || numeric <= 0) return 'red';
  return numeric >= 100 ? 'blue' : 'red';
}

function swapSideMap(sideMap) {
  if (!sideMap) return sideMap;
  return {
    ...sideMap,
    left: sideMap.right,
    right: sideMap.left,
  };
}

function resolveGlobalUnitDisplay({ bases, outposts, robots, globalUnit }, clientTeam) {
  if (clientTeam !== 'blue' || globalUnit?.sideBasis !== 'ally_enemy') {
    return {
      bases,
      outposts,
      robots,
    };
  }

  return {
    bases: swapSideMap(bases),
    outposts: swapSideMap(outposts),
    robots: swapSideMap(robots),
  };
}

function resolveRoleFromMecha(mecha, controls) {
  const robotId = Number(mecha?.robotId ?? mecha?.robot_id);
  if (robotId === 2 || robotId === 102) return 'engineer';
  if (robotId === 1 || robotId === 101) return 'hero';
  if ([3, 4, 5, 103, 104, 105].includes(robotId)) return 'infantry';
  if (robotId === 7 || robotId === 107) return 'sentry';

  const name = String(mecha?.pilotId ?? mecha?.name ?? mecha?.robotName ?? '').toUpperCase();
  if (name.includes('ENGINEER') || name.includes('工程')) return 'engineer';
  if (name.includes('HERO') || name.includes('英雄')) return 'hero';
  if (name.includes('INFANTRY') || name.includes('步兵')) return 'infantry';
  if (name.includes('SENTRY') || name.includes('哨兵')) return 'sentry';
  return controls?.activeRole ?? 'unknown';
}

function isEditableTarget(target) {
  if (!target) return false;
  const tagName = target.tagName?.toLowerCase();
  return tagName === 'input'
    || tagName === 'textarea'
    || tagName === 'select'
    || target.isContentEditable;
}

function resolveHotkeyAction(code, hotkeys) {
  if (code === hotkeys.heal) return 'heal';
  if (code === hotkeys.directAmmo) return 'directAmmo';
  if (code === hotkeys.remoteAmmo) return 'remoteAmmo';
  if (code === hotkeys.revive) return 'revive';
  return null;
}

export default function App() {
  const { uiState, setUiState } = useHudState();
  const [hudSettings, setHudSettings] = useState(() => loadHudSettings());
  const [resourceQuantities, setResourceQuantities] = useState(DEFAULT_RESOURCE_QUANTITIES);
  const hotkeyTapRef = useRef({});
  const normalizedHudSettings = useMemo(() => normalizeHudSettings(hudSettings), [hudSettings]);
  const clientTeam = resolveClientTeam(normalizedHudSettings.network.mqtt.clientId || uiState.mecha?.robotId);
  const globalUnitDisplay = useMemo(
    () => resolveGlobalUnitDisplay({
      bases: uiState.bases,
      outposts: uiState.outposts,
      robots: uiState.robots,
      globalUnit: uiState.globalUnit,
    }, clientTeam),
    [uiState.bases, uiState.globalUnit, uiState.outposts, uiState.robots, clientTeam],
  );
  const { leftRobots, rightRobots } = resolveRobotSides(globalUnitDisplay.robots);
  const miniMapState = resolveMiniMapState(uiState.miniMap);
  const respawnState = resolveRespawnState(uiState.respawn);
  const statsState = resolveStatsState(uiState.stats);
  const settingsMenuOpen = Boolean(uiState.settingsMenu?.open);
  const activeRole = resolveRoleFromMecha(uiState.mecha, uiState.controls);
  const isEngineer = activeRole === 'engineer';
  const [assemblyTask, setAssemblyTask] = useState({ active: false, activeLevel: null, startedAt: 0 });
  const resourceActions = useMemo(() => buildResourceActionState({
    activeRole,
    stats: statsState,
    mecha: uiState.mecha,
    respawn: respawnState,
    timeLeft: uiState.timeLeft,
    quantities: resourceQuantities,
  }), [activeRole, statsState, uiState.mecha, respawnState, uiState.timeLeft, resourceQuantities]);

  useEffect(() => {
    const background = uiState.forceBlackBg ? '#3939395b' : 'transparent';
    document.documentElement.style.background = background;
    document.body.style.background = background;
    return () => {
      document.documentElement.style.background = '';
      document.body.style.background = '';
    };
  }, [uiState.forceBlackBg]);

  useEffect(() => {
    saveHudSettings(normalizedHudSettings);
  }, [normalizedHudSettings]);

  useEffect(() => {
    const handleSettingsPatch = (event) => {
      const patch = event.detail;
      if (!patch?.logging?.path) return;
      setHudSettings((prev) => normalizeHudSettings({
        ...prev,
        logging: {
          ...(prev.logging ?? {}),
          path: patch.logging.path,
        },
      }));
    };

    window.addEventListener('hudSettingsPatch', handleSettingsPatch);
    return () => window.removeEventListener('hudSettingsPatch', handleSettingsPatch);
  }, []);

  useEffect(() => {
    emitGodotOperation(
      { type: 'setMouseSensitivity', value: normalizedHudSettings.mouseSensitivity },
      '[settings] mouseSensitivity',
      normalizedHudSettings.mouseSensitivity,
    );
  }, [normalizedHudSettings.mouseSensitivity]);

  useEffect(() => {
    emitGodotOperation(
      { type: 'setConnectionSettings', settings: normalizedHudSettings.network },
      '[settings] connectionSettings',
    );
  }, [normalizedHudSettings.network]);

  useEffect(() => {
    emitGodotOperation(
      { type: 'setDebugLogSettings', settings: normalizedHudSettings.logging },
      '[settings] debugLogSettings',
    );
  }, [normalizedHudSettings.logging]);

  const startAssemblyTask = useCallback((difficulty) => {
    setAssemblyTask({ active: true, activeLevel: difficulty, startedAt: Date.now() });
    emitGodotOperation({ type: 'assembly', operation: 0, difficulty }, '[hudOperate] assembly', difficulty);
  }, []);

  const confirmAssemblyTask = useCallback(() => {
    const difficulty = assemblyTask.activeLevel;
    if (!difficulty) return;
    emitGodotOperation({ type: 'assembly', operation: 1, difficulty }, '[hudOperate] assemblyConfirm', difficulty);
  }, [assemblyTask.activeLevel]);

  const cancelAssemblyTask = useCallback(() => {
    const difficulty = assemblyTask.activeLevel;
    if (!difficulty) return;
    emitGodotOperation({ type: 'assembly', operation: 2, difficulty }, '[hudOperate] assemblyCancel', difficulty);
    setAssemblyTask({ active: false, activeLevel: null, startedAt: 0 });
  }, [assemblyTask.activeLevel]);

  const visibleAssemblyTask = useMemo(() => {
    const resultTimestamp = uiState.assembly?.result ? Number(uiState.assembly?.timestamp) : 0;
    const resultAfterStart = Number.isFinite(resultTimestamp) && resultTimestamp >= assemblyTask.startedAt;
    return {
      ...assemblyTask,
      active: Boolean(assemblyTask.active && !resultAfterStart),
    };
  }, [assemblyTask, uiState.assembly?.result, uiState.assembly?.timestamp]);

  const setSettingsMenuOpen = useCallback((open) => {
    setUiState((prev) => ({
      ...prev,
      settingsMenu: {
        ...(prev.settingsMenu ?? {}),
        open,
      },
    }));
    emitGodotOperation({ type: 'setSettingsMenuOpen', open }, '[settings] setSettingsMenuOpen', open);
  }, [setUiState]);

  useEffect(() => {
    const handleKeyDown = (event) => {
      if (event.defaultPrevented) return;
      if (event.key !== 'Escape' || event.repeat) return;
      event.preventDefault();
      setSettingsMenuOpen(!settingsMenuOpen);
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [setSettingsMenuOpen, settingsMenuOpen]);

  useEffect(() => {
    const handleKeyDown = (event) => {
      const hotkeys = normalizedHudSettings.hotkeys;
      if (
        event.defaultPrevented
        || event.repeat
        || settingsMenuOpen
        || !hotkeys.enabled
        || isEditableTarget(event.target)
      ) {
        return;
      }

      const action = resolveHotkeyAction(event.code, hotkeys);
      if (!action || !resourceActions.supported) return;

      const now = Date.now();
      const lastTapAt = hotkeyTapRef.current[action] ?? 0;
      if (now - lastTapAt > hotkeys.doubleTapMs) {
        hotkeyTapRef.current[action] = now;
        return;
      }

      hotkeyTapRef.current[action] = 0;

      const config = {
        heal: {
          enabled: resourceActions.canHeal,
          operation: resourceActions.healOperation,
          label: 'remoteBuyHp',
        },
        directAmmo: {
          enabled: resourceActions.canDirectAmmo,
          operation: resourceActions.directAmmoOperation,
          label: resourceActions.directAmmoOperation.command,
          value: resourceActions.directAmmoOperation.param,
        },
        remoteAmmo: {
          enabled: resourceActions.canRemoteAmmo,
          operation: resourceActions.remoteAmmoOperation,
          label: 'remoteBuyAmmo',
          value: resourceActions.remoteAmmoOperation.param,
        },
        revive: {
          enabled: resourceActions.canRevive,
          operation: resourceActions.reviveOperation,
          label: 'buyRespawn',
          value: resourceActions.reviveOperation.param,
        },
      }[action];

      if (!config?.enabled) return;
      event.preventDefault();
      emitGodotOperation(config.operation, `[hotkey] ${config.label}`, config.value);
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [normalizedHudSettings.hotkeys, resourceActions, settingsMenuOpen]);

  const robotHpById = useMemo(
    () => buildRobotHpById(leftRobots, rightRobots),
    [leftRobots, rightRobots],
  );
  const effectiveUiSizing = useMemo(
    () => buildEffectiveUiSizing(uiState.uiSizing, normalizedHudSettings),
    [uiState.uiSizing, normalizedHudSettings],
  );
  const effectiveMessageCenter = useMemo(() => {
    const source = uiState.messageCenter ?? DEFAULT_UI_STATE.messageCenter;
    const sourceScale = Number(source?.scale);

    return {
      ...source,
      scale: (Number.isFinite(sourceScale) && sourceScale > 0 ? sourceScale : DEFAULT_UI_STATE.messageCenter.scale)
        * normalizedHudSettings.ui.scale,
    };
  }, [uiState.messageCenter, normalizedHudSettings.ui.scale]);

  return (
    <div className="hud-canvas font-sans text-white select-none">
      <DesignCanvas className="flex flex-col items-center pt-2">
        <div
          className="absolute inset-0 flex flex-col items-center pt-2"
          style={{ opacity: normalizedHudSettings.ui.opacity }}
        >
          <TopCoreLayout
            roundLabel={uiState.roundLabel}
            labels={uiState.labels}
            baseStateMeta={uiState.baseStateMeta}
            outpostStateMeta={uiState.outpostStateMeta}
            maxValues={uiState.maxValues}
            timeLeft={uiState.timeLeft}
            scores={uiState.scores}
            bases={globalUnitDisplay.bases}
            outposts={globalUnitDisplay.outposts}
            stats={statsState}
            leftRobots={leftRobots}
            rightRobots={rightRobots}
            robotLevels={uiState.robotLevels}
            uiSizing={effectiveUiSizing}
            match={uiState.match}
            mechanisms={uiState.mechanisms}
            fortress={uiState.fortress}
            links={uiState.links}
            fallbackBaseStateMeta={DEFAULT_UI_STATE.baseStateMeta}
            fallbackOutpostStateMeta={DEFAULT_UI_STATE.outpostStateMeta}
          />

          <MessageCenter messageCenter={effectiveMessageCenter} />
          <CommandPanel
            commandPanel={uiState.commandPanel}
            uiScale={normalizedHudSettings.ui.scale}
            onCommandPanelOpenChange={(open) => {
              setUiState((prev) => ({
                ...prev,
                commandPanel: {
                  ...(prev.commandPanel ?? {}),
                  open,
                },
              }));
            }}
            controls={uiState.controls}
            stats={statsState}
            mecha={uiState.mecha}
            respawn={respawnState}
            timeLeft={uiState.timeLeft}
            performance={uiState.performance}
            heroDeploy={uiState.heroDeploy}
            rune={uiState.rune}
            mechanisms={uiState.mechanisms}
            commandStatus={uiState.commandStatus}
            onAssemblyStart={startAssemblyTask}
            resourceQuantities={resourceQuantities}
            onResourceQuantitiesChange={setResourceQuantities}
            hotkeys={normalizedHudSettings.hotkeys}
          />
          {!isEngineer && <CenterCombatHUD centerHud={uiState.centerHud} uiSizing={effectiveUiSizing} />}
          <MechaHUD
            mecha={uiState.mecha}
            maxValues={uiState.maxValues}
            uiSizing={effectiveUiSizing}
            modules={uiState.modules}
            boostBuffs={uiState.boostBuffs}
            isEngineer={isEngineer}
            mechanisms={uiState.mechanisms}
            assembly={uiState.assembly}
            commandStatus={uiState.commandStatus}
            assemblyTask={visibleAssemblyTask}
            onAssemblyConfirm={confirmAssemblyTask}
            onAssemblyCancel={cancelAssemblyTask}
            activeRole={activeRole}
            resourceActions={resourceActions}
            hotkeys={normalizedHudSettings.hotkeys}
          />
          <MiniMapHUD
            miniMap={{ ...miniMapState, interactive: false }}
            uiSizing={effectiveUiSizing}
            robotHpById={robotHpById}
            radarTargets={uiState.radarTargets}
          />
          {/* ReviveOverlay disabled: respawn operations are handled by the right command panel. */}
        </div>
        <EscSettingsMenu
          open={settingsMenuOpen}
          settings={normalizedHudSettings}
          networkStatus={uiState.networkStatus}
          onSettingsChange={setHudSettings}
          onOpenChange={setSettingsMenuOpen}
        />
      </DesignCanvas>
    </div>
  );
}
