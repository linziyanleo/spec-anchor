# TODO

> Meta-Harness 协议提升后续任务（论文 2605.25665v1 启发）
>
> 第一步（协议/模板改动）已有 Task Spec：`.specanchor/tasks/_cross-module/2026-06-02_meta-harness-protocol-uplift.spec.md`

## 第二步：校验脚本承接

将第一步新增的协议字段接入现有校验工具链，使其从"建议"变为"可验证契约"。

- [ ] `specanchor-validate.sh` — 增加 `failure_class` 枚举校验（null | bug | spec_gap | noise | contract_ambiguity）；candidate 状态下非 null 时校验枚举值，null 不报错（可选字段）
- [ ] `specanchor-finding.sh new` — 增加 `--failure-class=` 可选参数；自动写入 frontmatter
- [ ] Sediment pipeline routing advisory — `specanchor-doctor.sh` 在 `failure_class=spec_gap` 的 accepted finding 上主动建议生成 Sediment Proposal；`failure_class=bug` 的 finding 标注"不建议走 sediment"
- [ ] `specanchor-validate.sh` — Task Spec (sdd-riper-one) §4.0 Contract Compilation Checklist 存在性检查（warn，不 block）
- [ ] `specanchor-validate.sh` — Task Spec (sdd-riper-one) §6.4 Verification Mode Record 枚举校验（independence | attention | mixed | self）

## 第三步：Metrics 与 Specialization（再议）

观察第一步和第二步落地效果后，根据积累数据决定是否推进。

### Metrics

- [ ] 定义 harness-level metrics 指标体系（参考论文 §8）：finding 总数/按 type+failure_class 分布、sediment 接受率、spec freshness 覆盖率、dual-agent-review 平均收敛轮数
- [ ] `specanchor-status.sh` 或新脚本 — 聚合 `.specanchor/findings/` 和 `.specanchor/sediment/` 数据输出关键指标
- [ ] Review Verdict metrics — 从已完成 Task Spec 的 §6.4 提取 verification_mode 分布

### Specialization Records

- [ ] 设计 specialization 协议文档（参考论文 §4.4）：领域知识卡格式、confidence threshold、注入时机
- [ ] `references/specializations/` 或 `.specanchor/specializations/` — 先作为手动引用的 reference docs 存在
- [ ] confidence-gated 注入 — 在 `specanchor-assemble.sh` 中按 task topic 自动注入（需要 topic detection 逻辑）
