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


## 2026-10-06 追加：Combat Lockdown

### 为什么做

只有 Encounter activation zone 还不够。玩家进入战斗区后如果仍能直接穿过 Arena，空间仍然缺少“进入战斗 → 被锁定 → 清场 → 放行”的节奏。

### 实现

新增 5 个 authored combat lockdown gates：

- Market Crossfire
- Gravity Breach
- Data Lane
- Null Warden
- Extraction

关卡接口：

- `set_encounter_lockdown(encounter_id, active)`
- `is_encounter_locked(encounter_id)`

运行逻辑：

```text
进入 Arena
→ activation zone 触发
→ lockdown gate 关闭
→ authored enemies 生成
→ 战斗
→ hostiles = 0
→ lockdown gate 开启
→ mission 进入下一段 traversal
```

Extraction 的 lockdown 解除后才允许继续前往最终 Beacon。

### 测试补充

`test_mission_level_geometry.gd` 新增：

- 5 个 lockdown gate 数量检查。
- 初始状态为 open。
- 可以关闭。
- 可以重新打开。

`test_mission_spatial_flow.gd` 新增：

- Market Crossfire 激活后 lockdown 为 closed。
- 清场后 lockdown 自动 reopen。

### Mac 测试环境

仓库的 `scripts/bootstrap_godot.sh` 已增加 macOS universal Godot 4.3 bootstrap。

开发原则保持不变：

- GitHub 直接开发。
- Mac 只拉取提交并做真机 Godot 测试。
- 不在 Mac 上维护独立开发版本。


## 2026-10-06 追加：World Navigation + Null Warden Arena Mechanics

### 世界内导航

为 traversal 阶段增加 5 个 world-space objective beacons，对应：

- Market Crossfire
- Gravity Breach
- Data Lane
- Null Warden
- Extraction

状态规则：

```text
当前战斗清场
→ 下一 Encounter activation zone armed
→ 对应 world beacon 显示
→ 玩家沿真实关卡空间移动
→ 进入 Arena
→ beacon 清除
→ lockdown 关闭
→ Encounter 开始
```

关卡接口：

- `set_navigation_target(encounter_id)`
- `current_navigation_target()`

HUD 继续显示文字目标，世界 beacon 负责空间方向感。

### Null Warden Arena Phase Hazards

Boss 不再只有生命比例 → 移速/攻速变化。

Boss Arena 现有 4 个实体危险地面区：

- Phase 1：0 个危险区，玩家熟悉 Arena。
- Phase 2（Boss HP <= 60%）：左右两块危险区启动。
- Phase 3（Boss HP <= 30%）：4 块危险区全部启动。

伤害规则：

- Phase 2：每次脉冲造成 6 点伤害（遵循护盾优先吸收规则）。
- Phase 3：每次脉冲造成 10 点伤害（遵循护盾优先吸收规则）。
- 脉冲间隔：0.75s。
- Boss 战结束后自动恢复 Phase 1 并关闭全部危险区。

`game.gd` 监听现有 Boss `health_changed` 信号，将 phase 同步给关卡，同时给 HUD 中央信息：

- `NULL WARDEN // PHASE 2 // TWIN HAZARDS ONLINE`
- `NULL WARDEN // PHASE 3 // ARENA OVERLOAD`

### 新增测试

`test_mission_level_geometry.gd`

- 5 个 navigation beacons。
- 4 个 boss hazard pads。
- navigation target 生命周期。
- Phase 1 / 2 / 3 激活数量：0 / 2 / 4。

`test_mission_spatial_flow.gd`

- traversal 时目标 beacon 指向 Market Crossfire。
- 进入 Arena 后 beacon 被清除。

`test_boss_arena_hazards.gd`

- Phase 2 实际站入危险区会受到 6 点伤害。
- Phase 3 实际站入危险区会受到 10 点伤害。
- Phase 1 不造成 hazard damage。

这一步的目标是让 Boss Phase 真正改变玩家的走位和掩体选择，而不是只改变敌人参数。


