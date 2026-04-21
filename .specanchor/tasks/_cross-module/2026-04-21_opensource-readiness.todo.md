# TODO: 开源准备清单

> 来源：codex 只读 review（2026-04-21）  
> 目标：让 spec-anchor 从"作者自用工作台"变成可公开的 GitHub 开源仓库

---

## P0 — 阻塞开源的硬问题

- [x] **收窄 `.gitignore`**  
  现状：`.github/`、`docs/`、`tests/` 等公开资产被 ignore，clone 后缺文件。  
  怎么改：`.gitignore` 只排除真正的本地垃圾；`.skillexclude` 负责安装裁剪，不要混用。

- [x] **补 `LICENSE` 文件**
  现状：README 已挂 MIT badge，但仓库里没有 LICENSE 文件，是假信号。  
  怎么改：补正式 `LICENSE`（MIT）；若许可证未定，先撤 badge。

- [x] **补 `CONTRIBUTING.md`（最小版）**
  现状：外部贡献者不知道依赖前提、如何本地验证、PR 范围。  
  怎么改：至少写清 `bash tests/run.sh`、支持平台、提交流程、哪些目录是 public surface。

- [x] **清理公开版 `anchor.yaml`**  
  现状：`anchor.yaml` 引用了 `mydocs/specs/`、`docs/superpowers/*`，这些路径被 `.gitignore` 排除，clone 后路径指向空气。  
  怎么改：公开版只保留 clone 后真实存在的路径；maintainer-local sources 放本地 overlay 配置（不入 Git）。

- [x] **整理 `.specanchor/` 目录，移除 maintainer 私有上下文**  
  现状：`module-index.md` 指向不存在的 `extensions/workflow/`；任务 spec 里暴露了 `@fanghu`、`linziyanleo/spec-anchor`、repo-local mirror sync 等私有细节。  
  怎么改：把 `.specanchor/` 整理成 curated public sample；保留稳定 Global/Module 示例；个人任务 spec 移到 `examples/self-dogfood/` 或直接删除。

---

## P1 — 影响第一印象的问题

- [x] **README 首屏加一句硬定义**
  现状：开头先讲隐喻，真正的"它是什么"要往下读，5 秒看不懂。  
  怎么改：首屏第一段直接给定义，例如：  
  > SpecAnchor 是面向 AI 编码的 spec governance / anti-decay layer：用 Global/Module/Task 三层规范做加载、索引、对齐和防腐，不负责写作流程本身。

- [x] **软化 README 中的绝对化表述**
  现状：`what nobody else does`、`don't ship any of this` 等说法开源后容易被 challenge。  
  怎么改：改成 plain-language 对比——SpecAnchor 重点解决治理和防腐；SDD-RIPER-ONE/OpenSpec 重点解决写作/流程。

- [x] **补 Quick Start（60 秒 first-success path）**
  现状："怎么用"只有 rsync/symlink 手工步骤，没有 smoke test。  
  怎么改：首屏补三步 Quick Start：安装 → 运行 `specanchor-boot.sh --format=summary` → 看到什么输出算成功；长安装说明下沉到 `docs/INSTALL.md`。

- [x] **修复语言链接不一致**
  现状：English README 顶部链接到中文 `WHY.md`；核心运行协议在中文 `SKILL.md` 和 `references/commands-quickref.md` 里。  
  怎么改：修语言链接；然后二选一——要么明确"Chinese-first project"，要么补 English 版 SKILL / quick reference。

---

## P2 — 贡献者友好度

- [ ] **补 `examples/` 目录**  
  现状：没有公开 examples，现有 dogfooding `.specanchor` 是维护现场不是教学样例。  
  怎么改：补 `examples/minimal-full/` 和 `examples/parasitic/`，各含最小 `anchor.yaml`、一份 module spec、一份 task spec、预期输出示例。

