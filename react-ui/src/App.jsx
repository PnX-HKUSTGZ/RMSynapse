import { useEffect, useState } from 'react';
import { CenterCombatHUD, MechaHUD, TopCoreLayout } from './HudComponents';
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
    </div>
  );
}
