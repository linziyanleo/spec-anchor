---
specanchor:
  level: task
  task_name: "单文件 module_path 健康度误判与 module 定义调研"
  author: "方壶"
  created: "2026-04-22"
  status: "draft"
  last_change: "记录单文件 module_path 被误判为 STALE 的问题、复现证据、协议冲突与后续建议。"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "research"
  research_phase: "CONCLUSION"
  branch: "main"
---

# Research: 单文件 module_path 健康度误判与 module 定义调研

## 1. Research Question
- **核心问题**: 当前 `specanchor-index.sh`、`specanchor-check.sh`、`specanchor-status.sh` 会将单文件页面对应的 Module Spec 标记为 `STALE`，这是否是 bug，还是系统本来只支持目录级 module？
- **调研范围**: `scripts/specanchor-index.sh`、`scripts/specanchor-check.sh`、`scripts/specanchor-status.sh`、`scripts/specanchor-resolve.sh`、`scripts/specanchor-validate.sh`、`scripts/specanchor-doctor.sh` 以及 `references/` 下关于 `module_path` / `module` 的协议文档。
- **范围边界（不调研什么）**: 本次不直接修改脚本实现，不设计完整的块级 module 数据模型，不引入新的存储结构或解析器。
- **成功标准（什么算调研完成）**: 明确当前仓库对 module 是否已有一致定义；确认单文件 `module_path` 是否应被视为合法；给出最小后续动作建议。
- **决策背景**: 用户观察到“单文件页面的 spec 在索引里显示成 `STALE`，不是因为 spec 缺失，而是健康度计算只认目录不认文件路径”，并进一步提出“单文件，甚至单文件内的一块代码也可以是 module”。

## 2. Explore
### 2.1 调研方法
- 文档阅读：读取 `specanchor_task`、`specanchor_check`、`specanchor_index`、`specanchor_module`、`specanchor_infer`、协议与模板文档。
- 代码分析：对比 `index`、`check`、`status`、`resolve`、`validate`、`doctor` 中 `module_path` 或路径存在性判断的逻辑。
- 最小复现：在临时 git 仓库中构造单文件 `module_path: "src/pages/home.tsx"` 的 Module Spec，观察索引、检查与解析结果。
- 覆盖度核实：确认本调研涉及文件已被 `scripts` / `references` 两个 Module Spec 覆盖。

### 2.2 调研过程
#### 方向 1: 行为层复现
- 调研内容: 检查健康度计算是否真的只接受目录。
- 关键发现:
  - `scripts/specanchor-index.sh` 的 `compute_health()` 在 `last_synced` 为空或 `[[ ! -d "$module_path" ]]` 时直接返回 `STALE`。
  - `scripts/specanchor-check.sh` 内有两处 `[[ ! -d "$module_path" ]]` / `[[ ! -d "$mp" ]]`，都会直接给出 `STALE (invalid module_path)`。
  - `scripts/specanchor-status.sh` 在汇总模块健康度时也用 `[[ ! -d "$mp" ]]`，会把存在的单文件路径直接计入 `STALE`。
  - 以 `module_path: "src/pages/home.tsx"` 做最小复现时，`index` 输出 `health: STALE`，`check module` 输出 `STALE (invalid module_path)`，`status` 汇总显示 `🟠1 STALE`。
- 数据/证据:
  - `scripts/specanchor-index.sh:99`
  - `scripts/specanchor-check.sh:313`
  - `scripts/specanchor-check.sh:478`
  - `scripts/specanchor-status.sh:148`
  - 复现输出:
    - `health: STALE`
    - `STALE (invalid module_path)`
    - `健康度: 🟢0 FRESH  🟡0 DRIFTED  🟠1 STALE  🔴0 OUTDATED`

#### 方向 2: 路径匹配与合法性判断
- 调研内容: 检查仓库其他能力是否已经把 `module_path` 当成“任意已有路径”使用，以及哪些脚本不受这个目录假设影响。
- 关键发现:
  - `scripts/specanchor-resolve.sh` 的 freshness 计算直接执行 `git log -- <module_path>`，不要求路径是目录。
  - `scripts/specanchor-resolve.sh` 的模块匹配使用 `[[ "$target_file" == "$module_path"* ]]`，对文件路径同样成立。
  - `scripts/specanchor-validate.sh` 用 `[[ ! -e "$module_path" ]]` 判断无效路径，天然接受文件和目录。
  - `scripts/specanchor-doctor.sh` 的 `! -d` 检查只用于 `.specanchor/`、Global Spec 目录和 `source` 目录，不针对 `module_path`，不属于这次误判链路。
  - 最小复现中，`resolve` 能正确将 `src/pages/home.tsx` 命中对应 Module Spec，并给出 `fresh`。
