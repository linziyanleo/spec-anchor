# SpecAnchor：Spec 驱动研发落地方案

> **机制名称**：SpecAnchor（规范锚定体系）
> **核心隐喻**：Spec 是锚，代码是船。锚定住了，船才不会漂。
> **版本**：v0.1.0 (Draft)
> **日期**：2026-03-13
> **状态**：研讨稿

---

## 0. SpecAnchor 是什么

SpecAnchor 是一套**面向多人协作的、分层的、与项目共存的 Spec 管理体系**。

它不是一个独立的产品，而是一组**约定 + 文件结构 + AI 指令 + CI 检查**的组合，嵌入到现有的研发流程中。

**它解决的核心问题**：

| 问题              | SpecAnchor 的回答                |
| --------------- | ----------------------------- |
| AI 生成的代码不符合团队规范 | Global Spec 提供"宪法级"约束，AI 必须遵守 |
| 不同开发者改同一模块风格不统一 | Module Spec 定义模块的接口契约和设计约定    |
| 代码改了但"为什么改"丢失了  | Task Spec 记录每次变更的意图和决策        |
| Spec 和代码不一致（腐化） | 单向主导 + 定期校验 + Spec 覆盖率指标      |
| 工程师与外包的协作边界不清   | 角色-Spec 权限矩阵，明确谁写、谁审、谁执行      |

**它不解决的问题**：

- 沙箱环境搭建（那是基础设施层的事）
- AI 模型能力本身（那是模型选型的事）
- CI/CD 流水线搭建（那是 DevOps 的事）

---

## 1. 三级 Spec 体系

### 1.1 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  L1: Global Spec（全局规范）                                 │
│  ─────────────────────────────────────                       │
│  生命周期：长期存在，低频变更（季度级）                        │
│  所有者：工程师团队（Peer Review 维护）                       │
│  作用：AI 生成代码的"宪法"，团队一致性的基线                   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  L2: Module Spec（模块规范）                                 │
│  ─────────────────────────────────────                       │
│  生命周期：中期存在，中频变更（迭代级）                        │
│  所有者：模块 Owner（工程师 / 外包均可创建，外包需 Review）    │
│  作用：AI 理解"这块业务怎么运转"，模块间接口的契约             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  L3: Task Spec（任务规范）                                   │
│  ─────────────────────────────────────                       │
│  生命周期：短期存在，高频变更（任务级），用完归档               │
│  所有者：执行该任务的工程师或外包                             │
│  作用：AI "这次改什么、怎么改"的执行合同                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 各级 Spec 的内容对比

| 维度          | L1 Global Spec   | L2 Module Spec     | L3 Task Spec  |
| ----------- | ---------------- | ------------------ | ------------- |
| **粒度**      | 项目/团队级           | 模块/功能域级            | 单次任务级         |
| **变更频率**    | 季度级              | 迭代级（Sprint）        | 每日/每任务        |
| **持久性**     | 永久保留             | 长期保留               | 完成后归档         |
| **编写者**     | 工程师              | 工程师 / 外包（需 Review） | 工程师 & 外包      |
| **审批者**     | 工程师（Peer Review） | 工程师                | 工程师 & 外包      |
| **AI 使用方式** | 每次生成代码必读         | 修改相关模块时读取          | 当前任务执行时读取     |
| **Git 策略**  | 合入 main 需 Review | 合入 main 需 Review   | 可随 feature 分支 |

---

## 2. 文件结构设计

### 2.1 设计原则

1. **Global Spec 集中存放**：像 `.eslintrc`、`.prettierrc` 一样，放在项目根目录约定位置
2. **Module Spec 就近放置**：像 `README.md` 一样，放在模块目录内（"触碰即可见"）
3. **Task Spec 按模块分目录**：以关联模块为一级子目录，跨模块任务放 `_cross-module/`，避免扁平目录难以检索
4. **Project Codemap 纳入版控**：项目级全景图（跨模块结构 + 核心流程）是有持久价值的，纳入 Git；Feature-level codemap 由 Module Spec 内的"代码结构"章节替代，不再单独存放

### 2.2 完整目录结构

```
project-root/
│
├── .specanchor/                          ← SpecAnchor 根目录
│   │
│   ├── config.yaml                       ← SpecAnchor 配置（角色、校验规则等）
│   │
│   ├── global/                           ← L1: Global Spec
│   │   ├── coding-standards.spec.md      ← 编码规范
│   │   ├── architecture.spec.md          ← 架构约定config.yaml
│   │   ├── design-system.spec.md         ← 设计系统规则
│   │   └── api-conventions.spec.md       ← API 设计约定
│   │
│   ├── project-codemap.md                ← 项目级全景图（纳入版控，Sprint 级更新）
│   │
│   ├── tasks/                            ← L3: Task Spec（按模块分子目录）
│   │   ├── auth/                         ← auth 模块相关任务
│   │   │   ├── 2026-03-13_sms-login.spec.md         (活跃)
│   │   │   └── 2026-03-05_password-reset.spec.md    (已完成)
│   │   ├── order/                        ← order 模块相关任务
│   │   │   └── 2026-03-12_fix-order-bug.spec.md
│   │   └── _cross-module/               ← 跨模块任务
│   │       └── 2026-03-10_auth-order-integration.spec.md
│   │
│   └── archive/                          ← 归档（按月 + 模块清理）
│       └── 2026-02/
│           ├── auth/
│           │   └── 2026-02-20_oauth-upgrade.spec.md
│           └── payment/
│               └── 2026-02-28_refactor-payment.spec.md
│
├── src/
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── MODULE.spec.md            ← L2: Module Spec（就近放置）
│   │   │   ├── auth.service.ts              包含"代码结构"章节，替代 feature codemap
│   │   │   ├── auth.controller.ts
│   │   │   └── ...
│   │   │
│   │   ├── order/
│   │   │   ├── MODULE.spec.md            ← L2: Module Spec
│   │   │   ├── order.service.ts
│   │   │   └── ...
│   │   │
│   │   └── payment/
│   │       ├── MODULE.spec.md            ← L2: Module Spec
│   │       └── ...
│   │
│   └── components/                       ← 前端组件目录
│       ├── LoginForm/
│       │   ├── MODULE.spec.md            ← 组件级 Module Spec
│       │   ├── LoginForm.tsx
│       │   └── LoginForm.test.tsx
│       └── ...
│
├── .cursor/
│   └── rules/
│       └── specanchor.mdc                ← Cursor Rule: AI 读取 Spec 的指令
│
└── .gitignore
```

### 2.3 为什么是这样的结构

