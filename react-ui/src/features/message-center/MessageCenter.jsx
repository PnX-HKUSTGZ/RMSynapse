import { useEffect, useMemo, useRef, useState } from 'react';
import { resolveMessageCenterState } from '../../state';
import NotificationItem from './NotificationItem';

function clearTimersById(timersRef, id) {
  const timers = timersRef.current.get(id);
  if (!timers) return;

  clearTimeout(timers.leaveTimer);
  clearTimeout(timers.removeTimer);
  timersRef.current.delete(id);
}

export default function MessageCenter({ messageCenter }) {
  const config = useMemo(() => resolveMessageCenterState(messageCenter), [messageCenter]);
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
      const id = rawId != null
        ? String(rawId)
        : `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
      const eventKey = rawId != null
        ? `${id}::${hasTimestamp ? String(timestampFromItem) : 'na'}`
        : `${tag ?? 'untagged'}::${level}::${text}::${hasTimestamp ? String(timestampFromItem) : 'na'}`;

      if (seenEventsRef.current.has(eventKey)) return;
      seenEventsRef.current.add(eventKey);

      if (tag) {
        const activeMessageId = activeTagsRef.current.get(tag);
        if (activeMessageId) {
          setMessages((prev) => prev.map((msg) => (
            msg.id !== activeMessageId
              ? msg
              : {
                ...msg,
                level,
                title: item?.title,
                category: item?.category,
                text,
                duration,
                isLeaving: false,
                rev: (msg.rev ?? 0) + 1,
              }
          )));
          scheduleLifecycle(activeMessageId, duration);
          return;
        }
      }

      setMessages((prev) => [
        ...prev,
        {
          id,
          level,
          title: item?.title,
          category: item?.category,
          text,
          duration,
          timestamp,
          isLeaving: false,
          tag,
          rev: 0,
        },
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

    return [...messages]
      .sort((a, b) => {
        const leftPriority = Number(priorityMap[a.level] ?? 99);
        const rightPriority = Number(priorityMap[b.level] ?? 99);
        if (leftPriority !== rightPriority) return leftPriority - rightPriority;
        return a.timestamp - b.timestamp;
      })
      .slice(0, maxVisible);
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
    <div
      className="pointer-events-none absolute left-6 z-40 flex flex-col"
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
  );
}
