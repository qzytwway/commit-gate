# commit-gate

一个 Claude Code 技能（skill）：给任意 git 项目装上一道“提交关卡”，让 Claude 每次 `git commit` 之前都必须先过两关——**全项目 lint 检查**和**一个独立 AI 的代码审查**。

## 解决什么问题

让 Claude 写代码并自己提交时，常见的问题是：

- 代码有语法问题、明显的坏味道，没跑 lint 就直接提交了；
- 项目里加了新语言（比如后来多了几个 Rust 文件），却没人给它配 lint，问题被悄悄放过；
- 写代码的和检查代码的是同一个 AI，它很难发现自己的错误。

commit-gate 用 Claude Code 的 hooks（在 Claude 执行某条命令前自动触发的检查）把这些堵住：

1. **Lint 关**：提交前必须运行 `scripts/lint-gate.sh run`，而且通过的必须正好是当前暂存的内容。暂存区一变，就得重跑。
2. **审查关**：一个没见过写代码过程的 Fable 5.2 代理单独读这次的改动，发现 bug、崩溃、安全问题、数据丢失等就拒绝提交，并列出 `文件:行号` 和原因。

## Lint 怎么检查

`lint-gate.sh run` 检查的是**整个项目**，不只是改动部分。它每次都根据 git 跟踪的文件扩展名自动判断项目里有哪些语言，再跑对应的内置 linter：

| 语言 | linter |
|------|--------|
| Go | golangci-lint |
| Python | ruff |
| Rust | cargo clippy |
| JS / TS（含 React） | oxlint |
| Shell | shellcheck |

以下情况都会拦下提交（宁可拦错，不放过）：

- 某个 linter 报错；
- 需要的 linter 没安装（会打印安装命令）；
- 出现了既不是已知语言、也不在“非代码”名单里的文件类型。

## 安装

前提：已装好 Claude Code、`git`、`jq`。

1. 把本仓库放到 Claude 的技能目录（或做个软链接）：

   ```bash
   git clone https://github.com/qzytwway/commit-gate.git ~/.claude/skills/commit-gate
   ```

2. 在想加关卡的项目里，对 Claude 说“给这个项目装上 commit gate”。Claude 会按 [SKILL.md](SKILL.md) 的步骤完成安装、跑一次检查，并把结果告诉你。

   也可以在项目根目录手动运行安装脚本：

   ```bash
   bash ~/.claude/skills/commit-gate/setup.sh
   ```

   手动安装后，还要把 [SKILL.md](SKILL.md) 第 4 步里那段“Committing”说明加进项目的 `CLAUDE.md`，Claude 才知道提交前要先跑脚本。

安装会在项目里生成或修改这些文件（需要你提交它们）：

- `scripts/lint-gate.sh` —— lint 脚本
- `scripts/lint-gate.conf` —— 项目设置（重复安装不会覆盖）
- `.claude/settings.json` —— 加入两个提交前 hook
- `.gitignore` —— 忽略 `.lint-gate/` 记录目录

装完后建议**新开一个 Claude Code 会话**，hook 才一定生效。

## 日常使用

装好后什么都不用做。Claude 提交时的流程是：

```text
git add <文件>  →  scripts/lint-gate.sh run  →  git commit
                      │                            │
                 lint 通过，记录暂存内容      hook 核对记录 + Fable 审查
```

被拦下时，Claude 会修代码再重来，不会去关规则或绕过 hook。

## 配置 `scripts/lint-gate.conf`

一般保持为空。只有遇到内置 linter 不认识的文件类型时才需要改：

- `LINT_CMD` + `COVERED`：给某种文件类型配一个 lint 命令，并把扩展名（不带点）写进 `COVERED`，例如 `vue sql`。
- `NOT_CODE`：真的不是代码的文件（数据、素材、生成文件）的扩展名，跳过检查。不要把源码放进来。

## 注意

- 只管 Claude 发起的提交，你自己在终端里敲的 `git commit` 不受影响。
- 缺少 linter 时，Claude 会先问你再安装（都是全局安装）。
- 项目原有代码如果 lint 不通过，在修好之前任何提交都过不了，包括提交关卡自己的文件。

## 仓库文件

| 文件 | 作用 |
|------|------|
| [SKILL.md](SKILL.md) | 给 Claude 看的安装步骤 |
| [setup.sh](setup.sh) | 安装脚本 |
| [lint-gate.sh](lint-gate.sh) | 复制到项目里的 lint 脚本 |
| [lint-gate.conf](lint-gate.conf) | 默认项目设置 |
| [hooks.json](hooks.json) | 要合并进项目的 hook 定义 |
