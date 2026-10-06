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