| 决策                                   | 理由                                                                        |
| ------------------------------------ | ------------------------------------------------------------------------- |
| Module Spec 命名为 `MODULE.spec.md`     | 统一命名，方便 glob 搜索（`**/MODULE.spec.md`）；大写突出重要性，类似 `README.md`               |
| Global Spec 放在 `.specanchor/global/` | 集中管理，不散落在各处；`.` 前缀表示"配置/元信息"                                              |
| Task Spec 按模块分子目录                    | 按关联模块组织，检索"某模块的历史任务"更直觉；跨模块任务放 `_cross-module/`                           |
| Project Codemap 纳入版控                 | 项目级全景图有跨模块结构价值，Module Spec 无法替代；Feature codemap 由 Module Spec 内"代码结构"章节吸收 |
| 不用 `specs/` 而用 `.specanchor/`        | 带前缀避免与业务目录冲突；`.` 约定表示工具/配置目录                                              |

### 2.4 Codemap 的定位：从独立产物到 Spec 的一部分

| 类型                           | 定位                                       | 存放位置                             | 版控              |
| ---------------------------- | ---------------------------------------- | -------------------------------- | --------------- |
| **Project Codemap**（项目级全景图）  | 独立文档，跨模块结构 + 核心流程，Sprint 级更新             | `.specanchor/project-codemap.md` | ✅ 纳入            |
| **Feature Codemap**（功能级代码地图） | **由 Module Spec 的"代码结构"章节替代**，不再单独存放     | MODULE.spec.md 内的 `## 7. 代码结构`   | ✅ 随 Module Spec |
| **临时 Codemap**（冷启动用）         | 过渡产物：AI 生成 codemap → 人确认后升级为 Module Spec | 不持久化（AI 对话中完成）                   | ❌ 不入库           |

**为什么 Module Spec 可以替代 Feature Codemap**：

Module Spec 的"模块职责 + 对外接口 + 依赖关系 + 代码结构"章节，已经覆盖了 feature codemap 的核心信息（入口、核心链路、依赖、风险）。区别在于：

- Codemap 是**描述性的**（"代码现在长什么样"），由 AI 自动生成
- Module Spec 是**规范性的**（"代码应该长什么样"），由人确认

当一个模块有了 Module Spec，codemap 就自然被替代了。

### 2.5 .gitignore 建议

```gitignore
# SpecAnchor
.specanchor/archive/    # 可选：归档的 Task Spec 是否入库由团队决定
```

---

## 3. 各级 Spec 模板

### 3.1 L1: Global Spec 模板（`coding-standards.spec.md` 示例）

```markdown
---
specanchor:
  level: global
  type: coding-standards
  version: "1.2.0"
  author: "@zhangsan"
  reviewers: ["@lisi", "@wangwu"]
  last_synced: "2026-03-01"
  applies_to: "**/*.{ts,tsx}"        # glob 表达式，标明作用范围
---

# 编码规范 (Coding Standards)

## 1. 技术栈约定
- 框架：React 18 + TypeScript 5.x
- 状态管理：Zustand（全局）/ React Query（服务端状态）
- 样式方案：TailwindCSS + CSS Modules（组件私有样式）
- 请求层：统一使用 `@/lib/request`，禁止直接调用 fetch/axios

## 2. 目录与命名约定
- 组件目录：`PascalCase/`，入口文件与目录同名
- 工具函数：`camelCase.ts`
- 常量文件：`UPPER_SNAKE_CASE` 导出
- 类型定义：与业务文件同目录，`*.types.ts`

## 3. 组件编码约定
- Props 接口必须导出，命名 `<ComponentName>Props`
- 禁止在组件内直接写内联样式（design token 除外）
- 副作用统一收敛到自定义 Hook
- 错误边界：页面级组件必须包裹 ErrorBoundary

## 4. API 调用约定
- 所有请求走 `@/lib/request` 封装
- Response 类型定义在 `@/types/api/` 下
- 错误处理统一用 `handleApiError` 拦截

## 5. 设计系统约定（Design Token）
- 色值：仅使用 `theme.colors.`*，禁止硬编码 hex
- 字号：仅使用 `text-sm/base/lg/xl/2xl`
- 间距：仅使用 `spacing.`*（4px 倍数）
- 圆角：仅使用 `rounded-sm/md/lg/xl`

## 6. Git 提交约定
- 格式：`<type>(<scope>): <subject>`
- type：feat / fix / refactor / docs / chore / test
- scope：模块名或组件名
- subject：中文，50 字以内

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
| 2026-03-01 | 新增 Design Token 约定 | @zhangsan |
| 2026-01-15 | 初始版本 | @zhangsan |
```

### 3.2 L2: Module Spec 模板（`MODULE.spec.md`）

```markdown
---
specanchor:
  level: module
  module_name: "用户认证"
  module_path: "src/modules/auth"
  version: "2.1.0"
  owner: "@zhangsan"
  author: "@zhangsan"
  reviewers: ["@lisi"]
  last_synced: "2026-03-10"
  status: "active"                  # draft | review | active | deprecated | archived
  depends_on:                       # 依赖的其他模块
    - "src/modules/user"
    - "src/lib/request"
  design_spec:                      # UED 可修改的安全边界（可选）
    safe_zones:
      - "样式: colors, spacing, font-size"
      - "文案: labels, placeholders, error messages"
    restricted_zones:
      - "交互逻辑: 表单校验规则, 跳转路由"
      - "数据结构: API 请求/响应格式"
---

# 用户认证模块 (Auth Module)

## 1. 模块职责
- 处理用户登录、登出、Token 刷新
- 管理认证状态（已登录/未登录/Token 过期）
- 提供路由守卫（未登录重定向）

## 2. 业务规则
- Token 有效期 2 小时，刷新窗口 30 分钟
- 连续 5 次密码错误锁定账号 15 分钟
- SSO 登录走 OAuth2 Authorization Code 流程

## 3. 对外接口契约

### 3.1 导出 API
| 函数/组件 | 签名 | 说明 |
|-----------|------|------|
| `useAuth()` | `() => { user, isLoading, login, logout }` | 认证状态 Hook |
| `AuthGuard` | `React.FC<{ children, fallback? }>` | 路由守卫组件 |
| `getToken()` | `() => string \| null` | 获取当前 Token |

### 3.2 内部状态
| Store | 字段 | 说明 |
|-------|------|------|
| `authStore` | `user: User \| null` | 当前用户 |
| | `token: string \| null` | JWT Token |
| | `refreshToken: string \| null` | 刷新 Token |

### 3.3 API 端点
| 方法 | 路径 | 用途 |
|------|------|------|
| POST | `/api/auth/login` | 密码登录 |
| POST | `/api/auth/refresh` | 刷新 Token |
| POST | `/api/auth/logout` | 登出 |

## 4. 模块内约定
- 所有认证错误统一抛 `AuthError`，不使用通用 Error
- Token 存储在 HttpOnly Cookie（SSR）或 localStorage（SPA）
- 登录表单校验规则定义在 `auth.validation.ts`

## 5. 已知约束 & 技术债
- [ ] SSO 回调偶发 race condition（#issue-234）
- [ ] 旧版 API 的 session 兼容将在 Q2 移除

## 6. TODO
- [ ] 增加生物识别登录支持 @lisi
- [x] 迁移至 Zustand v5 @zhangsan (2026-03-08)

## 7. 代码结构（替代 Feature Codemap）
- **入口**：`src/modules/auth/index.ts` 统一导出
- **核心链路**：`LoginForm → useAuth() → authStore → /api/auth/login`
- **数据流**：`用户输入 → 表单校验 → API 请求 → Token 存储 → 路由跳转`
- **关键文件**：
  | 文件 | 职责 |
  |------|------|
  | `auth.service.ts` | 登录/登出/刷新 API 调用 |
  | `auth.store.ts` | Zustand store，管理 user/token 状态 |
  | `auth.guard.tsx` | 路由守卫组件 |
  | `auth.validation.ts` | 表单校验规则 |
- **外部依赖**：`src/lib/request`（请求封装）、`src/modules/user`（用户信息）

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
| 2026-03-10 | Token 刷新策略调整 | @zhangsan |
| 2026-02-01 | 初始版本 | @zhangsan |
```