## 2026-10-06 追加：Authored Arena Routing

### 问题

实际关卡加入墙体、摊位、Server Rack、Boss Pylon 后，原有 Enemy movement 主要依赖：

- `CubeSurfaceNavigator` 的跨面方向。
- 短距离 ray obstacle avoidance。
- 直接朝玩家移动。

这对开阔面足够，但在 Market Hall / Data Lane 等密集空间中容易出现：

- 卡墙。
- 多个敌人扎堆。
- 只会在障碍边缘左右试探。
- 无法利用关卡作者预留的通路。

### 实现

每个 Encounter 新增 authored route waypoint network：

- Arrival Ambush：4 点。
- Market Crossfire：6 点。
- Gravity Breach：5 点。
- Data Lane：6 点。
- Null Warden：6 点。
- Extraction：5 点。

关卡提供：

- `route_points_for(encounter_id)`

生成 Encounter 时，`game.gd` 会把对应 route network 传给每个 `NeonEnemy`。

### Enemy routing 逻辑

同一 cube face 上：

```text
如果直接看到玩家
→ 清除 waypoint
→ 直接追击 / 攻击

如果看不到玩家，并且存在 authored routes
→ raycast 筛选当前可直达 waypoint
→ score = 0.32 × 自身到 waypoint 距离 + waypoint 到玩家距离
→ 选择最低分 waypoint
→ 先移动到 waypoint
→ 到达后重新选点
```

跨面追击仍使用 `CubeSurfaceNavigator`，因此 authored local routing 不会破坏六面重力导航。

### 回归测试

- 几何测试验证每个主要 Arena 的 route waypoint 数量。
- 验证 route waypoint 位于正确 cube face。
- Mission spatial flow 验证实际生成的 Market Crossfire 敌人收到 6 个 authored route points。


## 2026-10-06 追加：Tactical Combat Slots

### 问题

Authored waypoint 解决了“看不到玩家时如何绕过关卡障碍”，但敌人重新获得 LOS 后，仍然可能全部朝玩家同一坐标推进，导致：

- grunt / runner 扎堆。
- 多个敌人互相挤压。
- Arena 横向空间利用不足。
- 玩家被单点包围，而不是受到多角度压力。

### 实现

每个 Story Encounter 生成敌人时，会按该 Encounter 敌人数量分配唯一 tactical slot：

- `slot_index`
- `slot_count`

同一面并且已经重新看到玩家时，非 Boss 敌人会以玩家为中心选择环形战术位置。

默认半径：

- grunt / 普通 advance：4.0m
- runner：2.2m
- sniper：7.5m
- tank：5.5m
- boss：不使用 slot，继续使用 phase-driven movement

因此：

```text
无 LOS
→ authored waypoint routing

恢复 LOS
→ 清除 route waypoint
→ 移向自己的 tactical slot
→ EnemyBrain 再根据 rush / keep_distance / anchor 行为决策
```

### 回归测试

Mission spatial flow 现在验证：

- Market Crossfire 5 个敌人都收到 6 个 authored route waypoints。
- 每个敌人都知道 slot_count = 5。
- 5 个敌人的 slot_index 唯一，不会重复占同一个战术槽。


## 2026-10-06 追加：Enemy Attack Telegraphs

### 问题

此前敌人攻击只要满足：

```text
距离 <= attack_range
AND LOS = true
AND cooldown = 0
```

就会直接调用 `player.take_damage()`。

这导致玩家看不到攻击来源，也没有真正的躲避窗口。

### 数据化攻击前摇

`EnemyDefinition` 新增：

- `attack_windup`
- `attack_fx_color`

当前数据：

- grunt：0.08s，青色。
- runner：0.06s，粉色。
- sniper：0.55s，蓝色。
- tank：0.22s，橙色。
- Null Warden：0.14s，紫色。

### Attack Runtime

新增：

`scripts/ai/enemy_attack_runtime.gd`

状态：

```text
IDLE
→ begin(windup)
→ PENDING
→ tick(delta)
→ windup expires
→ FIRE once
→ IDLE
```

