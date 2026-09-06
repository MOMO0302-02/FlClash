import 'package:clash_party/common/context.dart';
import 'package:flutter/material.dart';

/// 界面风格。切风格时整套视觉取值跟着换，组件里不写 if-else。
///
/// **只管样式，不管排布。** 导航形态、卡片内部怎么摆这些属于布局，四种风格共用
/// 同一套——切主题只该改变「长什么样」，不该改变「东西在哪」。
enum AppStyle {
  /// 默认风格：对齐桌面端 HeroUI。深色纯黑底 + zinc 卡片、浅色一片纯白靠阴影
  /// 分层；设置项装在**一张带阴影的圆角卡片**里，分隔线内缩 16；选中整块填成
  /// 实蓝。**改这一档前先跑 `desktop_parity_test`。**
  ///
  /// 枚举值仍叫 `clashParty`（存档里存的就是这个名字，改了会让老配置读不出来），
  /// 但**界面上显示「默认」**——应用叫 Clash MO，界面里挂一个指向另一个项目的
  /// 风格名既奇怪也让人看不懂。显示名见 [labelOf]。
  clashParty(''),

  /// Fluent：Windows 11 观感。云母底比卡片深、圆角方一档、卡片有明确描边；
  /// 设置项**一行一张小卡片**、行间留空、不画分隔线；选中用左侧一条指示条；
  /// 开关关闭态描边。
  fluent('Fluent'),

  /// iOS：Inset Grouped 分组表。底色比卡片深、卡片不投影不描边、分隔线从
  /// **文字**开始（左缩 56）；分组标题全大写并拉开字距；选中不换底色，只在
  /// 右侧打一个勾。
  cupertino('iOS');

  /// 专有名词的显示名（Fluent、iOS）。默认风格留空，由 [labelOf] 取译文。
  final String label;

  const AppStyle(this.label);

  /// 界面上显示的名字。
  ///
  /// 默认风格叫「默认」，**必须走译文**——那是普通词，得跟界面语言走；
  /// Fluent 和 iOS 是专有名词，各语言都这么写，直接用 [label]。
  String labelOf(BuildContext context) =>
      label.isEmpty ? context.appLocalizations.defaultText : label;

  /// 从存档里读回来。**认不出的一律回落到默认风格。**
  ///
  /// 「Material You」这一档已经删掉，但用过它的机器存档里还留着那个名字；不兜底
  /// 的话枚举解码会抛，整份配置都读不出来——用户看到的是应用起不来，而不是
  /// 「风格变回默认」。
  static AppStyle safeFromJson(Object? value) {
    for (final style in values) {
      if (style.name == value) {
        return style;
      }
    }
    return AppStyle.clashParty;
  }
}

/// 选中时怎么表现。**这是样式差异，不是布局差异**——卡片的位置和内容都不变。
enum SelectionMode {
  /// 整块填充主色、文字转白，外面再冒一圈同色的光。Clash Party 的招牌。
  fill,

  /// 左侧一条主色指示条，背景只微微提亮。Fluent 的做法。
  indicator,

  /// 填充 secondaryContainer 这类柔和色。Material 的做法。
  tonal,

  /// 背景不变，只在右侧打一个主色的勾。iOS 的做法。
  check,
}

/// 一组设置项摆成什么形态。
///
/// 这是四种风格里**最一眼能看出来的差别**：同一批设置项，四种风格分别长成
/// 「一张带阴影的卡片」「一行一张小卡片」「通栏平铺」「iOS 的圆角分组」。
///
/// 改的是**同一批内容的容器几何**，不是内容本身在哪一页、按什么顺序排——后者
/// 才是布局，四种风格共用。
enum ListSectionStyle {
  /// 圆角卡片 + 阴影 + 高光边，分隔线内缩 16。Clash Party（对齐桌面端 HeroUI）。
  card,

  /// 每一行自己是一张小卡片，行与行之间留 4 的空隙，没有分隔线。
  /// Windows 11 设置页就是这个样子。
  splitRows,