### 3.3 L3: Task Spec 模板（兼容 SDD-RIPER-ONE）

Task Spec 直接沿用 SDD-RIPER-ONE 的 Spec 模板，增加 SpecAnchor 元信息头：

```markdown
---
specanchor:
  level: task
  task_name: "登录页增加手机号验证码登录"
  author: "@wangwu"
  assignee: "@wangwu"
  reviewer: "@zhangsan"
  created: "2026-03-13"
  status: "in_progress"            # draft | in_progress | review | done | archived
  related_modules:                  # 关联的 Module Spec
    - "src/modules/auth/MODULE.spec.md"
    - "src/components/LoginForm/MODULE.spec.md"
  related_global:                   # 引用的 Global Spec
    - ".specanchor/global/coding-standards.spec.md"
  sdd_phase: "PLAN"                # PRE-RESEARCH | RESEARCH | INNOVATE | PLAN | EXECUTE | REVIEW | DONE
  branch: "feat/sms-login"
---

# SDD Spec: 登录页增加手机号验证码登录

## 0. Open Questions
- [ ] 验证码有效期多少秒？（待产品确认）
- [x] 是否需要图形验证码前置？→ 是，频率 > 3次/分钟 时触发

## 1. Requirements (Context)
- **Goal**: 在现有密码登录基础上，增加手机号 + 短信验证码登录方式
- **In-Scope**: 登录表单改造、验证码发送/校验 API 对接
- **Out-of-Scope**: 注册流程、找回密码

## 1.1 Context Sources
- Requirement Source: `docs/prd/sms-login.md`
- Design Refs: `designs/login-v2.figma`
- Chat/Business Refs: 产品群消息 2026-03-12
- Extra Context: 参考竞品 XX 的登录流程

## 1.5 Codemap Used
- Codemap Mode: `feature`
- Codemap File: `.specanchor/codemap/2026-03-13_10-00_auth登录链路功能.md`

## 1.6 Context Bundle Snapshot
- Bundle Level: `Lite`
- Key Facts: 当前登录仅支持密码方式，短信服务已有基础设施

## 2. Research Findings
- 事实与约束: 短信服务走集团统一通道，QPS 限制 100/s
- 风险与不确定项: 验证码有效期规则待确认

## 2.1 Next Actions
- 确认验证码有效期
- 确认是否需要与现有密码登录做 Tab 切换

<!-- 后续 Plan / Execute / Review 按 SDD-RIPER-ONE 流程补齐 -->
```

---

## 4. 角色职责与权限矩阵

### 4.1 两类角色定义

只有两类角色：**工程师**（团队正式成员）和**外包**（外部协作者）。

```
┌─────────────────────────────────────────────────────────────┐
│  工程师（Engineer）                                          │
│  ─────────────────                                          │
│  拥有 SpecAnchor 体系的全部权限：                             │
│                                                             │
│  Spec 职责：                                                 │
│    ✍️  编写和维护 Global Spec（建议 Peer Review）             │
│    ✍️  编写和维护 Module Spec（作为模块 Owner）               │
│    ✍️  创建 Task Spec 并走完 SDD-RIPER 流程                  │
│    👀  Review 外包的 Module Spec 和 Task Spec                │
│    🔍  发起 Spec-代码一致性校验                               │
│                                                             │
│  在 SDD-RIPER 中的角色：                                     │
│    - 全流程自主：Research → Innovate → Plan → Execute → Review│
│    - 拥有 "Plan Approved" 权限                               │
│    - 可使用 FAST 模式（小改快速通道）                         │
│    - 可跳过 Innovate（简单任务注明原因）                      │
├─────────────────────────────────────────────────────────────┤
│  外包（Contractor）                                          │
│  ─────────────────                                          │
│  受限权限，核心产出需工程师 Review：                           │
│                                                             │
│  Spec 职责：                                                 │
│    📖  读取 Global Spec（只读）                               │
│    ✍️  创建和修改 Module Spec（需工程师 Review）              │
│    ✍️  创建和修改 Task Spec                                  │
│    🚫  不可修改 Global Spec                                  │
│                                                             │
│  在 SDD-RIPER 中的角色：                                     │
│    - Research / Plan: 可自主完成                             │
│    - Execute: 按 Checklist 执行                              │
│    - Review: 自检 + 工程师复核                                │
│    - FAST 模式: 允许使用（但产出仍需 Code Review）            │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 权限矩阵

| 操作                           | 工程师               | 外包          |
| ---------------------------- | ----------------- | ----------- |
| 读取 Global Spec               | ✅                 | ✅           |
| 修改 Global Spec               | ✅（建议 Peer Review） | ❌           |
| 读取 Module Spec               | ✅                 | ✅           |
| 创建/修改 Module Spec            | ✅                 | 需工程师 Review |
| 创建 Task Spec                 | ✅                 | ✅           |
| 审批 Task Spec (Plan Approved) | ✅                 | ✅           |
| 执行 Task Spec                 | ✅                 | ✅           |
| SDD FAST 模式                  | ✅                 | ❌           |
| 发起 Spec 校验                   | ✅                 | ✅           |

### 4.3 外包协作工作流

外包在 SpecAnchor 体系中是**受益最大的角色**——Global Spec + Module Spec 已经定义好了"怎么写代码"，AI 在这些约束下生成的代码天然符合团队规范，大幅降低外包的理解成本和返工率。

**典型工作流**：

```
工程师分配任务 + 指向相关 Module Spec
        ↓
