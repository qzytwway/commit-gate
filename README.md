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

## 自动格式化

`lint-gate.sh run` 在检查之前，会先把**这次要提交的文件**整理好格式，再重新加回暂存区。只动这次提交的文件，不碰别的：

| 语言 | 格式化工具 |
|------|------------|
| Go | gofmt（装了 Go 就有） |
| Python | ruff format |
| JS / TS | 项目自己装的 prettier（找离文件最近的 `node_modules/.bin/prettier`，所以会用项目自己的配置和插件；没装就不动） |

如果一个文件只有一部分改动加进了暂存区，它会拦下提交，并提示你把剩下的改动也加进去或者先收起来（stash）。不然重新加回暂存区时，会把你没打算提交的改动一起带进去。

所以装了 commit-gate 的项目，不需要再装只负责格式化的 git pre-commit 钩子。

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

2. 在想加关卡的项目里打开 Claude Code，输入 `/commit-gate`（或者直接说“给这个项目装上 commit gate”）。Claude 会按 [SKILL.md](SKILL.md) 的步骤完成安装、跑一次检查，并把结果告诉你。

   也可以在项目根目录手动运行安装脚本：

   ```bash
   bash ~/.claude/skills/commit-gate/setup.sh
   ```

   手动安装后关卡就已经生效：即使 Claude 不知道要先跑脚本，提交也会被 hook 拦下，拦截提示会告诉它去运行 `scripts/lint-gate.sh run`。建议再把 [SKILL.md](SKILL.md) 第 4 步里那段“Committing”说明加进项目的 `CLAUDE.md`，这样 Claude 第一次提交就会先跑脚本，不会先撞一次墙；它也会知道几条规矩：装 linter 前先问你、不许绕过 hook、写文件别用 heredoc（在命令里直接塞一大段文本的写法，hook 可能把它误当成提交命令）。

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

## 自己加 lint

项目设置在 `scripts/lint-gate.conf`，平时保持为空即可。这个文件重复安装也不会被覆盖，可以放心改。需要自己加 lint 时，分三种情况：

### 1. 内置五种语言以外的文件（最常见）

比如项目里有 `.vue` 或 `.sql` 文件，lint-gate 会报“这种文件没有 linter”，然后拦下提交。在 `scripts/lint-gate.conf` 里写：

```bash
LINT_CMD='npx eslint --ext .vue .'   # 用来检查这类文件的命令
COVERED='vue'                        # 这条命令负责的扩展名，不带点，多个用空格隔开
```

想跑好几个命令，就用 `&&` 连在同一个 `LINT_CMD` 里：

```bash
LINT_CMD='npx eslint --ext .vue . && sqlfluff lint .'
COVERED='vue sql'
```

真的不是代码的文件（数据、素材、生成文件），把扩展名写进 `NOT_CODE` 就会跳过检查。不要把源码放进去。

也可以直接跟 Claude 说“给 .vue 文件加上 lint”，它知道该改这里。

### 2. 已支持的语言，想再多查一项

比如 Python 除了 ruff 还想跑 mypy（类型检查），可以写 `LINT_CMD='mypy .'`。只要 `LINT_CMD` 不为空，它就会跑，而且是额外跑，内置的 ruff 照样会跑。`COVERED` 里不要写 `py`，那个列表只用来登记内置五种以外的文件类型。

注意：[SKILL.md](SKILL.md) 让 Claude 不要把项目自己的 lint 命令放进 `LINT_CMD`，所以这一项要你明确跟它说，它才会加。

### 3. 给所有项目换掉或新增一个内置 linter

改本仓库的 [lint-gate.sh](lint-gate.sh)：在 `detect_languages` 里把扩展名对应到语言，再加一个 `lint_<语言>` 函数。改完后在每个装过关卡的项目里重新运行一次 `setup.sh`，新脚本才会复制过去。

### 改配置也会被审查

提交时的 AI 审查会盯着 `lint-gate.conf`。如果往 `COVERED` 里加了扩展名却没配一条真正能检查它的命令，或者把源码放进 `NOT_CODE`，这次提交会被拒，防止靠改配置绕过检查。

## 注意

- 只管 Claude 发起的提交，你自己在终端里敲的 `git commit` 不受影响。因为关卡装在 Claude Code 的 hook 里（`.claude/settings.json`），不是 git 自己的 pre-commit hook（`.git/hooks/pre-commit`）。
- 缺少 linter 时，Claude 会先问你再安装（都是全局安装）。
- 项目原有代码如果 lint 不通过，在修好之前任何提交都过不了，包括提交关卡自己的文件。

## 仓库文件

| 文件 | 作用 |
|------|------|
| [SKILL.md](SKILL.md) | 给 Claude 看的安装步骤 |
| [setup.sh](setup.sh) | 安装脚本 |
| [lint-gate.sh](lint-gate.sh) | 复制到项目里的格式化 + lint 脚本 |
| [test.sh](test.sh) | 格式化步骤的自检（`bash test.sh`） |
| [lint-gate.conf](lint-gate.conf) | 默认项目设置 |
| [hooks.json](hooks.json) | 要合并进项目的 hook 定义 |
