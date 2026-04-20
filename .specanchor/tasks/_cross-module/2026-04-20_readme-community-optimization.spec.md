---
specanchor:
  level: task
  task_name: "README 社群传播优化"
  author: "@方壶"
  created: "2026-04-20"
  status: "draft"
  last_change: "初始创建，承接 README 社群传播优化项（Hero 图除外）"
  related_modules: []
  related_global:
    - ".specanchor/global/project-setup.spec.md"
  writing_protocol: "simple"
  branch: "main"
---

# Task: README 社群传播优化

## 目标

把当前 `README.md` 从"完整说明书"重构为"GitHub 首屏 + 社群传播"双场景文档——让初次访问者在 15 秒内理解 SpecAnchor 的价值、差异化和 Quick Start 路径，同时为 Twitter/小红书/V2EX 等场景提供独立可传播的素材。

**为什么做**：

- 现 README 255 行，首屏信息密度过高，"编译式知识 vs RAG"这一最强差异化卖点被埋到第 17 行（只出现"核心理念"小节，要点进 WHY.md 才看得到完整对比）
- 开头 tagline "Spec 是锚，代码是船" 诗意但抽象，访问者第一眼不知道工具能帮自己做什么
- Quick Start 直接给 `rsync --exclude-from=...` 命令，新手门槛高
- 缺少 badges、hero 图、Star History、Contributing 入口等社群传播元素
- 与 OpenSpec / SDD-RIPER-ONE 的详细对比过早出现，读者尚未理解工具本身
- 中文主导，未对 GitHub 英文受众做优先级取舍

## 范围

**In-Scope**：
- 重构 `README.md` 首屏（新增 tagline、徽章、hero 图引用、Quick Start 可复制命令）
- 精简信息密度（次级章节折叠 `<details>` 或拆分到 `docs/`）
- 将 WHY.md 的"编译式 vs 检索式"核心对比提升到 README 首屏（配合 hero 图）
- 新增"没有 vs 有 SpecAnchor"场景对照表
- 降低 Quick Start 门槛（提供 curl 一行安装或预封装脚本作为 rsync 的上层入口）
- 新增社群要素：Star History 徽章、CONTRIBUTING 入口、Discussions / Roadmap 链接
- 将"与 SDD-RIPER-ONE / OpenSpec 对比"章节从 README 迁移到独立 `docs/COMPARE.md`
- README 英文化策略决策（方案 A：英文主 + 中文副；方案 B：保持中文主但强化英文徽章/副标题）
- 同步更新 `README_EN.md` 和 `WHY_EN.md`

**Out-of-Scope**：
- Hero 图本身的生成（已单独走 `/baoyu-infographic` 产出 prompt，见 `infographic/specanchor-hero/prompts/infographic.md`，本任务仅引用其最终输出的 PNG）
- WHY.md 内容实质性重写（本任务只负责把 WHY.md 核心要点提炼到 README 首屏，不改写 WHY.md）
- Logo / 品牌字体等视觉资产设计
- 安装脚本（`install.sh`）的具体实现（若方案决定引入，作为后续独立任务）
- CI 徽章（build status / coverage）的配置
- 对 FLOWCHART.md / SKILL.md 的修改

## 改动计划

| 文件 | 变更说明 |
|------|---------|
| `README.md` | **重写首屏**：tagline 替换为直白痛点型、补徽章区、引入 hero 图、新增"问题 → 方案"开场段、注入"编译式 vs 检索式"对比表（从 WHY.md 提炼）、新增"没有 vs 有 SpecAnchor"对照表、重排章节顺序、次级章节用 `<details>` 折叠 |
| `README.md` | **精简**：移除或迁移"与 SDD-RIPER-ONE/OpenSpec 对比"详细章节，仅保留一行"兼容声明" |
| `README.md` | **Quick Start**：在 rsync 命令之前加入一行 curl/预封装脚本入口（若实现安装脚本则引用，若未实现则先写 TODO 占位） |
| `README.md` | **社群区**：底部新增 Star History 徽章、Contributing 引用、Roadmap 链接、Discussions 链接 |
| `README_EN.md` | 同步重构（对齐中文 README 的结构和要点） |
| `docs/COMPARE.md` | **新建**：容纳从 README 迁移出的"与 SDD-RIPER-ONE / OpenSpec 对比"详细内容 |
| `docs/INSTALL.md` | **新建**：容纳完整安装细节（Cursor/Claude Code/其他工具/rsync 原理说明），README 里只保留精简版 |
| `CONTRIBUTING.md` | **新建（最小版）**：说明如何贡献、Good First Issues 约定、PR 规范 |
| `infographic/specanchor-hero/` | 引用处：README 顶部用相对路径引用该目录下将生成的 PNG（PNG 文件本身不在本任务范围） |
| `.gitignore`（如需） | 若 `infographic/` 下含临时产物，补充忽略规则 |

