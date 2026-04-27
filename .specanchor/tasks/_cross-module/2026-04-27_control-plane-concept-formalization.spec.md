---
specanchor:
  level: task
  task_name: "控制平面概念写入与模板强化"
  author: "@fanghu"
  assignee: "@fanghu"
  reviewer: "@fanghu"
  created: "2026-04-27"
  status: "review"
  last_change: "Execute 完成，进入 Review"
  related_modules: []
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: ""
---

# SDD Spec: 控制平面概念写入与模板强化

> Current RIPER Phase: REVIEW

## 0. Open Questions

- [x] SpecAnchor 作为"控制平面"的定位表述应该是什么？→ "让人类能够安全放权给 Agent 的规格控制平面"
- [x] 文章中的概念在 SpecAnchor 中的命名映射？→ Spec Landscape / Alignment Surface / Spec Sediment
- [x] Sediment 子段加在 Review Verdict 中的哪个位置？→ 作为 §6 Review Verdict 内的 bullet 扩展，不用 §6.1 小节号（避免与多项目 §6.1 Touched Projects 冲突）
- [x] README 定位表述的措辞？→ 中英文双语 README 同步更新
- [x] schema.yaml 是否需要同步更新？→ 是，review artifact 的 description 需要反映 Sediment

## 1. Requirements (Context)

- **Goal**: 将"SpecAnchor = 规格控制平面"的概念正式写入项目文档，强化 Task Spec 模板中缺失的"经验沉淀"段
- **In-Scope**:
  - `README.md` + `README_ZH.md` 定位表述同步更新
  - Task Spec 模板（`references/schemas/sdd-riper-one/template.md`）Review Verdict 增加 Sediment bullets
  - `references/schemas/sdd-riper-one/schema.yaml` review artifact description 同步更新
  - `references/task-spec-template.md` 单项目和多项目模板同步更新（单项目增加 Sediment bullets，多项目在 §6 bullets 和 §6.1 Touched Projects 之间增加 Sediment bullets）
  - `mydocs/idea.md` 附录 B 术语表新增 3 个术语
- **Out-of-Scope**:
  - 新增 CLI 命令 / YAML 协议
  - SKILL.md Agent 循环补全（Step 2）
  - Assembly Trace 格式变更（Step 3）
  - `specanchor-protocol.md` 变更（Protocol 文档暂不改）

## 1.1 Context Sources

- Requirement Source: `mydocs/specs/2026-04-27_18-05_SpecAnchor-ControlPlane-Research.md`
- Design Refs: `mydocs/idea.md` 附录 D
- Chat/Business Refs: 《把工程任务交给 Agent》文章分析 + ChatGPT 审查 + Code Review 反馈
- Extra Context: N/A

## 1.5 Codemap Used

- Codemap Mode: N/A（非代码变更任务，涉及文档/模板编辑）
- Key Index:
  - `README.md` L38-42 — "What SpecAnchor Is" 段
  - `README_ZH.md` L38-42 — "SpecAnchor 是什么" 段
  - `references/schemas/sdd-riper-one/template.md` L96-103 — §6 Review Verdict
  - `references/schemas/sdd-riper-one/schema.yaml` L43-46 — review artifact
  - `references/task-spec-template.md` L106-117 — 单项目 §6, L244-262 — 多项目 §6+§6.1
  - `mydocs/idea.md` L1090-1106 — 附录 B 术语表

## 2. Research Findings

研究已在独立报告中完成，核心结论：

- **定位**：SpecAnchor 是 **spec control plane**（规格控制平面），不是多 Agent runtime。它管 Spec Landscape、Schema Gate、Alignment Surface、Spec Sediment；不管 Agent 调度、代码执行、全栈测试。
- **术语**：Spec Landscape（规格地形）/ Alignment Surface（对齐面）/ Spec Sediment（规格沉淀）
- **模板缺口**：Review Verdict 缺少显式 Sediment bullets；schema.yaml 的 review description 未反映 Sediment

## 2.1 Next Actions

