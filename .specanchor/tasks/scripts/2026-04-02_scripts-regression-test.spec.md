---
specanchor:
  level: task
  task_name: "scripts/ 回归测试脚本开发"
  author: "@fanghu"
  assignee: "@fanghu"
  created: "2026-04-02"
  status: "in_progress"
  last_change: "Skill 专家审计后更新 — 闭合 Open Questions，补充审计发现的 5 个已知 bug 对测试策略的影响"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
    - ".specanchor/global/architecture.spec.md"
    - ".specanchor/global/project-setup.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  sdd_phase: "PLAN"
  branch: "main"
---

# SDD Spec: scripts/ 回归测试脚本开发

## 0. Open Questions

- [x] 测试框架选型 → **bats-core**（与 Bash-only 项目一致，见 §3 Decision）
- [x] macOS/Linux fixture 差异 → **测试中 mock date 输出**，不依赖系统 `date` 命令的格式差异。fixture 使用固定的 `last_synced` 日期 + 可控的 git commit 时间戳
- [x] CI 集成 → **本任务不含 CI 配置**，后续独立任务处理 GitHub Actions。理由：先确保测试本地可运行，CI 集成是部署问题非测试问题
- [ ] 是否在测试前先修复 scripts.spec.md §8 中的 5 个已知 bug？→ **先测后修**，测试先记录已知 bug 的实际行为（@test 标注 `# known-bug`），修复后翻转为正向断言

## 1. Requirements (Context)

- **Goal**: 为 `scripts/` 下的三个 Shell 脚本建立回归测试套件，确保核心功能在修改后不会悄然退化
- **In-Scope**:
  - `specanchor-check.sh` 的四种模式（task/module/global/coverage）测试
  - `frontmatter-inject.sh` 的三种场景（无 frontmatter / 有非 SA frontmatter / 已有 SA frontmatter）测试
  - `frontmatter-inject-and-check.sh` 的 Layer 2 组合流程测试
  - 边界条件：空目录、无 git 仓库、缺失 anchor.yaml、畸形 YAML
  - 已知 bug 的行为记录测试（标注 `# known-bug`，当前预期为 bug 行为，修复后翻转）
- **Out-of-Scope**:
  - 不修改现有脚本逻辑（仅测试，不修复审计发现的 bug）
  - 不做性能测试
  - 不测试 extensions/ 下的脚本
  - 不配置 CI（后续任务）
- **Schema**: sdd-riper-one（默认 Schema，标准开发流程）

## 1.1 Context Sources

- Requirement Source: Skill 专家审计报告（本轮对话）
- Design Refs: `.specanchor/modules/scripts.spec.md`（Module Spec，特别是 §8 已知问题）
- Extra Context: `.specanchor/global/coding-standards.spec.md`（Shell 约定）
- Extra Context: `.specanchor/global/project-setup.spec.md`（环境要求 — bats-core 依赖）

## 2. Research Findings

- **事实**: 三个脚本合计 ~1,336 行 Bash，零测试覆盖
- **约束**: 脚本依赖 git 仓库环境和 anchor.yaml 配置文件
- **风险 1**: `specanchor-check.sh` 的 `date -j` 在 Linux CI 上不可用，需 fixture 隔离
- **风险 2**: `frontmatter-inject.sh` 的 trap 在循环中被覆盖，可能导致 tmpfile 泄漏（测试需验证）
- **风险 3**: `specanchor-check.sh` 的 `check_task` 双向子串匹配可能产生假阳性（如 `auth.ts` 匹配 `auth-service.ts`）
- **发现 1**: 脚本之间有层内依赖（Layer 2 调用 Layer 1 + check），测试需覆盖这种组合
- **发现 2**: `parse_yaml_field()` 在 check 和 inject 两个脚本中重复定义，行为应一致但无保证
- **发现 3**: `detect_sdd_phase()` 硬编码 `## 2.`/`## 4.`/`## 5.` 等章节号，与 Schema template 耦合
- **发现 4**: `usage()` 在 `specanchor-check.sh` 中引用了未初始化的配置变量（如 `$STALE_DAYS`）

## 2.1 Next Actions

- 确定测试框架并初始化测试目录结构
- 为每个脚本编写 fixture 文件（模拟 .specanchor/、anchor.yaml、git repo）
- 按优先级编写测试用例
- 为 scripts.spec.md §8 的 5 个已知 bug 各编写至少 1 个 `# known-bug` 测试

