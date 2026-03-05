import { Navigation } from 'lucide-react';
import { DEFAULT_UI_STATE } from './uiState';

function MiniMapHUD({ miniMap, uiSizing, robotHpById, onMoveCurrentPlayer, onSelectPlayer }) {
  const mergedMiniMap = { ...DEFAULT_UI_STATE.miniMap, ...(miniMap ?? {}) };
  const mergedSizing = { ...DEFAULT_UI_STATE.uiSizing, ...(uiSizing ?? {}) };

  const players = Array.isArray(mergedMiniMap.players) ? mergedMiniMap.players : DEFAULT_UI_STATE.miniMap.players;
  const currentPlayerId = mergedMiniMap.currentPlayerId ?? players[0]?.id;
  const currentMapPlayer = players.find((player) => player.id === currentPlayerId);

  const miniMapScale = mergedSizing.miniMapScale > 0 ? mergedSizing.miniMapScale : 1;
  const mapWidth = mergedSizing.miniMapWidth > 0 ? mergedSizing.miniMapWidth : DEFAULT_UI_STATE.uiSizing.miniMapWidth;
  const mapHeight = mergedSizing.miniMapHeight > 0 ? mergedSizing.miniMapHeight : DEFAULT_UI_STATE.uiSizing.miniMapHeight;
  const markerSize = mergedSizing.miniMapMarkerSize > 0 ? mergedSizing.miniMapMarkerSize : DEFAULT_UI_STATE.uiSizing.miniMapMarkerSize;

  const handleMiniMapClick = (e) => {
    if (!mergedMiniMap.interactive || !currentMapPlayer) return;

    const rect = e.currentTarget.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 100;
    const y = ((e.clientY - rect.top) / rect.height) * 100;
    onMoveCurrentPlayer?.({ x, y });
  };

  return (
    <div
      className="fixed z-40 flex flex-col items-end pointer-events-auto"
      style={{ right: `${mergedSizing.miniMapRight}px`, bottom: `${mergedSizing.miniMapBottom}px` }}
    >
      <div style={{ transform: `scale(${miniMapScale})`, transformOrigin: 'bottom right' }}>
        <div className="bg-slate-800/90 backdrop-blur text-[11px] px-3 py-1.5 rounded-t-lg border-t border-l border-r border-slate-600 text-slate-300 flex items-center shadow-lg">
          <Navigation className="w-3 h-3 mr-2 text-cyan-400" />
          <span>{mergedMiniMap.title}</span>
        </div>

        <div
          className="relative bg-slate-900 border-2 border-slate-600 rounded-b-lg rounded-tl-lg overflow-hidden shadow-[0_0_30px_rgba(0,0,0,0.8)] cursor-crosshair group"
          style={{ width: `${mapWidth}px`, height: `${mapHeight}px` }}
          onClick={handleMiniMapClick}
        >
          <img
            src={mergedMiniMap.imageSrc}
            alt={mergedMiniMap.imageAlt}
            className="w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity duration-300"
          />

          {players.map((player) => {
            const isCurrent = player.id === currentPlayerId;
            const hp = robotHpById[player.id];
            const isDestroyed = typeof hp === 'number' && hp <= 0;

            return (
              <div
                key={player.id}
                className="absolute transform -translate-x-1/2 -translate-y-1/2 transition-all duration-300 ease-out"
                style={{ left: `${player.x}%`, top: `${player.y}%`, width: `${markerSize}px`, height: `${markerSize}px` }}
                onClick={(e) => {
                  e.stopPropagation();
                  if (mergedMiniMap.interactive) onSelectPlayer?.(player.id);
                }}
              >
                {isCurrent && !isDestroyed && (
                  <div className="absolute inset-[-6px] rounded-full border-2 border-yellow-400 animate-pulse shadow-[0_0_10px_#facc15]" />
                )}

                {!isDestroyed && (
                  <div
                    className="absolute inset-0 transition-transform duration-200"
                    style={{ transform: `rotate(${player.rotation}deg)` }}
                  >
                    <div
                      className={`absolute top-[-8px] left-1/2 -translate-x-1/2 w-0 h-0 border-l-[6px] border-r-[6px] border-b-[10px] border-l-transparent border-r-transparent ${
                        player.team === 'red'
                          ? 'border-b-red-400 drop-shadow-[0_0_3px_red]'
                          : 'border-b-blue-400 drop-shadow-[0_0_3px_blue]'
                      }`}
                    />
                  </div>
                )}

                <div
                  className={`absolute inset-0 rounded-full flex items-center justify-center text-[12px] font-black text-white border-2 cursor-pointer shadow-md ${
                    isDestroyed
                      ? 'bg-slate-700/80 border-slate-400 text-slate-300'
                      : player.team === 'red'
                        ? 'bg-red-600 border-red-300 hover:bg-red-500'
                        : 'bg-blue-600 border-blue-300 hover:bg-blue-500'
                  }`}
                >
                  {player.number}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

export default MiniMapHUD;
