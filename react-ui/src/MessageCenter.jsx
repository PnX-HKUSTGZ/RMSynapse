import { memo, useEffect, useMemo, useRef, useState } from 'react';
import { DEFAULT_UI_STATE } from './uiState';

function buildMergedConfig(messageCenter) {
  const defaults = DEFAULT_UI_STATE.messageCenter ?? {};
  const incoming = messageCenter ?? {};

  return {
    ...defaults,
    ...incoming,
    levels: { ...(defaults.levels ?? {}), ...(incoming.levels ?? {}) },
    priorityMap: { ...(defaults.priorityMap ?? {}), ...(incoming.priorityMap ?? {}) },
    items: Array.isArray(incoming.items) ? incoming.items : (defaults.items ?? []),
  };
}

function clearTimersById(timersRef, id) {
  const timers = timersRef.current.get(id);
  if (!timers) return;
  clearTimeout(timers.leaveTimer);
  clearTimeout(timers.removeTimer);
  timersRef.current.delete(id);
}

const NotificationItem = memo(function NotificationItem({ msg, levelConfig, leaveAnimationMs }) {
  return (
    <div
      className={`
        relative flex items-stretch w-80 overflow-hidden rounded-r-xl
        border-l-4 backdrop-blur-md ${levelConfig.borderClass} ${levelConfig.glowClass} ${levelConfig.bgClass}
        transition-all duration-300 ease-in-out
        ${msg.isLeaving ? 'opacity-0 -translate-x-full scale-95 mb-3' : 'opacity-100 translate-x-0 scale-100 mb-3'}
      `}
      style={{ willChange: 'transform, opacity, margin-bottom' }}
    >
      <div className={`flex w-12 items-center justify-center text-xl ${levelConfig.iconBg} ${levelConfig.extraAnim}`}>
        {levelConfig.icon}
      </div>

      <div className="z-10 flex flex-1 flex-col justify-center px-3 py-2">
        <span className={`text-xs font-black tracking-widest ${levelConfig.colorClass}`}>
          {levelConfig.title}
        </span>
        <span className="mt-0.5 text-sm font-medium leading-snug text-white drop-shadow-md">
          {msg.text}
        </span>
      </div>

      <div
        className={`absolute bottom-0 left-0 z-20 h-[3px] origin-left ${
          msg.level === 'critical' ? 'bg-red-400' : 'bg-white/70'
        }`}
        style={{
          width: '100%',
          animation: `msg-shrink ${Math.max(leaveAnimationMs, msg.duration)}ms linear forwards`,
          willChange: 'transform',
        }}
      />
    </div>
  );
});

