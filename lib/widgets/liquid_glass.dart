import 'dart:ui';

import 'package:clash_party/common/render_capability.dart';
import 'package:flutter/material.dart';

/// 液态玻璃材质：模糊背景 + 半透明填充 + 边缘高光。
///
/// ## 这是仿的，不是真折射
///
/// 用户给的参考里，`QWEA0/Liquid-Glass-Android` 是**安卓原生的 AGSL 着色器**方案，
/// 要安卓 13 以上；那批 `liquid-glass-react` 之类是 **Web/Electron** 的，用 CSS
/// `backdrop-filter` 加 SVG 位移贴图。两条路这个应用都走不了——它是 Flutter，
/// 既不走安卓的绘制管线，也没有 CSS。
///
/// Flutter 能做到的是**磨砂玻璃**这一层：实时模糊背后的内容、压一层半透明色、
/// 沿上边缘描一道高光。苹果那种「边缘把背景掰弯」的折射需要位移贴图，
/// Flutter 的 `BackdropFilter` 只收 `ImageFilter`，给不了逐像素位移。
/// **所以这里明确只做磨砂 + 高光，不假装有折射。**
///
/// ## 按机器能力分档
///
/// 实时模糊是**逐帧重采样整块背景**，弱机上掉帧最明显的就是它。档位由
/// [RenderCapability] 按设备自己的回答定（低内存标记、物理内存、64 位 ABI），
/// 不按安卓版本号——版本号和性能没关系。
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.borderRadius,
    required this.child,
    this.tint,
    this.fallbackColor,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// 压在模糊之上的那层色。留空时按当前明暗自动取白/黑的低透明度。
  final Color? tint;

  /// 关闭档（不模糊）时用的不透明底色。
  ///
  /// 留空时取 `surfaceContainer`。调用点如果本来有自己的底色（比如底部弹层用的是
  /// `bottomSheetTheme` 那一档），必须传进来——否则弱机上弹层的头部会比它下面的
  /// 正文高一档色，看着像两块拼起来的。
  final Color? fallbackColor;

  /// 完整档的模糊半径。再大就糊成一片，看不出背后是什么，也就没有"玻璃"的意思了。
  static const _fullBlur = 24.0;
  static const _lightBlur = 12.0;

  @override
  Widget build(BuildContext context) {
    final tier = RenderCapability.effective(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (!tier.blurs) {
      // 不模糊时**必须给不透明底**：半透明而不模糊的话，背后的文字会直接透上来和
      // 前景叠在一起，比没有效果还糟。
      return DecoratedBox(
        decoration: BoxDecoration(
          color: fallbackColor ?? scheme.surfaceContainer,
          borderRadius: borderRadius,
        ),
        child: child,
      );
    }

    final blur = tier == RenderTier.full ? _fullBlur : _lightBlur;
    // 深色下压白、浅色下压白但更淡：玻璃是"提亮背后的东西"，两种明暗都靠白色。
    final fill =
        tint ?? (isDark ? const Color(0x2BFFFFFF) : const Color(0xB8FFFFFF));

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            // 上亮下暗的一道细边，模仿玻璃厚度在边缘的高光。只有完整档才画——
            // 减配档留着模糊就够了，多一层渐变边框是白花开销。
            border: tier == RenderTier.full
                ? Border.all(
                    color: isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x66FFFFFF),
                    width: 0.6,
                  )
                : null,
          ),
          child: tier == RenderTier.full
              ? _SpecularHighlight(borderRadius: borderRadius, child: child)
              : child,
        ),
      ),
    );
  }
}

/// 顶部那一道高光。
///
/// 玻璃的厚度会让上边缘比其余部分亮一些。用一条很短的渐变实现——**只到高度的
/// 三分之一**，铺满整块会变成"蒙了层白纱"，那是另一种材质了。
class _SpecularHighlight extends StatelessWidget {
  const _SpecularHighlight({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          // 高光只是装饰，不能吃掉点击——底下就是按钮。
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                  stops: [0, 0.34],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
