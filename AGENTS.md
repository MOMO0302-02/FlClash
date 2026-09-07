# AGENTS.md

This file is the entry point for AI coding agents working in this repository. Keep it small: detailed guidance lives under
`.agents/`, and discoverable repo skills live under `.agents/skills/*/SKILL.md`.

## Start Here

Read these files before making changes:

- [.agents/project.md](.agents/project.md): project overview, versions, and build dependencies.
- [.agents/commands.md](.agents/commands.md): build, development, code generation, and test commands.
- [.agents/rules.md](.agents/rules.md): lint, testing, generated-code, and workflow rules.

Read these only when the task touches their area:

- [.agents/architecture.md](.agents/architecture.md): core integration, providers, database, managers, build system, and
  local plugins.
- [.agents/agent-config.md](.agents/agent-config.md): how to choose between `AGENTS.md`, `.agents`, skills, Codex config,
  command rules, and hooks.
- [.agents/skills.md](.agents/skills.md): index of repo-scoped skills in `.agents/skills/`.

## Highest Priority Rules

- Use `flutter test`, not `dart test`, because models pull in Flutter types.
- Run code generation after modifying models, providers, or database schema.
- Do not manually edit generated files.
- Follow `analysis_options.yaml`, especially single quotes, trailing commas, `child:` last, no `print()`, const/final
  preferences, and declared return types.
- For CI parity, verify with `flutter pub get`, `flutter analyze --no-fatal-infos`, and
  `flutter test --reporter expanded` when practical.

## Repo Skills

Use repo skills from `.agents/skills/` when a task matches their descriptions. Current skills cover localization,
provider tests, UI work, and core/platform changes.

## 当前进度

### 2026-09-07 品牌改名 FlClash → ClashMO（已提交并推送）

- 提交 `0e323875`，247 个文件。本地 `main` 与 `rename-to-clash` 同指此提交，已推送到 fork。
- Dart 包名 `fl_clash` → `clash`；安卓源码 `com/follow/clash` → `com/clashmo`（40 个文件）。
- App 名、helper 服务名、IPC socket/pipe 名、applicationId（`com.clashmo.android`）均已改。
- GitHub fork 已改名：`MOMO0302-02/FlClash` → `MOMO0302-02/ClashMO`，本地 `fork` remote 已同步。
- 已验证产物：`temp/apk/ClashMO-0904k.apk`（2026-09-04，51MB），安卓可打包。
- `temp/baseline4.log` 记录约 1,136 条测试通过，退出码 0（该日志由改名期间的会话生成）。

### 改名遗留（尚未处理，均为小尾巴）

- `lib/common/path.dart:47` 仍找 `FlClashCore` 可执行文件、`:86` 仍用 `FlClash.lock`
  —— **优先级最高，可能影响桌面版启动**。
- `FlClashHttpOverrides` 类名未改：`lib/common/http.dart:8`、`lib/common/request.dart:27`、`lib/main.dart:21`。
- `android/common/.../common/GlobalState.kt:13` 通知频道名仍为 `FlClash`。
- `lib/views/about.dart:53,68` 链接仍指向原作者 Telegram 群与仓库（待定：是否保留以致敬上游）。
- `lib/common/constant.dart` 的 `repository` 常量仍为 `MOMO0302-02/FlClash`，仓库已改名，此处需更新。
- 子模块 `core/Clash.Meta` 仍指向 `chen08209/Clash.Meta` 的 `FlClash` 分支（上游资源，无需改）。

## 踩坑记录

- 2026-09-07：`.git/index.lock` 残留（0 字节）导致所有 git 写操作报
  "Another git process seems to be running"。先用
  `Get-CimInstance Win32_Process -Filter "Name='git.exe'"` 过 CommandLine 确认无进程真在操作本仓库，
  再删锁文件。切勿看到 git.exe 存在就以为锁是活的——本机常有多个其他仓库的 git 进程。
- 2026-09-07：本仓库文件数量大，`git add -A` 与 `git commit` 单次可超 3 分钟，
  易被工具超时打断。超时后**不要重试**，先用 `git diff --cached --shortstat` 确认实际是否已成功。
- 2026-09-07：`git add -A` 会把本地工作素材一并纳入。已在 `.gitignore` 排除
  `/.toolchain/`、`/temp/`、`/_产物备份/`、`/core/Clash.Meta-smart/`、`/.design/`、`/.smart-merge/`。
  提交前务必 `git show --stat HEAD` 检查有无混入截图或大文件。
- 2026-09-07：Claude 桌面版侧边栏项目名仍显示旧名「FlClash」。原因是目录曾由
  `F:\AI\FlClash` 改名为 `F:\AI\ClashMO`，而项目显示名在首次识别时被记录、未随目录更新。
  该名称不在本机配置文件内（`~/.claude.json`、`~/.claude/`、桌面版 AppData 均搜索无果），
  推测存于账号侧数据，只能从界面重命名或移除后重新添加项目，命令行无法修改。
  不影响任何实际路径：会话 cwd 与 git 根目录均为 `F:\AI\ClashMO`。

## 已否决方案

- 不提交 `00_项目状态.md`（改名期间某会话生成的一次性状态快照，内容会迅速过期，
  与本文件职责重复）。该文件保留在工作区但不纳入版本控制。