支持 cancel，避免死亡/中断后残留攻击。

### 实际攻击流程

```text
满足射程 + LOS
→ 开始 attack windup
→ 显示低能量 telegraph beam
→ windup 结束
→ 再次检查 cube face / range / LOS
→ 如果玩家仍暴露：结算伤害 + 高能量 tracer
→ 如果玩家已经躲到掩体后：本次攻击 miss
```

因此 sniper 的 0.55s 前摇现在是真正可利用的躲避窗口。

### 测试

新增 `tests/test_enemy_attack_runtime.gd`：

- runtime 初始 idle。
- begin 后进入 pending。
- partial tick 不会提前 fire。
- windup 到期只 fire 一次。
- cancel 清除 pending。
- sniper windup 长于 grunt/tank。
- 各 archetype 的 attack cadence / FX 数据保持区分。

视觉 beam 在 scripted capture 没有 `current_scene` 时会回退挂载到 SceneTree root，避免 CI screenshot 场景出现空引用。


## 2026-10-06 追加：CI Screenshot Readability Pass

### 依据

通过 GitHub Actions 的 `neon-cube-visual-smoke` artifact 检查实际渲染帧后，发现：

- 常驻城市 neon grid / window strip 过曝。
- 大面积路面和边缘被青/黄/粉高亮吞没，空间层次不足。
- Mission authored blockout 也过于发光。
- 顶部 Mission message 宽度过大，与右侧 Score / Objective 区域产生视觉冲突。
- Objective 单行文字过长，容易跑出安全区。

### 世界视觉调整

降低“常驻背景信息”的 emission：

- 建筑 neon edge：8.0 → 3.8。
- 天线：8.5 → 4.0。
- window strip：6.2 → 2.8。
- city grid / road grid：6.4 → 2.6。
- Mission 常驻碰撞块体：2.4 → 1.35。
- Mission 非碰撞视觉块：1.6 → 0.75。

保持高亮，不降低：

- Combat Lockdown。
- Navigation Beacon。
- Boss Hazard。
- Attack Telegraph / Tracer。

原则：**环境负责读空间，玩法信号负责发光。**

### HUD Safe Zone 调整

- 右上新增独立半透明信息板。
- Score 右对齐。
- Objective 改为 2 行显示。
- `ADVANCE TO` / `REACH EXTRACTION` 改为两行信息结构。
- Mission message 从 30px 降到 22px。
- 中央提示宽度 600 → 420，避免与左右 HUD 重叠。
- 增加 outline，提高深色/霓虹背景下的文字可读性。

下一次 GitHub visual smoke artifact 用于确认这轮改动是否真的改善画面，而不是只根据代码猜测。


## 2026-10-06 追加：Encounter Reinforcement Pacing

### 问题

此前玩家进入 Arena 后，整个 Encounter 的敌人一次性全部生成。即使空间、路线、锁门已经完成，战斗仍然是单段压力，没有明显节拍。

### 数据结构

`EncounterDefinition` 新增：

- `spawn_batch_sizes`
- `reinforcement_trigger_remaining`
- `reinforcement_delay`

并加入校验：

- batch size 必须为正数。
- 所有 batch size 总和必须等于 `enemy_kinds.size()`。
- trigger / delay 不允许负数。

### Mission 01 当前配置

- Arrival Ambush：`[4]`
- Market Crossfire：`[3, 2]`，剩 1 人时触发，0.7s 后增援。
- Gravity Breach：`[2, 2]`，剩 1 人时触发，0.65s 后增援。
- Data Lane：`[3, 2]`，剩 1 人时触发，0.8s 后增援。
- Null Warden：`[4]`，保持完整 Boss 开场阵容。
- Extraction：`[2, 2]`，首批清空后 0.65s 增援。

### 运行状态

Story encounter 现在维护：

- 完整 enemy plan。
- authored spawn positions。
- authored route points。
- batch sizes。
- 当前 batch index。
- 已生成 enemy index。
- reinforcement scheduled 状态。