  /// 不画卡片，贴着页面底色通栏平铺，左右不留边，也没有分隔线。
  /// Material 3 设置页的做法。
  flat,

  /// 圆角分组、不投影、分隔线从文字起始处才开始。iOS Inset Grouped。
  insetGrouped,
}

/// 分组小标题长什么样。
enum SectionHeaderStyle {
  /// labelLarge + 半粗 + 次级文字色。Clash Party。
  standard,

  /// 主文字色、更粗一档。Windows 11 的分组标题比正文更硬。
  strong,

  /// 主色小标题。Material 3 设置页的分组标题是带色的。
  accent,

  /// 全大写 + 拉开字距 + 小一号。iOS 分组表头。
  uppercase,
}

/// 深色下的底色层。为空表示不覆盖，用 Material 自己从种子推出来的那套
/// （Material You 就该这样，它要的就是跟随系统取色）。
@immutable
class SurfacePalette {
  const SurfacePalette({
    required this.surface,
    required this.containerLow,
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
  });

  final Color surface;
  final Color containerLow;
  final Color container;
  final Color containerHigh;
  final Color containerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;

  ColorScheme applyTo(ColorScheme scheme) {
    return scheme.copyWith(
      surface: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: containerLow,
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outlineVariant: outlineVariant,
    );
  }
}

/// 一套风格的全部视觉取值。新增风格只要再写一个常量。
@immutable
class AppStyleTokens extends ThemeExtension<AppStyleTokens> {
  const AppStyleTokens({
    required this.style,
    required this.seed,
    required this.cardRadius,
    required this.controlRadius,
    this.innerControlRadius,
    required this.selectionMode,
    required this.dividerOpacity,
    required this.schemeVariant,
    required this.rim,
    required this.cardShadow,
    required this.darkSurfaces,
    required this.glowOnSelect,
    required this.sectionStyle,
    required this.headerStyle,
    this.dividerColor,
    this.dividerColorLight,
    this.dividerInset = 16,
    this.switchOutline = false,
    this.selectionIndicatorWidth = 3,
    this.rimLight = const Color(0x00000000),
    this.cardShadowLight = const [],
    this.lightSurfaces,
  });

  final AppStyle style;

  /// 配色种子，也是「填充式强调」的实际用色。
  final Color seed;

  final double cardRadius;

  /// 中号控件圆角：按钮、输入框、下拉、分段控件的外框。
  ///
  /// 桌面端（HeroUI）控件圆角分两档——小号 8px、中号 12px，绝大多数控件默认吃
  /// 中号。安卓端原来只有一档 10，介于两者之间，于是**两头都不像**。
  final double controlRadius;

  /// 小号控件圆角：分段控件里的选中胶囊、小标签这类"套在别的控件里面"的东西。
  ///
  /// 做成派生值而不是独立字段：它和中号永远差一档，独立字段要连带改构造、
  /// copyWith、lerp、== 和 hashCode 五处，还多一个能被设错的地方。
  final double? innerControlRadius;

  double get controlRadiusSmall => innerControlRadius ?? controlRadius - 4;
  final SelectionMode selectionMode;
  final double dividerOpacity;
  final Color? dividerColor;
  final Color? dividerColorLight;

  /// Material 的配色推导方式。content 会把纯蓝推成淡紫，fidelity 更忠实原色。
  final DynamicSchemeVariant schemeVariant;

  /// 卡片边缘那圈细线，**深色下的取值**。透明表示这套风格不画描边。
  ///
  /// 桌面端这圈线不是边框，是 HeroUI 阴影里的最后一层
  /// `inset 0 0 1px 0 rgb(255 255 255 / 0.15)`——**有 1px 模糊、没有扩散**。
  /// Flutter 画不了内阴影，只能用 1px 边框近似，那就必须换算成「模糊之后的实际
  /// 亮度」，不能把 0.15 原样搬过来当边框透明度。两者差 17 倍，见 [rimLight]
  /// 下面那段实测数据。
  final Color rim;

