# Superpowers Integration

当项目同时使用 superpowers 与 SpecAnchor 时：

- superpowers 负责工作流推进：brainstorm → plan → execute → review。
- SpecAnchor 负责治理：frontmatter、staleness、coverage、module index。

## Recommended Order

1. `docs/superpowers/specs/` 写 Design Spec。
2. SpecAnchor 通过 `sources` 识别该文件，必要时注入 frontmatter。
3. `docs/superpowers/plans/` 写 Plan。
4. SpecAnchor 再次注入 frontmatter，并纳入新鲜度/覆盖率治理。
5. superpowers 执行实现；SpecAnchor 继续提供检查与索引。

## Gate Degradation

如果仓库中存在 `docs/superpowers/`：

- Task Spec 创建门禁从“阻塞”降级为“建议”。
- 仍然要输出 `⚡/📋` 决策检查点。
- 不再强推 schema 推荐，因为 superpowers 已有自己的阶段编排。