运行流程：

```text
进入 Arena
→ 生成 Batch 1
→ Arena lockdown 保持关闭
→ alive_enemies <= reinforcement_trigger_remaining
→ REINFORCEMENTS // INBOUND
→ reinforcement_delay
→ 生成下一 Batch
→ 如果仍有 batch，继续
→ 所有 batch 已生成且 alive_enemies = 0
→ Encounter 才真正完成
→ lockdown 打开
```

### HUD

多批次 Encounter 会显示：

`HOSTILES XX // BATCH N/M`

增援倒计时时显示：

`HOSTILES XX // INBOUND`

### 回归

`test_mission_runtime.gd`

验证 Mission 01 每个 Encounter 的 batch 数据。

`test_mission_spatial_flow.gd`

实际验证 Market Crossfire：

1. 进入 Arena 只生成 3 人。
2. 3 人仍使用总 Encounter 的 5 个 tactical slot 体系。
3. 击败 2 人后 alive = 1。
4. 不会误判清场，lockdown 仍关闭。
5. 0.7s 后生成 2 个 reinforcement。
6. reinforcement 使用剩余 tactical slot 3 / 4。
7. 最后一批全部清空后才 reopen Arena。


## 2026-10-06 追加：Reinforcement Spawn Telegraph

### 问题

分批增援已经解决了 Encounter 的节奏，但第二批敌人如果直接在 spawn socket 上出现，仍然会产生明显“刷怪感”。

### 实现

`NeonMarketSiegeLevel` 新增 world-space reinforcement warning：

- 每个 pending spawn socket 显示 Landing Ring。
- 同时显示竖直 Ingress Beam。
- 预警持续时间与该 Encounter 的 `reinforcement_delay` 一致。
- 到点后 warning 自动清理，随后敌人生成。

Headless 环境不创建 Mesh，但仍记录：

- `encounter_id`
- `warning count`

因此测试与真实渲染使用同一套运行状态。

### 绑定真实 spawn 位置

预警不是重新随机计算位置，而是直接读取 Game 已准备好的 `_encounter_positions`：

```text
当前已生成数量 = N
下一 batch size = K
→ warning positions = encounter_positions[N : N + K]
→ delay
→ 同一组 positions 实际生成敌人
```

所以玩家看到的预警点就是下一批真正的入场位置。

### 回归

Market Crossfire 测试新增：

- 剩 1 人触发 reinforcement 后，warning encounter = market_crossfire。
- warning count = 2。
- batch 到达后 warning count = 0。


## 2026-10-06 追加：Data Lane Destructible Objectives

### 目标

让 Mission 01 不再是连续六段“清空敌人即可”，开始引入不同 Arena 的局部目标。

### Data Lane

Data Lane 现在拥有两个可摧毁中继核心：

- `relay_a`
- `relay_b`

Mission 数据：

- `objective_node_count = 2`
- objective text 改为 `Destroy the data relay locks.`

### MissionObjectiveNode

新增：

`scripts/missions/mission_objective_node.gd`

节点行为：

- 继承 `StaticBody3D`，可被玩家现有 hitscan 武器直接命中。
- 未激活时伤害无效，避免玩家提前打掉未来目标。
- 激活后拥有独立 health。
- health <= 0 后隐藏 visual、关闭 collision，并发出 destroyed signal。
- 支持 reset，重新开始 Run 时恢复。

### Data Lane 完成条件

旧逻辑：

```text
alive_enemies = 0
→ Encounter complete
```

新逻辑：

```text
所有 reinforcement batch 已结束
AND alive_enemies = 0
AND relay_a destroyed
AND relay_b destroyed
→ Encounter complete
```

如果敌人全部死亡但仍有 Relay：

- Arena lockdown 保持关闭。
- MissionRuntime 不推进。
- HUD 显示剩余 Relay 数量。

### HUD

Data Lane 会显示：

`RELAYS XX // HOSTILES XX // BATCH N/M`

增援倒计时则显示：

`RELAYS XX LEFT // INBOUND`

