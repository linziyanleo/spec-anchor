# Assembly Trace

Assembly Trace 用来明确本轮到底读了哪些 Spec，以及读取深度是摘要还是全文。

标准格式：

```text
Assembly Trace:
  - Global: summary|full|none|skipped -> <files or reason>
  - Module: full|deferred|sources-only|none -> <files or reason>
```

语义：

- `summary`：只加载摘要、索引、统计，不注入正文全文。
- `full`：已读取正文全文并纳入上下文。
- `deferred`：本轮尚未加载 Module Spec，等命中路径或模块后再补。
- `sources-only`：parasitic 模式下只从外部 sources 按需读取。
- `skipped`：该层在当前模式下不自动加载。

规则：

1. 启动检查后先输出一次 Assembly Trace。
2. 如果后续按需加载了新的 Module Spec，必须再输出一次更新后的 Trace。
3. 不要把“读过文件名”伪装成“读过全文”；`summary` 和 `full` 必须分开写。