## 3. Innovate (Options & Decision)

### Option A: bats-core (Bash Automated Testing System)

- Pros: 原生 Bash，与被测脚本同语言；社区成熟；输出 TAP 格式
- Cons: 需额外安装 (`brew install bats-core`)；复杂断言需辅助库

### Option B: pytest + subprocess

- Pros: 断言强大；fixture 管理成熟；更易做 cross-platform
- Cons: 引入 Python 依赖；与 Bash-only 项目风格不一致

### Decision

- Selected: **Option A (bats-core)**
- Why: spec-anchor 是纯 Bash + Markdown 项目，测试保持同语言一致性。bats-core 的 `setup()` / `teardown()` 已足够管理 git fixture。辅助断言使用 bats-assert + bats-support。

## 4. Plan (Contract)

### 4.1 File Changes

- `tests/setup_helper.bash`: 共享 fixture 搭建（创建临时 git repo + anchor.yaml + .specanchor/ 结构）
- `tests/test_specanchor_check.bats`: specanchor-check.sh 回归测试
- `tests/test_frontmatter_inject.bats`: frontmatter-inject.sh 回归测试
- `tests/test_frontmatter_inject_and_check.bats`: frontmatter-inject-and-check.sh 回归测试
- `tests/fixtures/anchor.yaml`: 标准测试配置文件
- `tests/fixtures/sample-task-spec.md`: 含 File Changes 章节的 Task Spec 样本
- `tests/fixtures/sample-module-spec.md`: 含 module_path frontmatter 的 Module Spec 样本
- `tests/fixtures/sample-no-frontmatter.md`: 无 frontmatter 的纯 Markdown 文件
- `tests/fixtures/sample-non-sa-frontmatter.md`: 有非 SA frontmatter（如 Hugo/Jekyll 格式）的文件
- `tests/fixtures/sample-sa-frontmatter.md`: 已有 `specanchor:` frontmatter 的文件
- `tests/fixtures/sample-malformed.md`: 畸形 YAML frontmatter（用于边界测试）
- `tests/run_all.sh`: 一键运行所有测试的入口脚本

### 4.2 Signatures

测试文件结构（bats-core 格式）：

```bash
# test_specanchor_check.bats
setup()       # 创建临时 git repo + anchor.yaml + .specanchor/ fixture
teardown()    # rm -rf 临时目录

# ── task 模式 ──
@test "task: planned files all covered → exit 0 + PASS output"
@test "task: missing planned file → shows missing count"
@test "task: unplanned changes → shows unplanned count"
@test "task: spec without File Changes section → skips coverage check"
@test "task: nonexistent spec file → exit 1 with error message"
@test "task: short filename false positive # known-bug"
  # auth.ts 被 auth-service.ts 的子串匹配命中

# ── module 模式 ──
@test "module: fresh module (no commits since sync) → FRESH"
@test "module: stale module (commits + days > stale_days) → STALE"
@test "module: outdated module (days > outdated_days) → OUTDATED"
@test "module: drifted module (recent commits, within stale_days) → DRIFTED"
@test "module --all: lists all modules in .specanchor/modules/"
@test "module: missing module_path in frontmatter → skips gracefully"
@test "module: nonexistent spec file → exit 1 with error"

# ── global 模式 ──
@test "global: reports global spec count and module count"
@test "global: warns on stale modules"
@test "global: no warnings when all fresh"
@test "global: missing anchor.yaml → exit 1 with find_config error"
@test "global: empty .specanchor/modules/ → reports 0 modules"

# ── coverage 模式 ──
@test "coverage: file under covered module → shows covered"
@test "coverage: file under uncovered path → shows uncovered"
@test "coverage: multiple files mixed → correct covered/uncovered"
@test "coverage: empty modules dir → all uncovered"
@test "coverage: no arguments → exit 1 with usage"

# ── 边界条件 ──
@test "no subcommand → shows usage"
@test "unknown subcommand → exit 1 with error"
@test "usage references uninitialized variables # known-bug"
  # usage() 输出中 $STALE_DAYS 等变量为空
```