### 回归

新增 `tests/test_data_lane_objectives.gd`：

1. 两个 relay objective 必须存在。
2. 未激活核心无法提前摧毁。
3. 激活后可以接受武器兼容 damage。
4. 敌人 = 0 但仍剩 1 个 Relay 时，不推进 Encounter。
5. Data Lane lockdown 保持关闭。
6. 最后一个 Relay 摧毁后，MissionRuntime 才推进到 Null Warden。
7. Data Lane lockdown 同时解除。

同时：

- Mission runtime 测试断言 `objective_node_count = 2`。
- Geometry 测试断言实际存在两个 `mission_objective_node`。


## 2026-10-06 追加：Gravity Breach Continuous Hold Objective

### 目标

让 Gravity Breach 与 Data Lane 形成不同任务行为：

- Data Lane：摧毁两个 relay core。
- Gravity Breach：进入控制区并连续稳定 uplink。

### Mission 数据

Gravity Breach：

- `hold_zone_seconds = 4.0`
- objective text：`Stabilize the breach control uplink.`

### Hold Zone

东面 Gravity Breach Arena 新增一个 authored `Area3D`：

`Geometry/HoldZones/GravityBreachHold`

- 半径 3m。
- 激活时显示低高度能量圆区。
- 只在当前 Encounter 激活。
- Headless 下保留完整 occupancy 状态。

### 运行规则

```text
进入 Gravity Breach
→ Hold Zone 激活
→ 玩家进入控制区
→ hold_progress 连续累计
→ 玩家离开
→ hold_progress 立即归零
→ 重新进入后从 0 开始

hold_progress >= 4s
AND 所有 reinforcement batch 已完成
AND alive_enemies = 0
→ Encounter complete
```

所以“提前清光敌人”也不能跳过 uplink 任务。

### HUD

Gravity Breach 显示：

`UPLINK 2.3/4.0s // HOSTILES XX // BATCH N/M`

增援阶段：

`UPLINK X.X/4.0s // INBOUND`

### 回归

新增 `tests/test_gravity_breach_hold_objective.gd`：

1. 玩家站在区外不累计。
2. 即使敌人 = 0，也不会提前完成。
3. 进入控制区后连续累计。
4. 中途离开后进度归零。
5. 重新进入并连续站满 4 秒后才推进到 Data Lane。
6. Arena lockdown 同时解除。

Mission 与 Geometry 测试分别断言：

- `hold_zone_seconds = 4.0`
- 全关卡正好存在 1 个 `mission_hold_zone`


## 2026-10-06 追加：Continuous Extraction Hold

### 问题

此前最后一个 Encounter 清场后：

```text
Extraction Beacon active
→ 玩家一进入 Area3D
→ 立即 Victory
```

撤离缺少最后的紧张感，也没有“守住撤离点”的语义。

### Mission 数据

Extraction：

- `extraction_hold_seconds = 3.0`

### 新流程

```text
最终 reinforcement 清空
→ Extraction Beacon 激活
→ 玩家进入撤离区
→ extraction_progress 连续累计
→ 中途离开
→ progress 归零
→ 连续保持 3 秒
→ MissionRuntime complete
→ Victory
```

### Beacon Area

关卡不再在 `body_entered` 内直接发胜利信号，而只维护：

- armed
- occupied

Game 负责倒计时与 Mission 完成，避免把任务状态机塞进场景触发器。

### HUD

撤离阶段：

`HOLD EXTRACTION`
`EXTRACT X.X/3.0s`

### 回归

新增 `tests/test_extraction_hold.gd`：

1. 最后一战清空后不立即 Victory。
2. Beacon trigger 激活。
3. 站在区外 progress = 0。
4. 进区 1.5 秒仍不完成。
5. 离开后 progress 清零。
6. 重新进入并连续保持 3 秒。
7. GameState = VICTORY。
8. MissionRuntime = COMPLETED。


## 2026-10-06 追加：Dark Surface + Emissive Trim Art Pass

### 依据

