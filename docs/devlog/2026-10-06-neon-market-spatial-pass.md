# 2026-10-06 — Neon Market Siege Spatial Gameplay Pass

## 目标

把 Mission 01 从 Marker-only blockout 推进为真实可玩的关卡空间，并让空间真正决定 Encounter 流程。

## 已完成

### 1. 正式关卡场景

新增：

- `scenes/missions/neon_market_siege.tscn`
- `scripts/missions/neon_market_siege_level.gd`

保留原 14 个 Mission Anchor 作为任务系统契约，但不再依赖 Marker 表达关卡。

### 2. 实际空间

已制作：

- Arrival Street
- Market Hall
- 室内 Crossfire Arena
- Elevated Lane / 猫道
- Gravity Seam Gateway
- Gravity Breach Arena
- Trans-Face Transit
- Data Lane
- Warden Gate
- Void Docks Boss Arena
- Extraction Yard
- Extraction Beacon

### 3. 真实碰撞与战斗空间

新增分组：

- `mission_geometry`
- `combat_cover`
- `cross_face_passage`
- `boss_arena`
- `encounter_activation_zone`
- `extraction_zone`

### 4. Encounter 改为由空间触发

旧行为：

```text
清完当前战 → 下一波立刻在远处生成
```

新行为：

```text
清完当前战
→ HUD 提示前往下一战区
→ 旅行阶段保持 0 敌人
→ 玩家进入对应 Arena
→ Area3D 触发
→ 生成对应 Encounter
```

这样 Market Hall、Gravity Seam、跨面 Transit、Data Lane 等空间成为必须经过的实际游戏内容。

### 5. 作者指定敌人出生点

每个 Encounter 优先使用关卡作者定义的 spawn sockets：

- Arrival Ambush：4
- Market Crossfire：5
- Gravity Breach：4
- Data Lane：5
- Null Warden：4
- Extraction：4

若某个 Encounter 没有 authored spawn，则回退 `EncounterSpawnPlanner`。

### 6. Extraction

最后一波清空后不再立即 Victory。

现在流程：

```text
进入 Extraction Yard
→ 清理最后一组敌人
→ Extraction Beacon 激活
→ 玩家进入 Beacon
→ Mission Complete
```

### 7. 美术摆件

利用已有 Quaternius Cyberpunk CC0 资产固定布置：

- street_light
- computer
- fence
- door
- antenna

玩法碰撞仍由关卡 authored geometry 控制，第三方资产只负责视觉。

### 8. 程序化城市净空

`scripts/city_builder.gd` 针对 Mission 01 主路径保留程序化建筑净空，避免背景城市楼块堵住正式关卡。

## 测试

### 项目解析与启动

Tang 上 Godot 4.3：

- resource import：PASS
- 全部 scripts/tests check-only：PASS
- main scene headless startup：PASS
- `Project validation: PASS`

### Spatial geometry test

`tests/test_mission_level_geometry.gd`

验证：

- 14 个 Anchor 保留。
- 主要关卡区域存在。
- 真实碰撞数量。
- 掩体数量。
- 跨面通道。
- Boss Arena。
- 5 个 Encounter activation zones。
- authored spawn sockets。
- spawn face 正确。
- Extraction trigger。

结果：全部 PASS。

### Spatial flow test

`tests/test_mission_spatial_flow.gd`

实际启动正式 `main.tscn` 验证：

1. Arrival 生成 4 敌人。
2. 清场。
3. Mission Runtime 前进到 Market Crossfire。
4. 旅行阶段保持 0 敌人。
5. Market Crossfire activation zone 开启。
6. 玩家进入战区。
7. 才生成 5 个敌人。
8. 敌人位于 Neon Market authored face。

结果：PASS，且修复了 Area3D signal 内同步修改 monitoring 导致的 Godot ERROR。

## 环境决策

从本阶段开始：

- 不再使用 Tang 开发或测试 Neon Cube。
- GitHub = 开发现场 + 过程记录 + 版本管理 + 唯一事实源。
- Mac = Godot 实际运行、视觉检查、试玩和测试环境。

Tang 上本项目本地副本已经删除。
