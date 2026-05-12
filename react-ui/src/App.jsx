import { useEffect, useMemo } from 'react';
import { emitGodotOperation } from './bridge/godot';
import CenterCombatHUD from './features/center-hud/CenterCombatHUD';
import CommandPanel from './features/command-panel/CommandPanel';
import MessageCenter from './features/message-center/MessageCenter';
import MechaHUD from './features/mecha-hud/MechaHUD';
import MiniMapHUD from './features/mini-map/MiniMapHUD';
import ReviveOverlay from './features/revive/ReviveOverlay';
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

export default function App() {
  const { uiState } = useHudState();
  const { leftRobots, rightRobots } = resolveRobotSides(uiState.robots);
  const miniMapState = resolveMiniMapState(uiState.miniMap);
  const respawnState = resolveRespawnState(uiState.respawn);
  const statsState = resolveStatsState(uiState.stats);

  useEffect(() => {
    const background = uiState.forceBlackBg ? '#3939395b' : 'transparent';
    document.documentElement.style.background = background;
    document.body.style.background = background;
    return () => {
      document.documentElement.style.background = '';
      document.body.style.background = '';
    };
  }, [uiState.forceBlackBg]);

  const robotHpById = useMemo(
    () => buildRobotHpById(leftRobots, rightRobots),
    [leftRobots, rightRobots],
  );

  return (
    <div className="relative flex h-screen w-screen flex-col items-center overflow-hidden pt-2 font-sans text-white select-none">
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
        uiSizing={uiState.uiSizing}
        match={uiState.match}
        links={uiState.links}
        fallbackBaseStateMeta={DEFAULT_UI_STATE.baseStateMeta}
        fallbackOutpostStateMeta={DEFAULT_UI_STATE.outpostStateMeta}
      />

      <MessageCenter messageCenter={uiState.messageCenter} />
      <CommandPanel
        controls={uiState.controls}
        stats={statsState}
        mecha={uiState.mecha}
        respawn={respawnState}
        performance={uiState.performance}
        heroDeploy={uiState.heroDeploy}
        rune={uiState.rune}
        sentry={uiState.sentry}
        dart={uiState.dart}
        airSupport={uiState.airSupport}
        mechanisms={uiState.mechanisms}
        commandStatus={uiState.commandStatus}
      />
      <CenterCombatHUD centerHud={uiState.centerHud} uiSizing={uiState.uiSizing} />
      <MechaHUD
        mecha={uiState.mecha}
        maxValues={uiState.maxValues}
        uiSizing={uiState.uiSizing}
        modules={uiState.modules}
        boostBuffs={uiState.boostBuffs}
      />
      <MiniMapHUD miniMap={miniMapState} uiSizing={uiState.uiSizing} robotHpById={robotHpById} />
      <ReviveOverlay
        isDead={!!respawnState.isDead}
        countdown={respawnState.countdown}
        eco={statsState.eco}
        reviveCost={respawnState.reviveCost}
        scale={respawnState.scale}
        minScale={respawnState.minScale}
        maxScale={respawnState.maxScale}
        texts={respawnState.texts}
        onNormalRevive={() => emitGodotOperation({ type: 'normalRevive' }, '[revive] normalRevive')}
        onBuyRevive={({ cost }) => emitGodotOperation({ type: 'buyRevive', cost }, '[revive] buyRevive', cost)}
      />
    </div>
  );
}
