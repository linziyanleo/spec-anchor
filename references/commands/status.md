# specanchor_status

显示当前 Spec 加载状态和覆盖率概览。

**用户可能这样说**: "看看当前规范状态" / "模块规范覆盖率怎么样" / "哪些规范已经加载了" / "规范概览"

## 执行

**首选方式**：运行 `scripts/specanchor-status.sh` 脚本获取状态报告：

```bash
bash "<skill_install_dir>/scripts/specanchor-status.sh"

# 可选参数：
#   --config=<path>       指定配置文件（默认自动查找 anchor.yaml）
#   --format=summary|json 输出格式（默认 summary）
```

脚本自动完成以下步骤：

1. 读取配置文件
2. 扫描 `.specanchor/global/`，统计 Global Spec 数量和总行数
3. 扫描 `.specanchor/modules/`，统计 Module Spec 覆盖率和健康度
4. 统计活跃/归档 Task Spec 数量
5. 检测 module-index.md 格式（v2/legacy/missing）
6. 输出简洁摘要 + 默认 Assembly Trace

脚本只负责报告当前默认装配策略：

- Global: 当前是摘要装配还是未装配
- Module: 当前是 deferred / sources-only，而不是伪装成“已经加载”

若本轮对话后续又额外读取了 Module Spec，Agent 必须在脚本输出基础上补打一条更新后的 `Assembly Trace`。

### 输出格式

full 模式：

```
SpecAnchor Status [full]
  Config: anchor.yaml
  Assembly Trace:
    - Global: summary -> coding-standards.spec.md, architecture.spec.md
    - Module: deferred -> none (status does not preload module bodies)
  Coverage: 3/4 modules (75%)
  Tasks: 2 active, 15 archived
  Sources:
    specs/ [spec-kit]: 12 files, stale_check: ✅, frontmatter_inject: ❌
```

parasitic 模式：

```
SpecAnchor Status [parasitic]
  Config: anchor.yaml
  Assembly Trace:
    - Global: skipped -> parasitic mode does not auto-load global specs
    - Module: sources-only -> none (external specs load on demand)
  Sources:
    specs/ [spec-kit]: 12 files, stale_check: ✅, frontmatter_inject: ❌
    .qoder/specs/ [qoder]: 5 files, stale_check: ✅, frontmatter_inject: ✅
```
