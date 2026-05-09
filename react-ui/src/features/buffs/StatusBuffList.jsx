import StatusBuffIcon from './StatusBuffIcon';
import { normalizeStatusBuff, shouldShowStatusBuff } from './statusBuffs';

export default function StatusBuffList({
  buffs,
  size = 'md',
  showLabels = false,
  iconOnly = false,
  limit,
  className = '',
}) {
  const items = (Array.isArray(buffs) ? buffs : [])
    .map(normalizeStatusBuff)
    .filter(shouldShowStatusBuff);
  const visibleItems = Number(limit) > 0 ? items.slice(0, Number(limit)) : items;

  if (visibleItems.length === 0) return null;

  return (
    <div className={`status-buff-list status-buff-list--${size} ${className}`}>
      {visibleItems.map((buff) => (
        <StatusBuffIcon
          key={`${buff.key}-${buff.robotId ?? 'global'}-${buff.level ?? 0}`}
          buff={buff}
          displayMode={iconOnly ? 'hidden' : undefined}
          size={size}
          showLabel={showLabels}
        />
      ))}
    </div>
  );
}