最新 GitHub visual smoke 显示玩法/HUD 已经稳定，但 Mission 空间仍然存在明显 blockout 感：

- 路面、墙、掩体整块带 emission。
- 青 / 粉 / 黄大面积铺满画面。
- 建筑和道路缺少真实的暗部。
- 城市轮廓虽然清楚，但整体被高环境光洗平。

### 新视觉规则

从本阶段开始：

```text
结构主体 = 暗色金属 / 沥青
玩法导向 = 细 emissive trim
任务信号 = 高亮
局部空间 = 少量 OmniLight
全局环境 = 低环境光夜景
```

### Mission Geometry

普通 authored box 的 emission：

- collidable：1.35 → 0.22
- visual-only：0.75 → 0.10

碰撞、尺寸、位置全部不变。

新增 `mission_visual_trim`：

- Arrival Street 双车道灯带 + stop line
- Market Hall center/cross guide
- Gravity Breach 双轴控制线
- Data Lane spine/divider
- Extraction route guide

Trim 仍维持较高 emission（4.8），只承担方向和轮廓信息。

### Local Lighting

新增无阴影、有限范围的 authored OmniLight：

- Arrival Street ×2
- Market Hall ×2
- Gravity Breach ×1
- Data Lane ×2
- Boss Arena ×2
- Extraction Route ×1

这些灯只负责局部体块塑形，不参与 gameplay collision。

### Global Night Lighting

`CyberCityBuilder` 环境：

- ambient energy：1.70 → 0.95
- ambient color 更暗、更偏蓝紫
- key light：1.25 → 0.92
- fill light：0.65 → 0.34

目标：保留可玩亮度，但让局部灯、敌人 telegraph、lockdown、beacon、hazard 成为真正的视觉焦点。

### 不降低亮度的信号

以下仍维持高亮：

- Combat Lockdown
- Navigation Beacon
- Boss Hazard
- Enemy Attack Telegraph / Tracer
- Reinforcement Ingress Warning
- Extraction Beacon

下一次 CI visual smoke 用于判断这次调整是否真正减少“整屏纯霓虹”。


## 2026-10-06 追加：Neon Market Identity Pass

### Screenshot 复核

Dark Surface + Emissive Trim 之后的 CI 实际截图确认：

- 大面积纯青地面已经消失。
- 道路主体变暗，车道线和玩法信息更清楚。
- HUD 顶部安全区正常。
- 新问题变成：两侧建筑仍偏黑盒，Arrival Street 缺少“市场”识别度。

### Arrival Street 市场化

新增 6 个 visual-only 摊位：

- NOODLES // 24H
- SYNTH TEA
- NIGHT GRILL
- BYTE MART
- AUGMENT REPAIR
- HOT POT // B7

每个摊位包含：

- 暗色 Counter。
- 薄 Canopy。
- 两根发光立柱。
- 独立 Lightbox。
- Label3D 店招。

不增加 collision，不改变 AI / Player 路径。

### 跨街招牌

新增：

- `NEON MARKET // NIGHT BAZAAR`
- `SUBLEVEL 07 // OPEN ALL NIGHT`

结构为暗色 backing + 两侧 emissive edge + 文字，不再依赖整面霓虹墙表达区域身份。

### Neon Market 建筑立面

只对 `neon_market` district：

- 建筑 base 稍微提亮，保持夜景但不再纯黑。
- 每三层中的一层 window strip 改为暖橙色。
- 青 / 粉仍作为主要区域色，但加入暖色生活感。

其它五个 district 保持原调色，避免六面最终全部同质化。

下一轮 CI screenshot 用于检查：

1. 悬挂招牌朝向是否正确。
2. 两侧 kiosk 是否足够可见但不遮挡战斗。
3. 暖色窗口是否改善层次。


## 2026-10-06 追加：Market Interior Dressing + Mission Event Audio

### Market Hall Interior

在不增加碰撞复杂度的前提下，Market Hall 增加：

- 3 条 ceiling emissive strip。
- 3 块悬挂 aisle panel：
  - FOOD // A1
  - TECH // B4
  - EXIT // EAST
