# 交接给 Open Code（2026-09-04）

> **用法**：把这份文件从头到尾整个粘给 Open Code 当第一条消息。
> 项目路径：**`F:\AI\ClashMO`**（原先在 `F:\AI\FlClash`，已于 2026-09-04 迁移）。

---

## 0. 接手后的第一个任务（先看这一节）

**优化 iOS 主题和 Fluent 主题。** 要求参照三类来源，不许凭印象写：

1. **Fluent** —— 微软官方设计系统。`https://github.com/microsoft/fluentui` 的
   `packages/tokens`（设计令牌的真值所在），以及 Fluent 2 的官方文档。
   **注意**：那个仓库是 Web/React 的，代码用不上，**只取数值**。
2. **iOS** —— 苹果官方的 Human Interface Guidelines，以及 Liquid Glass / Materials
   相关章节。**同样只取数值和规则，不抄代码**。
3. **GitHub 高星开源项目** —— 找 Flutter 生态里已经把这两套做出来的，参考它们
   怎么落地。（`fluent_ui`、`macos_ui`、`flutter/cupertino` 本身都值得读。）

**动手前必须先做的事**：把三类来源里查到的**具体数值**列出来，和本项目现有的取值
逐项对照，指出哪些对不上。**没有对照表就直接改数值 = 凭印象改，本项目明令禁止。**

### 改哪里

全部视觉取值集中在 **`lib/common/app_style.dart`**（646 行）。它是一个
`ThemeExtension`，组件里**不写 `if (style == ...)`**，只读令牌。字段清单：

| 令牌 | 管什么 |
|---|---|
| `cardRadius` / `controlRadius` | 卡片和控件的圆角 |
| `rim` / `rimLight` | 卡片描边色（深色/浅色） |
| `cardShadow` / `cardShadowLight` | 卡片阴影 |
| `darkSurfaces` / `lightSurfaces` | 五级表面色（`surface` → `containerHighest`）、文字色、分隔线色 |
| `selectionMode` | 选中怎么表现：整块填充 / 左侧指示条 / 右侧打勾 |
| `selectionIndicatorWidth` | 指示条宽度 |
| `glowOnSelect` | 选中时外面冒不冒光 |
| `sectionStyle` | 设置项是「一张大卡片装多行」还是「一行一张小卡片」 |
| `headerStyle` | 分组标题的样式 |
| `dividerInset` / `dividerOpacity` | 分隔线内缩多少、多淡 |
| `switchOutline` | 开关关闭态画不画描边 |
| `schemeVariant` | 配色方案的生成算法 |

三档风格各自的取值在 `AppStyleTokens.of(AppStyle)`（`:492`）里。

### 三条不能破的约束

1. **默认风格（`clashParty`）不许动。** 它对齐桌面版 Clash Party，改之前先跑
   `desktop_parity_test`；那一档的取值是从桌面端源码逐条抄来的。
2. **风格只管「长什么样」，不管「东西在哪」。** 导航形态、卡片内部怎么摆属于布局，
   三档共用一套。切主题不该让控件搬家。
3. **液态玻璃只用在「浮起来的东西」上**（详见下面第 3 节），内容层绝不能半透明。

---

## 1. 这个项目是什么

- **Clash MO** —— 安卓代理客户端。基于 chen08209 的 **FlClash 分支，GPL-3.0**，
  合入了 vernesong 的 Smart 选路内核，界面照着桌面版 Clash Party 重做。
- Dart 包名仍是 `clash_party`（`import 'package:clash_party/...'`），**别改**，
  改了全仓库的 import 都要动，收益为零。
- 唯一真相源是 **`AGENTS.md`**（六节：项目目标 / 目录与命名 / 环境依赖 / 踩坑记录 /
  当前进度 / 已否决方案）。**接手第一件事是读它。**

---

## 2. 不可违反的硬规矩

每一条都是踩过坑换来的，不是客套话。

### 安全与隐私

- **订阅链接里带 token**——绝不能写进项目文件、报告、日志、界面提示、提交信息。
- **不碰用户的密码**——签名用的 keystore 密码必须由用户本人设置，AI 不经手。
- **用户真机上禁止**：读取或导出他的真实订阅、启停 VPN、`pm clear`。