外包创建 Task Spec（AI 辅助，可自主完成 Research/Plan）
        ↓
外包 Review Task Spec → "Plan Approved"
        ↓
外包按 Checklist 执行（AI 辅助生成代码，受 Global + Module Spec 约束）
        ↓
外包自检（Review Phase）
        ↓
工程师 Code Review（对照 Task Spec + Module Spec）
        ↓
合并（如有 Module Spec 变更，工程师确认后一并合入）
```

**外包修改 Module Spec 的场景**：当外包在开发过程中发现 Module Spec 需要更新（如新增接口、修改业务规则），可以直接修改并在 MR 中一并提交，工程师在 Review 时确认 Module Spec 的变更是否合理。

---

## 5. Spec-代码双向绑定机制

### 5.1 设计原则：单向主导 + 定期校验

**不追求完全自动的双向同步**，完全双向绑定意味着：

- 代码变了 → 自动更新 Spec（代码 → Spec 的逆向工程，准确率有限）
- Spec 变了 → 自动更新代码（Spec → 代码的正向生成，可行但危险）

这类似于数据库的"双向同步"——理论上完美，实际上充满冲突和一致性问题。

采用：

```
╔═══════════════════════════════════════════════════════╗
║  正向流（主流程，高优先级）                             ║
║  ──────────────────────                               ║
║  Spec 变更 → AI 生成/修改代码 → 人工 Review → 合并     ║
║                                                       ║
║  "Spec 是因，代码是果"                                 ║
╠═══════════════════════════════════════════════════════╣
║  逆向流（补偿流程，定期触发）                           ║
║  ──────────────────────                               ║
║  代码变更 → CI 检测 → Spec 一致性校验 →                ║
║    ├─ 一致 → 通过                                     ║
║    ├─ 不一致 → 标记 Warning（不阻断，但可视化）         ║
║    └─ 无 Spec → 标记为"无 Spec 覆盖区域"              ║
║                                                       ║
║  "代码是镜子，照出 Spec 是否过期"                      ║
╚═══════════════════════════════════════════════════════╝
```

### 5.2 各级 Spec 的同步策略

| Spec 级别       | 同步方向      | 触发条件              | 同步方式                     | 失败处理                |
| ------------- | --------- | ----------------- | ------------------------ | ------------------- |
| **L1 Global** | Spec → 代码 | Global Spec 变更时   | 人工触发全量检查                 | 标记不合规代码 + 创建修复 Task |
| **L2 Module** | Spec → 代码 | Module Spec 变更时   | AI 自动检查模块内代码一致性          | 生成 diff 报告 + 建议修改   |
| **L2 Module** | 代码 → Spec | 每个 Sprint 结束      | AI 扫描代码变更 → 生成 Spec 更新建议 | Owner 确认后更新         |
| **L3 Task**   | Spec ↔ 代码 | 实时（SDD-RIPER 流程内） | RIPER Reverse Sync 机制    | 停止执行 → 先更新 Spec     |

### 5.3 Spec 覆盖率指标

引入类比测试覆盖率的 **Spec 覆盖率** 机制：

```yaml
# .specanchor/config.yaml 中的覆盖率配置
coverage:
  scan_paths:
    - "src/modules/**"
    - "src/components/**"
  ignore_paths:
    - "src/components/ui/**"       # 基础 UI 组件可豁免
    - "src/**/*.test.*"
  thresholds:
    module_spec_coverage: 60       # 目标：60% 模块有 Spec
    warn_on_uncovered_change: true # 修改无 Spec 模块时发出 Warning
  report_output: ".specanchor/coverage-report.md"
```

**覆盖率报告示例**：

```
SpecAnchor Coverage Report (2026-03-13)
═══════════════════════════════════════

Global Spec:  4 files ✅
Module Spec:  12/20 modules covered (60%)

  ✅ src/modules/auth/          last_synced: 2026-03-10  owner: @zhangsan
  ✅ src/modules/order/         last_synced: 2026-03-08  owner: @lisi
  ⚠️ src/modules/payment/      last_synced: 2026-01-15  STALE (58 days)
  ❌ src/modules/search/        no MODULE.spec.md
  ❌ src/modules/recommend/     no MODULE.spec.md
  ...

Task Spec:  3 active, 47 archived

Warnings:
  ⚠️ payment 模块 Spec 已过期 58 天（代码有 12 次 commit 未同步）
  ⚠️ search 模块近 30 天有 8 次修改但无 Spec 覆盖
```

### 5.4 CI 集成点

```yaml
# CI Pipeline 中增加 SpecAnchor Check 阶段
specanchor-check:
  stage: lint
  script:
    # 1. 检查修改的文件是否属于有 Module Spec 的模块
    - specanchor check-coverage --changed-files

    # 2. 对有 Spec 的模块，检查代码是否违反 Spec 约束
    - specanchor check-consistency --modules auth,order

    # 3. 生成覆盖率报告
    - specanchor report --output .specanchor/coverage-report.md
  rules:
    - if: $CI_MERGE_REQUEST_IID    # 仅在 MR 时触发
  allow_failure: true               # 初期不阻断，仅报告
```

---

## 6. Git 协作机制

### 6.1 Spec 的 YAML Frontmatter 元信息

每个 Spec 文件通过 YAML frontmatter 记录元信息，确保 Git 友好：

```yaml
---
specanchor:
  level: module                     # global | module | task
  version: "2.1.0"                  # 语义化版本
  author: "@zhangsan"               # 创建者（Git 用户名）
  owner: "@zhangsan"                # 当前负责人
  reviewers: ["@lisi"]              # 审批人列表
  last_synced: "2026-03-10"         # 最后一次 Spec-代码同步日期
  status: "active"                  # draft | review | active | deprecated | archived
  created: "2026-02-01"
  updated: "2026-03-10"
