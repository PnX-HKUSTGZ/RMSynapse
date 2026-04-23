import { useMemo } from 'react';
import { emitGodotOperation } from './bridge/godot';
import CenterCombatHUD from './features/center-hud/CenterCombatHUD';
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

  const robotHpById = useMemo(
    () => buildRobotHpById(leftRobots, rightRobots),
    [leftRobots, rightRobots],
  );

  return (
    <div className={`relative flex min-h-screen flex-col items-center overflow-hidden pt-2 font-sans text-white select-none ${uiState.forceBlackBg ? 'bg-black' : 'bg-transparent'}`}>
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
        fallbackBaseStateMeta={DEFAULT_UI_STATE.baseStateMeta}
        fallbackOutpostStateMeta={DEFAULT_UI_STATE.outpostStateMeta}
      />

      <MessageCenter messageCenter={uiState.messageCenter} />
      <CenterCombatHUD centerHud={uiState.centerHud} uiSizing={uiState.uiSizing} />
      <MechaHUD
        mecha={uiState.mecha}
        maxValues={uiState.maxValues}
        uiSizing={uiState.uiSizing}
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
