# SpecAnchor Skill 调用全链路流程图

## 1. Skill 启动与加载链路

```mermaid
flowchart TD
    A[用户在对话中引用 SpecAnchor Skill] --> B[Agent 读取 SKILL.md]
    B --> C{.specanchor/ 目录存在?}
    C -->|不存在| D["⛔ 报错阻塞<br/>引导用户初始化"]
    C -->|存在| E[读取 config.yaml]
    E --> F[读取 .specanchor/global/*.spec.md<br/>全量加载 ≤ 200 行]
    F --> G[输出加载状态摘要]
    G --> H[等待用户指令]

    style D fill:#ff6b6b,color:#fff
    style G fill:#51cf66,color:#fff
```

## 2. 需求复杂度评估与流程选择

```mermaid
flowchart TD
    A[用户输入需求] --> B[SpecAnchor 自动评估复杂度]
    B --> C{需求复杂度判断}

    C -->|简单需求| D[简单需求特征:<br/>• 单文件修改<br/>• 样式调整<br/>• 单个 bug 修复<br/>• 简单配置修改<br/>• 预计工作量 < 2小时]
    C -->|复杂需求| E[复杂需求特征:<br/>• 新增功能模块<br/>• 多文件修改<br/>• 架构设计<br/>• 数据流变更<br/>• 预计工作量 >= 2小时]

    D --> F[快速流程:<br/>直接执行相应命令<br/>无需创建 Task Spec]
    E --> G[标准流程:<br/>必须先创建 Task Spec<br/>然后按 RIPER 流程执行]

    F --> H[执行 SpecAnchor 命令<br/>或工作流命令]
    G --> I[执行 specanchor_task<br/>创建 Task Spec]
    I --> J[按 RIPER 流程开发]

    style D fill:#51cf66,color:#fff
    style E fill:#ffd43b,color:#333
    style F fill:#74c0fc,color:#fff
    style G fill:#ff922b,color:#fff
```

## 3. 用户意图识别与命令分发

```mermaid
flowchart TD
    H[用户输入自然语言描述意图] --> I[Agent 匹配意图<br/>参考 commands-quickref.md]
    I --> J{识别到的命令类型}

    J -->|SpecAnchor 核心命令| K[SpecAnchor 命令]
    J -->|工作流命令| L[工作流命令]

    K --> K1["specanchor_init<br/>→ commands/init.md"]
    K --> K2["specanchor_global<br/>→ commands/global.md"]
    K --> K3["specanchor_module<br/>→ commands/module.md"]
    K --> K4["specanchor_infer<br/>→ commands/infer.md"]
    K --> K5["specanchor_task<br/>→ commands/task.md"]
    K --> K6["specanchor_load<br/>→ commands/load.md"]
    K --> K7["specanchor_status<br/>→ commands/status.md"]
    K --> K8["specanchor_check<br/>→ commands/check.md"]
    K --> K9["specanchor_index<br/>→ commands/index.md"]

    L --> L1["workflow_commit_push<br/>→ commands/workflow_commit_push.md"]
    L --> L2["workflow_submit_cr<br/>→ commands/workflow_submit_cr.md"]
    L --> L3["workflow_start_dev<br/>→ commands/workflow_start_dev.md"]
    L --> L4["workflow_stop_dev<br/>→ commands/workflow_stop_dev.md"]

    K1 --> T[Agent 按需读取<br/>对应命令文件]
    K2 --> T
    K3 --> T
    K4 --> T
    K5 --> T
    K6 --> T
    K7 --> T
    K8 --> T
    K9 --> T
    L1 --> T
    L2 --> T
    L3 --> T
    L4 --> T

    T --> U[执行命令逻辑]

    style K fill:#74c0fc,color:#fff
    style L fill:#ff922b,color:#fff
```

## 4. 核心场景链路：首次使用

```mermaid
flowchart LR
    A["'初始化 SpecAnchor'"] -->|specanchor_init| B[创建 .specanchor/ 目录]
    B --> C["'初始化项目信息'"]
    C -->|specanchor_global<br/>project-setup 类型| D[扫描 package.json<br/>生成 project-setup.spec.md]
    D --> E["'帮我生成编码规范'"]
    E -->|specanchor_global<br/>coding-standards 类型| F[扫描代码<br/>生成 coding-standards.spec.md]
    F --> G["'帮我生成架构约定'"]
    G -->|specanchor_global<br/>architecture 类型| H[扫描代码<br/>生成 architecture.spec.md]
    H --> I[Global Spec 就绪<br/>可开始使用工作流]

    style I fill:#51cf66,color:#fff
```

