import { memo } from 'react';
import { Navigation } from 'lucide-react';
import { resolveMiniMapState, resolveUiSizing } from '../../state';

function clampPercent(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return 0;
  return Math.max(0, Math.min(100, numeric));
}

function isMapPosition(position) {
  return position && Number.isFinite(Number(position.x)) && Number.isFinite(Number(position.y));
}

function playerIdForRobotId(robotId) {
  const numeric = Number(robotId);
  if (!Number.isFinite(numeric) || numeric <= 0) return null;
  if (numeric >= 100) return `blue-${numeric - 100}`;
  return `red-${numeric}`;
}

function markModeForClick(event) {
  if (event.button === 2) return 3;
  if (event.shiftKey) return 2;
  return 1;
}

function MiniMapMarker({ markerSize, player, isCurrent, isDestroyed }) {
  return (
    <div
      className="absolute -translate-x-1/2 -translate-y-1/2 transform"
      style={{ left: `${player.x}%`, top: `${player.y}%`, width: `${markerSize}px`, height: `${markerSize}px` }}
    >
      {isCurrent && !isDestroyed && (
        <div className="absolute inset-[-5px] rounded-full border-2 border-yellow-400/90 shadow-[0_0_8px_#facc15]" />
      )}

      {!isDestroyed && (
        <div className="absolute inset-0" style={{ transform: `rotate(${player.rotation}deg)` }}>
          <div
            className={`absolute left-1/2 top-[-8px] h-0 w-0 -translate-x-1/2 border-l-[6px] border-r-[6px] border-b-[10px] border-l-transparent border-r-transparent ${
              player.team === 'red'
                ? 'border-b-red-400 drop-shadow-[0_0_3px_red]'
                : 'border-b-blue-400 drop-shadow-[0_0_3px_blue]'
            }`}
          />
        </div>
      )}

      {player.radarHighlighted && !isDestroyed && (
        <div className="absolute inset-[-7px] rounded-full border-2 border-yellow-300/90 shadow-[0_0_12px_rgba(253,224,71,0.95)]" />
      )}

      <div
        className={`absolute inset-0 flex items-center justify-center rounded-full border-2 text-[12px] font-black text-white shadow-md ${
          isDestroyed
            ? 'border-slate-400 bg-slate-700/80 text-slate-300'
            : player.team === 'red'
              ? 'border-red-300 bg-red-600'
              : 'border-blue-300 bg-blue-600'
        }`}
      >
        {player.number}
      </div>
    </div>
  );
}