### 文件与路径

- **不写 C 盘**（`~/.claude\` 这类工具自身配置除外）。临时文件一律放
  `F:\AI\ClashMO\temp\`。项目根目录是 `F:\AI\`。
- **项目路径里不能有空格、不能有中文。** 这不是洁癖，是两个实测出来的硬故障，
  详见第 5 节。

### 对外动作

推分支、开 PR、建公开仓库、发私信、发布——**都要用户当次明确授权**，
授权不跨会话继承。

### 写代码的纪律

- **含反斜杠或转义的内容一律用写文件工具落盘**，不要走 shell 的 heredoc。
  本项目被这个坑咬过三次，`\n` 会被吃成真换行，把正则和模板字符串改坏，
  而且**自测时同样被吃掉，于是"验证通过"是假的**。
- **测试的期望值写死字面量，不要引用产品代码里的同一个常量。** 引用的话改了常量
  两边一起变，变异测试当场验不红。本项目被这个坑咬过两次。
- **写完测试必须做变异测试**：故意把被测行为改坏，确认测试真的变红，再还原。
  只有能验红的测试才算在守着行为。
- **性能结论至少跑 7 次并列出全部数值。** 曾用 3 次采样得出"快 38ms"，n=7 后
  缩水成 6ms。
- **`performance.memory` 不可信**（Chromium 做了粗粒度化，实测 7 轮返回同一个值）。
  量内存要用进程级的数字。
- **清单里"读代码读出来的 bug"，动手前必须实测或至少确认触发路径可达。**
  本项目已有多条误报。
- 标准是「商用 app」：**不加多余的东西**。桌面版有的就照抄桌面版，桌面版没有的
  才自己设计。

---

## 3. 已经做完的（别重复劳动）

### 液态玻璃与能力分档 ← 最近的工作，和第一个任务直接相关

- **`lib/common/render_capability.dart`** —— `RenderTier` 三档 `full` / `light` /
  `none`。判据取自**设备自己的回答**：安卓的低内存标记 `isLowRamDevice`、物理内存
  （≥6 GB 完整、≥3 GB 减配、更低关掉）、有没有 64 位 ABI。
  - **不按安卓版本号分档**——版本号和性能没关系，安卓 16 的百元机扛不住实时模糊，
    安卓 8 的旗舰跑得动。
  - 系统里的「移除动画」**优先于**性能判断，开了就一律不模糊。
  - 已接进 `System.init()`（`lib/common/system.dart:41`）。
- **`lib/widgets/liquid_glass.dart`** —— 模糊（完整档 24 / 减配档 12）+ 半透明填充
  + 只在完整档画的上边缘高光。**关闭档给的是不透明底，不是半透明**——半透明而不
  模糊的话背后文字会透上来叠在一起，比没有效果还糟。
- **`lib/widgets/scaffold.dart`** 的 `_CapsuleSurface` —— 胶囊顶栏按风格分叉，
  只有 iOS 走玻璃。阴影画在玻璃**外面**（`BackdropFilter` 会裁掉自身范围之外的
  绘制，阴影塞进去就没了）。
- 测试 `test/widgets/liquid_glass_test.dart` **5 条全绿，且已做变异验证**
  （把 `_lightBlur` 改成 24 → 「减配档」那条变红；还原后 5/5 绿）。

**必须向用户讲清、也别自己搞错的一件事**：这是**磨砂玻璃**，不是苹果那种真折射。
用户给的参考 `QWEA0/Liquid-Glass-Android` 是**安卓原生 AGSL 着色器**（要安卓 13+），
那批 `liquid-glass-react` 是 **Web/CSS**（`backdrop-filter` + SVG 位移贴图）。
两条路 Flutter 都走不了——`BackdropFilter` 只收 `ImageFilter`，做不了逐像素位移。
**所以「边缘把背景掰弯」这个效果做不出来，别假装能做。**

**液态玻璃的适用范围（这条是设计原则，做第一个任务时要接着往下铺）**：

- ✅ **只用在悬浮的东西上**：胶囊顶栏（已做）、弹出菜单（未做）、底部弹窗的头部
  （未做）、悬浮按钮（未做）。
- ❌ **内容层绝不用**：列表卡片、设置项、页面背景。半透明的内容层会让背后滚过的
  文字透上来和前景叠在一起，读都读不了。
- ❌ **只有 iOS 风格用。** Fluent 和默认风格保持原样——玻璃是苹果那套语言，
  套到别的风格上是四不像。

### 主题

- 删掉了 Material You 主题（枚举值、令牌块、两处特例全清）。
- Clash Party 风格**改名叫「默认」**（枚举值仍是 `clashParty`，只改显示名）。
- 加了 `AppStyle.safeFromJson`——存量用户配置里存着 `materialYou` 的话，读到不认识
  的值回落到默认风格，不会崩。

### 胶囊顶栏（三轮返工后定稿）

- 页面**没有 `appBar`**，body 外包一层 `Stack`，胶囊浮在上面。顶部留白通过给 body
  注入 `MediaQuery.padding.top` 实现——**留白在滚动内容里面**，往下滚时跟着滚走，
  内容从胶囊底下穿过去，不会留一条同色空带（用户说的「底座又加回来了」指的就是
  那条空带）。
- 返回键用 `ModalRoute.of(context)?.impliesAppBarDismissal` 判断（`AppBar` 自己
  用的就是这个），`canPop()` 太宽会把搜索层也算进去。
- 固定的 leading 必须放在 `ValueListenableBuilder` **里面**，否则搜索/编辑状态
  变了它不跟着变，会出现两个返回入口。
- 测试 `test/widgets/app_bar_test.dart` 6 条全绿。

### 图标与应用名

- 名字 **Clash MO**。图标是蓝色圆角方块（`#006FEE`）+ 白色猫头，闪电从猫头里挖空
  （通知栏只取 alpha 也能看出形状）。
