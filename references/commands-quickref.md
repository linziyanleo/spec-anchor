# SpecAnchor 命令速查表

## 初始化

```text
SA INIT                                  初始化 .specanchor/ 目录和 config.yaml
SA INIT scan=true                        初始化并扫描项目生成 Global Spec 草稿
```

## Global Spec

```text
SA GLOBAL coding-standards               从代码推断编码规范
SA GLOBAL architecture                   从代码推断架构约定
SA GLOBAL design-system                  从代码推断设计系统规则
SA GLOBAL api-conventions                从代码推断 API 约定
SA GLOBAL <custom-type>                  自定义类型
SA GLOBAL coding-standards scan=src/     指定扫描路径
```

## Module Spec

```text
SA MODULE src/modules/auth               创建/更新 auth 模块规范
SA MODULE src/components/LoginForm       创建/更新组件规范
SA INFER src/modules/auth                从代码逆向推断模块规范草稿
```

## Task Spec

```text
SA TASK 登录页增加验证码                   创建任务（自动推断关联模块）
SA TASK 登录页增加验证码 modules=auth      显式指定关联模块
```

## 加载 & 状态

```text
SA LOAD src/modules/auth/MODULE.spec.md  手动加载指定 Spec
SA STATUS                                查看加载状态和覆盖率
```

## 检测

```text
SA CHECK task <spec-file>                Task 级：PR 改动 vs Spec 计划
SA CHECK task <spec-file> --base=develop 指定基准分支
SA CHECK module <spec-file>              Module 级：模块文件是否有新 commit
SA CHECK module --all                    全部 Module Spec 新鲜度
SA CHECK module --all --stale-days=60    自定义过期天数
SA CHECK global                          Global 级：覆盖率报告
```

## 触发词汇总

| 触发词 | 命令 |
|--------|------|
| `SA INIT` / `初始化 SpecAnchor` | `specanchor_init` |
| `SA GLOBAL <type>` / `全局规范 <类型>` | `specanchor_global` |
| `SA MODULE <path>` / `模块规范 <路径>` | `specanchor_module` |
| `SA INFER <path>` / `推断规范 <路径>` | `specanchor_infer` |
| `SA TASK <name>` / `创建任务 <名称>` | `specanchor_task` |
| `SA LOAD <path>` / `加载规范 <路径>` | `specanchor_load` |
| `SA STATUS` / `规范状态` | `specanchor_status` |
| `SA CHECK [level]` | `specanchor_check` |
