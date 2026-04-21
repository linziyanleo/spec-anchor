# SDD-RIPER-ONE Integration

`sdd-riper-one` 是 SpecAnchor 的默认写作协议。

映射关系：

- Pre-Research：自动加载 Global Spec，并根据 `module-index.md`/文件路径决定相关 Module Spec。
- Research：Module Spec 作为现状输入。
- Plan：Task Spec 的 File Changes 应与相关 Module Spec 关键文件交叉校验。
- Execute：代码生成受 Global + Module Spec 约束。
- Review：如果接口、依赖或模块边界改变，应同步 Module Spec。

默认 Task Spec 路径：`.specanchor/tasks/<module>/`。
