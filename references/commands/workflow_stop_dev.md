# workflow_stop_dev - 停止项目

## 命令描述

自动停止正在运行的项目开发服务器。

## 触发词

- "停止项目"
- "停止开发服务器"
- "stop"
- "关闭项目"
- "停止本地服务器"

## 执行流程

1. 检查 environment_details 中的 "Actively Running Terminals" 部分
2. 识别正在运行的开发服务器进程
3. 向对应终端发送终止信号（Ctrl+C）
4. 确认进程已停止
5. 告知用户停止结果

## 识别规则

开发服务器进程通常包含以下特征：

### 命令特征

- `npm run dev`
- `npm start`
- `yarn dev`
- `pnpm dev`
- `vite`
- `webpack-dev-server`
- `next dev`
- `ng serve`
- `vue-cli-service serve`

### 端口特征

- `localhost:*`
- `127.0.0.1:*`
- `0.0.0.0:*`
- 常见端口：3000, 5173, 8080, 4200, 3001

## 执行示例

### 示例 1：单个开发服务器

```
用户："停止项目"

你的处理流程：
1. 检查 environment_details 中的活动终端
2. 发现终端 ID: 12345 正在运行 "npm run dev"
3. 向终端 12345 发送 Ctrl+C 信号
4. 等待进程停止（最多 5 秒）
5. 确认进程已停止
6. 告知用户："开发服务器已停止！"
```

### 示例 2：多个开发服务器

```
用户："stop"

你的处理流程：
1. 检查活动终端
2. 发现多个开发服务器进程：
   - 终端 12345: npm run dev (端口 5173)
   - 终端 12346: npm run dev:admin (端口 5174)
3. 询问用户："检测到多个开发服务器，请选择要停止的服务器：
   1. 主应用 (端口 5173)
   2. 管理后台 (端口 5174)
   3. 全部停止"
4. 根据用户选择执行停止操作
```

### 示例 3：无运行中的服务器

```
用户："停止开发服务器"

你的处理流程：
1. 检查活动终端
2. 未发现正在运行的开发服务器
3. 告知用户："未检测到正在运行的开发服务器。"
```

## 进程识别算法

### 第一步：扫描活动终端

```javascript
// 从 environment_details 获取活动终端信息
const activeTerminals = environmentDetails.activeTerminals || []

// 筛选开发服务器进程
const devServers = activeTerminals.filter((terminal) => {
	const command = terminal.command.toLowerCase()
	return (
		command.includes('npm run dev') ||
		command.includes('npm start') ||
		command.includes('yarn dev') ||
		command.includes('pnpm dev') ||
		command.includes('vite') ||
		command.includes('webpack-dev-server') ||
		command.includes('next dev') ||
		command.includes('ng serve') ||
		command.includes('vue-cli-service serve')
	)
})
```

### 第二步：端口检测

```bash
# 检测常用开发端口
lsof -i :3000 -i :5173 -i :8080 -i :4200 -i :3001

# 或使用 netstat (跨平台)
netstat -tulpn | grep -E ':(3000|5173|8080|4200|3001)'
```

### 第三步：进程匹配

```javascript
// 匹配终端进程和端口信息
const matchedServers = devServers.map((server) => ({
	terminalId: server.id,
	command: server.command,
	port: extractPortFromCommand(server.command),
	pid: server.pid,
}))
```

## 停止方法

### 方法 1：终端信号（推荐）

```javascript
// 向终端发送 Ctrl+C 信号
sendSignalToTerminal(terminalId, 'SIGINT')

// 等待进程响应
await waitForProcessStop(terminalId, 5000) // 5秒超时
```

### 方法 2：进程终止（备用）

```bash
# 如果终端信号失败，直接终止进程
kill -TERM <PID>

# 强制终止（最后手段）
kill -KILL <PID>
```

### 方法 3：端口释放检查

```bash
# 确认端口已释放
lsof -i :<PORT> || echo "端口已释放"
```

## 错误处理

### 常见错误处理示例

```
错误 1：未找到运行中的开发服务器
→ 告知用户："未检测到正在运行的开发服务器。"

错误 2：进程无法停止
→ 告知用户："无法正常停止进程，尝试强制终止...
   如果问题持续，请手动终止进程：
   - macOS/Linux: ps aux | grep 'npm run dev' 然后 kill -9 <PID>
   - Windows: tasklist | findstr node 然后 taskkill /F /PID <PID>"

错误 3：权限不足
→ 告知用户："权限不足，无法停止进程。请尝试：
   - 手动在终端中按 Ctrl+C 停止
   - 或使用管理员权限运行命令"

错误 4：端口仍被占用
→ 告知用户："进程已停止，但端口仍被占用。请检查：
   1. 是否有其他进程使用该端口
   2. 使用 lsof -i :<PORT> 查看端口占用情况
   3. 重启系统以释放所有端口"

错误 5：终端无响应
→ 告知用户："终端无响应，尝试强制关闭...
   如果问题持续，请：
   1. 手动关闭终端窗口
   2. 重启 IDE 或编辑器
   3. 检查系统资源使用情况"
```

