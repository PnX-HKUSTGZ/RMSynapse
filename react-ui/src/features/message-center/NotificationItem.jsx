import { memo } from 'react';

function NotificationItem({ msg, levelConfig, leaveAnimationMs }) {
  const title = String(msg.title || levelConfig.title || '').trim();

  return (
    <div
      className={`
        relative flex w-80 items-stretch overflow-hidden rounded-r-xl
        border-l-4 backdrop-blur-md ${levelConfig.borderClass} ${levelConfig.glowClass} ${levelConfig.bgClass}
        transition-all duration-300 ease-in-out
        ${msg.isLeaving ? 'mb-3 -translate-x-full scale-95 opacity-0' : 'mb-3 translate-x-0 scale-100 opacity-100'}
      `}
      style={{ willChange: 'transform, opacity, margin-bottom' }}
    >
      <div className={`flex w-12 items-center justify-center text-xl ${levelConfig.iconBg} ${levelConfig.extraAnim}`}>
        {levelConfig.icon}
      </div>

      <div className="z-10 flex flex-1 flex-col justify-center px-3 py-2">
        <span className={`text-xs font-black tracking-widest ${levelConfig.colorClass}`}>
          {title}
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
}

export default memo(NotificationItem);