---
```

### 6.2 Git 分支策略

```
main (protected)
  │
  ├── spec/global-v1.3              ← Global Spec 变更（需架构组 Review）
  │
  ├── feat/sms-login                ← 功能开发（含 Task Spec + Module Spec 更新）
  │   ├── .specanchor/tasks/2026-03-13_sms-login.spec.md  (Task Spec)
  │   └── src/modules/auth/MODULE.spec.md  (Module Spec 更新)
  │
  └── feat/order-refactor           ← 另一个功能分支
```

**规则**：

- Task Spec 随 feature 分支创建和提交
- Module Spec 的修改随功能分支一起提交（原子性：Spec 变更 + 代码变更在同一个 MR）
- Global Spec 变更走独立分支 + 架构组 Review

### 6.3 Commit 约定

```
# Spec 相关的 commit 使用 spec 类型
spec(auth): 更新认证模块接口契约，增加验证码登录方式
feat(auth): 实现手机验证码登录功能

# Task Spec 生命周期
spec(task): 创建短信登录 Task Spec [RESEARCH]
spec(task): 短信登录 Task Spec 进入 PLAN 阶段
feat(auth): 按 Task Spec 实现验证码发送逻辑 [EXECUTE 1/3]
feat(auth): 按 Task Spec 实现验证码校验逻辑 [EXECUTE 2/3]
spec(task): 短信登录 Task Spec 完成 REVIEW，归档
```

### 6.4 MR (Merge Request) 模板

```markdown
## MR 关联 Spec

### Task Spec
- [ ] `.specanchor/tasks/2026-03-13_sms-login.spec.md` (SDD Phase: REVIEW)

### Module Spec 变更
- [ ] `src/modules/auth/MODULE.spec.md` (v2.0.0 → v2.1.0): 增加验证码登录接口

### SpecAnchor 检查
- [ ] Task Spec 已完成 REVIEW 阶段
- [ ] Module Spec 已同步更新
- [ ] CI SpecAnchor Check 通过（或 Warning 已确认）

### 变更说明
<!-- 此处由 Task Spec 的 Review Verdict 自动填充 -->
```

---

## 7. 与项目共存的形式

### 7.1 方案对比

| 形式                     | 优点                      | 缺点                    | 适合阶段                 |
| ---------------------- | ----------------------- | --------------------- | -------------------- |
| **Cursor Skill**       | 零基建成本；AI 原生支持；即装即用      | 仅 Cursor 用户可用；无 UI 面板 | **Phase 1** 立即启用     |
| **Cursor Rule (.mdc)** | 项目级持久化；所有 Cursor 用户自动加载 | 表达能力有限（纯指令）           | **Phase 1** 配合 Skill |
| **Git Hooks + CI**     | IDE 无关；强制执行             | 只能做检查，不能辅助编写          | **Phase 2** 自动化      |
| **IDE Plugin**         | UI 面板；Spec 可视化；覆盖率仪表盘   | 开发维护成本高；IDE 绑定        | **Phase 3** 可选增强     |
| **CLI 工具**             | IDE 无关；CI/CD 友好；可脚本化    | 用户体验不如 IDE 集成         | **Phase 2** 基础工具     |

### 7.2 推荐实施路径

```
Phase 1: Cursor Skill + Rule（零成本启动）
──────────────────────────────────────────

  ├── .cursor/skills/specanchor/SKILL.md
  │     → 教 AI 如何读取/生成/维护 Spec
  │     → 包含 SDD-RIPER-ONE 的流程指令
  │     → 增加 SpecAnchor 的三级 Spec 支持
  │
  ├── .cursor/rules/specanchor.mdc
  │     → 项目级 Rule：AI 每次编码前自动读取 Global Spec
  │     → 修改模块时自动读取对应 MODULE.spec.md
  │
  └── .specanchor/ 目录结构
        → 手动创建初始 Global Spec
        → 约定 MODULE.spec.md 文件名


Phase 2: CLI + CI 集成（自动化校验）
──────────────────────────────────────────

  ├── npx specanchor init
  │     → 自动扫描项目生成 Global Spec 草稿
  │     → 生成 .specanchor/ 目录结构
  │
  ├── npx specanchor check
  │     → 检查 Spec 覆盖率
  │     → 检查 Spec-代码一致性
  │     → 输出报告
  │
  ├── npx specanchor sync <module>
  │     → AI 辅助同步某个模块的 Spec
  │
  └── CI Pipeline 集成
        → MR 时自动执行 specanchor check


Phase 3: IDE 增强（可选）
──────────────────────────────────────────

  ├── VS Code / Cursor 插件
  │     → Spec 覆盖率侧边栏
  │     → MODULE.spec.md 预览面板
  │     → "新建 Module Spec" 右键菜单
  │
  └── Web Dashboard（可选）
        → 团队级 Spec 覆盖率看板
        → Spec 变更历史时间线
```

### 7.3 Cursor Skill 设计草案

SpecAnchor Skill 是对 SDD-RIPER-ONE Skill 的**上层扩展**，不是替代：

```
SDD-RIPER-ONE Skill（已有）
  → 定义 RIPER 状态机
  → 管理 Task Spec 的创建和流转
  → 约束 AI 的编码行为

SpecAnchor Skill（新增，包裹 SDD-RIPER-ONE）
  → 在 RIPER 启动前，自动加载 Global Spec
  → 在 Research 阶段，自动定位并读取相关 Module Spec
  → 在 Execute 阶段，用 Global + Module Spec 约束代码生成
  → 在 Review 阶段，自动检查 Module Spec 是否需要更新
  → 管理 Module Spec 的创建和维护
```

### 7.4 Cursor Rule 设计草案（`.cursor/rules/specanchor.mdc`）

```markdown
---
description: "SpecAnchor 规范锚定 - AI 编码前自动加载 Spec 约束"
globs: ["**/*.{ts,tsx,js,jsx,vue}"]
alwaysApply: false
---

# SpecAnchor 编码约束

## 编码前必读
1. 在生成或修改任何代码前，先读取 `.specanchor/global/` 下的所有 Global Spec
2. 确定当前修改涉及的模块，读取对应的 `MODULE.spec.md`
3. 如果有活跃的 Task Spec（`.specanchor/tasks/`），检查当前任务是否在 Checklist 中

## 代码生成约束
- 必须遵循 Global Spec 中的编码规范
- 必须遵循 Module Spec 中的接口契约
- 新增的导出 API 必须在 Module Spec 中声明
- 新增的依赖模块必须在 Module Spec 的 depends_on 中声明

