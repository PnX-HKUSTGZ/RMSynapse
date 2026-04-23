import {
  Crosshair,
  Cpu,
  Target,
  Zap,
} from 'lucide-react';

export const ROLE_OPTIONS = [
  { role: 'infantry', label: '步兵', icon: Crosshair },
  { role: 'hero', label: '英雄', icon: Zap },
  { role: 'sentry', label: '哨兵', icon: Target },
];

export const DART_TARGET_OPTIONS = [
  { value: '1', label: '1 - 前哨站' },
  { value: '2', label: '2 - 基地固定目标' },
  { value: '3', label: '3 - 基地随机固定目标' },
  { value: '4', label: '4 - 基地随机移动目标' },
  { value: '5', label: '5 - 基地末端移动目标' },
];

export const SENTRY_MODE_OPTIONS = [
  { value: 'auto', label: '自动', icon: Cpu },
  { value: 'semi', label: '半自动', icon: Target },
];