## 特殊情况处理

### 情况 1：多个开发服务器运行

```javascript
// 检测到多个服务器时的处理逻辑
if (devServers.length > 1) {
	const options = devServers.map((server, index) => ({
		id: index + 1,
		description: `${server.name || '未知服务'} (端口 ${server.port})`,
		terminalId: server.terminalId,
	}))

	options.push({
		id: options.length + 1,
		description: '全部停止',
		action: 'stopAll',
	})

	// 询问用户选择
	const choice = await askUserChoice(options)

	if (choice.action === 'stopAll') {
		await stopAllServers(devServers)
	} else {
		await stopServer(devServers[choice.id - 1])
	}
}
```

### 情况 2：进程卡死

```javascript
// 处理卡死的进程
async function stopServerWithTimeout(server, timeout = 5000) {
	try {
		// 先尝试正常终止
		await sendSignal(server.terminalId, 'SIGINT')
		await waitForStop(server.pid, timeout)
	} catch (timeoutError) {
		// 超时后强制终止
		console.log('正常终止超时，尝试强制终止...')
		await sendSignal(server.terminalId, 'SIGKILL')
		await waitForStop(server.pid, 2000)
	}
}
```

### 情况 3：后台进程

```javascript
// 检测后台运行的开发服务器
async function detectBackgroundServers() {
	const processes = await getProcessList()

	const backgroundServers = processes.filter(
		(proc) =>
			proc.command.includes('node') &&
			(proc.args.includes('vite') ||
				proc.args.includes('webpack-dev-server') ||
				proc.args.includes('next'))
	)

	if (backgroundServers.length > 0) {
		console.log('检测到后台运行的开发服务器：')
		backgroundServers.forEach((server) => {
			console.log(`- PID: ${server.pid}, 端口: ${server.port}`)
		})

		const shouldStop = await askUser('是否停止这些后台服务器？')
		if (shouldStop) {
			await stopBackgroundServers(backgroundServers)
		}
	}
}
```

## 清理操作

### 临时文件清理

```bash
# 清理常见的临时文件
rm -rf .vite/
rm -rf .next/
rm -rf dist/
rm -rf build/

# 清理缓存
npm cache clean --force
yarn cache clean
```

### 端口释放确认

```javascript
async function confirmPortReleased(port) {
	const maxRetries = 3
	let retries = 0

	while (retries < maxRetries) {
		const isPortFree = await checkPortFree(port)
		if (isPortFree) {
			console.log(`端口 ${port} 已释放`)
			return true
		}

		retries++
		await sleep(1000) // 等待1秒后重试
	}

	console.warn(`端口 ${port} 仍被占用，可能需要手动处理`)
	return false
}
```

## 参数

- `--force`: 可选，强制终止所有相关进程
- `--port`: 可选，指定要停止的端口号
- `--all`: 可选，停止所有检测到的开发服务器

### 使用参数示例

```
用户："停止项目 --force"

你的处理流程：
1. 检测所有开发服务器进程
2. 跳过用户确认，直接强制终止所有进程
3. 清理临时文件和缓存
4. 告知用户："所有开发服务器已强制停止！"
```

```
用户："stop --port 3000"

你的处理流程：
1. 查找占用端口 3000 的进程
2. 终止该进程
3. 确认端口已释放
4. 告知用户："端口 3000 上的服务已停止！"
```

## 状态报告

### 停止前状态

```
检测到以下运行中的开发服务器：
1. 主应用 - npm run dev (PID: 12345, 端口: 5173)
2. 管理后台 - npm run dev:admin (PID: 12346, 端口: 5174)
3. API 服务 - node server.js (PID: 12347, 端口: 8080)
```

### 停止后状态

```
停止结果：
✅ 主应用 (端口 5173) - 已停止
✅ 管理后台 (端口 5174) - 已停止
❌ API 服务 (端口 8080) - 停止失败，需要手动处理

已释放端口：5173, 5174
仍被占用端口：8080
```

## 注意事项

- 停止前会先确认是否有正在运行的开发服务器
- 如果有多个开发服务器，会询问用户选择
- 使用 `--force` 参数会跳过确认直接强制终止
- 停止后会清理相关的临时文件和缓存（如果需要）
- 支持检测和停止后台运行的开发服务器
- 会确认端口释放状态，确保完全停止
- 提供详细的状态报告，便于用户了解停止结果
