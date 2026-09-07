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

### 改名收尾（2026-09-07 第二轮，35 个文件）

第一轮只改了 Dart 包名和安卓包路径，二进制名与桌面端显示名整套未动。本轮补齐：

- **修复真实故障**：`constant.dart` 的 `appHelperService` 在第一轮被改成
  `ClashMOHelperService`，但构建产物、Rust 服务注册名（`services/helper/src/service/windows.rs`）、
  Inno Setup 进程列表仍是 `FlClashHelperService`，两端对不上会导致 **Windows 管理员服务安装/查询失败
  （TUN 模式不可用）**。本轮把产物侧统一改为 ClashMO，两端一致。
- 二进制名：`FlClashCore` → `ClashMOCore`、`FlClashHelperService` → `ClashMOHelperService`
  （`build_config.yaml`、`options.dart` 默认值、三平台 CMake/podspec、Xcode 工程、Inno Setup、Rust）。
- 桌面端显示名与产物名：Windows/Linux/macOS 的 `BINARY_NAME`、窗口标题、`PRODUCT_NAME`、
  打包配置（deb/rpm/AppImage/dmg/exe）全部 ClashMO。
- Dart：`FlClashHttpOverrides` → `ClashMOHttpOverrides`、`FlClash.lock` → `ClashMO.lock`、
  isolate 名、`repository` 常量 → `MOMO0302-02/ClashMO`。
- 安卓：通知频道、通知标题、日志 tag、VPN 会话名、文件提供器标题；`core/tun/tun.go` 的 TUN 设备名。
- 「关于」页移除了原作者 Telegram 群入口（ClashMO 无自有群，留着等于把用户导去别人的群）。
- **已验证**（2026-09-07，`temp/verify_rename.ps1`）：`flutter analyze lib test` 退出码 0
  （仅 10 条 `withOpacity` 等旧写法 info），`flutter test` 417 项全通过、退出码 0。

### 刻意保留的上游引用（不是遗漏，勿"顺手改掉"）

- `lib/views/about.dart` 的内核链接 `chen08209/Clash.Meta/tree/FlClash`
  —— 2026-09-07 已访问核实：该分支真实存在（4,049 commits）。改成 ClashMO 会变成死链。
- `.gitmodules` 的 `branch = FlClash`、`setup.dart:167` 的 `--git-ref FlClash`
  —— 均为上游仓库里的真实分支名，改了会拉不到代码。
- `origin`/`upstream` 两个 remote 仍指向 `chen08209/FlClash`，用于同步上游更新。
- `README.md`、`README_zh_CN.md` 顶部保留 `chen08209/FlClash` 链接 —— 这是分支来源署名致谢，
  刻意保留，不要清。
- 各处**小写** `flclash` URL 协议名（`AndroidManifest.xml`、`lib/common/window.dart`、
  `macos/Runner/Info.plist`、`test/common/protocol_test.dart`）—— 保留是为了老订阅链接仍能
  一键导入；旁边都已并列加上 `clashmo`。删掉会让旧链接失效。

### 改名收尾（2026-09-07 第三轮，25 个文件）

前两轮漏掉的文字描述、文档与发布流程，本轮清完。留下的旧名见上一节，均为刻意保留。

- **修复真实故障 1**：两份 README 里给用户抄的安卓广播指令还是
  `com.follow.clash.action.START/STOP/TOGGLE`，而代码里 `applicationId` 早已是
  `com.clashmo.android`（`android/app/build.gradle.kts:39`，广播名由 `${applicationId}` 拼出）。
  照文档抄的指令**根本不生效**。已改为 `com.clashmo.android.action.*`。
- **修复真实故障 2**：URL 协议注册三处不一致 —— 安卓已加 `clashmo`，但 Windows
  （`lib/common/window.dart`）和 macOS（`Info.plist`）只注册了 `clash/clashmeta/flclash`。
  桌面端点 `clashmo://` 链接不会被接管。已补齐。
- **拆掉指向原作者的发布链条**（`.github/workflows/build.yaml`）：打 `v*` 标签会真的触发这个
  工作流，而其中三步是往**原作者的**仓库/频道推送 —— Homebrew tap、F-Droid 仓库、
  Telegram 频道 `@FlClash`。我们没有对应密钥，只会失败；且 Homebrew 那步按
  `FlClash-*.dmg` 找文件，改名后必然报错中断发布。已删除这三步与 telegram-bot-api 服务容器，
  并删掉只服务于它们的 `.github/homebrew_cask_template.rb`、`release_telegram.py`。
  保留的 GitHub Release 发布步骤改用 `${{ github.repository }}` 自取仓库名。
- 文档与描述：`.agents/` 六处、插件 podspec/pubspec 描述与作者字段、build_tool 命令描述、
  `plugins/wifi_ssid/LICENSE` 版权名、`.gitignore` 注释。
- README 两份：标题、License 徽章指向本仓库；删除原作者的下载徽章、Homebrew 安装说明、
  star-history 图（都指向上游，对本 fork 无意义）；下载改指本仓库 Releases。
- `.github/release_template.md` 下载链接与产物名、`.github/ISSUE_TEMPLATE/` 两份的 issue 链接。
- macOS 测试 bundle id `com.follow.flClash.RunnerTests` → `com.clashmo.RunnerTests`。
- **已验证**（`temp/verify_rename.ps1`）：`flutter analyze lib test` 退出码 0，
  `flutter test` 417 项全通过、退出码 0。

