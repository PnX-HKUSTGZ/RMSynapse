import { memo } from 'react';
import { Navigation } from 'lucide-react';
import { resolveMiniMapState, resolveUiSizing } from '../../state';

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

function MiniMapHUD({ miniMap, uiSizing, robotHpById }) {
  const mergedMiniMap = resolveMiniMapState(miniMap);
  const mergedSizing = resolveUiSizing(uiSizing);

  const players = mergedMiniMap.players;
  const currentPlayerId = mergedMiniMap.currentPlayerId ?? players[0]?.id;
  const miniMapScale = mergedSizing.miniMapScale > 0 ? mergedSizing.miniMapScale : 1;
  const mapWidth = mergedSizing.miniMapWidth;
  const mapHeight = mergedSizing.miniMapHeight;
  const markerSize = mergedSizing.miniMapMarkerSize;

  return (
    <div
      className="pointer-events-none fixed bottom-0 right-0 z-40 flex flex-col items-end"
      style={{ right: `${mergedSizing.miniMapRight}px`, bottom: `${mergedSizing.miniMapBottom}px` }}
    >
      <div style={{ transform: `scale(${miniMapScale})`, transformOrigin: 'bottom right' }}>
        <div className="flex items-center rounded-t-lg border-l border-r border-t border-slate-600 bg-slate-800/92 px-3 py-1.5 text-[11px] text-slate-300 shadow-lg">
          <Navigation className="mr-2 h-3 w-3 text-cyan-400" />
          <span>{mergedMiniMap.title}</span>
        </div>

        <div
          className="relative overflow-hidden rounded-b-lg rounded-tl-lg border-2 border-slate-600 bg-slate-900 shadow-[0_0_24px_rgba(0,0,0,0.65)]"
          style={{ width: `${mapWidth}px`, height: `${mapHeight}px` }}
        >
          <img
            src={mergedMiniMap.imageSrc}
            alt={mergedMiniMap.imageAlt}
            className="h-full w-full object-cover opacity-85"
          />

          {players.map((player) => {
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