  /// 浅色下的那圈细线。见 [rim]。
  ///
  /// 实测（Chrome 143 无头渲染，1 倍缩放，卡片 #18181b、页面 #000000）：
  ///
  /// | 画法 | 边缘像素 |
  /// |---|---|
  /// | 什么都不画 | 24（卡片本色） |
  /// | 桌面端真货 `inset 0 0 1px rgb(255 255 255/.15)` | **26** |
  /// | `inset 0 0 0 1px`（有扩散无模糊，等于实线边框） | 58 |
  ///
  /// 也就是说桌面端那圈线只把边缘像素抬高 2/255，几乎看不见；按 0.15 画实线边框
  /// 会抬高 34/255，**亮 17 倍**——那正是「磁贴四周一圈明显的边/像有投影」的来源。
  final Color rimLight;

  /// 卡片外阴影，**深色下的取值**。
  final List<BoxShadow> cardShadow;

  /// 浅色下的卡片外阴影。
  ///
  /// 必须和深色分开：HeroUI 的 `shadow-medium` 在两种亮度下是**两组不同的值**
  /// （深色 6% + 22% 黑，浅色 3% + 8% 黑再加一条 30% 黑的发丝线）。深色下卡片
  /// 坐在纯黑页面上，黑色阴影本来就看不见；浅色下页面是白的，同一组深色取值会
  /// 直接变成一圈很重的投影。
  final List<BoxShadow> cardShadowLight;

  /// 深色下的底色层。为空表示交给 Material 自己推。
  final SurfacePalette? darkSurfaces;

  /// 浅色下的底色层。为空表示交给 Material 自己推。
  final SurfacePalette? lightSurfaces;

  /// 选中时是否往外冒一圈同色的光。
  ///
  /// **只用于 Android 独有的大号主控件**（仪表盘上那颗启动按钮），桌面端没有对应
  /// 元素。普通卡片不冒光——桌面端选中的卡片只是把底色换成 `bg-primary`，阴影
  /// 一动不动，见 `components/sider/*.tsx` 里 `match ? 'bg-primary' : ...`。
  final bool glowOnSelect;

  /// 一组设置项摆成什么形态。见 [ListSectionStyle]。
  final ListSectionStyle sectionStyle;

  /// 分组小标题长什么样。见 [SectionHeaderStyle]。
  final SectionHeaderStyle headerStyle;

  /// 分组内部分隔线的左内缩。
  ///
  /// Clash Party 是 16（分隔线从卡片内边距开始）；iOS 是 56——分隔线要从**文字**
  /// 开始，前面的图标位留空，这是 iOS 分组表最好认的一处细节。用不到分隔线的
  /// 风格（Fluent / Material You）写多少都无所谓。
  final double dividerInset;

  /// 开关未选中时画不画那圈描边。
  ///
  /// Fluent 的 ToggleSwitch 关闭态是「透明填充 + 一圈描边」，Material 3 也画描边；
  /// HeroUI 和 iOS 都是「实色轨道、不描边」。
  final bool switchOutline;

  /// [SelectionMode.indicator] 那条指示条的宽度。
  final double selectionIndicatorWidth;