- Market signage 全部改为 billboard，保证从 gameplay camera 可读。
- 跨街 signboard 背板降亮，只保留边框和文字高亮。

### Combat Cover Dressing

所有 `combat_cover` 自动附加 visual-only：

- ArmorPlate。
- CoverBand。
- 两个 bolt / status light。

碰撞仍使用原始简单 BoxShape3D，不增加 AI 物理复杂度。

### Mission Event Audio

`NeonAudio` 新增纯程序生成事件提示音：

- `play_lockdown`
- `play_reinforcement`
- `play_objective_destroyed`
- `play_uplink_complete`
- `play_boss_phase`
- `play_extraction_ready`

所有声音由短 tone sequence 构成，不引入外部音频资产。

### Gameplay 绑定

- 进入 Arena / lockdown 关闭 → Lockdown cue。
- reinforcement scheduled → Inbound cue。
- Data Relay 摧毁 → Objective Destroyed cue。
- Gravity Breach hold 达到 4s → Uplink Complete cue。
- Null Warden Phase 2/3 → Boss Phase cue。
- 最终战清场、Extraction Beacon 激活 → Extraction Ready cue。

Headless 模式下所有声音自动静音，但方法仍可安全调用。

### 测试

新增 `tests/test_mission_audio_events.gd`：

- 验证所有 mission audio 方法存在。
- 验证 headless 下调用不会产生 ERROR。


## 2026-10-07 追加：World Objective Feedback + Boss Hazard Telegraph

### Relay World Status

Data Lane Relay 目标现在不再只是发光方块。

每个 Relay 新增：

- BaseRing。
- Billboard StatusLabel。
- 未激活：`RELAY A/B // LOCKED`。
- 激活：实时显示完整度百分比。
- 被击中：短暂 emission boost。
- health 越低，核心视觉纵向强度越弱。
- 摧毁：`OFFLINE` 状态。

Headless 回归验证 partial damage 会降低 `health_ratio()`，但不会误判摧毁；destroyed 后 ratio = 0。

### Gravity Breach World Progress

Hold Zone 新增世界空间进度反馈：

- 中央 ProgressCore。
- `UPLINK 000% → 100%` Billboard。
- 进度柱高度与 Game 的 `_hold_progress / hold_zone_seconds` 同步。
- 玩家离开控制区，HUD 和世界进度同时归零。

测试验证 2.0 / 4.0 秒时 world ratio ≈ 0.5。

### Extraction World Progress

Extraction Beacon 新增中央进度核心：

- 进入 Beacon 后随连续 hold 从 0% 升至 100%。
- 世界进度和 HUD `EXTRACT X.X/3.0s` 共用同一 Game 状态。
- 中途离开时两者同时归零。

测试验证 1.5 / 3.0 秒时 world ratio ≈ 0.5。

### Null Warden Hazard Telegraph

此前 Boss Phase 2/3 一切换，危险地面立即具备伤害，留给玩家的反应窗口过短。

新流程：

```text
Boss phase changes
→ Hazard pads immediately light up
→ emission = telegraph state
→ 0.9s warning window
→ damage arms
→ emission rises
→ normal 0.75s damage pulse
```

Phase 2：

- 2 个 hazard pad 先预警。
- 0.9s 内不造成伤害。
- 预警后每次 pulse 6 damage。

Phase 3：

- 4 个 pad 全部预警。
- 同样有 0.9s 安全反应窗口。
- 预警后每次 pulse 10 damage。

`boss_hazard_state()` 现在暴露：

- phase
- active_count
- damage
- damage_armed
- telegraph_seconds

回归测试明确验证 telegraph 阶段不会扣玩家护盾。


## 2026-10-07 追加：Combat Fairness + Pause-safe Mission Timers

### Sniper Windup 可被掩体打断

新增端到端物理回归：

`tests/test_enemy_attack_telegraph.gd`

验证：

