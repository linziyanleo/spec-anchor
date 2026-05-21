---
specanchor:
  level: task
  task_name: "specanchor-init --scan-sources Bash 3.2 bug"
  author: "@maintainer"
  created: "2026-05-20"
  status: "done"
  last_change: "Bash 3.2 兼容修复完成：associative array → 普通数组 + find 括号修正"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "bug-fix"
  branch: "fix/init-scan-sources-bash3"
---

# Bug Fix: specanchor-init --scan-sources Bash 3.2 bug

Current Bug-Fix Phase: DONE

## 0. Bug Report
- **报告来源**: Codex argue / 本地复现
- **严重程度**: Medium
- **影响范围**: `scripts/specanchor-init.sh --scan-sources`；任何依赖 init source scan 的新交互式 init 逻辑

## 1. Reproduce
- **复现步骤**:
  1. 在 macOS 系统 Bash 3.2 环境运行：
     ```bash
     tmpdir=$(mktemp -d)
     cd "$tmpdir"
     bash /Users/fanghu/Documents/Work/spec-anchor/scripts/specanchor-init.sh --project=probe --scan-sources
     ```
  2. 观察 `Scanning for existing spec systems...` 阶段。
- **环境**: macOS system Bash `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)`
- **预期行为**: 没有外部 spec 目录时输出 no existing spec systems detected，并以 0 退出。
- **实际行为**: `scripts/specanchor-init.sh` 在 source scan 阶段报错并以 1 退出：
  ```text
  /Users/fanghu/Documents/Work/spec-anchor/scripts/specanchor-init.sh: line 232: openspec: unbound variable
  ```
- **复现率**: 必现（Bash 3.2 + `set -u` + `local -A` 关联数组初始化）

## 2. Diagnose
### 2.1 诊断策略
- 无需新增诊断代码；已有 shell error 指向 `scan_external_sources()` 的 associative array 初始化。

### 2.2 诊断代码
- [x] 无新增诊断代码

### 2.3 控制台输出
```text
Scanning for existing spec systems...
/Users/fanghu/Documents/Work/spec-anchor/scripts/specanchor-init.sh: line 232: openspec: unbound variable
```

### 2.4 证据分析
- `scripts` module 要求 Bash 3.2+ 兼容。
- `scan_external_sources()` 使用 `local -A type_registry=( ["openspec/"]="openspec" ... )`，这是 Bash 4 associative array 风格；在 Bash 3.2 + `set -u` 下会把 key 解析触发为未绑定变量。

## 3. Root Cause
- **根因**: `scripts/specanchor-init.sh` 在 Bash 3.2 目标环境中使用 Bash 4-only associative array。
- **证据链**: 复现命令 → `openspec: unbound variable` → `scan_external_sources()` 中 `local -A type_registry`。
- **相关代码**: `scripts/specanchor-init.sh:229`
- **为什么之前正常（如回归）**: 若在 Bash 4+ 或未走 `--scan-sources` 路径，不会暴露。

## 4. Fix Plan
### 4.1 Fix Checklist
- [x] 1. 将 `scan_external_sources()` 的 registry 改成 Bash 3.2 兼容的普通数组条目（如 `"openspec/:openspec"`）。
- [x] 2. 用 `${entry%%:*}` / `${entry#*:}` 拆分 `dir` / `type`。
- [x] 3. 修正 `find` 计数表达式，加括号避免 `-o` 优先级歧义。
- [x] 4. 在临时目录覆盖"无 sources"和"有 sources"两个 smoke 场景。

### 4.2 File Changes
- `scripts/specanchor-init.sh`: Bash 3.2 兼容化 source registry scan。

### 4.3 Risk Assessment
- **回归风险**: Low
- **影响的其他功能**: 仅 `--scan-sources` 输出顺序可能因普通数组变为 deterministic insertion order。
- **需要额外测试的场景**: 无外部 spec 目录；存在 `openspec/`、`mydocs/specs/`、`docs/specs/` 时的文件计数。

## 5. Fix Log
- [x] Step 1: `local -A type_registry=( ["k"]="v" )` → `local registry=( "k:v" )` + `${entry%%:*}` / `${entry#*:}` 拆分
- [x] Step 2: `find "$dir" -name "*.md" -o -name "*.yaml"` → `find "$dir" \( -name "*.md" -o -name "*.yaml" \)`

## 6. Verify
- [x] Bug 已修复（按复现步骤验证）
- [x] `bash -n scripts/specanchor-init.sh`
- [x] 临时目录无 sources smoke
- [x] 临时目录多 sources smoke
- [x] Module Spec 是否需更新: No（init.sh 接口不变，仅内部实现修正）
- **Follow-ups**: init 交互式三问 task 若依赖 source scan，必须在此 bug 修复后再实现相关 init.sh 检测逻辑。