- [x] **把 tests / CI / 公开脚本纳入 Git**  
  现状：tests、workflow、`doctor/resolve/validate` 等 public surface 没有稳定入库，外部读者无法验证质量。  
  怎么改：全部纳入 Git；在 `CONTRIBUTING.md` 固定验证命令。

- [ ] **清理 maintainer-specific 信息**  
  现状：代码中有 `@fanghu`、`linziyanleo/spec-anchor`、repo-local mirror sync 等个人信息。  
  怎么改：全局替换或删除；无企业敏感信息（好消息），重点是个人标识。

- [ ] **补社区治理文件（可选但推荐）**  
  `CODE_OF_CONDUCT.md`、`SECURITY.md` 不是硬 blocker，但缺了显得只准备"被看"没准备"被参与"。  
  怎么改：补最小版，行为边界 + 安全联系方式即可。

---

## 补充发现（2026-04-21 二次审视）

> 来源：在现仓库中逐个验证 TODO 诊断时发现的增量问题  
> 核心判断：按原 TODO 修完能到"能开源"的及格线，但离"好的开源项目"还差一档

### A — 原 P0 比文字描述的更严重（需提升优先级）

- [x] **`.gitignore` 把 `SKILL.md` 的依赖文件一起排除了，clone 后 Skill 本体是坏的**  
  证据：`.gitignore` 排除了 `references/assembly-trace.md`、`references/script-contract.md`、`references/workflow-gates.md`、`references/integrations/`、`scripts/specanchor-doctor.sh`、`scripts/specanchor-resolve.sh`、`scripts/specanchor-validate.sh`、`scripts/lib/`——而这些全部被 `SKILL.md`（第 45、51、84-91 行）明确引用。  
  影响：外部用户 clone 后，`specanchor-boot.sh` 会因缺文件失败；SKILL 的 Reference Index 章节指向空气。  
  怎么改：这条不是"收窄 gitignore"的一部分，而是其**验收标准**——收窄后必须能跑通 `bash scripts/specanchor-boot.sh --format=summary`，否则没改到位。

- [x] **`anchor.yaml` 的外部 sources 全部指向被 ignore 的路径**  
  证据：`anchor.yaml` 的 `sources` 引用 `mydocs/specs/`、`docs/superpowers/specs/`、`docs/superpowers/plans/`，而 `/mydocs/*`、`/docs/` 均在 `.gitignore` 中。  
  影响：fresh clone 后第一次 `boot` / `check` 都会在 sources 路径解析上报错。  
  怎么改：公开版 `anchor.yaml` 只保留仓库内真实存在的路径；maintainer-local sources 不入 Git（保留为本地 uncommitted 修改或 maintainer 分支）。  
  **工具现状（重要）**：现有公开脚本（`boot` / `status` / `check`）只认 `anchor.yaml` 与 `.specanchor/config.yaml`（见 `scripts/specanchor-boot.sh:196`、`scripts/specanchor-status.sh:112`、`references/specanchor-protocol.md:25`），**没有 `anchor.local.yaml` overlay 合并机制**。此 TODO 不承诺"有 overlay 文件就会自动合并"——这会误导执行。若确实需要 overlay 能力，作为独立实现项参见 B⑦。

- [x] **`.specanchor/modules/extensions-workflow.spec.md` 引用的 `extensions/` 目录不存在**  
  证据：`anchor.yaml coverage.scan_paths` 和 `module-index` 都声明了 `extensions/`，但仓库根没有该目录。  
  影响：`specanchor-check.sh` 会报 orphan module spec 或覆盖率异常。  
  怎么改：删除 extensions 模块 spec，或补真正的 `extensions/workflow/` 目录。属于原 TODO "整理 `.specanchor/`"范畴，但这是**现有腐化**不是私有信息泄露。

### B — 原 TODO 缺失的条目

