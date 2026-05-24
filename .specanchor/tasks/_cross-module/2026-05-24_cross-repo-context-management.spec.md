---
specanchor:
  level: task
  task_name: "Cross-Repo Context Management Plan"
  author: "@方壶"
  created: "2026-05-24"
  status: "draft"
  last_change: "多 repo 共享 spec 场景的设计方案：SpecAnchor 作为 consumer 端，distribution 交给 git/包管理器"
  related_modules: []
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
---

# Plan: Cross-Repo Context Management

> 场景：多个前后端项目需统一业务语言 / 架构 / 前后端规范 / API 规范，支持多人开发
> 关联：`references/external-sources-protocol.md` / `2026-05-24_context-system-construction.spec.md`

## 0. 核心判断

**不构建"完整的跨代码仓库上下文管理体系"。**

> **跨 repo 共享的"内容"由 git / 包管理器 distribute；SpecAnchor 只做 consumer 端的 assemble + 漂移检测。**

跨 repo 是 distribution 问题，不是 SpecAnchor 问题。强行让 SpecAnchor 自己解决 distribution，会引入远程协议 / 同步机制 / 冲突解决 / 权限管理——这些都不是 SpecAnchor 的核心能力，且业界都有成熟答案。

## 1. 共享内容分两类（用不同机制）

### 1.1 硬契约（API / 事件 schema / 数据模型）

- **不用 markdown spec**
- 用 OpenAPI / Protobuf / JSON Schema 作为 source of truth
- 通过 codegen 在各 repo 产出 client（`openapi-generator` / `buf` / `protoc`）
- 版本管理用 semver + 各 repo 的依赖文件 pin 版本
- **SpecAnchor 完全不碰这部分**——没比成熟 codegen 工具做得更好

### 1.2 软规范（业务语言 / 架构 / 前后端规范 / UI guidelines）

- 用 markdown spec（沿用 SpecAnchor 现有格式）
- distribution 用 git submodule / git subtree / npm 私有包
- 各 consumer repo 把它挂在固定本地路径（如 `vendor/standards/`）
- 在 `anchor.yaml` 用 `sources` 引用本地挂载路径
- **SpecAnchor 当 consumer**（消费 + 校验，不分发）

## 2. Distribution 三种模式（按团队规模递增）

| 模式 | distribute 机制 | 适合 | 不适合 |
|---|---|---|---|
| Monorepo + 共享目录 | git（一个仓） | 团队 < 20、技术栈统一 | 多组织、不同部署节奏 |
| Shared Repo as Submodule / Subtree | git submodule / subtree | 团队 20-100、跨技术栈但同组织 | 不熟 submodule 的团队 |
| Shared Package via Registry | npm / Maven / pip 私有 registry | 大型组织、多团队、严格语义化版本 | 小团队（registry 维护成本高） |

**所有这些机制都不需要 SpecAnchor 发明**——选其一即可。

## 3. 推荐项目结构（中等规模团队示例）

```
独立仓 acme-standards/         ← 软规范源
├── global/
│   ├── coding-standards.spec.md
│   ├── api-design-principles.spec.md
│   ├── ubiquitous-language.spec.md     ← DDD 业务术语
│   └── architecture-overview.spec.md
├── decisions/
│   └── adr-001-event-driven.spec.md
└── anchor.yaml                          ← 自己也用 SpecAnchor 治理

独立仓 acme-contracts/         ← 硬契约源（OpenAPI / Protobuf）
├── openapi/
│   ├── auth.v1.yaml
│   └── billing.v2.yaml
└── events/
    └── user-created.v1.yaml

各 consumer repo（web / api / worker）/
├── vendor/standards/         ← submodule 指向 acme-standards
├── generated/                ← codegen 输出（不进 git）
├── anchor.yaml               ← 在 sources 段引用 vendor/standards/
└── .specanchor/
    ├── global/               ← 本 repo 的 repo-local global
    ├── modules/              ← 本 repo 的 module spec
    └── findings/             ← 本 repo 内部 finding（不跨 repo 共享）
```

## 4. 哪些进 SpecAnchor

### 4.1 已有能力（继续用，无需新增）

已存在于 `references/external-sources-protocol.md`：

- `sources` 协议（path / type / maps_to / file_pattern / governance）
- `spec-index.md` 的 `source: external:<type>` 字段
- 降级解析（无 frontmatter 时从 git / 文件名推断）
- `stale_check` 已覆盖 external sources
- frontmatter 注入工具（可选）

**当前 `sources` 协议假设 path 在项目根目录相对路径下——这对 submodule / npm 包 / git subtree 都适用。所以"跨 repo"能力 90% 已经有了，没明确支持过而已。**

### 4.2 需要新增（4 个小字段 + 1 个检测维度）

#### 4.2.1 sources 字段扩展

```yaml
specanchor:
  sources:
    - path: "vendor/standards/"
      type: "acme-standards"
      maps_to: global_specs
      version: "v1.3.0"               # 新增：本 repo pin 的版本（commit hash 或 tag）
      upstream_url: "git@github.com:acme/standards.git"   # 新增（可选）：让 check 能远程对比
      precedence: "above_native"      # 新增：与 native global spec 冲突时谁覆盖（above_native | below_native | merge_warn）
      change_stop_trigger: true       # 新增：上游变化时 boot warning
      governance:
        stale_check: true
        frontmatter_inject: false
        scan_on_init: true
```

4 字段全部 optional，**不破坏既有 sources 用户的 anchor.yaml**。

#### 4.2.2 `specanchor-check` 新增 external_drift 维度