```text
sniper begin windup
→ windup 期间出现墙体遮挡 LOS
→ windup 到期
→ resolve attack 再检查 LOS
→ 玩家不受伤
```

墙体移除后再次攻击：

- windup 正常结束。
- LOS 保持开放。
- 玩家护盾下降。

因此 Sniper 的 0.55s 前摇是真正可利用的躲避窗口，而不是纯视觉特效。

### Pause-safe Gameplay Timers

发现 Godot `SceneTree.create_timer()` 默认 `process_always = true`。

原风险：

```text
Encounter cleared
→ 1.8s intermission timer
→ 玩家暂停
→ timer 仍然到期
→ _advance_wave() 在 PAUSED 状态 return
→ _wave_transitioning 永远为 true
→ Mission 卡死
```

现在以下 gameplay timers 都使用 `process_always = false`：

- Story Encounter 1.8s intermission。
- Campaign wave intermission。
- Reinforcement delay。
- Reinforcement world-warning lifetime。
- Null Warden hazard telegraph。

仍允许继续运行的 timer：

- UI message fade。
- Audio tone queue。
- 短 tracer / impact visual lifetime。

因为这些不会改变任务状态。

新增：

`tests/test_pause_safe_mission_timers.gd`

验证：

1. Arrival 清场进入 intermission。
2. 立即 Pause。
3. 等待超过原本 1.8 秒。
4. Market Crossfire 仍未 armed，session wave index 不变。
5. Resume。
6. 剩余 timer 正常继续。
7. Market Crossfire 最终只 advance 一次并进入 traversal。


## 2026-10-07 追加：Persistent World State + Navigation Feedback

### Gravity Breach Uplink 锁存

修复了一个任务语义问题：

旧行为：

```text
hold_progress 达到 4s
→ 如果仍有敌人
→ 玩家离开控制区
→ progress 又归零
```

新行为：

```text
连续 hold 达到 4s
→ _hold_completed = true
→ UPLINK STABLE
→ 可以离开控制区收尾敌人
→ 完成状态不会回退
→ 最后敌人清空后才推进
```

世界进度柱在完成后保持 100%，Label 显示 `UPLINK STABLE`。

### Data Lane 世界完成状态

Data Relay 摧毁后：

- 主核心 Visual 消失。
- 保留 DestroyedVisual 残骸。
- 留下 3 块倾斜装甲碎片。
- 保留红色 OfflineCore。
- Billboard 状态显示 `RELAY A/B // OFFLINE`。

Relay 激活期间：

- Billboard 实时显示 health percentage。
- partial damage 会改变 `health_ratio()`。
- 受击产生短 emission flash。

### Warden Access Door

Data Lane 完成后，世界状态不再只依赖 lockdown：

- `WardenAccessDoor` 视觉门向上升起。
- `GateStatus` 从 `ACCESS LOCKED` 改为 `ACCESS OPEN`。
- headless 下独立维护 progression gate state。

新开局：

- Warden gate 强制关闭。

Checkpoint Continue：

- 如果 `completed_encounters` 已含 `data_lane`，
- 恢复到 Null Warden 时 Warden gate 直接恢复 open。

新增 `test_checkpoint_world_restore.gd` 验证 checkpoint 不会把已完成世界状态重置。

### Navigation Distance

World-space objective beacon 现在每 0.15s 更新：

```text
OBJECTIVE // MARKET CROSSFIRE
042m
```

使用实际玩家与 beacon 的世界距离，不改变 MissionRuntime。

### Extraction Ring Progress

Extraction 0→100% hold 除了中央 ProgressCore：

- 外圈 Ring emission 也随进度增强。
- 0% 保持基础亮度。
- 100% 达到最高亮度。
- 离开 Beacon 重置时 Ring 同步回落。

### Boss Arena World Phase

Boss Arena 新增 `BossPhaseStatus`：

- PHASE 1
- PHASE 2 // TWIN HAZARDS
- PHASE 3 // OVERLOAD

BossArenaRing emission 同步随 phase 提升，使阶段变化直接作用于场景，而不是只显示在 HUD。