- [x] **加一条 "fresh-clone smoke" CI 作为 P0 验收标准**  
  现状：没有任何机制能保证 P0 修完"clone 后真的能用"——人肉很容易漏。  
  经验校验（Codex 2026-04-21 实测）：仅 tracked 文件的 fresh clone 跑 `boot` 与 `check` 都 0 退出，但 `boot` 仍打印 3 个本地 source 的 `✗`；`check` 仍对 `extensions/workflow` 报 warning，并且会改写 `.specanchor/module-index.md` 的 `generated_at` 字段。**单纯看退出码会漏掉它本来该拦的所有错误。**  
  怎么改：`.github/workflows/` 里加 job，验收标准必须同时满足——  
  1. `bash scripts/specanchor-boot.sh --format=summary` 输出里**不再出现本仓本地 source 的 `✗`**（用 grep 断言）  
  2. 校验走 `specanchor-doctor.sh --strict`（或等价 non-zero 语义），**不能依赖 warning-only 退出码**  
  3. 全部验证跑完后 `git status --porcelain` 必须为空（拦住 `generated_at` 这类"CI 绿但改了文件"的副作用）  
  4. `bash tests/run.sh` 通过  
  这四条合起来才是守门员；少任何一条都会放过现在已知的问题。

- [ ] **公开 API 稳定性边界声明**  
  现状：开源后外部会依赖 `anchor.yaml` schema、`scripts/*.sh` 参数、`specanchor_*` 命令 ID——但仓库内没有任何地方区分 public surface 和 internal。一改就是 breaking change。  
  怎么改：在 `CONTRIBUTING.md` 或 `references/stability-contract.md` 里明确：0.x 版本不承诺稳定；或列出哪些接口稳定（boot/status/check 的 flags）、哪些内部（`scripts/lib/`、命令 ID 命名）。

- [x] **声明 `assets/` 的来源与授权**
  现状：`assets/SpecAnchor_logo.png`、`assets/SpecAnchorHero.jpg` 没有来源声明。MIT 只覆盖代码，图像资产许可需要单独说明。  
  怎么改：在 `assets/README.md`（或根 `LICENSE` 的附加条款里）注明：原创 / CC-BY / 第三方授权，附署名要求。若 Hero 图是 AI 生成，也要注明模型与 prompt 责任归属。

- [x] **写一行 Skill 的威胁模型**
  现状：此 Skill 会写入 `.specanchor/`、修改任意 Markdown 的 frontmatter（`frontmatter-inject.sh`）、执行 shell 脚本——开源用户需要知道它会改他们的仓库。  
  怎么改：README Quick Start 顶部加一行红字提示："此 Skill 会在你的仓库内创建 `.specanchor/` 并修改 Markdown 文件的 frontmatter，首次使用建议在干净分支上试。"这比事后补完整 `SECURITY.md` 更有用。

- [x] **双语策略落地（不是二选一后不做）**
  现状：原 P1 提了修语言链接，但没给策略。  
  怎么改：按当前方向明确 **English-first**——`README.md`、`CONTRIBUTING.md`、安装等开源 contributor-facing 文档以英文为权威；保留 `README_ZH.md` 作为中文导读/翻译。若中英文漂移，以英文版为准。

- [ ] **Release 纪律：v0.4.0 需要 tag 和 changelog**  
  现状：README badge 写 `v0.4.0`、`anchor.yaml` 写 `0.4.0`、但 `CHANGELOG.md` 只有 346 字节，且仓库没有 `v0.4.0` tag。  
  怎么改：开源那天之前——`CHANGELOG.md` 补一段 0.4.0 release note；`git tag v0.4.0` 并推送；后续版本走 `CHANGELOG.md` + tag 双轨。

