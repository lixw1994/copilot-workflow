# copilot-workflow

[English](./README.md) | 简体中文

给任意项目一键装上 AI 协作的工程化工作流：以 OpenSpec 的 spec-driven 流程为核心（proposal → specs → design → adr → tasks），配 ADR 决策记录与 pre-commit 纪律钩子。可选增强：基于 Herdr（终端多路复用器）的 AI 小队，装在 `.herdr/` 下，不侵入项目版本库。

## 设计

**工作流是本体，小队是增强。**

- **工程化工作流**（侵入项目、随项目版本化）：大变更走 OpenSpec 流水线，spec 和 ADR 是跨变更持久的事实来源，小改动直接做；pre-commit 钩子强制 spec 校验与「已采纳 ADR 不可修改」。任何 coding agent 读 `AGENTS.md` 即可遵守，不需要 Herdr。
- **Herdr 小队**（机器级环境，整目录 gitignore）：一个 Tech Lead 主导一切，按需拉起三个辅助角色。只有 `HERDR_ENV=1` 且 `.herdr/` 存在时生效；没有 Herdr 时 agent 独立工作，主流程不受影响。

```
你（用户）
 └── Tech Lead（主 pane，直接对话对象）
      ├── researcher   外部资料收集与调研（按需拉起）
      ├── writer       docs/ 文档编写（按需拉起）
      └── worker       简单杂活外包（很少拉起）
```

小队哲学：**默认 Dogfooding**。Tech Lead 是能力 world-class、作风务实的工程师——该写的单测认真写，但不让测试盖过代码本身的风头；坚守质量由工程内建、而非靠 QA 兜底的原则。它 eat its own dog food，亲自负责架构、开发和维护。其他角色只在特定场景被调用，且产出一律由 Tech Lead 审查。

## 目录说明

```
init.sh              一键安装下列受托管工作流资产
AGENTS.md            工作流纪律 + 小队条件入口（coding agent 自动加载）
scripts/
  pre-commit.sh      纪律钩子逻辑（spec 校验 + ADR 不可变，随项目版本化）
  regression-test.sh 仅在模板仓库运行的安装自愈与小队名称冲突回归检查
openspec/            OpenSpec 工作区（specs = 功能现状，changes = 进行中变更）
  schemas/spec-driven-with-adr/   默认工作流 schema（随仓库版本化）
  schemas/minimalist/             探索性 spike 用的轻量 schema（specs → tasks）
adr/                 架构决策记录，跨变更持久，已采纳即不可修改
docs/                项目文档（writer 的唯一写入范围）
.agents/skills/      schema 配套 skills + 小队级 skills + OpenSpec 工作流 skills
squad/               小队源码（角色提示词、协作协议、配置模板、生命周期脚本）
                     ——安装时映射为目标项目的 .herdr/，本目录自身不会被复制进目标项目
.herdr/              小队运行实例（已 gitignore；本仓库对自己跑 init.sh 生成，自迭代测试用）
  AGENTS.md          小队协作协议
  roles/             四个角色的提示词
  squad.conf         小队配置（本地定制复制为 squad.local.conf）
  scripts/squad.sh   小队生命周期：up / down / restart / status / print
  handoff/           成员交接产物（调研报告等中间过程）
```

源码与实例分离：改小队要改 `squad/` 源码，重跑 `./init.sh` 刷新 `.herdr/` 实例；直改 `.herdr/` 会在下次安装时被覆盖。

## 一键安装到你的项目

在目标项目根目录执行（新项目、存量项目均可）：

```bash
curl -fsSL https://raw.githubusercontent.com/lixw1994/copilot-workflow/main/init.sh | bash
# 或克隆本仓库后：cd 你的项目 && /path/to/copilot-workflow/init.sh
```

特性：

- **合并式**：已有 `AGENTS.md` 只追加标记块，已有 git 钩子备份后链式调用，用户内容零破坏
- **幂等**：重跑即升级托管内容，`.copilot-workflow.yaml` 清单记录版本与托管路径
- **组件可选**：`--with squad,openspec,adr,skills,hooks`（默认全装）；缺 openspec CLI 时自动跳过该组件并给出指引
- **不侵入**：小队装进 `.herdr/` 并自动 gitignore，项目版本库只多出工作流本体
- **语言偏好**：OpenSpec 产出工件默认英文，可用 `--language "Simplified Chinese"`（或任意语言）配置
- **存量项目冷启动**：安装完成后输出 onboarding 引导（反推初始 specs、回填既成决策为 ADR）

注意：`.herdr/` 和 git 钩子都不入版本库，clone 项目的新机器重跑一次 `init.sh` 即可恢复。

## 使用方式

### 工作流（任何 coding agent，无需 Herdr）

大变更用自然语言发起——请求会触发对应的 `openspec-*` skill，由 skill 执行流水线（`AGENTS.md` 只定义"什么变更必须走流程"的纪律）：

```
「起个 OpenSpec 变更：<变更想法>」   创建变更并依次产出 proposal / specs / design / adr / tasks
「按 tasks 实施」                    对应 openspec-apply-change skill
「归档这个变更」                     specs 合入 openspec/specs/，ADR 留在 adr/
```

这些 skill 位于 `.agents/skills/openspec-*`，跨 agent 通用。

### 小队（Herdr 环境）

1. 在 Herdr 中打开项目，主 pane 启动你的 coding agent——它读到 `AGENTS.md` 的条件入口后加载 `.herdr/AGENTS.md`，自动成为 Tech Lead。
2. 正常给它派活。它默认独立完成；需要外部调研、文档整理或简单杂活时，会自行拉起对应成员并投递任务。
3. 也可以手动操作：

```bash
.herdr/scripts/squad.sh up              # 一键拉起全队（按 .herdr/squad.conf）
.herdr/scripts/squad.sh up researcher   # 或只拉起单个角色
herdr agent prompt researcher "调研 X 库最新版本的 breaking changes，产出报告到 .herdr/handoff/"
# 投递后各干各的（异步），稍后收结果：
herdr agent get researcher
herdr agent read researcher --source recent-unwrapped --lines 120
.herdr/scripts/squad.sh down            # 用完停止全队；restart 重启；status 看存活
```

默认模型分工（`.herdr/squad.conf`）：researcher 用 grok（grok-4.6 xhigh），writer 用 pi（gemini-3.7-flash），worker 用 codex（gpt-5.6-sol）。想改就把它复制为 `.herdr/squad.local.conf` 后修改（整文件优先生效，模板升级不会覆盖它）。

## 依赖

- git（必需）
- OpenSpec CLI：`npm install -g @fission-ai/openspec@latest`（需 ≥ 1.3，本项目用 `openspec init --tools agents` 初始化）
- 小队增强另需：Herdr（`HERDR_ENV=1`）、`jq`、一个 Herdr 支持的 coding agent（默认 kind 为 `codex`，可用 `HERDR_AGENT_KIND` 覆盖）

## 角色权限矩阵

| 角色 | 读代码 | 写代码/架构 | 写 openspec/ 与 adr/ | 写 docs/ | 写 .herdr/handoff/ | 上外网调研 |
|------|:------:|:-----------:|:--------------------:|:--------:|:----------------:|:----------:|
| tech-lead | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| researcher | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| writer | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ |
| worker | ✓ | 仅任务指定范围 | ✗ | ✗ | ✗ | ✗ |
