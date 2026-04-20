# specanchor_load

手动加载指定 Spec 文件到当前对话上下文。通常自动加载已覆盖大部分场景，手动加载适用于需要额外参考某个 Spec 的情况。

**用户可能这样说**: "帮我加载 auth 模块的规范" / "把这个 Spec 文件读取到上下文" / "加载一下编码规范"

## 参数

- `path`（必须）: Spec 文件路径

## 执行

1. 读取指定文件内容
2. 注入当前对话上下文
3. 输出更新后的 `Assembly Trace`，明确这个文件属于 Global 还是 Module，以及是 `summary` 还是 `full`
4. 报告已加载的 Spec

标准输出：

```text
Assembly Trace:
  - Global: <summary|full|none|skipped> -> ...
  - Module: <summary|full|deferred|sources-only> -> ...
```