- 数据/证据:
  - `scripts/specanchor-resolve.sh:227`
  - `scripts/specanchor-resolve.sh:493`
  - `scripts/specanchor-validate.sh:107`
  - `scripts/specanchor-doctor.sh:219`
  - `scripts/specanchor-doctor.sh:222`
  - `scripts/specanchor-doctor.sh:253`
  - 复现输出:
    - `File path src/pages/home.tsx is inside module_path src/pages/home.tsx.`
    - `freshness: fresh`

#### 方向 3: 协议与文档定义
- 调研内容: 检查文档对 module 的定义是否一致。
- 关键发现:
  - `references/commands/module.md` 与 `references/commands/infer.md` 明写“模块目录路径”与“扫描模块目录下所有代码文件”。
  - `references/specanchor-protocol.md` 的自动加载规则也沿用“位于某模块目录下”的表述。
  - 但 `references/module-spec-template.md` 对 `module_path` 的说明是“模块相对路径（从项目根开始）”，没有限制必须为目录。
  - 仓库中当前没有 `scripts/specanchor-infer.sh`，因此 `infer` 目前主要是 Agent 协议文档；若要支持单文件 infer，文档必须补足“扫描什么”和“如何推断”的语义。
  - 任务覆盖度判断本质上依赖路径前缀匹配，而不是目录语义。
- 数据/证据:
  - `references/commands/module.md:9`
  - `references/commands/module.md:14`
  - `references/commands/infer.md:9`
  - `references/specanchor-protocol.md:158`
  - `references/module-spec-template.md:86`
  - `scripts/` 下无 `specanchor-infer.sh`

### 2.3 实验/原型（如有）
- 实验目的: 验证单文件 `module_path` 在现有系统中到底是“完全不支持”还是“部分支持但状态判断错误”。
- 实验方法:
  - 创建临时 git 仓库。
  - 新建 `src/pages/home.tsx`。
  - 写入 Module Spec，设置 `module_path: "src/pages/home.tsx"` 与 `last_synced: "2026-04-22"`。
  - 运行 `scripts/specanchor-index.sh`、`scripts/specanchor-check.sh module ...`、`scripts/specanchor-status.sh`、`scripts/specanchor-resolve.sh --files=src/pages/home.tsx`。
- 实验结果:
  - `index` 判为 `STALE`。
  - `check module` 判为 `STALE (invalid module_path)`。
  - `status` 汇总将该模块计入 `🟠1 STALE`。
  - `resolve` 成功命中并显示 `fresh`。
  - 结论不是“单文件 spec 不存在”，而是“系统内部对单文件路径的语义不一致”。

## 3. Findings
### 3.1 关键事实
1. 当前仓库没有“明确且一致”的 module 定义；文档层偏目录语义，实现层已经部分支持路径语义。
2. 单文件 `module_path` 的误判是已复现的真实问题，不是用户误读。
3. `index`、`check`、`status` 仍使用目录存在性判断，`resolve` 与 `validate` 已接受文件路径，系统行为互相矛盾。
4. 修复不能只把 `-d` 改成 `-e`；还必须保证“路径存在（目录或文件）→ 进入正常健康度流程，路径不存在 → 才输出 `invalid module_path`”。
5. 如果团队认可“单文件也可以是 module”，那么当前 `STALE` 结果是 bug，而不是合理退化。
6. “单文件内的一块代码也可以是 module”在理念上可成立，但现有模型没有 `symbol`、`range`、`selector` 之类字段承载它，当前系统还不能把块级边界作为一等对象。

### 3.2 对比分析（如有多方案）
| 维度 | 方案 A：坚持目录级 module | 方案 B：正式支持路径级 module（目录或文件） | 方案 C：立即支持块级 module |
|------|---------------------------|-------------------------------------------|-----------------------------|
| 与当前 `module_path` 字段契合度 | 高 | 高 | 低 |
| 与现有 `resolve` / `validate` 一致性 | 中 | 高 | 低 |
| 修复当前误判成本 | 低 | 低 | 高 |
| 对用户心智的自然程度 | 中 | 高 | 中 |
| 实现复杂度 | 低 | 低 | 高 |
| 后续扩展空间 | 低 | 中 | 高 |

