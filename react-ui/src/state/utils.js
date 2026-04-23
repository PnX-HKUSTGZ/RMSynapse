export function isPlainObject(value) {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

export function deepMerge(base, patch) {
  if (!isPlainObject(base) || !isPlainObject(patch)) {
    return patch;
  }

  const result = { ...base };
  for (const [key, value] of Object.entries(patch)) {
    if (value == null) continue;

    const prev = base[key];
    if (isPlainObject(prev) && isPlainObject(value)) {
      result[key] = deepMerge(prev, value);
      continue;
    }

    result[key] = value;
  }

  return result;
}

export function toPercent(value, max) {
  if (!max || max <= 0) return 0;
  return Math.max(0, Math.min(100, (value / max) * 100));
}

export function toFiniteNumber(value, fallback = 0) {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : fallback;
}

export function toNonNegativeInt(value, fallback = 0) {
  return Math.max(0, Math.trunc(toFiniteNumber(value, fallback)));
}

export function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}
