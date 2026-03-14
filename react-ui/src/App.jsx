import { useCallback, useEffect, useMemo, useState } from 'react';
import { CenterCombatHUD, MechaHUD, TopCoreLayout } from './HudComponents';
import MiniMapHUD from './MiniMapHUD';
import ReviveOverlay from './ReviveOverlay';
import { DEFAULT_UI_STATE, deepMerge, normalizeIncomingData } from './uiState';

export default function App() {
  const [uiState, setUiState] = useState(DEFAULT_UI_STATE);

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
    miniMap,
    respawn
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

  const mergedRespawn = useMemo(
    () => ({ ...DEFAULT_UI_STATE.respawn, ...(respawn ?? {}) }),
    [respawn],
  );

  const currentEco = Number(stats?.eco) || 0;

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

  const handleNormalRevive = useCallback(() => {
    if (typeof window.godotOperate === 'function') {
      window.godotOperate({ type: 'normalRevive' });
      return;
    }
    console.log('[revive] normalRevive');
  }, []);

  const handleBuyRevive = useCallback(({ cost }) => {
    if (typeof window.godotOperate === 'function') {
      window.godotOperate({ type: 'buyRevive', cost });
      return;
    }
    console.log('[revive] buyRevive', cost);
  }, []);

  return (
    <div className={`min-h-screen ${forceBlackBg ? 'bg-black' : 'bg-transparent'} flex flex-col items-center pt-2 relative overflow-hidden font-sans text-white select-none`}>
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

      <ReviveOverlay
        key={mergedRespawn.isDead ? 'respawn-dead' : 'respawn-alive'}
        isDead={!!mergedRespawn.isDead}
        countdown={mergedRespawn.countdown}
        eco={currentEco}
        reviveCost={mergedRespawn.reviveCost}
        scale={mergedRespawn.scale}
        onNormalRevive={handleNormalRevive}
        onBuyRevive={handleBuyRevive}
      />
    </div>
  );
}