- `temp/make_icon.py` 是纯 Python 手写的栅格化器（zlib 手写 PNG + 4×4 超采样），
  因为这台机器没有任何图像库。
- **为什么要自己画**：原来的 `assets/images/icon.png` 和桌面版 Clash Party 的图标
  逐字节相同，是别人项目的美术资源，公开发布不能带着它。

### 更早完成的（细节见 AGENTS.md）

删掉没用的 `GEOIP.dat`（APK 小 4.37 MB、设备上省 20.5 MB）、修掉两处 10 秒启动
等待、崩溃检测改成「启动完成」判据且要连续两次才算、Smart 参数默认值 + 一次性
迁移、语义色统一、排序弹窗的「黑边」（阴影半径没跟着实际形状走）、IPv6 中间
省略号、订阅默认名、仪表盘磁贴字号字重。

---

## 4. 还没做完的（第一个任务之后按这个顺序）

1. **iOS 玻璃只做了顶栏** —— 弹出菜单、底部弹窗头部、悬浮按钮还没做。
   也还欠用户一份正式方案（哪些控件上玻璃、哪些不上，理由）。
2. **Fluent 对齐 fluentui** —— 已经抓到的官方令牌：圆角 0/2/4/6/8/12/16/24/32/40/
   全圆；描边宽度 1/2/3/4 px；间距 0/2/4/6/8/10/12/16/20/24/32。**阴影令牌还没
   找到，也还没落进代码。**
3. **`views_smoke_test` 还剩 2 个真失败** —— 上次在内存充足的干净环境下，26 个
   失败降到 2 个，那 24 个是环境问题，这 2 个是真的。
4. **代理二级菜单卡顿** —— 用户原话「点击代理进入二菜单时会卡顿，其它页面也需要
   优化」。**要真机测量（n=7）**，无线调试当时断了，一直没做。
5. **投稿给 Clash Party 作者** —— 要中英双语 README、私信草稿、建仓库。
   **README 开头必须写明这是 chen08209 的 FlClash 分支、GPL-3.0。**
   建仓库和发私信都是对外动作，做之前必须拿到用户授权。
6. **`targetSdk` 要不要跟进** —— v2rayNG 用的是 37，我们的还没查。
   `minSdk` 是 **24（安卓 7）**，不是 23——用户问过「为什么写只支持安卓 6」，
   那个说法本身就是错的。

---

## 5. 迁移过程中实测出来的两个路径陷阱（重要）

