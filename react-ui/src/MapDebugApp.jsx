import { useMemo } from 'react';
import MapTopControls from './features/map-controls/MapTopControls';
import MiniMapHUD from './features/mini-map/MiniMapHUD';
import { useMapDebugState } from './hooks/useMapDebugState';
import {
  buildRobotHpById,
  resolveMiniMapState,
  resolveRobotSides,
  resolveStatsState,
} from './state';

export default function MapDebugApp() {
  const state = useMapDebugState();
  const miniMapState = resolveMiniMapState(state.miniMap);
  const statsState = resolveStatsState(state.stats);
  const { leftRobots, rightRobots } = resolveRobotSides(state.robots);

  const robotHpById = useMemo(
    () => buildRobotHpById(leftRobots, rightRobots),
    [leftRobots, rightRobots],
  );

  return (
    <div className="relative min-h-screen overflow-hidden bg-transparent font-mono text-white">
      <MapTopControls eco={statsState.eco} controls={state.controls} />
      <MiniMapHUD
        miniMap={{ ...miniMapState, interactive: false }}
        uiSizing={state.uiSizing}
        robotHpById={robotHpById}
      />
    </div>
  );
}