## Module Spec 不存在时
- 如果目标模块没有 MODULE.spec.md，在修改前提醒用户
- 建议先创建 Module Spec 再进行修改（"触碰即文档化"）
- 如果用户选择跳过，在 commit 信息中标注 `[NO_SPEC]`
```

---

## 8. 存量项目冷启动方案

### 8.1 Phase 0: 自动生成 Global Spec（1-2 天）

```
输入：项目代码
  ↓
AI 执行 create_codemap(mode=project)
  ↓
AI 分析：
  - package.json / tsconfig.json → 技术栈
  - 目录结构 → 架构模式
  - .eslintrc / .prettierrc → 已有规范
  - 代码模式 → 隐含约定（命名、状态管理、请求方式）
  ↓
输出：Global Spec 草稿（4 个文件）
  ↓
工程师 Review + 补充 → 正式 Global Spec
```

### 8.2 Phase 1: 渐进式 Module Spec（持续进行）

**"触碰即文档化"原则**：不主动为所有模块生成 Spec，而是在以下时机触发：

| 触发条件       | 动作                              |
| ---------- | ------------------------------- |
| 新建模块       | 创建 Module Spec 作为模块的第一个文件       |
| 修改现有模块（首次） | AI 建议生成 Module Spec 草稿，Owner 确认 |
| 重大重构       | 强制要求先更新/创建 Module Spec          |
| 新人接手模块     | 建议创建/完善 Module Spec 作为知识传递      |

### 8.3 冷启动的心理预期管理

| 时间节点   | 预期覆盖率                            | 重点         |
| ------ | -------------------------------- | ---------- |
| 第 1 周  | Global Spec 100%, Module Spec 0% | 建立基线       |
| 第 1 个月 | Module Spec 10-20%               | 覆盖核心模块     |
| 第 3 个月 | Module Spec 40-60%               | 高频修改模块自然覆盖 |
| 第 6 个月 | Module Spec 70%+                 | 接近"健康水位"   |

---

## 9. 风险与缓解

| 风险                         | 严重性  | 缓解策略                                                   |
| -------------------------- | ---- | ------------------------------------------------------ |
| Spec 成为形式主义负担              | 🔴 高 | Task Spec 由 AI 辅助生成，人只需 Review；Global/Module Spec 低频维护 |
| 外包绕过 Spec 流程               | 🟡 中 | CI 检查 + MR 模板强制关联 Spec；Module Spec 变更需工程师 Review       |
| Spec 腐化（代码和 Spec 不一致）      | 🔴 高 | 定期校验 + 覆盖率报告 + Sprint 结束 Spec 同步会                      |
| 团队抵触（"又多了一个文档要写"）          | 🟡 中 | 渐进推行；先从 Global Spec 开始（一次编写，长期受益）；强调 AI 辅助             |
| Global Spec 过于严格导致 AI 生成困难 | 🟡 中 | Global Spec 应定义"原则"而非"实现细节"；留出灵活空间                     |

---

## 10. 社区 SDD 实践调研 & 可吸收经验

### 10.1 主要社区方案对比（2025-2026）

| 方案                  | 定位                        | 核心设计                                                                      | 优点                                                                     | 局限                                   |
| ------------------- | ------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------ |
| **AWS Kiro**        | AI IDE（GA 2025.11）        | 三文件结构（requirements.md → design.md → tasks.md），存放于 `.kiro/specs/`          | 最成熟的商业化 SDD 实现；EARS 格式精确；steering files 提供持久上下文                        | IDE 绑定（只能在 Kiro 内使用）；三文件粒度偏粗（不区分模块级） |
| **SPECLAN**         | VS Code 插件（v0.9, 2026.02） | 层级域模型 Goal→Feature→Requirement→Scenario；7 状态生命周期；Markdown + YAML          | WYSIWYG 编辑器让非技术角色可用；**Codebase Inference 可从代码逆向生成 Spec**；MCP 集成 42+ 工具 | 依赖 VS Code 插件；层级模型偏学术化，团队上手有门槛       |
| **IntentSpec**      | 开放标准（intent.md）           | 单文件标准（objective/outcomes/constraints/edge-cases/health-metrics）；CI/CD 可验证 | **IDE 无关**；JSON Schema 验证；极简轻量                                         | 只覆盖 Task 级，没有 Global/Module 层；不管组织结构 |
| **SpecGuard**       | Markdown 工作流引擎            | 8 步 role-based pipeline；每个 specialist agent 有严格边界                         | 角色隔离做得好；纯 Git 无外部依赖                                                    | 流程偏重；角色定义过于细碎                        |
| **GitHub Spec Kit** | CLI 框架                    | 跨 feature 分析 + 冲突检测；支持 Claude Code / Copilot                              | **系统思维**：发现不同 spec 之间的冲突；开源                                            | 生态还不成熟                               |
| **OpenSpec**        | 扩展框架（v1.0, 2026）          | 自定义 schema；支持 AsyncAPI 生成                                                 | 灵活的 schema 扩展机制；事件驱动架构支持                                               | 标准仍在早期                               |
| **Living ADRs**     | ADR + AI 集成               | AI 从 PR 自动生成 ADR；AGENTS.md 作为 AI 控制面板                                     | **架构决策文档化**自动化；CI 中 AI 代码审查强制执行 ADR 合规                                 | 偏向决策记录，不覆盖实现规范                       |

**参考链接**：

| 方案              | 链接                                                                                                                                                                                                                                    |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS Kiro        | [kiro.dev](https://kiro.dev) / [SDD Best Practices](https://kiro.directory/blog/best-practices-spec-driven-development) / [Spec 使用指南](https://kiro.dev/docs/guides/learn-by-playing/05-using-specs-for-complex-work)                  |
| SPECLAN         | [speclan.net](https://speclan.net) / [VS Code 插件](https://marketplace.visualstudio.com/items?itemName=DigitalDividend.speclan-vscode-extension) / [v0.9 发布说明](https://speclan.net/news/2026-02-21-releasev0-9/)                       |
| IntentSpec      | [intentspec.org](https://intentspec.org)                                                                                                                                                                                              |
| GitHub Spec Kit | [GitHub Blog 介绍](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit) / [详细文档](https://intent-driven.dev/knowledge/spec-kit/)                                      |
| OpenSpec        | [OpenSpec 自定义 Schema](https://intent-driven.dev/blog/2026/02/12/openspec-custom-schemas/)                                                                                                                                             |
| SpecWeave       | [spec-weave.com](https://spec-weave.com)                                                                                                                                                                                              |
| SpecMem         | [super-agentic.ai/specmem](https://super-agentic.ai/specmem/)                                                                                                                                                                         |
| MetaSpec        | [GitHub - ACNet-AI/MetaSpec](https://github.com/ACNet-AI/MetaSpec)                                                                                                                                                                    |
| Living ADRs     | [brainfork.is/blog/adrs](https://brainfork.is/blog/brainfork-adrs) / [AI ADR Code Review](https://shinglyu.com/blog/2026/03/01/ai-adr-code-review.html)                                                                               |
| SDD 综合指南        | [productbuilder.net/sdd](https://www.productbuilder.net/learn/spec-driven-development) / [oshy.tech/sdd](https://oshy.tech/en/blog/spec-driven-development-ia/) / [zencoder.ai/sdd](https://zencoder.ai/blog/spec-driven-development) |

### 10.2 关键趋势

1. **Spec 从"人读文档"变成"机器可读约束"**：IntentSpec 的 JSON Schema 验证、Kiro 的 steering files、AGENTS.md 作为 AI 控制面板——所有方案都在让 Spec 从被动的文档变成主动的约束。
2. **Codebase Inference（代码逆向生成 Spec）**：SPECLAN 的杀手特性。解决了我们最关心的"存量项目冷启动"问题——AI 读代码 → 自动生成 Spec 草稿 → 人确认。
3. **Spec 状态生命周期管理**：SPECLAN 的 7 状态模型（Draft → Review → Approved → In-Development → Under-Test → Released → Deprecated）比我们当前的简单状态更完善。
4. **MCP 集成是关键桥梁**：SPECLAN 通过 MCP 让任何 AI 助手（Cursor/Windsurf/Claude Code）都能读取 Spec。这与 SpecAnchor 的 IDE 无关目标高度一致。
5. **跨 Spec 冲突检测**：GitHub Spec Kit 的"系统思维"——不只看单个 Spec，而是检测多个 Spec 之间是否存在矛盾或依赖冲突。

### 10.3 SpecAnchor 可吸收的设计

| 来源                  | 可吸收的设计                        | 吸收方式                                                            |
| ------------------- | ----------------------------- | --------------------------------------------------------------- |
| **SPECLAN**         | Codebase Inference（代码逆向 Spec） | 纳入冷启动方案：`specanchor infer <module>` 命令                          |
| **SPECLAN**         | 7 状态生命周期                      | 增强 Module Spec 的 status 字段（当前只有 active/deprecated/draft）        |
| **IntentSpec**      | JSON Schema 验证                | 为 YAML frontmatter 定义 JSON Schema，CI 中自动校验 Spec 格式合规性           |
| **IntentSpec**      | health-metrics 字段             | 在 Module Spec 模板中增加"健康指标"章节（如 API 响应时间、错误率阈值）                   |
| **Kiro**            | EARS 格式的需求表达                  | 可选引入到 Task Spec 的 Requirements 章节（"When X, the system shall Y"） |
| **GitHub Spec Kit** | 跨 Spec 冲突检测                   | Phase 2 CLI 工具中加入 `specanchor check-conflicts`                  |
| **Living ADRs**     | AGENTS.md 作为 AI 控制面板          | 与 `.cursor/rules/specanchor.mdc` 定位一致，可互补                       |
| **SPECLAN**         | MCP 集成                        | Phase 2 暴露 Spec 为 MCP Resource，任何 AI 工具都能读取                     |

### 10.4 与 SpecAnchor 定位最接近的方案

SpecAnchor 的定位是"Spec 组织管理工具"——管理文件结构、状态生命周期、角色权限、覆盖率。社区中与这个定位**最接近**但不完全对等的方案有三个：

| 方案            | 与 SpecAnchor 的重叠           | 关键差异                                                                                                                           |
| ------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **SPECLAN**   | 层级组织 + 生命周期管理 + Git 原生     | 层级是**任务分解维度**（Goal→Feature→Requirement→Scenario→AC→Test），不是**作用域维度**（Global→Module→Task）；且绑定了自己的写作工具（VS Code 插件 + WYSIWYG 编辑器） |
| **SpecWeave** | 生命周期管理 + 多 Agent 协作 + 质量门禁 | 更偏向**自动化执行平台**（自动规划、拆分、实现、测试、同步 JIRA/GitHub）；不是轻量级组织框架，而是全流程引擎                                                                 |
| **SpecMem**   | 跨工具 Spec 聚合 + 关系图谱 + 覆盖度   | 定位为**Agent 统一记忆层**（解决 Agent 健忘症）；是企业级平台方案，不是项目内文件约定                                                                            |

**快速体验链接**：

- SPECLAN：直接安装 [VS Code 插件](https://marketplace.visualstudio.com/items?itemName=DigitalDividend.speclan-vscode-extension)，在任意项目中 `speclan/` 目录下体验层级 Spec 管理
- SpecWeave：访问 [spec-weave.com](https://spec-weave.com) 了解全流程自动化
- SpecMem：访问 [super-agentic.ai/specmem](https://super-agentic.ai/specmem/) 了解 Agent 记忆层方案

**结论：SpecAnchor 所处的生态位——"轻量级、文件驱动、写作工具无关的 Spec 组织框架"——在社区中是一个空白。**

原因分析：

- 大多数方案把**组织**和**写作**绑定在一起（SPECLAN = 组织 + 编辑器，SpecWeave = 组织 + 自动执行）
- SpecAnchor 选择只做组织层，把写作交给已有工具（SDD-RIPER、SPECLAN、手写等），这种"Unix 哲学"式的解耦在社区还没有先例
- 这是 SpecAnchor 的差异化优势，也是风险——需要证明"纯组织层"足够有独立价值

### 10.5 SpecAnchor 的差异化定位

对比社区方案，SpecAnchor 的独特价值在于：

```
社区方案普遍解决的问题：
  "如何让 AI 按 Spec 写代码"（单次任务的 Spec → 代码）

