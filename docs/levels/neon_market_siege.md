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

## 当前空间契约

- 保留原 14 个 Mission Anchor，现有 MissionRuntime / SpawnPlanner / Checkpoint 不需要重写。
- 新增真实碰撞体分组：`mission_geometry`。
- 新增战斗掩体分组：`combat_cover`。
- 新增跨面空间分组：`cross_face_passage`。
- 新增 Boss Arena 分组：`boss_arena`。
- 新增撤离触发分组：`extraction_zone`。
- 新增 headless 测试：`tests/test_mission_level_geometry.gd`。

## 这一阶段还不是最终美术

这次完成的是 **可玩的空间设计 / spatial gameplay pass**：尺度、碰撞、动线、Arena、掩体、室内与跨面结构已落到代码中。后续可以在这个真实空间上继续做模块化建筑资产替换、灯光、美术材质、门禁/闸门、动态事件、Nav/AI 局部路径、Boss 机制和性能分区，而不再回退到 Marker-only blockout。
