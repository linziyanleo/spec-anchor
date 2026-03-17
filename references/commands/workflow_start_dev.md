# workflow_start_dev - 启动项目

## 命令描述

自动启动项目开发服务器，并在浏览器中打开项目页面。

## 触发词

- "启动项目"
- "运行项目"
- "start"
- "dev"
- "启动开发服务器"

## 执行流程

1. 从 `.specanchor/global/project-setup.spec.md` 读取项目启动命令
2. 如果 project-setup.spec.md 不存在或启动命令为空，从 package.json 读取（优先级：start > dev > serve）
3. 执行启动命令（如 `npm run dev`）
4. 等待服务器启动完成（检测输出中的关键词或端口）
5. 从 project-setup.spec.md 读取本地运行地址
6. 执行 `open <url>` 命令自动打开浏览器（默认必须执行，不可跳过）

## 启动命令优先级

### 从 project-setup.spec.md 读取

```markdown
## 项目启动命令

npm run dev
```

### 从 package.json 读取

```javascript
// 优先级：start > dev > serve
const startCommand =
	packageJson.scripts.start || packageJson.scripts.dev || packageJson.scripts.serve
```

## 服务器启动检测

### 检测关键词

- "Local:"
- "localhost"
- "127.0.0.1"
- "Network:"
- "ready"
- "compiled"
- "running at"
- "server started"

### 检测端口

- `:3000`
- `:5173`
- `:8080`
- `:4200`
- `:3001`

### 超时设置

- 最大等待时间：30 秒
- 如果超时，仍然尝试打开浏览器

## 执行示例

### 示例 1：标准流程

```
用户："启动项目"

你的处理流程：
1. 从 project-setup.spec.md 读取启动命令：npm run dev
2. 执行命令：npm run dev
3. 等待服务器启动（检测输出中的 "Local:" 或 "localhost"）
4. 从 project-setup.spec.md 读取地址：http://localhost:5173
5. 执行：open http://localhost:5173
6. 告知用户："项目已启动，浏览器已打开！"
```

### 示例 2：从 package.json 读取

```
用户："运行项目"

你的处理流程：
1. project-setup.spec.md 不存在或启动命令为空
2. 从 package.json 读取：scripts.dev = "vite"
3. 执行命令：npm run dev
4. 检测到输出："Local: http://localhost:5173/"
5. 提取地址：http://localhost:5173
6. 执行：open http://localhost:5173
7. 告知用户："项目已启动，浏览器已打开！"
```

### 示例 3：多端口项目

```
用户："start"

你的处理流程：
1. 执行启动命令：npm run dev
2. 检测到多个端口：
   - Frontend: http://localhost:3000
   - Backend: http://localhost:8080
3. 询问用户："检测到多个服务，请选择要打开的地址：
   1. 前端应用 (http://localhost:3000)
   2. 后端服务 (http://localhost:8080)
   3. 全部打开"
4. 根据用户选择执行 open 命令
```

## 地址提取规则

### 从输出中提取

```bash
# Vite 输出示例
Local:   http://localhost:5173/
Network: http://192.168.1.100:5173/

# Next.js 输出示例
ready - started server on 0.0.0.0:3000, url: http://localhost:3000

# Create React App 输出示例
Local:            http://localhost:3000
On Your Network:  http://192.168.1.100:3000
```

### 提取优先级

1. "Local:" 后的地址
2. "localhost" 相关地址
3. "127.0.0.1" 相关地址
4. 从 project-setup.spec.md 的默认地址

## 错误处理

### 常见错误处理示例

```
错误 1：启动命令未配置
→ 告知用户："未找到启动命令，请先通过 'specanchor_global' (project-setup 类型) 配置项目信息。"

错误 2：端口被占用
→ 告知用户："端口被占用，请检查是否有其他进程占用该端口。
   可以使用以下命令查看：
   - macOS/Linux: lsof -i :5173
   - Windows: netstat -ano | findstr :5173"

错误 3：依赖未安装
→ 告知用户："依赖未安装，请先执行 npm install 安装依赖。"

错误 4：Node.js 版本不兼容
→ 告知用户："Node.js 版本不兼容，请检查项目要求的 Node.js 版本。
   当前版本：$(node --version)
   建议使用 nvm 管理 Node.js 版本。"

错误 5：权限不足
→ 告知用户："权限不足，请检查：
   1. 文件读写权限
   2. 端口绑定权限
   3. 尝试使用管理员权限运行"

错误 6：内存不足
→ 告知用户："内存不足，请尝试：
   1. 关闭其他应用程序
   2. 增加 Node.js 内存限制：--max-old-space-size=4096
   3. 检查系统可用内存"
```

## 浏览器打开规则

### 默认行为

- **必须自动打开浏览器**，这是默认行为
- 使用系统默认浏览器
- 如果有多个地址，询问用户选择

### 地址选择优先级

1. 用户通过 `--url` 参数指定的地址
2. project-setup.spec.md 中配置的地址
3. 从启动输出中提取的 Local 地址
4. 从启动输出中提取的第一个 localhost 地址

### 特殊情况处理

```bash
# 情况 1：HTTPS 地址
https://localhost:3000 → 直接打开

# 情况 2：带路径的地址
http://localhost:3000/admin → 直接打开

# 情况 3：IP 地址
http://192.168.1.100:3000 → 询问用户是否打开（可能是网络地址）
```

## 参数

- `--no-browser`: 可选，不自动打开浏览器（仅在用户明确指定时才跳过）
- `--url`: 可选，指定打开的 URL（覆盖 project-setup.spec.md 中的值）
- `--port`: 可选，指定启动端口

### 使用参数示例

```
用户："启动项目 --no-browser"

你的处理流程：
1. 执行启动命令：npm run dev
2. 等待服务器启动
3. 跳过打开浏览器步骤
4. 告知用户："项目已启动在 http://localhost:5173，但未自动打开浏览器。"
```

```
用户："start --url http://localhost:3000/admin"

你的处理流程：
1. 执行启动命令
2. 等待服务器启动
3. 使用指定地址：http://localhost:3000/admin
4. 执行：open http://localhost:3000/admin
```

## 后台运行管理

### 进程管理

- 启动命令在后台运行，不阻塞后续操作
- 记录进程 ID 和端口信息
- 支持通过 `workflow_stop_dev` 命令停止

### 状态监控

- 定期检查服务器状态
- 如果服务器意外停止，通知用户
- 提供重启选项

## 多项目支持

### 检测多个 package.json

```
项目根目录/
├── package.json (主项目)
├── frontend/package.json
└── backend/package.json
```

### 处理流程

1. 检测到多个项目配置
2. 询问用户选择要启动的项目
3. 切换到对应目录执行启动命令
4. 记录启动的项目信息

## 注意事项

- 启动命令会在后台运行，不会阻塞后续操作
- 服务器启动后**必须自动执行** `open <url>` 打开浏览器，这是默认行为
- 如果用户明确指定 `--no-browser`，才跳过打开浏览器的步骤
- 服务器启动检测超时时间为 30 秒
- 如果检测失败，仍然尝试打开浏览器（可能服务器已启动但输出格式不同）
- 支持同时启动多个开发服务器（前端、后端等）
- 记录启动的服务器信息，便于后续管理和停止