SpecAnchor 额外解决的问题：
  "如何管理项目中所有 Spec 的生命周期"（多人协作的 Spec 治理）
```

具体差异：

| 维度        | 社区主流方案        | SpecAnchor                       |
| --------- | ------------- | -------------------------------- |
| Spec 层级   | 单层（Task 级）    | 三层（Global → Module → Task）       |
| 角色管理      | 无 / 弱         | 工程师 vs 外包权限矩阵                    |
| Spec-代码同步 | 单向（Spec → 代码） | 单向主导 + 定期校验                      |
| 覆盖率指标     | 无             | Spec 覆盖率仪表盘                      |
| 写作工具绑定    | 绑定特定工具        | **不绑定**（可调用 SDD-RIPER、SPECLAN 等） |

---

## 11. SpecAnchor 的架构定位（修订）

### 11.1 核心定位：Spec 的组织管理工具

**SpecAnchor 是 Spec 文档的"Git"，不是 Spec 的"IDE"。**

```
┌─────────────────────────────────────────────────────────┐
│                    Spec 写作工具（可插拔）                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │SDD-RIPER │  │ SPECLAN  │  │ IntentSpec│  │ 手写   │  │
│  │ -ONE     │  │          │  │          │  │        │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       │              │              │             │      │
│  ─ ─ ─│─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ │─ ─  │
│       ▼              ▼              ▼             ▼      │
│  ┌──────────────────────────────────────────────────┐    │
│  │              SpecAnchor                          │    │
│  │  ── Spec 组织管理层 ──                            │    │
│  │                                                  │    │
│  │  • 三级 Spec 体系（Global/Module/Task）           │    │
│  │  • 文件结构约定（.specanchor/ + MODULE.spec.md）   │    │
│  │  • 角色权限矩阵（工程师/外包）                     │    │
│  │  • Spec 状态生命周期                              │    │
│  │  • 覆盖率指标 & 一致性校验                        │    │
│  │  • 跨 Spec 冲突检测                              │    │
│  └──────────────┬───────────────────────────────────┘    │
│                 │                                        │
│  ─ ─ ─ ─ ─ ─ ─ │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│                 ▼                                        │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Spec 消费层                          │    │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌───────┐  │    │
│  │  │Cursor  │  │CI/CD   │  │Code    │  │ MCP   │  │    │
│  │  │Rules   │  │Pipeline│  │Review  │  │Server │  │    │
│  │  └────────┘  └────────┘  └────────┘  └───────┘  │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 11.2 SpecAnchor 与 SDD-RIPER-ONE 的关系（修订）

