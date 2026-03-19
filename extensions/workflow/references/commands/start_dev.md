# workflow_start_dev - 启动项目

## 触发词

"启动项目" / "运行项目" / "start" / "dev" / "启动开发服务器"

## 执行流程

1. 从 `.specanchor/global/project-setup.spec.md` 读取项目启动命令和本地运行地址
2. 如果 project-setup.spec.md 不存在，从 `package.json` 的 scripts 中读取（优先级：start > dev > serve）
3. 执行启动命令（如 `npm run dev`），在后台运行
4. 检测服务器启动完成（检测输出中的 "Local:" / "localhost" / "ready" / "compiled" 等关键词）
5. 从 project-setup.spec.md 或服务器输出中获取本地地址
6. 执行 `open <url>` 打开浏览器（默认行为，`--no-browser` 跳过）

## 超时与边界

- 最大等待启动时间：30 秒
- 超时后仍尝试打开浏览器（服务器可能已启动但输出格式不同）
- 多端口项目：询问用户选择要打开的地址
- 端口被占用：提示检查进程（`lsof -i :<port>`）

## 参数

- `--no-browser`：不自动打开浏览器
- `--url`：指定打开的 URL
- `--port`：指定启动端口
