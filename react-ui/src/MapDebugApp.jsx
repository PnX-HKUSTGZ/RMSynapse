import { useMemo } from 'react';
import MiniMapHUD from './features/mini-map/MiniMapHUD';
import { emitGodotOperation } from './bridge/godot';
import DesignCanvas from './components/DesignCanvas';
import { useMapDebugState } from './hooks/useMapDebugState';
import {
  buildRobotHpById,
  resolveMiniMapState,
  resolveRobotSides,
} from './state';

export default function MapDebugApp() {
  const state = useMapDebugState();
  const miniMapState = resolveMiniMapState(state.miniMap);
  const { leftRobots, rightRobots } = resolveRobotSides(state.robots);
  const mapPageSizing = {
    ...state.uiSizing,
    miniMapScale: 1,
    miniMapWidth: 980,
    miniMapHeight: 525,
  };

  const robotHpById = useMemo(
    () => buildRobotHpById(leftRobots, rightRobots),
    [leftRobots, rightRobots],
  );

  return (
    <div className="hud-canvas bg-transparent font-mono text-white">
      <DesignCanvas className="relative">
        <MiniMapHUD
          miniMap={{ ...miniMapState, interactive: true, placement: 'center', showHeader: false }}
          uiSizing={mapPageSizing}
          robotHpById={robotHpById}
          radarTargets={state.radarTargets}
          onMapClick={(payload) => emitGodotOperation({ type: 'mapClick', ...payload }, '[map] click')}
        />
      </DesignCanvas>
    </div>
  );
}