```
SpecAnchor   = "图书馆"：管理所有 Spec 的存放、索引、权限、状态
SDD-RIPER-ONE = "作家"：按流程创作高质量的 Task Spec

SpecAnchor 不依赖 SDD-RIPER-ONE
  → 团队可以手写 Spec、用 SPECLAN 写、用 AI 对话生成
  → SpecAnchor 只关心：Spec 放在哪、格式对不对、谁在维护、有没有过期

SDD-RIPER-ONE 不依赖 SpecAnchor
  → 单人开发者可以只用 SDD-RIPER-ONE 管理 Task Spec
  → 不需要三级体系和覆盖率检查

两者结合使用是最佳实践：
  → SpecAnchor 提供 Global + Module Spec 上下文
  → SDD-RIPER-ONE 在这个上下文约束下生成 Task Spec 并执行
  → 执行结果反馈给 SpecAnchor 更新覆盖率和同步状态
```

### 11.3 Module Spec 状态生命周期（吸收 SPECLAN 设计）

```
Draft ──→ Review ──→ Active ──→ Deprecated
  ↑          │                      │
  └──────────┘                      ↓
  （Review 未通过）              Archived

状态说明：
  Draft:      草稿，AI 初始生成或人工创建，尚未审核
  Review:     等待工程师 Review
  Active:     正式生效，AI 编码时必须读取
  Deprecated: 已废弃（模块重构/删除），保留历史参考
  Archived:   归档，不再在 Active Spec 列表中显示
```

---

## 12. 总结

### SpecAnchor 的核心价值

```
不是让人多写文档，而是让 AI 少犯错误。

不是增加流程负担，而是把隐性约定变成显性约束。

不是追求完美覆盖，而是让最重要的模块先有 Spec。

不是绑定某个写作工具，而是为所有工具提供组织框架。
```

### 一句话定义

> **SpecAnchor = 三级 Spec 体系 + 角色权限矩阵 + 单向主导同步 + 渐进式覆盖**
>
> 它是 Spec 的"组织管理工具"，不是"写作工具"。可以调用 SDD-RIPER、SPECLAN 等写作引擎，但自身只关心 Spec 的结构、状态、权限和一致性。

---

## 附录 A: SpecAnchor 配置文件模板

```yaml
# .specanchor/config.yaml

specanchor:
  version: "0.1.0"
  project_name: "my-project"

  # Spec 路径配置
  paths:
    global_specs: ".specanchor/global/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    project_codemap: ".specanchor/project-codemap.md"
    module_spec_filename: "MODULE.spec.md"    # Module Spec 固定文件名

  # 角色配置（两类角色）
  roles:
    engineer:
      members: ["@zhangsan", "@lisi", "@wangwu"]
      permissions:
        - "global_spec:write"
        - "module_spec:write"
        - "task_spec:create"
        - "task_spec:approve"
        - "fast_mode:allowed"
    contractor:
      members: ["@extern-01", "@extern-02"]
      permissions:
        - "global_spec:read"
        - "module_spec:write"           # 需工程师 Review
        - "task_spec:create"
        - "fast_mode:allowed"

  # 覆盖率配置
  coverage:
    scan_paths:
      - "src/modules/**"
      - "src/components/**"
    ignore_paths:
      - "src/components/ui/**"
      - "src/**/*.test.*"
      - "src/**/*.stories.*"
    thresholds:
      module_spec_coverage: 60          # 目标覆盖率 %
      stale_days: 30                    # 超过 N 天未同步标记为过期

  # 同步配置
  sync:
    auto_check_on_mr: true              # MR 时自动检查
    sprint_sync_reminder: true          # Sprint 结束提醒同步
    stale_notification: true            # 过期 Spec 通知 Owner
```

## 附录 B: 术语表

| 术语              | 含义                                            |
| --------------- | --------------------------------------------- |
| SpecAnchor      | 规范锚定体系，本文档定义的 Spec 管理机制                       |
| Global Spec     | L1 全局规范：编码标准、架构约定、设计系统规则                      |
| Module Spec     | L2 模块规范：模块职责、接口契约、业务规则                        |
| Task Spec       | L3 任务规范：单次任务的 SDD-RIPER 执行计划                  |
| MODULE.spec.md  | Module Spec 的固定文件名（就近放置于模块目录）                 |
| Spec 覆盖率        | 有 Module Spec 的模块数 / 扫描范围内总模块数                |
| Project Codemap | 项目级全景图：跨模块结构、核心流程，纳入版控                        |
| 触碰即文档化          | 修改模块时触发 Module Spec 的创建/更新                    |
| 正向流             | Spec → 代码的主流程（Spec 驱动代码生成）                    |
| 逆向流             | 代码 → Spec 的补偿流程（定期校验 + 同步建议）                  |
| RIPER           | Research → Innovate → Plan → Execute → Review |
| SDD             | Spec-Driven Development，规范驱动开发                |