- [ ] **B⑦ `anchor.local.yaml` overlay 支持（可选实现项）**  
  现状：上面 A② 建议把 maintainer-local sources 移出 Git，但现有脚本不支持 overlay 合并——maintainer 每次本地开发都得手动 uncommitted 修改 `anchor.yaml`，体验差且易误提交。  
  怎么改：在 `boot` / `status` / `check` 的 config 加载层增加一步——若存在 `anchor.local.yaml` 则合并进 resolved config（`sources` 列表追加，其他 key 以 local 覆盖 base）；加 `.gitignore` 守护；在 `references/specanchor-protocol.md` 的 config 加载章节记录合并语义。  
  优先级：不是开源硬 blocker，属于 maintainer DX 改善；若不实现，就按 A② 的保守说法（本地不入库、不自动合并）执行。

- [x] **B⑧ "consumer install smoke" 回归保护**  
  现状：README 宣称的真实使用路径是 `rsync -a --exclude-from=.skillexclude` 把 Skill 装到别人的项目里跑，不是在本仓内 dogfood。Codex 实测目前 install→`specanchor-init.sh`→`specanchor-boot.sh` 这条链是通的，所以不是 blocker，但没有任何回归保护。  
  怎么改：在 CI 里加一个与 fresh-clone smoke 并列的 job——`rsync --exclude-from=.skillexclude` 到一个临时 fixture 项目 → 跑 `specanchor-init.sh` → `specanchor-boot.sh --format=summary` → 断言 exit 0 且无 `✗`。把 consumer 视角的安装链路 pin 成回归测试，防止未来 `.skillexclude` 或脚本路径改坏外部安装。

### C — 建议执行顺序（已按 Codex 反馈修订）

修订要点：  
- 把"tests / CI / public scripts 入库"从 P2 提到 Step 1——否则 B① 验收里的 `tests/run.sh` 压根没入库，无法执行  
- Step 1 只做"unbreak clone + 可验证"，Step 2 只做 legal/assets，移除重复出现的 LICENSE  
- B⑧（consumer install smoke）与 B① 并列进 Step 1

1. [x] **"Unbreak clone + verifiable" PR**（已完成，2026-04-21）  
   包含：原 P0 ①（收窄 `.gitignore`）+ 原 P0 ④（清理公开版 `anchor.yaml`）+ 原 P0 ⑤（整理 `.specanchor/`）+ **原 P2 "tests / CI / public scripts 入库"（从 P2 提上来）** + 补充 A①②③ + 补充 B①（fresh-clone smoke 守门员）+ 补充 B⑧（consumer install smoke）。  
   目标：fresh clone 后达到 B① 四条验收（无 `✗`、`doctor --strict` 通过、工作树 clean、`tests/run.sh` 通过）；且 `rsync` 安装到外部项目后也能 boot 成功。**这是所有其他工作的前提。**  
   完成记录：仓库根验证 `boot + doctor --strict + tests/run.sh + git diff --check` 已通过；基于当前工作树内容导出的 staged-state checkout 验证通过；consumer install 显式 smoke 通过。
2. [x] **Legal / Assets PR**（已完成，2026-04-21）
   原 P0 ②（`LICENSE` 文件）+ 补充 B③（assets 许可声明）。
3. [x] **DX / README PR**（已完成，2026-04-21）
   原 P0 ③（`CONTRIBUTING.md` 最小版，固定 B① 的验证命令）+ 原 P1 全部 + 补充 B④（威胁模型一行字）+ 补充 B⑤（双语策略：English-first）。
   完成记录：`README.md` 改成 English-first overview，补 60-second Quick Start 与风险提示；长安装说明下沉到 `docs/INSTALL.md`；中文版本收敛为 `README_ZH.md`，并明确英文 contributor-facing 文档为权威版本。
4. **Contributor / Polish PR**  
   原 P2 剩余项（`examples/`、maintainer-specific 信息清理、`CODE_OF_CONDUCT.md` / `SECURITY.md`）+ 补充 B②（稳定性边界）+ 补充 B⑥（release 纪律 + `v0.4.0` tag）+ 补充 B⑦（overlay 支持，若决定实现）。