### 尚未改名的标识符（本轮刻意没动，将来要动需谨慎）

`com.follow.clash` 这个应用标识符仍在用：`macos/Runner/Configs/AppInfo.xcconfig`、
`macos/Runner.xcodeproj/project.pbxproj`（debug 变体）、`linux/CMakeLists.txt` 的
`APPLICATION_ID`、`plugins/setup/android/` 的 gradle group 与 namespace。
**没改的原因**：改 bundle id / APPLICATION_ID 会让已安装的桌面版被当成另一个应用
——配置目录、偏好设置、已授权的系统权限全部丢失，等于用户数据被清空。
安卓侧的 `applicationId` 已是 `com.clashmo.android`（安卓可接受，因为本 fork 尚未分发过）。
将来若要统一，必须先设计配置目录迁移方案，不能直接改字符串。

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
- 2026-09-07：改名类任务**先摸清"名字是谁生成的"再改**。本项目 `FlClashCore` 出现在
  `path.dart` 里看似是遗留，实则整套构建（`build_config.yaml` → CMake/podspec/Xcode）
  都在生成这个文件名，单改消费侧会直接找不到内核。改二进制名必须**生产侧与消费侧一起改**。
- 2026-09-07：`sed 's/FlClash/ClashMO/g'` 全量替换会把 URL 里的**上游用户名**一起改坏，
  造出 `github.com/chen08209/ClashMO` 这种死链（已在 `windows/packaging/exe/make_config.yaml` 修回）。
  批量替换后务必回查 `chen08209/ClashMO`、`t.me/ClashMO` 这类组合。
- 2026-09-07：`.toolchain/env.ps1` **会切换当前目录**。脚本里 `. env.ps1` 之后必须重新
  `Set-Location` 回项目根，且日志等输出路径一律写绝对路径——否则会落到
  `.toolchain\temp\` 之类不存在的路径，脚本报错但**外层退出码仍是 0**，看起来"跑通了"实则没跑。
  验证类脚本必须在末尾自行打印真实退出码（`ANALYZE_EXIT=`/`TEST_EXIT=`）并检查日志非空。
- 2026-09-07：**加载 `.toolchain/env.ps1` 会覆盖调用方的同名变量**。它内部用了
  `$root`（值为 `.toolchain` 目录），而点号加载是在当前作用域执行的，
  所以脚本里凡是用 `$root` 命名的路径，加载后全部被改指到 `.toolchain\`。
  症状：日志写去 `.toolchain\temp\`（假成功）、`flutter analyze $root\lib` 报
  "f:\ai\clashmo\.toolchain\lib does not exist"。
  写调用 env.ps1 的脚本时**变量名避开 `$root`**，路径直接写死绝对路径。
- 2026-09-07：`flutter analyze` 在项目根不带路径运行时，会把 `.toolchain\flutter`
  自带的 SDK 示例代码一起分析，刷出约 104 万行与本项目无关的错误
  （`Analyzing .toolchain...`、`flutter\dev\a11y_assessments\...`）。
  `.gitignore` 对 analyze 无效。**必须显式指定目录**：`flutter analyze --no-fatal-infos lib test`。
- 2026-09-07：`flutter test` 整体跑时 `test/common/converter_test.dart` 偶发报
  "Connection closed before test suite loaded"（并发加载导致，非代码问题）。
  单独跑该文件退出码 0，整体重跑一次也 0。遇到此错先单跑该文件再判定，不要当成回归。
- 2026-09-07：跑 `flutter test` 会顺带升级 `pubspec.lock` 里几个小版本依赖
  （intl、matcher、meta、test、vector_math 等）。提交改名类变更前先
  `git checkout -- pubspec.lock`，避免把无关的依赖升级混进业务提交。
- 2026-09-07：改名任务里**文档也是产品的一部分**。README 给用户抄的安卓广播指令用的是旧
  `applicationId`，改名后指令静默失效——没有任何报错，用户只会以为"这功能坏了"。
  凡是文档里出现的**可执行内容**（命令、包名、协议链接、路径），改名后都要回代码核对一遍。
- 2026-09-07：fork 仓库要检查 `.github/workflows/` 里有没有**推向原作者仓库**的步骤。
  本项目 `build.yaml` 由 `v*` 标签触发，其中三步往 chen08209 的 Homebrew tap、F-Droid 仓库
  和 Telegram 频道推送。fork 没有对应 secrets，打标签发版时会失败中断。已删除。
- 2026-09-07：Claude 桌面版侧边栏项目名仍显示旧名「FlClash」。原因是目录曾由
  `F:\AI\FlClash` 改名为 `F:\AI\ClashMO`，而项目显示名在首次识别时被记录、未随目录更新。
  该名称不在本机配置文件内（`~/.claude.json`、`~/.claude/`、桌面版 AppData 均搜索无果），
  推测存于账号侧数据，只能从界面重命名或移除后重新添加项目，命令行无法修改。
  不影响任何实际路径：会话 cwd 与 git 根目录均为 `F:\AI\ClashMO`。

## 已否决方案

- 不提交 `00_项目状态.md`（改名期间某会话生成的一次性状态快照，内容会迅速过期，
  与本文件职责重复）。该文件保留在工作区但不纳入版本控制。
