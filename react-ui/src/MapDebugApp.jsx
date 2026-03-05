import { useCallback, useEffect, useMemo, useState } from 'react';
import MiniMapHUD from './MiniMapHUD';
import { DEFAULT_UI_STATE, deepMerge, normalizeIncomingData } from './uiState';

function clonePlayers(players) {
  return players.map((player) => ({ ...player }));
}

function cloneRobots(robots) {
  return {
    left: robots.left.map((robot) => ({ ...robot })),
    right: robots.right.map((robot) => ({ ...robot }))
  };
}

function createDefaultMapDebugState() {
  return {
    forceBlackBg: true,
    uiSizing: {
      ...DEFAULT_UI_STATE.uiSizing,
      miniMapScale: 1,
      miniMapWidth: 560,
      miniMapHeight: 315,
      miniMapMarkerSize: 28,
      miniMapBottom: 20,
      miniMapRight: 20
    },
    miniMap: {
      ...DEFAULT_UI_STATE.miniMap,
      title: '地图调试',
      players: clonePlayers(DEFAULT_UI_STATE.miniMap.players)
    },
    robots: cloneRobots(DEFAULT_UI_STATE.robots),
    debug: {
      title: 'Debug Console',
      subtitle: 'Robot Info + Map'
    }
  };
}

export default function MapDebugApp() {
  const [state, setState] = useState(() => createDefaultMapDebugState());
  const [lastMsg, setLastMsg] = useState('');

  useEffect(() => {
    const handler = (payload) => {
      let data = payload;
      if (typeof payload === 'string') {
        try {
          data = JSON.parse(payload);
        } catch (error) {
          console.error('godotMapPush payload is not valid JSON:', error);
          return;
        }
      }

      const normalized = normalizeIncomingData(data);
      const now = new Date();
      setLastMsg(now.toLocaleTimeString() + '.' + String(now.getMilliseconds()).padStart(3, '0'));
      setState((prev) => deepMerge(prev, normalized));
    };

    window.godotMapPush = handler;
    // 兼容直接沿用 godotPush 的场景
    window.godotPush = handler;

    return () => {
      delete window.godotMapPush;
      delete window.godotPush;
    };
  }, []);

  const mergedMiniMap = useMemo(
    () => ({ ...DEFAULT_UI_STATE.miniMap, ...(state.miniMap ?? {}) }),
    [state.miniMap],
  );

  const miniMapPlayers = Array.isArray(mergedMiniMap.players)
    ? mergedMiniMap.players
    : DEFAULT_UI_STATE.miniMap.players;

  const leftRobots = Array.isArray(state.robots?.left) ? state.robots.left : DEFAULT_UI_STATE.robots.left;
  const rightRobots = Array.isArray(state.robots?.right) ? state.robots.right : DEFAULT_UI_STATE.robots.right;

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

  const currentPlayerId = mergedMiniMap.currentPlayerId ?? miniMapPlayers[0]?.id;
  const selected = miniMapPlayers.find((player) => player.id === currentPlayerId);

  const playerRows = useMemo(
    () => miniMapPlayers.map((player) => {
      const hp = robotHpById[player.id];
      return {
        ...player,
        hp: typeof hp === 'number' ? hp : '-',
      };
    }),
    [miniMapPlayers, robotHpById],
  );

  const handleMiniMapPlayerSelect = useCallback((playerId) => {
    setState((prev) => deepMerge(prev, { miniMap: { currentPlayerId: playerId } }));
  }, []);

  const handleMiniMapMoveCurrentPlayer = useCallback(({ x, y }) => {
    setState((prev) => {
      const prevMiniMap = { ...DEFAULT_UI_STATE.miniMap, ...(prev.miniMap ?? {}) };
      const players = Array.isArray(prevMiniMap.players)
        ? prevMiniMap.players
        : DEFAULT_UI_STATE.miniMap.players;

      const selectedId = prevMiniMap.currentPlayerId ?? players[0]?.id;
      if (!selectedId) return prev;

      const selectedPlayer = players.find((player) => player.id === selectedId);
      if (!selectedPlayer) return prev;

      const nextX = Math.max(0, Math.min(100, x));
      const nextY = Math.max(0, Math.min(100, y));

      const nextPlayers = players.map((player) => {
        if (player.id !== selectedId) return player;
        const dx = nextX - player.x;
        const dy = nextY - player.y;
        const nextRotation = Math.atan2(dy, dx) * (180 / Math.PI) + 90;
        return { ...player, x: nextX, y: nextY, rotation: nextRotation };
      });

      return deepMerge(prev, { miniMap: { players: nextPlayers } });
    });
  }, []);

  return (
    <div className={`min-h-screen ${state.forceBlackBg ? 'bg-black' : 'bg-slate-950'} relative overflow-hidden text-white font-mono`}>
      <div className="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.03)_1px,transparent_1px)] bg-[size:48px_48px] pointer-events-none" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(56,189,248,0.08),transparent_45%),radial-gradient(circle_at_70%_80%,rgba(99,102,241,0.08),transparent_45%)] pointer-events-none" />

      <div className="absolute top-3 left-3 z-30 text-[11px] text-cyan-200/90 bg-slate-900/75 px-3 py-2 rounded border border-cyan-400/30 backdrop-blur-sm">
        <div className="font-bold tracking-wide">{state.debug?.title ?? 'Debug Console'}</div>
        <div className="text-cyan-300/80">{state.debug?.subtitle ?? 'Robot Info + Map'}</div>
        <div className="mt-1 text-white/70">lastMsg: {lastMsg || '—'}</div>
      </div>

      <div className="absolute top-24 left-3 z-30 w-[380px] max-h-[70vh] overflow-auto rounded border border-slate-700 bg-slate-900/80 backdrop-blur px-3 py-3">
        <div className="text-sm font-bold text-cyan-300 mb-2">Selected Robot</div>
        <div className="text-xs text-slate-300 mb-3">
          {selected ? `${selected.id} | x:${selected.x.toFixed(1)} y:${selected.y.toFixed(1)} | rot:${selected.rotation.toFixed(1)} | hp:${robotHpById[selected.id] ?? '-'}` : 'None'}
        </div>

        <div className="text-sm font-bold text-cyan-300 mb-2">All Robots</div>
        <div className="grid grid-cols-[82px_42px_70px_70px_60px] gap-y-1 text-[11px]">
          <div className="text-slate-400">ID</div>
          <div className="text-slate-400">Team</div>
          <div className="text-slate-400">Pos</div>
          <div className="text-slate-400">Rot</div>
          <div className="text-slate-400">HP</div>
          {playerRows.map((row) => (
            <div key={row.id} className="contents">
              <div className={row.id === currentPlayerId ? 'text-yellow-300' : 'text-slate-200'}>{row.id}</div>
              <div className={row.team === 'red' ? 'text-red-300' : 'text-blue-300'}>{row.team}</div>
              <div className="text-slate-200">{row.x.toFixed(1)}, {row.y.toFixed(1)}</div>
              <div className="text-slate-200">{row.rotation.toFixed(0)}</div>
              <div className="text-slate-100">{row.hp}</div>
            </div>
          ))}
        </div>
      </div>

      <MiniMapHUD
        miniMap={{ ...mergedMiniMap, players: miniMapPlayers }}
        uiSizing={state.uiSizing}
        robotHpById={robotHpById}
        onSelectPlayer={handleMiniMapPlayerSelect}
        onMoveCurrentPlayer={handleMiniMapMoveCurrentPlayer}
      />
    </div>
  );
}