function MiniMapHUD({ miniMap, uiSizing, robotHpById, radarTargets, onMapClick }) {
  const mergedMiniMap = resolveMiniMapState(miniMap);
  const mergedSizing = resolveUiSizing(uiSizing);

  const players = mergedMiniMap.players;
  const currentPlayerId = mergedMiniMap.currentPlayerId ?? players[0]?.id;
  const miniMapScale = mergedSizing.miniMapScale > 0 ? mergedSizing.miniMapScale : 1;
  const mapWidth = mergedSizing.miniMapWidth;
  const mapHeight = mergedSizing.miniMapHeight;
  const markerSize = mergedSizing.miniMapMarkerSize;
  const interactive = Boolean(mergedMiniMap.interactive);
  const isCenterPlacement = mergedMiniMap.placement === 'center';
  const showHeader = mergedMiniMap.showHeader !== false;
  const targets = Array.isArray(radarTargets) ? radarTargets : [];
  const radarTargetByPlayerId = new Map(
    targets
      .map((target) => [playerIdForRobotId(target?.robotId), target])
      .filter(([playerId, target]) => playerId && isMapPosition(target)),
  );
  const displayedPlayers = players.map((player) => {
    if (player.id === currentPlayerId && isMapPosition(mergedMiniMap.currentPosition)) {
      return {
        ...player,
        x: clampPercent(mergedMiniMap.currentPosition.x),
        y: clampPercent(mergedMiniMap.currentPosition.y),
        rotation: Number.isFinite(Number(mergedMiniMap.currentPosition.yaw))
          ? Number(mergedMiniMap.currentPosition.yaw)
          : player.rotation,
      };
    }
    const radarTarget = radarTargetByPlayerId.get(player.id);
    if (!radarTarget || player.id === currentPlayerId) return player;
    return {
      ...player,
      x: clampPercent(radarTarget.x),
      y: clampPercent(radarTarget.y),
      rotation: Number.isFinite(Number(radarTarget.angle)) ? Number(radarTarget.angle) : player.rotation,
      radarHighlighted: radarTarget.highlighted,
    };
  });
  const rootClass = isCenterPlacement
    ? `${interactive ? 'pointer-events-auto' : 'pointer-events-none'} fixed inset-0 z-40 flex items-center justify-center bg-black/40 p-6`
    : `${interactive ? 'pointer-events-auto' : 'pointer-events-none'} fixed bottom-0 right-0 z-40 flex flex-col items-end`;
  const rootStyle = isCenterPlacement
    ? undefined
    : { right: `${mergedSizing.miniMapRight}px`, bottom: `${mergedSizing.miniMapBottom}px` };
  const mapStyle = isCenterPlacement
    ? {
        width: `min(92vw, ${mapWidth}px)`,
        maxHeight: '82vh',
        aspectRatio: `${mapWidth} / ${mapHeight}`,
      }
    : { width: `${mapWidth}px`, height: `${mapHeight}px` };

  const handleMapClick = (event) => {
    if (!interactive || typeof onMapClick !== 'function') return;
    const rect = event.currentTarget.getBoundingClientRect();
    const xRatio = rect.width > 0 ? (event.clientX - rect.left) / rect.width : 0;
    const yRatio = rect.height > 0 ? (event.clientY - rect.top) / rect.height : 0;
    const coordinateMax = Number(mergedMiniMap.protocolCoordinateMax ?? 1000);
    const mapCoordinateMax = Number.isFinite(coordinateMax) && coordinateMax > 0 ? coordinateMax : 1000;
    onMapClick({
      screenX: Math.round(event.clientX),
      screenY: Math.round(event.clientY),
      mapX: Math.max(0, Math.min(1, xRatio)) * mapCoordinateMax,
      mapY: Math.max(0, Math.min(1, yRatio)) * mapCoordinateMax,
      mode: markModeForClick(event),
      typeValue: 1,
      isSendAll: 1,
    });
  };

  return (
    <div className={rootClass} style={rootStyle}>
      <div style={{ transform: `scale(${miniMapScale})`, transformOrigin: isCenterPlacement ? 'center center' : 'bottom right' }}>
        {showHeader && (
          <div className="flex items-center rounded-t-lg border-l border-r border-t border-slate-600 bg-slate-800/92 px-3 py-1.5 text-[11px] text-slate-300 shadow-lg">
            <Navigation className="mr-2 h-3 w-3 text-cyan-400" />
            <span>{mergedMiniMap.title}</span>
          </div>
        )}

        <div
          className={`relative overflow-hidden border-2 border-slate-600 bg-slate-900 shadow-[0_0_24px_rgba(0,0,0,0.65)] ${showHeader ? 'rounded-b-lg rounded-tl-lg' : 'rounded-lg'} ${interactive ? 'cursor-crosshair' : ''}`}
          style={mapStyle}
          onClick={handleMapClick}
          onContextMenu={(event) => {
            if (interactive) {
              event.preventDefault();
              handleMapClick(event);
            }
          }}
        >
          <img
            src={mergedMiniMap.imageSrc}
            alt={mergedMiniMap.imageAlt}
            className="h-full w-full object-cover opacity-85"
          />

          {displayedPlayers.map((player) => {
            const hp = robotHpById[player.id];
            const isDestroyed = typeof hp === 'number' && hp <= 0;

            return (
              <MiniMapMarker
                key={player.id}
                markerSize={markerSize}
                player={player}
                isCurrent={player.id === currentPlayerId}
                isDestroyed={isDestroyed}
              />
            );
          })}
        </div>
      </div>
    </div>
  );
}

export default memo(MiniMapHUD);