## 5. 核心场景链路：完整开发工作流

```mermaid
flowchart TD
    A["用户需求输入"] --> B[需求复杂度评估]
    B --> C{简单需求 vs 复杂需求}

    C -->|简单需求| D[直接处理]
    C -->|复杂需求| E["'创建任务：XX功能'"]

    E -->|specanchor_task| F{关联模块有 Module Spec?}
    F -->|有| G[On-Demand 加载 Module Spec]
    F -->|无| H["⚠️ 提醒: 建议先创建模块规范"]
    H --> H2[用户决定是否先创建 Module Spec]
    H2 -->|创建| M["specanchor_module<br/>创建 Module Spec"]
    M --> G
    H2 -->|跳过| G2[仅加载 Global Spec]

    G --> I[创建 Task Spec<br/>按 RIPER 流程开发]
    G2 --> I
    D --> J[开发完成]
    I --> J

    J --> K["'提交代码'"]
    K -->|workflow_commit_push| L[智能分析变更<br/>生成 commit message<br/>自动提交推送]

    L --> N["'提交代码评审'"]
    N -->|workflow_submit_cr| O[读取项目配置<br/>自动创建 CR<br/>执行 SA CHECK 质量检查]

    O --> P["'检查 Spec-代码对齐'"]
    P -->|specanchor_check| Q[输出对齐报告]

    style J fill:#51cf66,color:#fff
    style L fill:#74c0fc,color:#fff
    style O fill:#ff922b,color:#fff
```

## 6. 工作流命令详细流程

```mermaid
flowchart TD
    subgraph "开发服务器管理"
        A1["'启动项目'"] -->|workflow_start_dev| A2[从 project-setup.spec.md<br/>读取启动命令]
        A2 --> A3[执行启动命令<br/>检测服务器状态]
        A3 --> A4[自动打开浏览器<br/>访问本地地址]

        B1["'停止项目'"] -->|workflow_stop_dev| B2[检测运行中的服务器]
        B2 --> B3[停止开发服务器<br/>清理进程]
    end

    subgraph "代码管理"
        C1["'提交代码'"] -->|workflow_commit_push| C2[检查代码状态<br/>分析变更类型]
        C2 --> C3[生成符合规范的<br/>commit message]
        C3 --> C4[执行 git add & commit<br/>推送到远程仓库]
    end

    subgraph "代码评审"
        D1["'提交代码评审'"] -->|workflow_submit_cr| D2[从 project-setup.spec.md<br/>读取评审人配置]
        D2 --> D3[执行 codereview.sh<br/>创建代码评审]
        D3 --> D4[运行 SA CHECK<br/>质量检查]
        D4 --> D5[提取 CR 链接<br/>询问是否打开]
    end

    style A4 fill:#51cf66,color:#fff
    style B3 fill:#51cf66,color:#fff
    style C4 fill:#51cf66,color:#fff
    style D5 fill:#51cf66,color:#fff
```

## 7. 项目配置管理流程

```mermaid
flowchart TD
    A["'初始化项目信息'"] --> B[扫描 package.json]
    B --> C[提取项目信息:<br/>• 项目名称<br/>• 启动命令<br/>• 本地运行地址<br/>• 默认评审人]
    C --> D[生成 project-setup.spec.md<br/>作为 Global Spec]
    D --> E[工作流命令读取配置]

    E --> F1[workflow_start_dev<br/>读取启动命令和地址]
    E --> F2[workflow_submit_cr<br/>读取默认评审人]

    F1 --> G[统一的项目配置管理<br/>不再使用独立 metadata.md]
    F2 --> G

    style D fill:#74c0fc,color:#fff
    style G fill:#51cf66,color:#fff
```

## 8. 文件读取层级（Agent 上下文管理）

```mermaid
flowchart TD
    subgraph "Always Load (每次对话)"
        A1[SKILL.md<br/>~200行 包含需求复杂度评估]
        A2[config.yaml<br/>~40行 包含复杂度配置]
        A3[Global Specs<br/>≤200行 合计<br/>包含 project-setup.spec.md]
    end

    subgraph "On-Demand Load (按需加载)"
        B1[commands-quickref.md<br/>~150行 包含工作流命令]
        B2["SpecAnchor 命令文件<br/>commands/<cmd>.md<br/>~20-40行/个"]
        B3["工作流命令文件<br/>commands/workflow_<cmd>.md<br/>~30-50行/个"]
        B4[specanchor-protocol.md<br/>~190行]
        B5[Module Spec<br/>按模块]
        B6[模板文件<br/>按命令需要]
    end

    A1 --> B1
    B1 -->|识别 SpecAnchor 命令| B2
    B1 -->|识别工作流命令| B3
    B2 -->|需要协议约束| B4
    B3 -->|需要协议约束| B4
    A2 -->|定位模块| B5
    B2 -->|需要模板| B6
    B3 -->|读取项目配置| A3

    style A1 fill:#74c0fc,color:#fff
    style A2 fill:#74c0fc,color:#fff
    style A3 fill:#74c0fc,color:#fff
    style B2 fill:#ffd43b,color:#333
    style B3 fill:#ff922b,color:#fff
```