```bash
# test_frontmatter_inject.bats
setup()       # 创建临时 git repo + anchor.yaml + 样本 md 文件
teardown()    # 清理

# ── 单文件注入 ──
@test "inject: file without frontmatter → prepends specanchor frontmatter"
@test "inject: file with non-SA frontmatter → appends specanchor block inside existing ---"
@test "inject: file with SA frontmatter → skips (idempotent), count +1 skipped"
@test "inject: --force on existing SA frontmatter → overwrites"
@test "inject: --dry-run → stdout shows frontmatter, file unchanged"
@test "inject: nonexistent file → exit 1 with error"
@test "inject: malformed YAML frontmatter → warns and counts as failed"

# ── 自动推断 ──
@test "detect_level: file in .specanchor/tasks/ → level=task"
@test "detect_level: file in .specanchor/modules/ → level=module"
@test "detect_level: file in .specanchor/global/ → level=global"
@test "detect_level: file in mydocs/specs/ → level=task (sources mapping)"
@test "detect_author: in git repo → returns @<git user.name>"
@test "detect_author: outside git repo → returns @unknown"
@test "detect_status: all checkboxes [x] → status=done"
@test "detect_status: some [x] some [ ] → status=in_progress"
@test "detect_status: no checkboxes → status=draft"
@test "detect_task_name: H1 '# SDD Spec: Foo Bar' → task_name='Foo Bar'"
@test "detect_task_name: no H1 → uses filename stem"
@test "detect_sdd_phase: only §2 filled → RESEARCH"
@test "detect_sdd_phase: §4 filled → PLAN"
@test "detect_sdd_phase: §5 has checked items → EXECUTE"

# ── 批量注入 ──
@test "batch: --dir with 3 files → injects all, summary shows 3 injected"
@test "batch: --dir with 0 matching files → warns 'no files found'"
@test "batch: --dir mixed → correct inject/skip/fail counts"
@test "batch: --file-pattern '*.spec.md' → only processes .spec.md files"

# ── 配置读取 ──
@test "no anchor.yaml + --no-config → uses builtin defaults"
@test "anchor.yaml present → reads writing_protocol field"
@test "anchor.yaml at .specanchor/config.yaml (legacy) → fallback reads it"

# ── 已知 bug 场景 ──
@test "parse_yaml_field: duplicate definition consistency # known-bug"
  # 验证 check.sh 和 inject.sh 中的 parse_yaml_field 行为一致
@test "trap overwrite in batch loop # known-bug"
  # 批量模式下 trap 被覆盖，中断时可能残留 tmpfile
```

```bash
# test_frontmatter_inject_and_check.bats
setup()       # 创建临时 git repo + 所需脚本 + fixture
teardown()    # 清理

# ── Layer 2 组合 ──
@test "layer2: inject + check for task file → Phase 1 + Phase 2 both run"
@test "layer2: --dry-run → inject preview only, no check, no file modification"
@test "layer2: --skip-check → inject runs, Phase 2 skipped"
@test "layer2: missing Layer 1 script → exit 1 with clear error"
@test "layer2: missing check script → warns and skips Phase 2"
@test "layer2: --check-level global → runs global check after inject"
@test "layer2: --check-level module → runs module check on injected file"
@test "layer2: inherits Layer 1 --force flag → passes through to inject"
```

### 4.3 Implementation Checklist

- [ ] 1. 初始化 `tests/` 目录结构，创建 `setup_helper.bash`（git fixture 管理 + 共享工具函数）
- [ ] 2. 创建 `tests/fixtures/` 下的 7 个 fixture 数据文件
- [ ] 3. 编写 `test_specanchor_check.bats`（23 个用例，含 2 个 known-bug 用例）
- [ ] 4. 编写 `test_frontmatter_inject.bats`（29 个用例，含 2 个 known-bug 用例）
- [ ] 5. 编写 `test_frontmatter_inject_and_check.bats`（8 个用例）
- [ ] 6. 创建 `tests/run_all.sh` 入口脚本（TAP 输出 + 汇总统计）
- [ ] 7. 全量运行，确保非 known-bug 用例全部通过
- [ ] 8. 更新 `scripts.spec.md` 的 §7 代码结构（新增 tests/ 条目）

## 5. Execute Log

（待执行）

## 6. Review Verdict

（待执行）

## 7. Plan-Execution Diff

（待执行）