项目原本在 `F:\AI\FlClash`。用户要求搬到 `F:\AI\Clash 安卓`，搬完发现**整套工具链
当场废掉**，实测定位到两个独立故障，最终改用 **`F:\AI\ClashMO`**（无空格、无中文）：

### 陷阱一：路径里有中文 → `flutter analyze` 崩溃

报错 `FormatException: Unexpected end of input`。

**根因（读 Flutter 源码确认，不是猜的）**：
`.toolchain/flutter/packages/flutter_tools/lib/src/dart/analysis.dart:157`

```dart
_process?.stdin.write('Content-Length: ${message.length}\r\n\r\n$message');
```

`message.length` 是 **Dart 字符串长度（UTF-16 码元数）**，而 LSP 协议要求的是
**UTF-8 字节数**。同一个文件 `:115` 把目录原样塞进 `'name': dir` **没有转义**，
于是路径里每个中文字符占 1 个码元、3 个字节，声明的长度偏小 → 消息被截断 →
JSON 解析失败。

**绕过办法**：`dart analyze lib test` 不走这条路，实测可用。但 `flutter analyze`
就是废的。

### 陷阱二：路径里有空格 → `flutter test` 完全跑不起来

报错 `'F:\AI\Clash' 不是内部或外部命令`。native assets 的构建钩子
（`objective_c` 包）调 dart 编译器时**没给可执行文件路径加引号**，而 Flutter SDK
装在项目内的 `.toolchain\flutter\`，路径里的空格把命令截成两半。

清 `.dart_tool/hooks_runner` 缓存**无效**，是真的路径问题。

### 搬家时还踩到的操作坑

- **文件夹被占用时不要硬搬。** `Move-Item` 整体改名失败后，逐项搬运会把
  `.toolchain` 拆散（当时 `adb.exe` 正从 `.toolchain\android-sdk\` 里跑着），
  结果 Flutter SDK 跑到了 `Clash 安卓\FlClash\.toolchain\flutter`、
  go 缓存出现两份、还多了个 `.toolchain\.toolchain`。收拾了好几轮。
  **正确顺序：先杀掉 `adb` / `dart` / `flutter_tester` / `java`，再整体改名。**
- **锁在根目录上时，子目录仍然能单独改名**——可以据此判断到底是谁被占用。
- **搬完必须重跑 `flutter pub get`**。`.dart_tool/package_config.json` 里存的是
  绝对路径，不重跑的话 `flutter analyze` 会报出两万多条假错误。
- **`.toolchain/env.ps1` 原先写死了绝对路径**，已改成自己定位自己
  （`$root = Split-Path -Parent $PSCommandPath`），以后再搬不会失效。
  但里面的 `GOROOT` 仍指向 `F:\AI\Clash Party\.toolchain\go`（另一个项目，
  故意复用，避免重复占 500 MB），那个项目还在原地，暂时有效。

---

## 6. 怎么跑起来

```bash
cd "F:/AI/ClashMO" && export PATH="$PWD/.toolchain/flutter/bin:$PATH" && export PUB_CACHE="$PWD/.toolchain/pub-cache" && flutter analyze lib test
```

Windows / PowerShell 下先加载环境：

```powershell
cd F:\AI\ClashMO; . .\.toolchain\env.ps1
```

**全量测试用 `python temp/run_tests_chunked.py`，别直接 `flutter test`。**
那个脚本逐个文件跑、残留进程超过 4 个就清理、红了的文件重跑一次再定罪。
直接跑全量会因为 `flutter_tester` 进程堆积产生大量假失败——曾经 26 个失败里
24 个是环境问题。

**报红先清环境重跑，但也别拿"抖动"当挡箭牌**——我犯过两次相反方向的错：
一次把真失败误判成偶发抖动，一次在脏环境里做 A/B 对比得出了完全相反的结论。

**迁移后的验证状态（2026-09-04 实测）**：

| 检查 | 结果 |
|---|---|
| `flutter pub get` | 通过 |
| `flutter analyze lib test` | No issues found |
| `test/widgets/liquid_glass_test.dart` | 5/5 通过，变异验证过 |
| `test/widgets/app_bar_test.dart` | 6/6 通过 |
| 全量测试 | **未跑**，接手后自己跑一次拿基线 |
