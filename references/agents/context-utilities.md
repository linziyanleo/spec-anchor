# Context Utilities

SpecAnchor v0.6 提供的 context 装配 / 记录 / 沉淀能力。**这不是 agent execution loop**——SpecAnchor 不拥有 agent loop，只提供 utilities，由 agent / harness 自己组装工作流。

> 老的 7 步 deterministic loop（agent-contract.md）已拆分：步骤 1/2/6 → 本文（context utility）；步骤 3/4/5/7 → `references/integrations/sdd-riper-one-flow.md`（opt-in workflow）。

---

## 1. Enter Context Landscape

Session 起步装配上下文。

```bash
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-boot.sh"
```

- `--format=summary`：人类可读概览
- `--format=full`：附带 Global Spec 正文
- `--format=json`：机器可读
- `--agent --intent "<intent>"`：**v0.6 新增**——直接包装 assemble 输出 preflight context bundle，agent 无需再跑第二步

**输出 Assembly Trace**：每轮必须显式输出，说明本轮加载了哪些 spec / decision / evidence / finding、是 summary 还是 full、freshness 如何。完整规则见 `references/assembly-trace.md`。

不要在 boot 有 blocking errors 时继续编辑代码。

## 2. Resolve Anchors（精准装配）

当文件路径与任务意图已明确时，跑 assemble 拿 bounded context bundle：

```bash
specanchor-assemble.sh --files=<paths> --intent="<description>"
```

- `--format=json` → 输出 `specanchor.assembly.v1`（默认，向后兼容）
- `--format=json --bundle-schema=context_bundle.v1` → **v0.6 新增** `specanchor.context_bundle.v1`，含 layers / freshness / freshness_reasons / source_type / confidence
- 读完 `files_to_read` 中列出的所有文件
- 如果 `missing` count > 0 且本次涉及行为变更，先创建 Module Spec / Task Spec

**Lazy-load findings**（v0.6 新增；仅在 `--format=json --bundle-schema=context_bundle.v1` 且 `--files=` 非空时启用）：

- 扫描 `.specanchor/findings/*.md`，按 `affects.path` / `affects.module` 命中 `--files=` 目标文件做分级载荷
  - `visibility: immediate` → 入 layers.finding，`load=full`（带完整 body）
  - `visibility: sediment_queue` → 入 layers.finding，`load=summary`（仅含 frontmatter `summary` 字段）
  - `visibility: handoff` → 入 layers.finding，`load=title`（仅 id + summary，无 body）
  - `visibility: hidden` → 不进 bundle
- 桶排序：precision desc（path > module > none）→ impact desc（high > medium > low）→ created desc
- `--max-findings=N` 覆写共享桶 cap（默认 50；`anchor.yaml.findings.max_per_bundle` 可项目级覆写；immediate 桶不受 cap）
- 截断时以前缀 `finding_cap_truncated:` 追加到 `warnings[]` string array（保持 schema 向后兼容）
- bundle `agent_instructions[]` 会带三条 hint，告诉 agent finding load 字段语义

boot 与 assemble 共存：
- `boot --agent --intent` 适用于 session 起步（agent 还不知道该读什么）
- `assemble --files --intent` 适用于已知目标文件、要精准上下文的场景

## 3. Record Hot Context（agent 写回入口）

执行中发现的新事实**不要散落在聊天里**——写入 `.specanchor/findings/`：

```bash
# 推荐方式（自动校验 summary 字段，赋 id，派生 visibility）：
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-finding.sh" new \
  --topic=<slug> \
  --summary="<≤120 字符单行：主语 + 事实 + 锚点>" \
  --type=<stale-claim|missing-coverage|...> \
  --confidence=<low|medium|high> \
  --impact=<low|medium|high>

# 手工方式（仅在脚本不可用时）——cp 后必须立即编辑 summary 字段，
# 否则 candidate 状态下 specanchor-validate.sh 会 fail：
cp references/templates/finding-template.md .specanchor/findings/F-$(date +%Y%m%d)-NNN-<topic>.md
```

Finding frontmatter 必须含 `id` / `summary` / `type` / `status` / `confidence` / `impact` / `visibility` / `affects` / `evidence_ref`。`summary` 是 v0.6 新增必需字段（≤120 字符单行；主语 + 事实 + 锚点；`<...>` 占位串会被拒绝）；driven the lazy-load tier in §2 above。具体见 `references/concepts/findings-ledger.md`。

**关键原则**：
- `candidate finding ≠ spec fact`
- `accepted finding ≠ 自动 update global/module spec`
- low confidence / low impact finding 默认 `visibility: hidden`——保留但不打扰

## 4. Alignment Check（context drift 检测）

编辑完成后验证 spec 与 code 是否同步：

```bash
# Spec 文件被修改 → 校验格式 / frontmatter
specanchor-doctor.sh && specanchor-validate.sh

# Code 文件被修改 → task-scoped module 对齐检测
specanchor-check.sh task <spec-file>
```

报告应包含：anchors used、files changed、verification results、remaining drift（含 context drift：finding 引用的代码文件已变 / evidence 命令未重跑）。

## 5. Propose Sediment（hot → cold 安全回流）

当某个 `visibility=sediment_queue` 的 finding 应该变成长期 spec 时，**不要让 agent 直接改 Module/Global Spec**——生成 Sediment Proposal：

```
.specanchor/sediment/proposals/SP-YYYYMMDD-<topic>.md
```

Proposal frontmatter 必须含 `source_findings` / `target` / `operation`（append / replace / supersede / deprecate / delete / merge）。具体见 `references/concepts/sediment-proposal.md`。

人 batch review proposal 后才决定是否 apply。Proposal 可以走 GitHub PR 流程作为 review surface。

---

## What This is NOT

- **Not an agent execution contract**：SpecAnchor 不规定 agent 必须按 1→2→3→4→5 顺序执行。这只是可用的 utility 集合。
- **Not a runtime enforcer**：advisory stop trigger 不会真正阻断 agent 行为。需要硬阻断时配 hooks / CI / pre-commit。
- **Not a substitute for sdd-riper-one**：需要 strict workflow（Plan Approved gate / Phase Checkpoint）时，opt-in `sdd-riper-one` schema，见 `references/integrations/sdd-riper-one-flow.md`。

## Must Never Do

- 不要让 agent 把未经 sediment 的 finding 直接写入 Global / Module Spec
- 不要把 `advisory` stop trigger 标记为可执行边界
- 不要跳过 boot 直接编辑代码（错失 missing context 警告）
- 不要在 missing module spec 时凭空发明业务规则
- 不要把 shell script 名称当作用户面的命令语言（自然语言才是主入口）