### 3.3 Trade-offs
- **方案 A：目录级 module**: Pros: 文档与创建流程更简单，代码扫描逻辑天然贴合目录。 / Cons: 与已有 `module_path` 文案、`resolve` / `validate` 行为和用户需求不一致，会继续把单文件边界排除在外。
- **方案 B：路径级 module（目录或文件）**: Pros: 与现有大多数实现兼容，只需对齐少数目录假设即可修复当前误判。 / Cons: 文档、测试和部分创建流程需要统一口径。
- **方案 C：块级 module**: Pros: 最接近“责任边界”的抽象。 / Cons: 现有前缀匹配、健康度计算、索引、覆盖率、去重全部需要重新建模，不适合当作这次问题的最小修复范围。

### 3.4 未解决的问题
- module 的一等标识究竟应是“路径边界”还是“责任边界”？
- 如果未来支持块级 module，应复用 `module_path` 还是新增 `symbol` / `range` 等字段？
- `specanchor_infer` 在单文件场景下是否允许执行？如果允许，扫描输入与推断边界该如何定义？
- 当仓库尚未正式支持某种粒度时，系统应“明确拒绝”还是“允许记录但不参与健康度计算”？

## 4. Challenge & Follow-up
> 此环节由 Agent 向用户追问，目的是激活用户思路、发现盲区、修正调研方向。

### 4.1 Agent 追问
- 追问 1: 团队是否愿意把 module 正式定义为“仓库中的一个已存在路径边界”，允许目录和单文件并列？
- 追问 2: 对“单文件内的一块代码也可以是 module”，团队希望现在就进入协议设计，还是先作为后续扩展保留？
- 追问 3: 如果短期内不支持块级 module，是否应在文档中明确写出“当前只支持目录/文件级路径边界”？

### 4.2 用户反馈
- 用户反馈: “单文件，甚至是单文件内的一块代码也可以是module，这是我个人认为的。”

### 4.3 方向调整（基于追问）
- 需要补充调研的方向: 若团队采纳块级 module 目标，需要单独调研 frontmatter 扩展、健康度计算与覆盖匹配模型。
- 需要修正的结论: 当前阶段更适合先统一为“路径级 module（目录或文件）”，不要把块级抽象直接塞进现有 `module_path` 语义；`infer` 是否支持单文件需要单独明确。

## 5. Conclusion
### 5.1 Action Items
- [ ] 1. 明确写入协议：`module_path` 表示仓库中的相对路径边界，可为目录或单文件。
- [ ] 2. 修正 `scripts/specanchor-index.sh`、`scripts/specanchor-check.sh`、`scripts/specanchor-status.sh` 的目录假设与错误标签语义：路径存在（目录或文件）时进入正常健康度计算；仅当路径不存在时才输出 `invalid module_path`。
- [ ] 3. 为 `index` / `check` / `status` / `validate` / `resolve` 补充单文件 `module_path` 回归测试，并新增一个可复用的单文件 fixture（如 `tests/fixtures/single-file-module/`）。
- [ ] 4. 对齐 `references/commands/module.md`、`references/commands/infer.md`、`references/specanchor-protocol.md`、`references/module-spec-template.md` 的术语与例子，并明确 `infer` 是否支持单文件路径；若不支持，也要显式写出约束。
- [ ] 5. 单独开一个后续 research task，评估块级 module 是否需要新字段建模。
- [ ] 6. 在最小修复完成后，评估是否将 `index` 与 `status` 的健康度计算提取为共享 helper，降低同类回归再次发生的概率。

### 5.2 最终建议
- **推荐方案**: 将当前系统正式收敛到“路径级 module”，即 module 可以是目录，也可以是单文件；本次问题按 bug 修复处理。
- **推荐理由**: 这与现有 `resolve`、`validate` 和路径前缀匹配机制最一致，修复范围小，能直接消除 `STALE` 误判并恢复健康度信号可信度。
- **风险提示**: 如果不先把“文件级 module”与“块级 module”分开，后续容易把一个小 bug 修复演变成协议重写。
- **下一步**: 先依据本结论创建实现型 Task Spec，聚焦 `index + check + status + docs + tests` 的最小一致性修复；块级 module 另立课题。