## 9. 全景架构图

```mermaid
graph TB
    subgraph "用户层"
        U[用户自然语言 / SA 命令<br/>包含开发需求和工作流命令]
    end

    subgraph "Skill 入口层"
        S[SKILL.md<br/>包含需求复杂度评估]
        Q[commands-quickref.md<br/>意图映射 + 工作流命令]
    end

    subgraph "SpecAnchor 命令层"
        C1[init.md]
        C2[global.md<br/>包含项目配置管理]
        C3[module.md]
        C4[infer.md]
        C5[task.md]
        C6[load.md]
        C7[status.md]
        C8[check.md]
        C9[index.md]
    end

    subgraph "工作流命令层"
        W1[workflow_commit_push.md<br/>代码提交推送]
        W2[workflow_submit_cr.md<br/>代码评审]
        W3[workflow_start_dev.md<br/>启动开发服务器]
        W4[workflow_stop_dev.md<br/>停止开发服务器]
    end

    subgraph "协议层"
        P1[specanchor-protocol.md<br/>核心协议]
        P2[SDD-RIPER-ONE<br/>写作协议 可替换]
    end

    subgraph "模板层"
        T1[global-spec-template.md<br/>包含 project-setup 类型]
        T2[module-spec-template.md]
        T3[task-spec-template.md]
    end

    subgraph "产出层 (.specanchor/)"
        O1[config.yaml<br/>包含复杂度评估配置]
        O2[global/*.spec.md<br/>包含 project-setup.spec.md]
        O3[modules/*.spec.md]
        O4[tasks/**/*.spec.md]
        O5[module-index.md]
    end

    subgraph "检测层"
        D1[specanchor-check.sh]
    end

    U --> S
    S --> Q
    Q --> C1 & C2 & C3 & C4 & C5 & C6 & C7 & C8 & C9
    Q --> W1 & W2 & W3 & W4
    C1 & C2 & C3 & C4 & C5 & C6 & C7 & C8 & C9 --> P1
    W1 & W2 & W3 & W4 --> P1
    C5 --> P2
    C2 --> T1
    C3 & C4 --> T2
    C5 --> T3
    C1 --> O1
    C2 --> O2
    C3 & C4 --> O3
    C5 --> O4
    C3 & C4 & C7 & C9 --> O5
    C8 --> D1
    W1 & W2 & W3 & W4 --> O2

    style U fill:#845ef7,color:#fff
    style S fill:#74c0fc,color:#fff
    style Q fill:#74c0fc,color:#fff
    style C2 fill:#51cf66,color:#fff
    style W1 fill:#ff922b,color:#fff
    style W2 fill:#ff922b,color:#fff
    style W3 fill:#ff922b,color:#fff
    style W4 fill:#ff922b,color:#fff
    style P1 fill:#ff922b,color:#fff
    style P2 fill:#ff922b,color:#fff
    style O2 fill:#51cf66,color:#fff
```

## 10. 需求复杂度评估决策树

```mermaid
flowchart TD
    A[用户输入需求] --> B{涉及文件数量}
    B -->|单文件| C{变更类型}
    B -->|多文件| D[复杂需求]

    C -->|样式调整| E[简单需求]
    C -->|bug修复| F{影响范围}
    C -->|功能修改| G{架构影响}

    F -->|局部影响| E
    F -->|全局影响| D

    G -->|无架构变更| H{预计工作量}
    G -->|有架构变更| D

    H -->|< 2小时| E
    H -->|>= 2小时| D

    D --> I[标准流程:<br/>创建 Task Spec<br/>按 RIPER 执行]
    E --> J[快速流程:<br/>直接执行命令]

    I --> K[复杂需求处理完成]
    J --> L[简单需求处理完成]

    style E fill:#51cf66,color:#fff
    style D fill:#ffd43b,color:#333
    style I fill:#ff922b,color:#fff
    style J fill:#74c0fc,color:#fff
    style K fill:#51cf66,color:#fff
    style L fill:#51cf66,color:#fff
```
