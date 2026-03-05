import { useCallback, useEffect, useMemo, useState } from 'react';
import { Navigation } from 'lucide-react';
import { CenterCombatHUD, MechaHUD, TopCoreLayout } from './HudComponents';
import { DEFAULT_UI_STATE, deepMerge, normalizeIncomingData } from './uiState';

const NUMBERS = [1, 2, 3, 4, 6, 7];

function createInitialMapPlayers() {
  return [
    ...NUMBERS.map((n, i) => ({
      id: `red-${n}`,
      team: 'red',
      number: n,
      x: 12,
      y: 15 + i * 14,
      rotation: 90,
    })),
    ...NUMBERS.map((n, i) => ({
      id: `blue-${n}`,
      team: 'blue',
      number: n,
      x: 88,
      y: 15 + i * 14,
      rotation: 270,
    })),
  ];
}

export default function App() {
  const [uiState, setUiState] = useState(DEFAULT_UI_STATE);
  const [lastMsg, setLastMsg] = useState('');
  const [mapPlayers, setMapPlayers] = useState(() => createInitialMapPlayers());
  const [currentPlayerId, setCurrentPlayerId] = useState('red-1');

  useEffect(() => {
    window.godotPush = (payload) => {
      let data = payload;
      if (typeof payload === 'string') {
        try {
          data = JSON.parse(payload);
        } catch (error) {
          console.error('godotPush payload is not valid JSON:', error);
          return;
        }
      }

      const normalizedData = normalizeIncomingData(data);
      const now = new Date();
      setLastMsg(now.toLocaleTimeString() + '.' + String(now.getMilliseconds()).padStart(3, '0'));
      setUiState((prev) => deepMerge(prev, normalizedData));
    };

    return () => {
      delete window.godotPush;
    };
  }, []);

  const {
    forceBlackBg,
    roundLabel,
    labels,
    baseStateMeta,
    outpostStateMeta,
    maxValues,
    timeLeft,
    scores,
    bases,
    outposts,
    stats,
    robots,
    mecha,
    centerHud
  } = uiState;

  const leftRobots = Array.isArray(robots?.left) ? robots.left : DEFAULT_UI_STATE.robots.left;
  const rightRobots = Array.isArray(robots?.right) ? robots.right : DEFAULT_UI_STATE.robots.right;
  const currentMapPlayer = mapPlayers.find((p) => p.id === currentPlayerId);

  const robotHpById = useMemo(() => {
    const map = {};
    leftRobots.forEach((robot) => {
      map[`red-${robot.id}`] = robot.hp;
    });
    rightRobots.forEach((robot) => {
      map[`blue-${robot.id}`] = robot.hp;
    });
    return map;
  }, [leftRobots, rightRobots]);

  const handleMiniMapClick = useCallback(
    (e) => {
      if (!currentMapPlayer) return;

      const rect = e.currentTarget.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = ((e.clientY - rect.top) / rect.height) * 100;

      setMapPlayers((prev) =>
        prev.map((player) => {
          if (player.id !== currentPlayerId) return player;
          const dx = x - player.x;
          const dy = y - player.y;
          const newRotation = Math.atan2(dy, dx) * (180 / Math.PI) + 90;
          return { ...player, x, y, rotation: newRotation };
        }),
      );
    },
    [currentMapPlayer, currentPlayerId],
  );

  return (
    <div className={`min-h-screen ${forceBlackBg ? 'bg-black' : 'bg-transparent'} flex flex-col items-center pt-2 relative overflow-hidden font-sans text-white select-none`}>
      <div className="absolute top-1 left-1 z-50 text-[10px] text-white/70 bg-black/30 px-2 py-1 rounded">
        lastMsg: {lastMsg || '—'}
      </div>

      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@500;700;900&display=swap');
        .font-orbitron { font-family: 'Orbitron', sans-serif; }

        .clip-trapezoid { clip-path: polygon(15px 0, calc(100% - 15px) 0, 100% 100%, 0 100%); }
        .clip-trapezoid-top { clip-path: polygon(10px 0, calc(100% - 10px) 0, 100% 100%, 0 100%); }

        .scanline-bg {
          background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.4) 2px, rgba(0,0,0,0.4) 4px);
        }

        .glass-panel {
          background: linear-gradient(180deg, rgba(15,20,25,0.3) 0%, rgba(5,10,15,0.5) 100%);
          backdrop-filter: blur(8px);
        }

        .ultra-glass {
          background: rgba(0, 0, 0, 0.25);
          backdrop-filter: blur(6px);
        }
      `}</style>

      <TopCoreLayout
        roundLabel={roundLabel}
        labels={labels}
        baseStateMeta={baseStateMeta}
        outpostStateMeta={outpostStateMeta}
        maxValues={maxValues}
        timeLeft={timeLeft}
        scores={scores}
        bases={bases}
        outposts={outposts}
        stats={stats}
        leftRobots={leftRobots}
        rightRobots={rightRobots}
      />

      <CenterCombatHUD centerHud={centerHud} />
      <MechaHUD mecha={mecha} maxValues={maxValues} />

      <div className="fixed bottom-4 right-4 z-40 flex flex-col items-end pointer-events-auto">
        <div className="bg-slate-800/90 backdrop-blur text-[11px] px-3 py-1.5 rounded-t-lg border-t border-l border-r border-slate-600 text-slate-300 flex items-center shadow-lg">
          <Navigation className="w-3 h-3 mr-2 text-cyan-400" />
          <span>小地图</span>
        </div>

        <div
          className="relative w-[360px] h-[202px] md:w-[420px] md:h-[236px] bg-slate-900 border-2 border-slate-600 rounded-b-lg rounded-tl-lg overflow-hidden shadow-[0_0_30px_rgba(0,0,0,0.8)] cursor-crosshair group"
          onClick={handleMiniMapClick}
        >
          <img
            src="/map.png"
            alt="RoboMaster Map"
            className="w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity duration-300"
          />

          {mapPlayers.map((player) => {
            const isCurrent = player.id === currentPlayerId;
            const hp = robotHpById[player.id];
            const isDestroyed = typeof hp === 'number' && hp <= 0;

            return (
              <div
                key={player.id}
                className="absolute transform -translate-x-1/2 -translate-y-1/2 transition-all duration-300 ease-out"
                style={{ left: `${player.x}%`, top: `${player.y}%`, width: '24px', height: '24px' }}
                onClick={(e) => {
                  e.stopPropagation();
                  setCurrentPlayerId(player.id);
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
