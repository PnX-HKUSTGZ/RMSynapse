import { useCallback, useEffect, useMemo, useState } from 'react';
import { emitGodotOperation } from './bridge/godot';
import CenterCombatHUD from './features/center-hud/CenterCombatHUD';
import CommandPanel from './features/command-panel/CommandPanel';
import MessageCenter from './features/message-center/MessageCenter';
import MechaHUD from './features/mecha-hud/MechaHUD';
import MiniMapHUD from './features/mini-map/MiniMapHUD';
import EscSettingsMenu from './features/settings/EscSettingsMenu';
import TopCoreLayout from './features/top-core/TopCoreLayout';
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

export default function App() {
  const { uiState, setUiState } = useHudState();
  const [hudSettings, setHudSettings] = useState(() => loadHudSettings());
  const normalizedHudSettings = useMemo(() => normalizeHudSettings(hudSettings), [hudSettings]);
  const { leftRobots, rightRobots } = resolveRobotSides(uiState.robots);
  const miniMapState = resolveMiniMapState(uiState.miniMap);
  const respawnState = resolveRespawnState(uiState.respawn);
  const statsState = resolveStatsState(uiState.stats);
  const settingsMenuOpen = Boolean(uiState.settingsMenu?.open);

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
    emitGodotOperation(
      { type: 'setMouseSensitivity', value: normalizedHudSettings.mouseSensitivity },
      '[settings] mouseSensitivity',
      normalizedHudSettings.mouseSensitivity,
    );
  }, [normalizedHudSettings.mouseSensitivity]);

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
      if (event.key !== 'Escape' || event.repeat) return;
      event.preventDefault();
      setSettingsMenuOpen(!settingsMenuOpen);
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [setSettingsMenuOpen, settingsMenuOpen]);

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
    <div className="relative flex h-screen w-screen flex-col items-center overflow-hidden pt-2 font-sans text-white select-none">
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
          bases={uiState.bases}
          outposts={uiState.outposts}
          stats={statsState}
          leftRobots={leftRobots}
          rightRobots={rightRobots}
          uiSizing={effectiveUiSizing}
          match={uiState.match}
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
        />
        <CenterCombatHUD centerHud={uiState.centerHud} uiSizing={effectiveUiSizing} />
        <MechaHUD
          mecha={uiState.mecha}
          maxValues={uiState.maxValues}
          uiSizing={effectiveUiSizing}
          modules={uiState.modules}
          boostBuffs={uiState.boostBuffs}
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
        onSettingsChange={setHudSettings}
        onOpenChange={setSettingsMenuOpen}
      />
    </div>
  );
}