## Checklist

- [ ] 1. 确认英文化策略（方案 A vs 方案 B）——需要与 owner 对齐后再动笔
- [ ] 2. 起草 README 新首屏（tagline、徽章区、hero 图占位符、问题→方案开场）
- [ ] 3. 从 WHY.md 提炼"编译式 vs 检索式"对比表，注入 README 首屏
- [ ] 4. 编写"没有 vs 有 SpecAnchor"场景对照表（新成员接手模块 / 迭代一年后 / AI 反复询问 三场景）
- [ ] 5. 新建 `docs/COMPARE.md`，迁移现有"与 SDD-RIPER-ONE / OpenSpec 对比"章节
- [ ] 6. 新建 `docs/INSTALL.md`，迁移完整安装细节；README 中改为精简摘要 + 跳转链接
- [ ] 7. 新建 `CONTRIBUTING.md` 最小版
- [ ] 8. README 底部补社群区（Star History 徽章、Contributing/Roadmap/Discussions 链接）
- [ ] 9. 用 `<details>` 折叠次级章节（使用策略、目录结构、配置详情等），确保首屏 ≤ 60 行可见
- [ ] 10. 同步更新 `README_EN.md` 结构
- [ ] 11. Hero 图 PNG 生成完成后（走 /baoyu-infographic 流程），在 README 引用处替换占位符
- [ ] 12. 本地预览（用 GitHub Markdown 渲染或 grip）检查所有徽章、折叠块、锚点可用
- [ ] 13. 对比改动前后字数/行数/首屏密度，记录到本 Task Spec 的"备注"

## 完成确认

- [ ] README 首屏（前 60 行）包含：tagline、徽章、hero 图、核心差异化（编译式 vs 检索式）、60 秒 Quick Start 入口
- [ ] 详细章节已迁移或折叠，未一次性暴露在首屏
- [ ] `docs/COMPARE.md` / `docs/INSTALL.md` / `CONTRIBUTING.md` 可独立访问并从 README 正确跳转
- [ ] README 和 README_EN.md 结构对齐，核心信息一致
- [ ] 代码符合 Global Spec（纯文档任务，主要是格式规范性）
- [ ] Module Spec 无需同步（不涉及代码模块）
- [ ] 测试：不适用（纯文档任务）；但需执行本地渲染预览作为等价验证

## 备注

### 与 Hero 图任务的边界

Hero 图 prompt 已在本任务创建前生成并归档于 `infographic/specanchor-hero/prompts/infographic.md`，对应的 PNG 生成/优化/多轮迭代**不由本任务承接**——本任务只负责在 README 中为它预留引用位置，PNG 完成后替换占位即可。

### 与 WHY.md 的融合策略

WHY.md 作为"长文档"继续保留，深度内容不搬运。README 首屏只引用 WHY.md 中的**两个最强要素**：

1. **"编译式 vs 检索式"对比表**（WHY.md §编译式知识 vs 检索式知识 中的核心两行表格，提炼到 README）
2. **"Spec 是锚，代码是船"的锚/船隐喻**（继续保留，但放到 hero 图中视觉化，不单独作为 tagline）

WHY.md 中的其他段落（更深层愿景、设计原则、不同角色使用建议、冷启动方案、演进路线图）保持在 WHY.md 内，README 通过链接引导感兴趣的读者深入阅读。

### 英文化策略决策点

两种方案的权衡：

| 方案 | 优势 | 代价 |
|------|------|------|
| A: 英文主 + 中文副 | GitHub 国际受众更大，社群传播半径广 | 对现有中文用户产生迁移成本；作者本人维护中英双文档有负担 |
| B: 中文主 + 英文副 | 符合作者当前工作语境，维护成本低 | GitHub 英文访问者第一眼看到中文可能流失 |

**建议**：方案 B 起步，但强化英文切换入口（顶部明显的 English 徽章 + 英文 tagline 副标题），保留切换到方案 A 的退路。最终由 owner 决策。

### 改动前后密度对比（执行后填写）

- 改动前：README.md 255 行
- 改动后：README.md __ 行（首屏可见 __ 行）
- 迁移行数：COMPARE.md __ 行 / INSTALL.md __ 行
- 新增社群区：__ 行