- 检测"上游 spec 已升级 N 个版本但本 repo 未 sync"
- submodule 情况：`git -C vendor/standards log $pinned..HEAD --oneline`
- 包情况：对比 lockfile 版本 vs registry 最新版本（需要可选的 registry 访问）
- 输出加入 Alignment Surface 报告，与现有 spec↔code drift 并列

#### 4.2.3 boot 阶段提示

- 上游契约 / 共享 spec 文件变更 → boot warning
- 本 repo `version` pin 与 `vendor/standards` 当前 commit 不一致 → 提示"考虑 `git submodule update`"或"考虑升级 pin"

## 5. 哪些不进 SpecAnchor（明确不做）

| 提议 | 不做的理由 |
|---|---|
| System Context Hub（独立中央 spec 仓的格式协议） | 这是项目结构选择，不是 SpecAnchor 能力；用户可以用任何目录结构 |
| Repo registry / service topology / 服务依赖图 | monorepo 工具（Nx / Turborepo / Bazel）或服务网格的事 |
| Context Graph（System → Repo → Module → Symbol 多层节点 + 横向 API / Event 节点） | over-engineering；多数项目只要 2-3 层；强求建图会成为准入门槛 |
| Distribution 机制（fetch / cache / 版本协商 / push） | git submodule / npm / OpenAPI codegen 已经做了 |
| 跨 repo 的 finding 共享 | finding 是 repo 内 hot context；跨 repo 共享 = 一个 repo 内部讨论污染另一个 |
| 跨 repo 的 agent bundle 编排 | Harness（Claude Code / Codex / Cursor）该做的事，不是 SpecAnchor |
| 多人 review / approval 流程 | GitHub CODEOWNERS / GitLab approval rules / PR review 已经做了 |
| 跨 repo 的 sediment proposal | sediment 在源 spec 仓（acme-standards）做，consumer 通过 git sync 拿到 |
| 角色化 bundle（architect / implementer / reviewer / release） | 暂无真实用户用例；上游 Context System 方案也未启动；不在跨 repo 范畴 |

## 6. 多人协作的边界

| 问题 | 谁解决 |
|---|---|
| 共享内容是什么（spec / 契约 / 业务语言） | 用户自定义，放独立仓 |
| 共享内容怎么 distribute | git submodule / git subtree / npm / OpenAPI codegen |
| 谁能改共享 spec | GitHub CODEOWNERS / GitLab approval rules |
| 改了之后通知谁 | GitHub PR auto-assign / Slack webhook |
| 冲突 review | PR review 流程 |
| 本 repo 怎么消费共享内容 | **SpecAnchor**（`sources` 协议 + 升级） |
| 上游变了本 repo 怎么知道 | **SpecAnchor**（`check` 加 external_drift 维度） |
| 共享 spec 和本 repo spec 冲突 warning | **SpecAnchor**（`precedence` 字段 + lint） |
| 跨 repo 编排 agent 任务 | Harness（不是 SpecAnchor） |

## 7. 落地顺序（3 步，全部小改）

> 原则：每一步独立可逆。每步完成后停下评估。

### Step 1: 写 `docs/multi-repo-setup.md`（200 行内）

- 教用户用 git submodule 或 npm 包挂在 `vendor/standards/`
- 给 anchor.yaml 完整示例配置
- 给两个完整 walkthrough：
  - submodule 路线（git submodule add + anchor.yaml sources）
  - npm 私有包路线（package.json + postinstall symlink）
- 说明硬契约（OpenAPI）和软规范（markdown spec）的分工
- **零代码改动**，纯文档

### Step 2: `sources` 加 4 字段

- 在 `references/external-sources-protocol.md` §1 字段表加 `version` / `upstream_url` / `precedence` / `change_stop_trigger`
- 修改 `scripts/specanchor-resolve.sh` 解析这 4 字段
- 修改 `scripts/specanchor-validate.sh` 校验 `precedence` 枚举
- 修改 `scripts/specanchor-init.sh` 交互式提示时加上这 4 字段（可选）
- **4 字段全部 optional**，不破坏既有 sources 用户

### Step 3: `specanchor-check` 新增 external_drift 检测

- 新增 `scripts/lib/external-drift.sh`
- `specanchor-check` 输出新增 `external_drift` section
- 上游 submodule 落后 → warn（含落后的 commit 数量与文件清单）
- 上游 npm 包有新版本 → warn（可选，需要 registry 访问；离线环境降级为提示用户手动检查）
- 与现有 spec↔code drift 检测并列，不互相替代

## 8. 验证标准

- 一个有 3 个 consumer repo + 1 个 standards repo 的实际项目能跑通
- 共享 spec 改了，consumer repo 在 boot 时能看到 warning
- consumer repo 自己的 module spec 引用共享 ubiquitous-language 不会失效
- 不需要新增任何"中央仓协议"或"跨 repo agent 编排"
- 硬契约（OpenAPI）变更通过 codegen 报错传播，不依赖 SpecAnchor

## 9. 备注

- **跨 repo 是 distribution 问题，不是 SpecAnchor 问题**——SpecAnchor 只做 consumer
- 如果未来某个用户真的需要"中央 spec 仓"协议，那应该是另一个独立项目（如 `acme-standards-cli`），不是 SpecAnchor 一部分
- OpenAPI / Protobuf 这些硬契约工具链不要在 SpecAnchor 里重造
- 本方案与姊妹文档 `2026-05-24_context-system-construction.spec.md` 互不阻塞：跨 repo 方案的 3 步可独立推进
- 反例提醒：GPT 提议的 "System Context Hub" / "Context Graph" / "Cross-repo findings sharing" 都已显式列为不做项；如果未来再有类似提议，应明确驳回理由再讨论