  /// 取当前亮度该用的那一套。
  ///
  /// 深色返回自身，浅色返回把 [rim]/[cardShadow] 换成浅色版本的副本。调用点不必
  /// 自己判断亮度——[AppStyleContextExt.styleTokens] 会先过这里。
  ///
  /// 底色层不在这里换：它由 [surfacesFor] 在配色推导时就用掉了，不走主题扩展。
  AppStyleTokens resolve(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return this;
    }
    return copyWith(
      rim: rimLight,
      cardShadow: cardShadowLight,
      dividerColor: dividerColorLight,
    );
  }

  /// 当前亮度下的底色层。[resolve] 之后 [darkSurfaces] 里装的就是它。
  SurfacePalette? surfacesFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaces : lightSurfaces;

  // ── Clash Party ───────────────────────────────────────────────────
  /// 取值照抄桌面端用的 HeroUI 默认主题（`heroui()` 不带任何定制，所以就是
  /// 库的默认值）。每一项都能在桌面端源码里指到具体位置：
  ///
  /// - 底色：`@heroui/theme/dist/chunk-FFKHVGFX.mjs:45-78`
  ///   深色 background `#000000`、content1 `#18181b`、content2 `#27272a`、
  ///   content3 `#3f3f46`、foreground `#ECEDEE`、foreground-500 `#a1a1aa`；
  ///   浅色 background/content1 都是 `#FFFFFF`、content2 `#f4f4f5`、
  ///   content3 `#e4e4e7`、foreground `#11181C`、foreground-500 `#71717a`。
  /// - 圆角：`chunk-HUBDRSA4.mjs:17-21` radius large 14px（`Card` 默认
  ///   `radius: "lg"`，见 `components/card.js:380-388`）。
  /// - 阴影：`chunk-HUBDRSA4.mjs:27-42`，`Card` 默认 `shadow: "md"`。
  /// - 分隔线：`chunk-FFKHVGFX.mjs:60` `rgba(255,255,255,0.15)`。
  // ── 语义色 ──────────────────────────────────────────────────────
  //
  // 桌面端用的是 HeroUI 的默认语义色，深浅两种亮度下取值相同。之前安卓端这三个
  // 色是 Material 从蓝色种子推出来的——推出来的"危险色"是偏橙的红，和桌面端那
  // 个偏玫红的 #F31260 差得很远，而删除、断开、报错这些地方全在用它。
  //
  // 做成静态常量而不是 ThemeExtension 字段：四种风格用的是同一组值，加成字段要
  // 连带改构造、copyWith、lerp、== 和 hashCode 五处，不值。
  //
  // 注意 success 和 warning 配的是**黑**字：这两个色亮度很高，白字在上面几乎读
  // 不出来。桌面端也是黑字。

  /// 危险 / 错误。删除、断开、校验失败。
  static const danger = Color(0xFFF31260);
  static const onDanger = Color(0xFFFFFFFF);

  /// 成功 / 已连接。
  static const success = Color(0xFF17C964);
  static const onSuccess = Color(0xFF000000);

  /// 警告。
  static const warning = Color(0xFFF5A524);
  static const onWarning = Color(0xFF000000);

  static const clashParty = AppStyleTokens(
    style: AppStyle.clashParty,
    seed: Color(0xFF006FEE),
    cardRadius: 14,
    // 桌面端 radius-medium = 12px（`chunk-HUBDRSA4.mjs:17-21`）。
    controlRadius: 12,
    selectionMode: SelectionMode.fill,
    // 桌面端 divider 是 rgba(255,255,255,0.15)，不是 0.10。
    dividerOpacity: 0.15,
    schemeVariant: DynamicSchemeVariant.fidelity,
    // 2/255。**不是** 0.15——见 [rimLight] 上面那张实测表：桌面端那层内阴影带
    // 1px 模糊，糊完只把边缘抬高 2/255；照 0.15 画实线边框会抬高 34/255。
    rim: Color(0x02FFFFFF),
    // 深色 shadow-medium：
    //   0 0 15px rgb(0 0 0/.06), 0 2px 30px rgb(0 0 0/.22)
    // 透明度换算：.06*255≈15=0x0F、.22*255≈56=0x38。
    // 模糊半径直接照搬 15/30——Flutter 与 Chromium 走的是同一个 Skia 换算
    // （sigma = 0.57735*r + 0.5），实测两边落差不超过 2/255，见 desktop_parity_test。
    cardShadow: [
      BoxShadow(color: Color(0x0F000000), blurRadius: 15),
      BoxShadow(color: Color(0x38000000), blurRadius: 30, offset: Offset(0, 2)),
    ],
    // 浅色 shadow-medium 是**另一组**值：
    //   0 0 15px rgb(0 0 0/.03), 0 2px 30px rgb(0 0 0/.08), 0 0 1px rgb(0 0 0/.3)
    // 注意第三层在浅色下**不是** inset，是贴着边的一条外发丝线，所以在这里当
    // 阴影画（[rimLight] 因此是全透明，不再画边框）。
    cardShadowLight: [
      BoxShadow(color: Color(0x08000000), blurRadius: 15),
      BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 2)),
      // 第三层那条发丝线的模糊半径**不是 1**，是一个「大于 0 的极小值」。
      // Flutter 的换算是 sigma = r > 0 ? r*0.57735 + 0.5 : 0，也就是：
      //   · 写 1   → sigma 1.08，比 Chrome 糊得宽，紧贴边缘实测 111（应为 117）
      //   · 写 0   → sigma 0，完全不模糊，变成一条 30% 的硬黑边，暗到 90 上下
      //   · 写极小值 → 落在 sigma 下限 0.5，实测 **117**，和 Chrome 一模一样
      // 所以透明度照抄 CSS 的 0.3 不动，只把半径压到下限。**别把 0.01 改成 0**。
      BoxShadow(color: Color(0x4D000000), blurRadius: 0.01),
    ],
    rimLight: Color(0x00000000),
    darkSurfaces: SurfacePalette(
      surface: Color(0xFF000000),
      containerLow: Color(0xFF18181B),
      container: Color(0xFF18181B),
      containerHigh: Color(0xFF27272A),
      containerHighest: Color(0xFF3F3F46),
      onSurface: Color(0xFFECEDEE),
      onSurfaceVariant: Color(0xFFA1A1AA),
      outlineVariant: Color(0xFF3F3F46),
    ),
    // 桌面端浅色的卡片和页面**都是纯白**，靠阴影区分层次——这也是为什么浅色的
    // 阴影必须单独给一套，之前套用深色那组会重得离谱。
    lightSurfaces: SurfacePalette(
      // 页面底色用 content2 (#F4F4F5)，**不是**桌面端那个纯白。
      //
      // 桌面端 HeroUI light 里 background 和 content1 都是 #FFFFFF，我们最初照抄
      // 了。但桌面端是「窄侧边栏 + 大片内容区」，白卡片浮在白背景上还有边界感；
      // 手机上整屏铺满同一个白，磁贴和背景就糊成一片——用户的原话是「总感觉
      // 怪怪的」。
      //
      // 所以底色降一档、卡片保持纯白。取值仍来自 HeroUI 自己的色板（content2），
      // 不是随手挑的灰。
      surface: Color(0xFFF4F4F5),
      containerLow: Color(0xFFFFFFFF),
      container: Color(0xFFFFFFFF),
      containerHigh: Color(0xFFFFFFFF),
      containerHighest: Color(0xFFE4E4E7),
      onSurface: Color(0xFF11181C),
      onSurfaceVariant: Color(0xFF71717A),
      outlineVariant: Color(0xFFE4E4E7),
    ),
    glowOnSelect: true,
    sectionStyle: ListSectionStyle.card,
    headerStyle: SectionHeaderStyle.standard,
    dividerInset: 16,
    // HeroUI 的 Switch 关闭态是实心的 default-200 轨道，不画描边。
    switchOutline: false,
  );

  // ── Fluent ────────────────────────────────────────────────────────
  /// Windows 11 的云母灰：底 #202020、卡片 #2B2B2B，圆角方一档，
  /// 描边比 Clash Party 淡（Fluent 的边框是很轻的一道）。
  static const fluent = AppStyleTokens(
    style: AppStyle.fluent,
    seed: Color(0xFF0078D4),
    cardRadius: 4,
    controlRadius: 4,
    innerControlRadius: 2,
    selectionMode: SelectionMode.indicator,
    dividerOpacity: 0.14,
    dividerColor: Color(0x15FFFFFF),
    dividerColorLight: Color(0x0F000000),
    schemeVariant: DynamicSchemeVariant.fidelity,
    rim: Color(0x14FFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x3D000000), blurRadius: 2),
      BoxShadow(color: Color(0x47000000), blurRadius: 8, offset: Offset(0, 4)),
    ],
    // Fluent 浅色下的卡片边是很轻的一道黑，阴影也比深色淡。
    rimLight: Color(0x14000000),
    cardShadowLight: [
      BoxShadow(color: Color(0x1F000000), blurRadius: 2),
      BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 4)),
    ],
    darkSurfaces: SurfacePalette(
      surface: Color(0xFF202020),
      containerLow: Color(0xFF2B2B2B),
      container: Color(0xFF2B2B2B),
      containerHigh: Color(0xFF323232),
      containerHighest: Color(0xFF3D3D3D),
      onSurface: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFFC5C5C5),
      outlineVariant: Color(0xFF3D3D3D),
    ),
    // Windows 11 浅色的云母底是 #F3F3F3，卡片浮在上面是接近纯白的 #FBFBFB
    // ——这是「底色比卡片深」，和 Clash Party 浅色下「两者都是纯白、只靠阴影
    // 分层」正好相反。之前这里是 null，浅色下 Fluent 会退回 Material 从蓝种子
    // 推出来的带蓝味的灰，一点也不像 Windows。
    lightSurfaces: SurfacePalette(
      surface: Color(0xFFF3F3F3),
      containerLow: Color(0xFFFBFBFB),
      container: Color(0xFFFBFBFB),
      containerHigh: Color(0xFFF0F0F0),
      containerHighest: Color(0xFFE8E8E8),
      onSurface: Color(0xFF1B1B1B),
      onSurfaceVariant: Color(0xFF5D5D5D),
      outlineVariant: Color(0xFFE5E5E5),
    ),
    glowOnSelect: false,
    sectionStyle: ListSectionStyle.splitRows,
    headerStyle: SectionHeaderStyle.strong,
    // Fluent 的 ToggleSwitch 关闭态是「透明填充 + 一圈描边 + 小灰点」。
    switchOutline: true,
  );

  // ── iOS ───────────────────────────────────────────────────────────
  /// 纯黑底 + systemGray6，分隔线用 iOS 的 separator 色，不画卡片描边，
  /// 阴影也几乎没有——iOS 的分组列表靠底色差和分隔线区分层次。
  static const cupertino = AppStyleTokens(
    style: AppStyle.cupertino,
    seed: Color(0xFF0A84FF),
    cardRadius: 10,
    controlRadius: 9,
    innerControlRadius: 7,
    selectionMode: SelectionMode.check,
    dividerOpacity: 0.18,
    dividerColor: Color(0x99545458),
    dividerColorLight: Color(0x493C3C43),
    schemeVariant: DynamicSchemeVariant.fidelity,
    rim: Color(0x00000000),
    cardShadow: [],
    darkSurfaces: SurfacePalette(
      surface: Color(0xFF000000),
      containerLow: Color(0xFF1C1C1E),
      container: Color(0xFF1C1C1E),
      containerHigh: Color(0xFF2C2C2E),
      containerHighest: Color(0xFF3A3A3C),
      onSurface: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFF98989F),
      outlineVariant: Color(0xFF38383A),
    ),
    // iOS 浅色分组表：页面是 systemGroupedBackground #F2F2F7，分组卡片是纯白，
    // 分隔线是 separator #C6C6C8。同样是「底色比卡片深」。之前为 null，浅色下
    // 完全不像 iOS。
    lightSurfaces: SurfacePalette(
      surface: Color(0xFFF2F2F7),
      containerLow: Color(0xFFFFFFFF),
      container: Color(0xFFFFFFFF),
      containerHigh: Color(0xFFE5E5EA),
      containerHighest: Color(0xFFD1D1D6),
      onSurface: Color(0xFF000000),
      onSurfaceVariant: Color(0xFF6C6C70),
      outlineVariant: Color(0xFFC6C6C8),
    ),
    glowOnSelect: false,
    sectionStyle: ListSectionStyle.insetGrouped,
    headerStyle: SectionHeaderStyle.uppercase,
    // iOS 分组表的分隔线从**文字**开始，前面的图标位是空的。
    dividerInset: 56,
    // iOS 的开关不描边。
    switchOutline: false,
  );

  static AppStyleTokens of(AppStyle style) => switch (style) {
    AppStyle.clashParty => clashParty,
    AppStyle.fluent => fluent,
    AppStyle.cupertino => cupertino,
  };

  /// 用来做「填充式强调」的颜色。
  ///
  /// 不能直接用 `colorScheme.primary`：Material 在深色模式下会把纯蓝种子推成很浅
  /// 的淡紫蓝（色调 80），和设计稿里的实蓝差很远。所以一律用种子色本身。
  ///
  /// （曾经有一档 Material You 要跟随系统壁纸取色，是唯一的例外；那一档已删。）
  Color accent(ColorScheme scheme) => seed;

  /// 顶栏底下那条分隔线的颜色。
  ///
  /// 优先用风格自带的实测值（Fluent 的 `DividerStrokeColorDefault`、iOS 的
  /// `CupertinoColors.separator`），没有就按透明度从 `onSurface` 推。
  Color topBarDividerOf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return dividerColor ??
        scheme.onSurface.withValues(alpha: dividerOpacity);
  }

  /// 强调色之上的文字色。
  ///
  /// **只在底色确实是强调色时才用它。** 判断"选中的东西该用什么字色"请改用
  /// [selectedForeground]——四种风格里只有 `fill` 会把底色换成强调色。
  Color onAccent(ColorScheme scheme) => const Color(0xFFFFFFFF);

  /// 被选中的东西上面，文字和图标该用什么颜色。
  ///
  /// **必须跟着选中时的底色走，不能一律用 [onAccent]。** 四种选中方式里只有
  /// `fill` 真的把底色换成了强调色，另外三种底色几乎没变：
  ///
  /// | 选中方式 | 选中后的底色 | 该配的字色 |
  /// |---|---|---|
  /// | fill | 强调色 | onAccent |
  /// | tonal | secondaryContainer | onSecondaryContainer |
  /// | indicator | surfaceContainerHighest | onSurface |
  /// | check | 一点没变 | onSurface |
  ///
  /// 不分情况一律给 onAccent 的后果实测过：**iOS 风格 + 浅色模式下，选中的卡片
  /// 是白底白字，整块内容直接消失**；Fluent 和 Material You 也是浅底浅字，
  /// 勉强能看出个影。`app_style_test` 里「浅色模式下选中卡片的字读得出来」
  /// 那条就是钉这个的。
  Color selectedForeground(ColorScheme scheme) => switch (selectionMode) {
    SelectionMode.fill => onAccent(scheme),
    SelectionMode.tonal => scheme.onSecondaryContainer,
    SelectionMode.indicator || SelectionMode.check => scheme.onSurface,
  };

  /// 强调色控件往外冒的光。
  ///
  /// **只给仪表盘那颗启动按钮这类 Android 独有的大控件用，卡片不要用。**
  /// 桌面端没有任何发光：选中的卡片只是把底色换成 `bg-primary`，阴影仍是同一个
  /// `shadow-medium`（`components/sider/proxy-card.tsx:70` 等十几处都是
  /// `match ? 'bg-primary' : 'hover:bg-primary/30'`，没碰 shadow）。
  List<BoxShadow> accentGlow(ColorScheme scheme) {
    if (!glowOnSelect) {
      return cardShadow;
    }
    return [
      BoxShadow(
        color: accent(scheme).withValues(alpha: 0.45),
        blurRadius: 18,
        spreadRadius: -2,
      ),
      BoxShadow(
        color: accent(scheme).withValues(alpha: 0.20),
        blurRadius: 34,
        spreadRadius: 2,
      ),
    ];
  }

  @override
  AppStyleTokens copyWith({
    AppStyle? style,
    Color? seed,
    double? cardRadius,
    double? controlRadius,
    double? innerControlRadius,
    SelectionMode? selectionMode,
    double? dividerOpacity,
    Color? dividerColor,
    Color? dividerColorLight,
    DynamicSchemeVariant? schemeVariant,
    Color? rim,
    Color? rimLight,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? cardShadowLight,
    SurfacePalette? darkSurfaces,
    SurfacePalette? lightSurfaces,
    bool? glowOnSelect,
    ListSectionStyle? sectionStyle,
    SectionHeaderStyle? headerStyle,
    double? dividerInset,
    bool? switchOutline,
    double? selectionIndicatorWidth,
  }) {
    return AppStyleTokens(
      style: style ?? this.style,
      seed: seed ?? this.seed,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      innerControlRadius: innerControlRadius ?? this.innerControlRadius,
      selectionMode: selectionMode ?? this.selectionMode,
      dividerOpacity: dividerOpacity ?? this.dividerOpacity,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerColorLight: dividerColorLight ?? this.dividerColorLight,
      schemeVariant: schemeVariant ?? this.schemeVariant,
      rim: rim ?? this.rim,
      rimLight: rimLight ?? this.rimLight,
      cardShadow: cardShadow ?? this.cardShadow,
      cardShadowLight: cardShadowLight ?? this.cardShadowLight,
      darkSurfaces: darkSurfaces ?? this.darkSurfaces,
      lightSurfaces: lightSurfaces ?? this.lightSurfaces,
      glowOnSelect: glowOnSelect ?? this.glowOnSelect,
      sectionStyle: sectionStyle ?? this.sectionStyle,
      headerStyle: headerStyle ?? this.headerStyle,
      dividerInset: dividerInset ?? this.dividerInset,
      switchOutline: switchOutline ?? this.switchOutline,
      selectionIndicatorWidth:
          selectionIndicatorWidth ?? this.selectionIndicatorWidth,
    );
  }

  @override
  AppStyleTokens lerp(covariant AppStyleTokens? other, double t) {
    if (other == null) return this;
    // 圆角和描边可以插值做出过渡；枚举和底色只能跳变。
    return AppStyleTokens(
      style: t < 0.5 ? style : other.style,
      seed: Color.lerp(seed, other.seed, t) ?? seed,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      controlRadius: controlRadius + (other.controlRadius - controlRadius) * t,
      innerControlRadius: t < 0.5
          ? innerControlRadius
          : other.innerControlRadius,
      selectionMode: t < 0.5 ? selectionMode : other.selectionMode,
      dividerOpacity:
          dividerOpacity + (other.dividerOpacity - dividerOpacity) * t,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      dividerColorLight: Color.lerp(
        dividerColorLight,
        other.dividerColorLight,
        t,
      ),
      schemeVariant: t < 0.5 ? schemeVariant : other.schemeVariant,
      rim: Color.lerp(rim, other.rim, t) ?? rim,
      rimLight: Color.lerp(rimLight, other.rimLight, t) ?? rimLight,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      cardShadowLight: t < 0.5 ? cardShadowLight : other.cardShadowLight,
      darkSurfaces: t < 0.5 ? darkSurfaces : other.darkSurfaces,
      lightSurfaces: t < 0.5 ? lightSurfaces : other.lightSurfaces,
      glowOnSelect: t < 0.5 ? glowOnSelect : other.glowOnSelect,
      sectionStyle: t < 0.5 ? sectionStyle : other.sectionStyle,
      headerStyle: t < 0.5 ? headerStyle : other.headerStyle,
      dividerInset: dividerInset + (other.dividerInset - dividerInset) * t,
      switchOutline: t < 0.5 ? switchOutline : other.switchOutline,
      selectionIndicatorWidth:
          selectionIndicatorWidth +
          (other.selectionIndicatorWidth - selectionIndicatorWidth) * t,
    );
  }
}

/// 取当前风格的取值。主题里一定挂了，取不到就回落到默认风格。
///
/// 会按当前亮度先过一次 [AppStyleTokens.resolve]：桌面端的阴影和描边在深浅两种
/// 亮度下是两组不同的值，调用点不必自己判断。
extension AppStyleContextExt on BuildContext {
  AppStyleTokens get styleTokens {
    final theme = Theme.of(this);
    final tokens =
        theme.extension<AppStyleTokens>() ?? AppStyleTokens.clashParty;
    return tokens.resolve(theme.brightness);
  }
}
