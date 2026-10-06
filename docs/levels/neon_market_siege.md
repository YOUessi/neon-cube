# Neon Market Siege — 实际关卡空间

本文件记录 Mission 01 从 Marker blockout 进入可玩空间后的关卡结构。正式运行场景为 `scenes/missions/neon_market_siege.tscn`，空间由 `scripts/missions/neon_market_siege_level.gd` 构建；旧的 `neon_market_siege_blockout.tscn` 保留为早期锚点原型。

## 关卡主路线

1. **Arrival Street / 市场入口主街**
   - 玩家从 Neon Market 南侧主街进入。
   - 双侧路缘和 4 组低掩体构成第一段基础射击空间。
   - Encounter：`arrival_ambush`。

2. **Market Hall / 市场建筑与室内段**
   - 真正的三面墙市场大厅、顶部结构、入口和东侧开放出口。
   - 内部布置摊位掩体、遮棚与可攀登台阶。
   - 一条约 2m 高的 Elevated Lane / 猫道提供垂直视线。
   - Encounter：`market_crossfire`。

3. **Seam Gateway / 重力接缝**
   - 从 Neon Market 底面沿东侧通道推进至 +X 面。
   - 护栏、门架和照明明确提示即将发生的重力方向变化。
   - 该区域统一加入 `cross_face_passage` 分组。

4. **Gravity Breach Arena / 东面战斗 Arena**
   - +X 面设置落地区、方形战斗空间和多组高低掩体。
   - 之后通过 Relay Approach 前往跨面 Transit。
   - Encounter：`gravity_breach`。

5. **Trans-Face Transit / 跨面通道**
   - 东面 → 南面 → 西面形成连续的引导通道。
   - 南面用分段平台/霓虹带做方向识别，不依赖 Marker 才能理解路线。
   - 该区为后续更复杂的跨面门、动态重力桥和脚本化遭遇预留接口。

6. **Data Lane / 西面数据街区**
   - Server Rack 阵列同时承担空间分区和战斗掩体。
   - Warden Gate 作为 Boss 前的视觉门槛。
   - Encounter：`data_lane`。

7. **Void Docks Boss Arena**
   - +Z 面独立的圆形视觉 Arena。
   - 四个大型核心柱 + 后侧掩体形成绕柱、转移、拉扯的 Boss 战空间。
   - Encounter：`null_warden`。

8. **Extraction Yard / 撤离区**
   - 返回 Neon Market 后先在 Yard 完成最后清场。
   - 清敌后游戏不会直接结算；正式激活 `ExtractionZone`。
   - 玩家进入撤离信标区域才结束任务。
   - Encounter：`extraction`。

## 与全局城市生成器的关系

`CyberCityBuilder` 仍负责六面的整体城市背景，但现在会针对 Mission 01 的主街、市场大厅、接缝、东面 Arena、西面 Data Lane、南面 Boss Arena 和撤离路线保留净空。这样程序化楼块不会随机堵住正式任务路径。

## Encounter 空间流转

现在战役不再是“上一波结束后，下一波立刻在远处生成”。

- 第一段 `arrival_ambush` 随任务开始直接激活。
- 从 `market_crossfire` 开始，每个后续 Encounter 都有一个实际 `Area3D` 激活体积。
- 当前战斗清空后，任务进入 traversal 状态，HUD 提示玩家前往下一战斗区；此时下一批敌人数量保持为 0。
- 玩家真正进入目标 Arena 后，激活区触发，才生成该 Encounter 的敌人。
- 这使市场大厅、重力接缝、跨面 Transit、Data Lane 和 Boss 入口成为必须经过的游戏空间，而不是背景装饰。
- `extraction` Encounter 进入 Extraction Yard 后才刷最后一组敌人；清场后再单独激活最终 Extraction Beacon，玩家进入信标才结算胜利。

## 作者指定出生点

正式 Mission 优先使用 `NeonMarketSiegeLevel.spawn_points_for()` 提供的作者出生点，而不是围绕 Marker 随机排布：

- Arrival Street：4 个入口伏击点。
- Market Crossfire：5 个摊位/大厅交火点。
- Gravity Breach：4 个东面 Arena 点位。
- Data Lane：5 个数据街区点位。
- Null Warden：Boss 中心 + 3 个随从点位。
- Extraction Yard：4 个撤离战点位。

如果未来某个 Encounter 没有作者点位，`game.gd` 仍会回退到 `EncounterSpawnPlanner`，不会破坏数据驱动兼容性。

## 美术摆件层

在碰撞 blockmesh 之上，关键区域现在会实例化仓库已有的 Quaternius cyberpunk 资产：

- 主街：street light。
- 市场大厅：door、fence、computer terminals。
- 重力接缝 / Gravity Breach：antenna、fence、street light。
- 跨面 Transit：antenna、fence。
- Data Lane / Warden Gate：computer、antenna、door。
- Boss Arena：door、antenna。
- Extraction：street light、fence、antenna beacon。

这些资产只负责视觉层，碰撞与玩法尺度仍由 authored mission geometry 控制，避免第三方模型碰撞影响路线稳定性。

## 当前空间契约

- 保留原 14 个 Mission Anchor，现有 MissionRuntime / SpawnPlanner / Checkpoint 不需要重写。
- 新增真实碰撞体分组：`mission_geometry`。
- 新增战斗掩体分组：`combat_cover`。
- 新增跨面空间分组：`cross_face_passage`。
- 新增 Boss Arena 分组：`boss_arena`。
- 新增撤离触发分组：`extraction_zone`。
- 新增 5 个战斗区触发分组：`encounter_activation_zone`。
- 新增作者指定 Encounter spawn sockets，并保留 SpawnPlanner fallback。
- 新增 headless 测试：`tests/test_mission_level_geometry.gd`。
- 新增整局流转测试：`tests/test_mission_spatial_flow.gd`，验证“清场 → 无敌人旅行 → 进入 Arena → 敌人生成”。
- Authored route 现在带运行时 stall watchdog：敌人持续无进展时会临时屏蔽当前 waypoint 并重选，避免复杂碰撞把 AI 永久卡死。

## 这一阶段还不是最终美术

这次完成的是 **可玩的空间设计 / spatial gameplay pass**：尺度、碰撞、动线、Arena、掩体、室内与跨面结构已落到代码中。后续可以在这个真实空间上继续做模块化建筑资产替换、灯光、美术材质、门禁/闸门、动态事件、Nav/AI 局部路径、Boss 机制和性能分区，而不再回退到 Marker-only blockout。
