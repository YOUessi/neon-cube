# Neon Cube 开发工作流

## 唯一事实源

本项目以 GitHub 仓库 `YOUessi/neon-cube` 为唯一事实源（source of truth）。

GitHub 不只是代码备份仓库，而是主要开发现场，必须长期保留：

- 所有正式代码与场景文件。
- 关卡、玩法、系统与架构设计文档。
- 每个阶段的开发过程记录。
- 测试方案、测试结果与已知问题。
- 重要技术决策及其原因。
- 分支、提交和版本演进记录。
- 后续开发计划与未完成项。

禁止形成“Mac 上有一套最新代码、GitHub 只是偶尔同步”的工作方式。

## Mac 的角色

Mac 只承担运行与验证环境：

1. 从 GitHub 拉取当前开发分支。
2. 运行 Godot 编辑器与游戏。
3. 进行实际试玩、视觉检查和截图。
4. 运行 headless / regression / performance 测试。
5. 将测试发现反馈到 GitHub 开发分支，由 GitHub 侧修改代码与文档。
6. 再次拉取并复测。

除必要的临时调试外，不在 Mac 上形成未提交的长期开发代码。

## 固定闭环

```text
GitHub 设计/实现
      ↓
GitHub commit
      ↓
Mac git pull
      ↓
Mac Godot 实际运行 / 测试 / 截图
      ↓
发现问题与数据
      ↓
记录回 GitHub
      ↓
GitHub 修复 / 继续开发
```

## 分支规则

- `main`：稳定主线。
- `production/aaa-foundation`：AAA 化基础生产线。
- `level/*`：正式关卡开发。
- `gameplay/*`：玩法系统开发。
- `art/*`：美术与视觉开发。
- `perf/*`：性能优化。
- `release/*`：发布候选。

当前 Neon Market Siege 工作分支：

`level/neon-market-siege-spatial-pass`

## 过程记录要求

每一个较大的开发块至少记录：

- 为什么做。
- 修改了什么。
- 关键文件。
- 设计取舍。
- 测试方法。
- 测试结果。
- 已知问题。
- 下一步。

记录优先放在 `docs/`，阶段性日志放在 `docs/devlog/`。

## 测试原则

所有“完成”都必须对应可验证证据。

至少区分：

- 解析 / import 是否通过。
- headless 功能测试是否通过。
- 正式主场景是否启动。
- Mac 实际渲染是否正确。
- 玩家是否真的可走通。
- Encounter 是否按设计触发。
- AI 是否能在实际空间中正常移动。
- 性能是否在预算范围内。

不能用“代码看起来合理”代替运行结果。
