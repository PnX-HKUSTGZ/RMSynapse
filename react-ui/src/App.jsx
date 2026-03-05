import { useCallback, useEffect, useMemo, useState } from 'react';
import { CenterCombatHUD, MechaHUD, TopCoreLayout } from './HudComponents';
import MiniMapHUD from './MiniMapHUD';
import { DEFAULT_UI_STATE, deepMerge, normalizeIncomingData } from './uiState';

export default function App() {
  const [uiState, setUiState] = useState(DEFAULT_UI_STATE);
  const [lastMsg, setLastMsg] = useState('');

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
    uiSizing,
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
    centerHud,
    boostBuffs,
    miniMap
  } = uiState;

  const leftRobots = Array.isArray(robots?.left) ? robots.left : DEFAULT_UI_STATE.robots.left;
  const rightRobots = Array.isArray(robots?.right) ? robots.right : DEFAULT_UI_STATE.robots.right;

  const mergedMiniMap = useMemo(
    () => ({ ...DEFAULT_UI_STATE.miniMap, ...(miniMap ?? {}) }),
    [miniMap],
  );

  const miniMapPlayers = Array.isArray(mergedMiniMap.players)
    ? mergedMiniMap.players
    : DEFAULT_UI_STATE.miniMap.players;

  const robotHpById = useMemo(() => {
    const hpMap = {};
    leftRobots.forEach((robot) => {
      hpMap[`red-${robot.id}`] = robot.hp;
    });
    rightRobots.forEach((robot) => {
      hpMap[`blue-${robot.id}`] = robot.hp;
    });
    return hpMap;
  }, [leftRobots, rightRobots]);

  const handleMiniMapPlayerSelect = useCallback((playerId) => {
    setUiState((prev) => deepMerge(prev, { miniMap: { currentPlayerId: playerId } }));
  }, []);

  const handleMiniMapMoveCurrentPlayer = useCallback(({ x, y }) => {
    setUiState((prev) => {
      const prevMiniMap = { ...DEFAULT_UI_STATE.miniMap, ...(prev.miniMap ?? {}) };
      const players = Array.isArray(prevMiniMap.players)
        ? prevMiniMap.players
        : DEFAULT_UI_STATE.miniMap.players;

      const currentPlayerId = prevMiniMap.currentPlayerId ?? players[0]?.id;
      if (!currentPlayerId) return prev;

      const currentPlayer = players.find((player) => player.id === currentPlayerId);
      if (!currentPlayer) return prev;

      const nextX = Math.max(0, Math.min(100, x));
      const nextY = Math.max(0, Math.min(100, y));

      const nextPlayers = players.map((player) => {
        if (player.id !== currentPlayerId) return player;
        const dx = nextX - player.x;
        const dy = nextY - player.y;
        const nextRotation = Math.atan2(dy, dx) * (180 / Math.PI) + 90;
        return { ...player, x: nextX, y: nextY, rotation: nextRotation };
      });

      return deepMerge(prev, { miniMap: { players: nextPlayers } });
    });
  }, []);

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
        uiSizing={uiSizing}
      />

      <CenterCombatHUD centerHud={centerHud} uiSizing={uiSizing} />
      <MechaHUD mecha={mecha} maxValues={maxValues} uiSizing={uiSizing} boostBuffs={boostBuffs} />

      <MiniMapHUD
        miniMap={{ ...mergedMiniMap, players: miniMapPlayers }}
        uiSizing={uiSizing}
        robotHpById={robotHpById}
        onSelectPlayer={handleMiniMapPlayerSelect}
        onMoveCurrentPlayer={handleMiniMapMoveCurrentPlayer}
      />
    </div>
  );
}
