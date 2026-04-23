# RM Synapse React UI

这是一个基于 `Vite + React 19 + Tailwind CSS 4` 的 RoboMaster HUD / 地图调试前端。项目保留了两个入口页面：

- `index.html`：主 HUD 页面，展示顶部战况、中心战斗 HUD、机甲状态、小地图、消息中心和复活提示。
- `map.html`：地图调试页面，侧重小地图与控制面板联调。

## 启动与构建

```bash
npm install
npm run dev
npm run build
npm run preview
npm run lint
```

开发环境下：

- 主页面通常从 `/index.html` 打开。
- 地图调试页通常从 `/map.html` 打开。

生产构建会同时输出两套入口文件到 `dist/`。

## 技术栈

- `React 19`
- `Vite 7`
- `Tailwind CSS 4`
- `lucide-react`

## 目录结构

```text
src/
  bridge/        Godot 与浏览器全局桥接
  features/      按功能拆分的 UI 组件
  hooks/         页面级状态接入 hooks
  state/         默认状态、merge、selector、proto 映射
  styles/        HUD 共用样式
  App.jsx        主 HUD 页面装配
  MapDebugApp.jsx 地图调试页装配
  main.jsx
  main_map.jsx
```

目录职责说明：

- `src/state/defaults.js`
  维护默认 UI 状态，是所有 fallback 的单一来源。
- `src/state/proto.js`
  负责把 Godot / proto 风格输入整理成前端 UI patch。
- `src/state/controls.js`
  负责控制面板配置的深层 merge。
- `src/state/mapDebug.js`
  负责地图调试页的 patch 筛选、节流合并与应用。
- `src/state/selectors.js`
  提供 UI 安全读取函数，避免组件内部到处手写默认值拼接。
- `src/hooks/useHudState.js`
  主 HUD 页对 `window.godotPush` 的接入。
- `src/hooks/useMapDebugState.js`
  地图调试页对 `window.godotMapPush` / `window.godotPush` 的接入。

## 数据入口与桥接方式

项目保留以下全局接口，供 Godot 或浏览器控制台直接调用：

- `window.godotPush(payload)`
- `window.godotMapPush(payload)`

其中 `payload` 支持两种形式：

1. JS 对象
2. JSON 字符串

桥接流程如下：

1. `bridge/godot.js` 负责解析字符串 payload。
2. `state/proto.js` 中的 `normalizeIncomingData()` 负责把 proto 风格字段映射成 UI 可消费的数据结构。
3. 主 HUD 页通过 `deepMerge` 合并 patch。
4. 地图调试页会先用 `pickMapPatch()` 过滤与地图相关的数据，再通过 `requestAnimationFrame` 做批量更新。

## 页面说明

### 主 HUD 页面

由 [App.jsx](/Users/sato/Projects/RM/RMSynapse/react-ui/src/App.jsx) 装配，主要 feature 包括：

- `top-core`：顶部比分、基地/前哨站状态、机器人条、科技/雷达等级
- `center-hud`：中心准星、热量、弹量、攻击/防御 Buff 提示
- `mecha-hud`：机甲主状态 HUD
- `mini-map`：小地图
- `message-center`：战术消息中心
- `revive`：死亡复活提示
- `map-controls`：控制面板

### 地图调试页面

由 [MapDebugApp.jsx](/Users/sato/Projects/RM/RMSynapse/react-ui/src/MapDebugApp.jsx) 装配，目标是：

- 单独联调小地图与控制面板
- 在不渲染整套 HUD 的情况下验证位置与地图 patch
- 用 `requestAnimationFrame` 节流高频地图更新

## 默认状态与调试数据

默认展示数据集中定义在 [defaults.js](/Users/sato/Projects/RM/RMSynapse/react-ui/src/state/defaults.js) 的 `DEFAULT_UI_STATE` 中。  
当 Godot 还没有推送任何数据时，页面会使用这里的默认状态渲染。

可直接在浏览器控制台中测试，例如：

```js
window.godotPush({
  GameStatus: {
    current_round: 2,
    total_rounds: 5,
    stage_countdown_sec: 318,
    red_score: 120,
    blue_score: 95,
  },
});

window.godotMapPush({
  miniMap: {
    players: [
      { id: 'red-1', team: 'red', number: 1, x: 20, y: 20, rotation: 90 },
    ],
  },
});
```

## 常见维护方式

### 1. 新增一个 HUD 模块

建议做法：

1. 在 `src/features/` 下新增 feature 目录。
2. 需要默认值时，先补到 `DEFAULT_UI_STATE`。
3. 如果 Godot 会推送对应字段，再到 `state/proto.js` 中补映射。
4. 页面层只负责装配，不要在 `App.jsx` / `MapDebugApp.jsx` 内部堆大段数据清洗逻辑。

### 2. 扩展默认状态

统一修改：

- `src/state/defaults.js`

如果该字段需要安全 fallback 或派生读取，再补：

- `src/state/selectors.js`

### 3. 接入新的协议字段

统一检查这几个位置：

1. `src/state/proto.js`
2. `src/state/defaults.js`
3. 相关 feature 组件 props

原则：

- proto 到 UI 的映射只放在 `state/proto.js`
- 组件只消费已经整理好的 UI 数据

### 4. 调整控制面板配置

优先修改：

- `src/state/controls.js`
- `src/features/map-controls/`

这样可以保证默认值、动态 patch 和 UI 展示逻辑保持一致。

## 样式组织

- `src/index.css` 负责 Tailwind 和全局入口样式。
- `src/styles/hud.css` 负责 HUD 共用字体、裁切类、玻璃态类、动画等。

组件内部不再写 `<style>`，避免样式定义散落在 render 中。

## 当前开发约束

- 不引入额外状态管理库。
- 不改 Godot 侧接口名与输入方式。
- 主页面与地图调试页面继续共存。
- 优先把默认值、协议映射、视图组件职责分开。