- Plan Approved 后进入 Execute

## 3. Innovate

### Skip
- Skipped: true
- Reason: 变更范围明确，不涉及架构决策

## 4. Plan (Contract)

### 4.1 File Changes

1. **`README.md`** L40 段落：在现有 "What SpecAnchor Is" 描述后追加一句控制平面定位
2. **`README_ZH.md`** L40 段落：同步中文版
3. **`references/schemas/sdd-riper-one/template.md`** §6 Review Verdict：在 "Module Spec 需更新" 行后增加 Sediment bullets
4. **`references/schemas/sdd-riper-one/schema.yaml`** review artifact：更新 description 加入 Sediment
5. **`references/task-spec-template.md`**：
   - 变体 1 单项目模板 §6：增加 Sediment bullets（位于 "Module Spec 需更新" 行后）
   - 变体 1 多项目模板 §6：增加 Sediment bullets（位于 "Module Spec 需更新" 行后，在 §6.1 Touched Projects 之前）
6. **`mydocs/idea.md`** 附录 B 术语表：新增 3 行（Spec Landscape / Alignment Surface / Spec Sediment）

### 4.2 Signatures

N/A（非代码变更）

### 4.3 Implementation Checklist

- [ ] 1. 更新 `README.md` — "What SpecAnchor Is" 段追加控制平面定位句
- [ ] 2. 更新 `README_ZH.md` — "SpecAnchor 是什么" 段同步中文版
- [ ] 3. 更新 `references/schemas/sdd-riper-one/template.md` — §6 增加 Sediment bullets
- [ ] 4. 更新 `references/schemas/sdd-riper-one/schema.yaml` — review artifact description
- [ ] 5. 更新 `references/task-spec-template.md` — 单项目和多项目模板 §6 增加 Sediment bullets
- [ ] 6. 更新 `mydocs/idea.md` 附录 B 术语表 — 新增 3 个术语
- [ ] 7. 自检所有变更的一致性（术语/措辞/heading 编号）

## 5. Execute Log

- [x] Step 1: `README.md` L42 — 新增 "spec control plane" 段落，含 Spec Landscape / Schema Gates / Alignment Surface / Spec Sediment 四个术语
- [x] Step 2: `README_ZH.md` L42 — 同步中文版，含对应中文术语（规格地形/门禁/对齐面/规格沉淀）
- [x] Step 3: `references/schemas/sdd-riper-one/template.md` — §6 Review Verdict 增加 Sediment bullets（3 行）
- [x] Step 4: `references/schemas/sdd-riper-one/schema.yaml` — review artifact description 加入 Spec Sediment 说明
- [x] Step 5: `references/task-spec-template.md` — 单项目 §6（L113）和多项目 §6（L256）均增加 Sediment bullets
- [x] Step 6: `mydocs/idea.md` 附录 B 术语表 — 新增 Spec Landscape / Alignment Surface / Spec Sediment 3 行
- [x] Step 7: 自检一致性 — 4 个术语在中英文 README 中完全对应；3 个 Sediment 位置格式一致

## 6. Review Verdict

- Spec coverage: PASS — 所有计划中的文件均已变更
- Behavior check: PASS — 纯文档/模板变更，无运行时影响
- Regression risk: Low — 不涉及脚本逻辑、Schema 结构或 frontmatter schema 变更
- Module Spec 需更新: No
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: No
  - 新发现的项目规则: 中英文 README 定位段落必须同步更新，建议在 `.specanchor/global/` 或贡献指南中记录此规则
  - 值得记录的反模式: 避免在 §6 内使用编号子节（如 §6.1）定义新概念——多项目模板已占用 §6.1 Touched Projects
- Follow-ups:
  - Step 2: SKILL.md 或 agent-contract.md 中补全 Agent 完整循环（D.4）
  - Step 3: Assembly Trace 增加 Landscape Readiness 指标

## 7. Plan-Execution Diff

- 无偏差。所有 7 步 Checklist 按计划完成，未增减文件或变更范围。
