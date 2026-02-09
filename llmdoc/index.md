---
id: index
type: reference
related_ids: [doc-standard, project-architecture]
---

# 维度走私商 (Dimension Smuggler)

> **Summary:** 模拟经营 + 物理沙盒 + Roguelike。技术栈: Godot 4.6 + Tripo AI。

## 项目定位

**类型:**
- 模拟经营: 资源管理、跨维度交易
- 物理沙盒: 物理引擎驱动的货物处理
- Roguelike: 随机事件、永久死亡、解锁系统

**技术栈:**
- **引擎:** Godot 4.6 (GDScript/C#)
- **AI生成:** Tripo AI (3D资源生成)
- **架构:** ECS + 事件驱动

## 核心概念

**维度走私机制:**
- 玩家驾驶货船穿越维度裂缝
- 每个维度有独特物理规则和资源
- 货物必须符合物理约束才能安全运输

**关键系统:**
- `DimensionPortal`: 维度跳跃与规则切换
- `CargoPhysics`: 货物物理模拟
- `TradeNetwork`: 跨维度市场系统
- `RogueGenerator`: 随机事件与挑战生成

## 文档导航

### 📘 指南 (Guides)
`llmdoc/guides/`
- `doc-standard.md`: 文档规范与模板
- `godot-workflow.md`: Godot开发工作流
- `ai-integration.md`: Tripo AI集成指南

### 🔧 技术参考 (Reference)
`llmdoc/reference/`
- `architecture.md`: 系统架构与核心设计
- `dimension-system.md`: 维度系统技术规格
- `physics-rules.md`: 物理引擎约束
- `data-models.md`: 核心数据模型 (GDScript Types)

### 🎯 策略文档 (Agent)
`llmdoc/agent/`
- `strategy-*.md`: 代理执行策略
- `memory-*.md`: 项目上下文与决策记录

## 快速开始

**新开发者:**
1. 阅读 `llmdoc/reference/architecture.md` (系统全貌)
2. 阅读 `llmdoc/reference/data-models.md` (数据结构)
3. 检查 `src/` 中的核心场景 (Godot Scene Tree)

**AI代理:**
1. 搜索 `llmdoc/reference/` (技术真相)
2. 搜索 `llmdoc/agent/` (执行策略)
3. 遵守 `skills/style-hemingway.md` (代码风格)

## 项目状态

**当前阶段:** 原型开发 (Phase 1)
**优先级:**
1. 维度跳跃原型
2. 货物物理模拟
3. 基础交易系统

**技术债务:**
- [ ] 需要定义 GDScript 类型规范
- [ ] 需要建立 Tripo AI 资源管线
- [ ] 需要编写物理单元测试

## 相关链接

- **Godot Docs:** https://docs.godotengine.org/en/4.6/
- **Tripo AI:** https://www.tripo3d.ai/
- **项目规范:** `llmdoc/guides/doc-standard.md`