export default function MessageCenter({ messageCenter }) {
  const config = useMemo(() => buildMergedConfig(messageCenter), [messageCenter]);
  const [messages, setMessages] = useState([]);
  const timersRef = useRef(new Map());
  const seenEventsRef = useRef(new Set());
  const activeTagsRef = useRef(new Map());

  useEffect(() => {
    const timers = timersRef.current;
    const activeTags = activeTagsRef.current;
    return () => {
      timers.forEach(({ leaveTimer, removeTimer }) => {
        clearTimeout(leaveTimer);
        clearTimeout(removeTimer);
      });
      timers.clear();
      activeTags.clear();
    };
  }, []);

  useEffect(() => {
    const leaveAnimationMs = Number(config.leaveAnimationMs) > 0 ? Number(config.leaveAnimationMs) : 300;
    const defaultDurationMs = Number(config.defaultDurationMs) > 0 ? Number(config.defaultDurationMs) : 5000;

    const scheduleLifecycle = (id, duration) => {
      clearTimersById(timersRef, id);

      const leaveAt = Math.max(0, duration - leaveAnimationMs);
      const leaveTimer = setTimeout(() => {
        setMessages((prev) => prev.map((msg) => (msg.id === id ? { ...msg, isLeaving: true } : msg)));
      }, leaveAt);

      const removeTimer = setTimeout(() => {
        setMessages((prev) => prev.filter((msg) => msg.id !== id));
        clearTimersById(timersRef, id);

        const activeTags = activeTagsRef.current;
        for (const [tag, taggedId] of activeTags.entries()) {
          if (taggedId === id) {
            activeTags.delete(tag);
          }
        }
      }, duration);

      timersRef.current.set(id, { leaveTimer, removeTimer });
    };

    const incomingItems = Array.isArray(config.items) ? config.items : [];
    incomingItems.forEach((item) => {
      const level = config.levels?.[item?.level] ? item.level : 'normal';
      const duration = Number(item?.duration) > 0 ? Number(item.duration) : defaultDurationMs;
      const text = String(item?.text ?? '').trim();
      if (!text) return;

      const rawTag = typeof item?.tag === 'string' ? item.tag.trim() : '';
      const tag = rawTag || null;

      const timestampFromItem = Number(item?.timestamp);
      const hasTimestamp = timestampFromItem > 0;
      const timestamp = hasTimestamp ? timestampFromItem : Date.now();

      const rawId = item?.id;
      const id = rawId != null ? String(rawId) : `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
      const eventKey = rawId != null
        ? `${id}::${hasTimestamp ? String(timestampFromItem) : 'na'}`
        : `${tag ?? 'untagged'}::${level}::${text}::${hasTimestamp ? String(timestampFromItem) : 'na'}`;

      if (seenEventsRef.current.has(eventKey)) return;
      seenEventsRef.current.add(eventKey);

      if (tag) {
        const activeMessageId = activeTagsRef.current.get(tag);
        if (activeMessageId) {
          setMessages((prev) => prev.map((msg) => {
            if (msg.id !== activeMessageId) return msg;
            return {
              ...msg,
              level,
              text,
              duration,
              isLeaving: false,
              rev: (msg.rev ?? 0) + 1,
            };
          }));
          scheduleLifecycle(activeMessageId, duration);
          return;
        }
      }

      setMessages((prev) => [
        ...prev,
        { id, level, text, duration, timestamp, isLeaving: false, tag, rev: 0 },
      ]);

      if (tag) {
        activeTagsRef.current.set(tag, id);
      }

      scheduleLifecycle(id, duration);
    });
  }, [config.items, config.defaultDurationMs, config.leaveAnimationMs, config.levels]);

  const sortedMessages = useMemo(() => {
    const priorityMap = config.priorityMap ?? {};
    const maxVisible = Number(config.maxVisible) > 0 ? Number(config.maxVisible) : 8;
    const sorted = [...messages].sort((a, b) => {
      const pa = Number(priorityMap[a.level] ?? 99);
      const pb = Number(priorityMap[b.level] ?? 99);
      if (pa !== pb) return pa - pb;
      return a.timestamp - b.timestamp;
    });
    return sorted.slice(0, maxVisible);
  }, [messages, config.priorityMap, config.maxVisible]);

  if (!config.enabled) return null;

  const topPercent = Number(config.topPercent);
  const safeTopPercent = Number.isFinite(topPercent) ? topPercent : 25;
  const safeMinScale = Number(config.minScale) > 0 ? Number(config.minScale) : 0.5;
  const safeMaxScale = Number(config.maxScale) > safeMinScale ? Number(config.maxScale) : 2;
  const rawScale = Number(config.scale);
  const safeScale = Number.isFinite(rawScale)
    ? Math.max(safeMinScale, Math.min(safeMaxScale, rawScale))
    : 1;

  return (
    <>
      <style>{`
        @keyframes msg-shrink {
          from { transform: scaleX(1); }
          to { transform: scaleX(0); }
        }
      `}</style>
      <div
        className="absolute left-6 z-40 flex flex-col pointer-events-none"
        style={{
          top: `${safeTopPercent}%`,
          transform: `scale(${safeScale})`,
          transformOrigin: 'top left',
        }}
      >
        {sortedMessages.map((msg) => {
          const levelConfig = config.levels?.[msg.level] ?? config.levels?.normal;
          if (!levelConfig) return null;
          return (
            <NotificationItem
              key={`${msg.id}-${msg.rev ?? 0}`}
              msg={msg}
              levelConfig={levelConfig}
              leaveAnimationMs={config.leaveAnimationMs}
            />
          );
        })}
      </div>
    </>
  );
}
